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
    @ObservationIgnored private var windowStart = Date()
    @ObservationIgnored private var windowFrames = 0

    public init(port: UInt16 = 11111) { self.port = port }

    public func start() {
        stop()
        guard let p = NWEndpoint.Port(rawValue: port), let l = try? NWListener(using: .udp, on: p) else { return }
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor in self?.accept(conn) }
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
        displayLayer.flushAndRemoveImage()
        fps = 0
        isListening = false
    }

    // MARK: internals

    private func accept(_ conn: NWConnection) {
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
        for nal in parser.feed([UInt8](data)) { handle(nal) }
    }

    private func handle(_ nal: NALUnit) {
        switch nal.type {
        case 7:
            if sps != nal.bytes { sps = nal.bytes; format = nil }
        case 8:
            if pps != nal.bytes { pps = nal.bytes; format = nil }
        case 1, 5:
            if format == nil { format = makeFormat() }
            guard let format, let sb = makeSample(nal.bytes, format: format) else { return }
            if displayLayer.sampleBufferRenderer.status == .failed { displayLayer.sampleBufferRenderer.flush() }
            displayLayer.sampleBufferRenderer.enqueue(sb)
            countFrame()
        default:
            break
        }
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

    private func makeSample(_ nal: [UInt8], format: CMVideoFormatDescription) -> CMSampleBuffer? {
        var avcc = [UInt8](repeating: 0, count: 4)
        let len = UInt32(nal.count).bigEndian
        withUnsafeBytes(of: len) { avcc.replaceSubrange(0..<4, with: $0) }
        avcc.append(contentsOf: nal)

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
