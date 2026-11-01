import Foundation

public enum SafetyStatus: Equatable, Sendable {
    case normal, warning, ceiling, over, noTelemetry
}

/// Limits upward throttle near the altitude ceiling. Pure logic, no I/O.
/// `over` latches once height exceeds `ceilingCM` and releases below `clampCM`.
public struct SafetyGovernor: Equatable, Sendable {
    public var ceilingCM: Int
    public var telemetryMaxAge: TimeInterval = 1.0
    public var descendThrottle: Float = -0.3
    private var overLatched = false

    public init(ceilingCM: Int = 305) { self.ceilingCM = ceilingCM }

    /// Height where upward throttle starts to taper (8 ft at the default ceiling).
    public var warnCM: Int { ceilingCM - 65 }
    /// Height where upward throttle reaches zero.
    public var clampCM: Int { ceilingCM - 15 }

    public mutating func apply(_ input: DroneSticks, heightCM: Int?, telemetryAge: TimeInterval?)
        -> (sticks: DroneSticks, status: SafetyStatus) {
        var out = input
        guard let h = heightCM, let age = telemetryAge, age <= telemetryMaxAge else {
            out.throttle = min(out.throttle, 0)
            return (out, .noTelemetry)
        }
        if h > ceilingCM { overLatched = true } else if h < clampCM { overLatched = false }
        if overLatched {
            out.throttle = descendThrottle
            return (out, .over)
        }
        if h >= clampCM {
            out.throttle = min(out.throttle, 0)
            return (out, .ceiling)
        }
        if h >= warnCM {
            if out.throttle > 0 {
                out.throttle *= Float(clampCM - h) / Float(clampCM - warnCM)
            }
            return (out, .warning)
        }
        return (out, .normal)
    }

    public mutating func reset() { overLatched = false }
}
