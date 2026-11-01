import AVFoundation
import CoreMedia
import Foundation
import Observation

/// Receives the Tello H.264 Annex B stream on UDP 11111 and renders it into `displayLayer`.
/// Socket read, NAL parsing and sample building run on a private queue; observed stats
/// publish to the main actor at most 4 times per second.
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

    /// Test hook: called with every sample buffer before it is enqueued (on the decode queue for UDP input).
    @ObservationIgnored public nonisolated(unsafe) var onSample: ((CMSampleBuffer) -> Void)?

    @ObservationIgnored private let core: VideoCore
    @ObservationIgnored private var receiver: UDPSocketReceiver?
    @ObservationIgnored private var publishTimer: Timer?

    public init(port: UInt16 = 11111) {
        self.port = port
        core = VideoCore(renderer: displayLayer.sampleBufferRenderer)
    }

    /// Idempotent: a live socket is kept. Each new session binds a fresh socket.
    public func start() {
        if receiver != nil { return }
        core.queue.sync { core.reset() }
        displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
        let core = core
        guard let r = UDPSocketReceiver(port: port, queue: core.queue, onData: { [weak self] bytes in
            core.process(bytes, onSample: self?.onSample)
        }) else {
            FileLog.shared.write("video", "bind failed on \(port); retry")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.start()
            }
            return
        }
        receiver = r
        isListening = true
        FileLog.shared.write("video", "listening udp \(port)")
        publishTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
    }

    public func stop() {
        receiver?.cancel(); receiver = nil
        publishTimer?.invalidate(); publishTimer = nil
        core.queue.sync { core.reset() }
        displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
        fps = 0
        bytesPerSecond = 0
        lastFrameAt = nil
        isListening = false
    }

    /// Public for tests and replay: feed raw stream bytes synchronously.
    public func ingest(_ data: Data) {
        let bytes = [UInt8](data)
        let cb = onSample
        core.queue.sync { core.process(bytes, onSample: cb) }
        publish()
    }

    /// Sends the assembled access unit now instead of waiting for the next one.
    public func flushPending() {
        let cb = onSample
        core.queue.sync { core.flush(onSample: cb) }
        publish()
    }

    private func publish() {
        let s = core.queue.sync { core.snapshot() }
        if framesDecoded != s.frames { framesDecoded = s.frames }
        if totalBytes != s.bytes { totalBytes = s.bytes }
        if nalCounts != s.nals { nalCounts = s.nals }
        if fps != s.fps { fps = s.fps }
        if bytesPerSecond != s.bps { bytesPerSecond = s.bps }
        if lastFrameAt != s.lastFrameAt { lastFrameAt = s.lastFrameAt }
    }
}

/// Decode state owned by `queue`.
final class VideoCore: @unchecked Sendable {
    struct Snapshot { var frames: Int; var bytes: Int; var nals: [Int: Int]; var fps: Double; var bps: Double; var lastFrameAt: Date? }

    let queue = DispatchQueue(label: "tello.video", qos: .userInteractive)
    private let renderer: AVSampleBufferVideoRenderer
    private var assembler = H264FrameAssembler()
    private var frames = 0
    private var bytes = 0
    private var nals: [Int: Int] = [:]
    private var fps: Double = 0
    private var bps: Double = 0
    private var lastFrameAt: Date?
    private var windowStart = Date(), windowFrames = 0
    private var byteWindowStart = Date(), byteWindow = 0

    init(renderer: AVSampleBufferVideoRenderer) { self.renderer = renderer }

    /// Parser state only; counters keep running so callers can compare against a base.
    func reset() {
        nals.merge(assembler.nalCounts, uniquingKeysWith: +)
        assembler = H264FrameAssembler()
        fps = 0; bps = 0; lastFrameAt = nil
        windowStart = Date(); windowFrames = 0
        byteWindowStart = Date(); byteWindow = 0
    }

    func process(_ data: [UInt8], onSample: ((CMSampleBuffer) -> Void)?) {
        countBytes(data.count)
        enqueue(assembler.feed(data), onSample)
    }

    func flush(onSample: ((CMSampleBuffer) -> Void)?) { enqueue(assembler.flush(), onSample) }

    func snapshot() -> Snapshot {
        Snapshot(frames: frames, bytes: bytes, nals: nals.merging(assembler.nalCounts, uniquingKeysWith: +),
                 fps: fps, bps: bps, lastFrameAt: lastFrameAt)
    }

    private func enqueue(_ samples: [CMSampleBuffer], _ onSample: ((CMSampleBuffer) -> Void)?) {
        for sb in samples {
            onSample?(sb)
            if renderer.status == .failed { renderer.flush() }
            renderer.enqueue(sb)
            countFrame()
        }
    }

    private func countBytes(_ n: Int) {
        bytes += n
        byteWindow += n
        let now = Date()
        let dt = now.timeIntervalSince(byteWindowStart)
        if dt >= 1 { bps = Double(byteWindow) / dt; byteWindow = 0; byteWindowStart = now }
    }

    private func countFrame() {
        frames += 1
        let now = Date()
        lastFrameAt = now
        windowFrames += 1
        let dt = now.timeIntervalSince(windowStart)
        if dt >= 1 { fps = Double(windowFrames) / dt; windowFrames = 0; windowStart = now }
    }
}
