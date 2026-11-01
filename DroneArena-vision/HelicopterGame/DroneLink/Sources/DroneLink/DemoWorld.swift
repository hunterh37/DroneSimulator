import CoreGraphics
import Foundation

/// Simulated drone and light poles for running the obstacle pipeline without hardware.
/// Produces the same camera detections the vision scanner would and integrates sticks into a pose.
public struct DemoWorld: Sendable {
    public struct Pole: Sendable, Equatable {
        public var at: SIMD2<Double>
        public var widthM = 0.25
    }

    public var pose = DronePose(heightM: 1.2)
    public var poles: [Pole] = [Pole(at: SIMD2(3.5, 0.3)), Pole(at: SIMD2(6, -1.6)), Pole(at: SIMD2(5, 2.4))]
    public var maxSpeed = 1.2
    public private(set) var speedCMS = 0.0

    public init() {}

    public mutating func step(_ s: DroneSticks, dt: Double) {
        let f = Double(s.pitch) * maxSpeed * dt
        let r = Double(s.roll) * maxSpeed * dt
        let p = pose.toWorld(forward: f, right: r)
        // Bounce off poles instead of passing through.
        if !poles.contains(where: { simd_len($0.at - p) < 0.2 }) { pose.x = p.x; pose.y = p.y }
        pose.yaw += Double(s.yaw) * 1.5 * dt
        speedCMS = max(0, Double(s.pitch)) * maxSpeed * 100
    }

    /// Drops a new pole `ahead` meters in front of the drone, offset slightly toward `toward`.
    public mutating func popUp(ahead: Double = 2.2) {
        poles.append(Pole(at: pose.toWorld(forward: ahead, right: 0.1)))
    }

    public func detections() -> [ObstacleDetection] {
        poles.compactMap { pole in
            let b = pose.toBody(pole.at)
            guard b.x > 0.3, b.x < 9 else { return nil }
            let x = 0.5 + TelloCamera.fx * b.y / b.x
            let w = TelloCamera.widthNorm(realM: pole.widthM, rangeM: b.x)
            guard x + w / 2 > 0, x - w / 2 < 1 else { return nil }
            // Pole runs from ground to 4 m.
            let top = 0.5 - TelloCamera.fy * (4 - pose.heightM) / b.x
            let bottom = 0.5 + TelloCamera.fy * pose.heightM / b.x
            let y0 = max(0, top), y1 = min(1, bottom)
            return ObstacleDetection(rect: CGRect(x: x - w / 2, y: y0, width: w, height: y1 - y0), kind: .pole)
        }
    }
}
