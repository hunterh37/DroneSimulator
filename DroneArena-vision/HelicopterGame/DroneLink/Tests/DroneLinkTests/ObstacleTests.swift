import CoreGraphics
import Foundation
import Testing
@testable import DroneLink

struct ObstacleTests {
    @Test func cameraRangeRoundTrips() {
        let w = TelloCamera.widthNorm(realM: 0.25, rangeM: 3)
        #expect(abs(TelloCamera.range(widthNorm: w, realM: 0.25) - 3) < 1e-6)
        #expect(TelloCamera.bearing(x: 0.5) == 0)
    }

    @Test func approachingPoleEscalatesToBrake() {
        var t = ObstacleTracker()
        var out: [Obstacle] = []
        var range = 6.0
        for k in 0..<40 {
            let w = TelloCamera.widthNorm(realM: 0.25, rangeM: range)
            let d = ObstacleDetection(rect: CGRect(x: 0.5 - w / 2, y: 0.1, width: w, height: 0.8), kind: .pole)
            out = t.update([d], at: Double(k) * 0.1, speedCMS: 150)
            range -= 0.15
        }
        #expect(out.first?.threat == .brake)
        #expect(out.first?.inPath == true)
    }

    @Test func offPathObjectIsClear() {
        var t = ObstacleTracker()
        let d = ObstacleDetection(rect: CGRect(x: 0.02, y: 0.4, width: 0.1, height: 0.2), kind: .object)
        _ = t.update([d], at: 0, speedCMS: 0)
        let out = t.update([d], at: 0.1, speedCMS: 0)
        #expect(out.first?.threat == .clear)
    }

    @Test func poleDetectorFindsDarkColumn() {
        let w = 320, h = 240
        var px = [UInt8](repeating: 200, count: w * h)
        for y in 10..<230 { for x in 150..<170 { px[y * w + x] = 30 } }
        let dets = px.withUnsafeBufferPointer { PoleDetector().detect(luma: $0, width: w, height: h, stride: w) }
        let pole = try! #require(dets.first)
        #expect(pole.kind == .pole)
        #expect(abs(pole.rect.midX - 0.5) < 0.05)
        #expect(pole.rect.height > 0.6)
    }

    @Test func poleDetectorIgnoresFlatImage() {
        let px = [UInt8](repeating: 120, count: 160 * 120)
        let dets = px.withUnsafeBufferPointer { PoleDetector().detect(luma: $0, width: 160, height: 120, stride: 160) }
        #expect(dets.isEmpty)
    }
}

struct PathPlannerTests {
    @Test func detoursAroundBlockingPole() {
        let pole = WorldObstacle(id: 1, kind: .pole, center: SIMD2(2, 0), radius: 0.15, heightM: 3, seenAt: 0)
        let path = PathPlanner.plan(from: SIMD2(0, 0), to: SIMD2(4, 0), obstacles: [pole])
        #expect(path.count >= 4)
        for (a, b) in zip(path, path.dropFirst()) {
            #expect(PathPlanner.firstBlock(a, b, [pole], 0.4) == nil)
        }
    }

    @Test func straightWhenClear() {
        let path = PathPlanner.plan(from: SIMD2(0, 0), to: SIMD2(4, 0), obstacles: [])
        #expect(path.count == 2)
    }

    @Test func demoFlightReachesTargetWithoutHitting() {
        var w = DemoWorld()
        var tracker = ObstacleTracker()
        var mem = ObstacleMemory()
        var f = PathFollower()
        let goal = SIMD2(8.0, 0.5)
        var minGap = Double.infinity
        for k in 0..<600 {
            let t = Double(k) / 30
            let obs = tracker.update(w.detections(), at: t, speedCMS: w.speedCMS)
            if mem.ingest(obs, pose: w.pose, at: t) || f.path.isEmpty {
                f.set(PathPlanner.plan(from: w.pose.xy, to: goal, obstacles: mem.items))
            }
            w.step(f.sticks(pose: w.pose), dt: 1.0 / 30)
            for p in w.poles { minGap = min(minGap, simd_len(p.at - w.pose.xy)) }
            if f.isDone { break }
        }
        #expect(simd_len(w.pose.xy - goal) < 0.5)
        #expect(minGap > 0.2)
    }
}
