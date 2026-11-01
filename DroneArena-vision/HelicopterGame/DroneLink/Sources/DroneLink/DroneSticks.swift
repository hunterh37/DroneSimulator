import Foundation

/// Mode 2 stick state, each axis -1...1.
/// left.x = yaw (+ clockwise), left.y = throttle (+ up),
/// right.x = roll (+ right), right.y = pitch (+ forward).
public struct DroneSticks: Equatable, Sendable {
    public var yaw: Float
    public var throttle: Float
    public var roll: Float
    public var pitch: Float

    public static let zero = DroneSticks(yaw: 0, throttle: 0, roll: 0, pitch: 0)

    public init(yaw: Float, throttle: Float, roll: Float, pitch: Float) {
        self.yaw = yaw
        self.throttle = throttle
        self.roll = roll
        self.pitch = pitch
    }

    /// Tello `rc a b c d` values: a=roll, b=pitch, c=throttle, d=yaw, each -limit...limit.
    /// `minOutput` (0...1) is the fraction of `limit` sent at the first step past the deadzone.
    /// The Tello barely moves below rc ~15, so small stick moves would otherwise look dead.
    public func rcValues(limit: Int = 100, deadzone: Float = 0.05, minOutput: Float = 0) -> (Int, Int, Int, Int) {
        func scale(_ v: Float) -> Int {
            let c = max(-1, min(1, v.isFinite ? v : 0))
            guard abs(c) > deadzone else { return 0 }
            let raw = (abs(c) - deadzone) / (1 - deadzone)
            let n = minOutput + (1 - minOutput) * raw
            return Int((n * Float(limit)).rounded()) * (c < 0 ? -1 : 1)
        }
        return (scale(roll), scale(pitch), scale(throttle), scale(yaw))
    }

    public func rcCommand(limit: Int = 100, deadzone: Float = 0.05, minOutput: Float = 0) -> String {
        let (a, b, c, d) = rcValues(limit: limit, deadzone: deadzone, minOutput: minOutput)
        return "rc \(a) \(b) \(c) \(d)"
    }
}
