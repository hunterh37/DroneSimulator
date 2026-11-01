#if os(visionOS)
import CoreMedia
import DroneLink
import Foundation
import QuartzCore
import Vision
import VideoToolbox

/// Decodes the Tello H.264 samples and scans frames at `scanHz` for obstacles:
/// PoleDetector (vertical structures) plus Vision objectness saliency (anything popping up).
/// Results land on the main actor through `onDetections`.
final class ObstacleScanner: @unchecked Sendable {
    var scanHz = 10.0
    var onDetections: (@MainActor ([ObstacleDetection], Double) -> Void)?

    private let lock = NSLock()
    private var session: VTDecompressionSession?
    private var format: CMFormatDescription?
    private var lastScan = 0.0
    private var busy = false
    private let queue = DispatchQueue(label: "obstacle-scan", qos: .userInitiated)
    private let poles = PoleDetector()

    func decode(_ sample: CMSampleBuffer) {
        guard let fd = CMSampleBufferGetFormatDescription(sample) else { return }
        lock.lock(); defer { lock.unlock() }
        if session == nil || format.map({ !CMFormatDescriptionEqual($0, otherFormatDescription: fd) }) ?? true {
            makeSession(fd)
        }
        guard let session else { return }
        VTDecompressionSessionDecodeFrame(session, sampleBuffer: sample,
                                          flags: [._EnableAsynchronousDecompression],
                                          infoFlagsOut: nil) { [weak self] status, _, image, _, _ in
            guard status == noErr, let image else { return }
            self?.offer(image)
        }
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        if let session { VTDecompressionSessionInvalidate(session) }
        session = nil; format = nil
    }

    private func makeSession(_ fd: CMFormatDescription) {
        if let session { VTDecompressionSessionInvalidate(session) }
        session = nil
        let attrs: [CFString: Any] = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        var s: VTDecompressionSession?
        if VTDecompressionSessionCreate(allocator: nil, formatDescription: fd, decoderSpecification: nil,
                                        imageBufferAttributes: attrs as CFDictionary, outputCallback: nil,
                                        decompressionSessionOut: &s) == noErr {
            session = s; format = fd
        }
    }

    private func offer(_ image: CVPixelBuffer) {
        let now = CACurrentMediaTime()
        lock.lock()
        guard !busy, now - lastScan >= 1 / scanHz else { lock.unlock(); return }
        busy = true; lastScan = now
        lock.unlock()
        nonisolated(unsafe) let px = image
        queue.async { [weak self] in
            guard let self else { return }
            let start = CACurrentMediaTime()
            let dets = self.scan(px)
            let ms = (CACurrentMediaTime() - start) * 1000
            self.lock.lock(); self.busy = false; self.lock.unlock()
            let cb = self.onDetections
            Task { @MainActor in cb?(dets, ms) }
        }
    }

    private func scan(_ px: CVPixelBuffer) -> [ObstacleDetection] {
        var out: [ObstacleDetection] = []
        CVPixelBufferLockBaseAddress(px, .readOnly)
        if let base = CVPixelBufferGetBaseAddressOfPlane(px, 0) {
            let w = CVPixelBufferGetWidthOfPlane(px, 0), h = CVPixelBufferGetHeightOfPlane(px, 0)
            let stride = CVPixelBufferGetBytesPerRowOfPlane(px, 0)
            let buf = UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: stride * h)
            out = poles.detect(luma: buf, width: w, height: h, stride: stride)
        }
        CVPixelBufferUnlockBaseAddress(px, .readOnly)

        let req = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cvPixelBuffer: px, options: [:]).perform([req])
        let salient = (req.results?.first?.salientObjects ?? []).filter { $0.confidence > 0.3 }
        for s in salient {
            let b = s.boundingBox
            let r = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
            let area = r.width * r.height
            guard area > 0.004, area < 0.85 else { continue }
            if out.contains(where: { ObstacleScanner.iou($0.rect, r) > 0.3 }) { continue }
            out.append(ObstacleDetection(rect: r, kind: area > 0.35 ? .wall : .object, confidence: s.confidence))
        }
        return out
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        guard !i.isNull else { return 0 }
        let inter = i.width * i.height
        return inter / (a.width * a.height + b.width * b.height - inter)
    }
}
#endif
