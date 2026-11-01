import AVFoundation
import CoreMedia
import Foundation
import Network
import Observation

/// Receives the Tello H.264 Annex B stream on UDP 11111 and renders it into `displayLayer`.
/// Start the drone side with `TelloLink.startVideo()` (sends `streamon`).
@MainActor @Observable
public final class TelloVideoStream {
    public private(set) var fps: Double = 0
    public private(set) var framesDecoded: Int = 0
    public private(set) var lastFrameAt: Date?
    public private(set) var isListening = false
    /// NAL unit counts by type (1 slice, 5 IDR, 7 SPS, 8 PPS).
    public private(set) var nalCounts: [Int: Int] = [:]
    public private(set) var totalBytes = 0
    /// Received bytes per second over the last full second.
    public private(set) var bytesPerSecond: Double = 0

    @ObservationIgnored public let displayLayer: AVSampleBufferDisplayLayer = {
        let l = AVSampleBufferDisplayLayer()
        l.videoGravity = .resizeAspect
        return l
    }()

    public let port: UInt16

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var conns: [NWConnection] = []
    @ObservationIgnored private var parser = H264NALParser()
    @ObservationIgnored private var sps: [UInt8]?
    @ObservationIgnored private var pps: [UInt8]?
    @ObservationIgnored private var format: CMVideoFormatDescription?
    /// Slices of the access unit being assembled. Tello can split one frame into several slices.
    @ObservationIgnored private var pendingSlices: [[UInt8]] = []
    /// Test hook: called with every sample buffer before it is enqueued.
    @ObservationIgnored public var onSample: ((CMSampleBuffer) -> Void)?
    @ObservationIgnored private var windowStart = Date()
    @ObservationIgnored private var windowFrames = 0
    @ObservationIgnored private var byteWindowStart = Date()
    @ObservationIgnored private var byteWindow = 0

    public init(port: UInt16 = 11111) { self.port = port }

    /// Idempotent: a live listener is kept. Rebinding 11111 while the old socket is
    /// still closing fails silently, which showed as a permanent NO SIGNAL.
    public func start() {
        if listener != nil, isListening { return }
        stop()
        guard let p = NWEndpoint.Port(rawValue: port) else { return }
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        guard let l = try? NWListener(using: params, on: p) else {
            FileLog.shared.write("video", "listener create failed on \(port)")
            return
        }
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.accept(conn) }
        }
        l.stateUpdateHandler = { [weak self] st in
            Task { @MainActor in
                guard let self, self.listener === l else { return }
                switch st {
                case .ready:
                    FileLog.shared.write("video", "listening udp \(self.port)")
                case .failed(let e):
                    FileLog.shared.write("video", "listener failed \(e); retry")
                    self.listener = nil
                    self.isListening = false
                    l.cancel()
                    try? await Task.sleep(for: .milliseconds(500))
                    self.start()
                default:
                    break
                }
            }
        }
        l.start(queue: .main)
        listener = l
        isListening = true
    }

    public func stop() {
        listener?.cancel(); listener = nil
        conns.forEach { $0.cancel() }
        conns.removeAll()
        parser = H264NALParser()
        sps = nil; pps = nil; format = nil
        pendingSlices.removeAll()
        displayLayer.flushAndRemoveImage()
        fps = 0
        bytesPerSecond = 0
        isListening = false
    }

    // MARK: internals

    private func accept(_ conn: NWConnection) {
        FileLog.shared.write("video", "stream from \(conn.endpoint)")
        conns.append(conn)
        conn.start(queue: .main)
        read(conn)
    }

    nonisolated private func read(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data { Task { @MainActor in self?.ingest(data) } }
            if error == nil { self?.read(conn) }
        }
    }

    /// Public for tests and replay: feed raw stream bytes.
    public func ingest(_ data: Data) {
        countBytes(data.count)
        for nal in parser.feed([UInt8](data)) { handle(nal) }
    }

    private func countBytes(_ n: Int) {
        totalBytes += n
        byteWindow += n
        let now = Date()
        let dt = now.timeIntervalSince(byteWindowStart)
        if dt >= 1 {
            bytesPerSecond = Double(byteWindow) / dt
            byteWindow = 0
            byteWindowStart = now
        }
    }

    private func handle(_ nal: NALUnit) {
        nalCounts[Int(nal.type), default: 0] += 1
        switch nal.type {
        case 7:
            flushFrame()
            if sps != nal.bytes { sps = nal.bytes; format = nil }
        case 8:
            flushFrame()
            if pps != nal.bytes { pps = nal.bytes; format = nil }
        case 1, 5:
            // first_mb_in_slice == 0 (ue(v) "1" bit) starts a new picture.
            if nal.bytes.count > 1, nal.bytes[1] & 0x80 != 0 { flushFrame() }
            pendingSlices.append(nal.bytes)
        case 9:
            flushFrame()
        default:
            break
        }
    }

    /// Sends the assembled access unit now instead of waiting for the next one.
    public func flushPending() {
        for nal in parser.flush() { handle(nal) }
        flushFrame()
    }

    private func flushFrame() {
        guard !pendingSlices.isEmpty else { return }
        let slices = pendingSlices
        pendingSlices.removeAll()
        if format == nil { format = makeFormat() }
        guard let format else {
            if framesDecoded == 0 { FileLog.shared.write("video", "no SPS/PPS yet, frame dropped") }
            return
        }
        guard let sb = makeSample(slices, format: format) else {
            FileLog.shared.write("video", "sample build failed")
            return
        }
        if framesDecoded == 0 { FileLog.shared.write("video", "first frame") }
        onSample?(sb)
        if displayLayer.sampleBufferRenderer.status == .failed { displayLayer.sampleBufferRenderer.flush() }
        displayLayer.sampleBufferRenderer.enqueue(sb)
        countFrame()
    }

    private func makeFormat() -> CMVideoFormatDescription? {
        guard let sps, let pps else { return nil }
        var fd: CMFormatDescription?
        let status = sps.withUnsafeBufferPointer { s in
            pps.withUnsafeBufferPointer { p in
                let ptrs = [s.baseAddress!, p.baseAddress!]
                let sizes = [s.count, p.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil, parameterSetCount: 2,
                    parameterSetPointers: ptrs, parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4, formatDescriptionOut: &fd)
            }
        }
        return status == noErr ? fd : nil
    }

    private func makeSample(_ slices: [[UInt8]], format: CMVideoFormatDescription) -> CMSampleBuffer? {
        var avcc: [UInt8] = []
        for nal in slices {
            withUnsafeBytes(of: UInt32(nal.count).bigEndian) { avcc.append(contentsOf: $0) }
            avcc.append(contentsOf: nal)
        }

        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: nil, memoryBlock: nil, blockLength: avcc.count, blockAllocator: nil,
            customBlockSource: nil, offsetToData: 0, dataLength: avcc.count, flags: 0,
            blockBufferOut: &block) == noErr, let block else { return nil }
        guard avcc.withUnsafeBytes({
            CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: avcc.count)
        }) == noErr else { return nil }

        var sample: CMSampleBuffer?
        var size = avcc.count
        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid)
        guard CMSampleBufferCreateReady(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr,
              let sample else { return nil }
        if let arr = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(arr) > 0 {
            let d = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(d, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }

    private func countFrame() {
        framesDecoded += 1
        let now = Date()
        lastFrameAt = now
        windowFrames += 1
        let dt = now.timeIntervalSince(windowStart)
        if dt >= 1 {
            fps = Double(windowFrames) / dt
            windowFrames = 0
            windowStart = now
        }
    }
}
