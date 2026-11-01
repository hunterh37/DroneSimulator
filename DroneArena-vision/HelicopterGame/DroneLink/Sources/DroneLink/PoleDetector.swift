import CoreGraphics
import Foundation

/// Finds tall vertical structures (light poles, posts, door frames, wall edges) in a luma plane.
/// Samples a coarse grid, marks cells with strong horizontal gradient, keeps columns with long
/// vertical runs, and groups neighboring edge columns into pole boxes.
public struct PoleDetector: Sendable {
    public var gridW = 96
    public var gridH = 72
    public var edgeThreshold = 28
    /// Minimum run length as a fraction of image height.
    public var minRun = 0.35
    /// Max pole width as a fraction of image width.
    public var maxWidth = 0.18

    public init() {}

    /// `luma` is row-major 8 bit, `stride` bytes per row.
    public func detect(luma: UnsafeBufferPointer<UInt8>, width: Int, height: Int, stride: Int) -> [ObstacleDetection] {
        guard width > 8, height > 8, luma.count >= stride * height else { return [] }
        let gw = gridW, gh = gridH
        var g = [Int](repeating: 0, count: gw * gh)
        for gy in 0..<gh {
            let row = (gy * (height - 1)) / (gh - 1) * stride
            for gx in 0..<gw { g[gy * gw + gx] = Int(luma[row + (gx * (width - 1)) / (gw - 1)]) }
        }
        // Vertical edge mask: strong |dx| that dominates |dy|.
        var runs: [(start: Int, end: Int)?] = Array(repeating: nil, count: gw)
        for gx in 1..<(gw - 1) {
            var best = (0, -1), cur = 0, gap = 0
            for gy in 1..<(gh - 1) {
                let dx = abs(g[gy * gw + gx + 1] - g[gy * gw + gx - 1])
                let dy = abs(g[(gy + 1) * gw + gx] - g[(gy - 1) * gw + gx])
                if dx > edgeThreshold, dx > dy * 2 {
                    if cur == 0 { cur = gy }
                    gap = 0
                    if gy - cur > best.1 - best.0 { best = (cur, gy) }
                } else if cur != 0 {
                    gap += 1
                    if gap > 2 { cur = 0; gap = 0 }
                }
            }
            if Double(best.1 - best.0) >= minRun * Double(gh) { runs[gx] = (best.0, best.1) }
        }
        // Group edge columns into clusters, then pair clusters into poles.
        var clusters: [(x0: Int, x1: Int, y0: Int, y1: Int)] = []
        for gx in 0..<gw {
            guard let r = runs[gx] else { continue }
            if var last = clusters.last, gx - last.x1 <= 1 {
                last.x1 = gx; last.y0 = min(last.y0, r.start); last.y1 = max(last.y1, r.end)
                clusters[clusters.count - 1] = last
            } else {
                clusters.append((gx, gx, r.start, r.end))
            }
        }
        let maxW = Int(maxWidth * Double(gw))
        var out: [ObstacleDetection] = []
        var i = 0
        while i < clusters.count {
            let a = clusters[i]
            if i + 1 < clusters.count, clusters[i + 1].x1 - a.x0 <= maxW {
                let b = clusters[i + 1]
                out.append(box(a.x0, b.x1, min(a.y0, b.y0), max(a.y1, b.y1), .pole))
                i += 2
            } else {
                out.append(box(a.x0, a.x1 + 1, a.y0, a.y1, .wall))
                i += 1
            }
        }
        return Array(out.sorted { $0.rect.height > $1.rect.height }.prefix(4))
    }

    private func box(_ x0: Int, _ x1: Int, _ y0: Int, _ y1: Int, _ kind: ObstacleKind) -> ObstacleDetection {
        let w = CGFloat(gridW - 1), h = CGFloat(gridH - 1)
        let r = CGRect(x: CGFloat(x0) / w, y: CGFloat(y0) / h,
                       width: max(CGFloat(x1 - x0), 1) / w, height: CGFloat(y1 - y0) / h)
        return ObstacleDetection(rect: r, kind: kind, confidence: Float(min(1, r.height)))
    }
}
