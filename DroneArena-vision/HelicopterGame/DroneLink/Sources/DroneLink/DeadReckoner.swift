import Foundation

public enum ReturnStatus: Equatable, Sendable {
    case idle, returning, arrived, pilotTookOver, positionLost, timedOut
}

/// How the Tello's `vgx`, `vgy` and `yaw` map onto forward, right and clockwise.
/// The SDK docs do not state the frame or signs, so these are measured in flight.
public struct VelocityCalibration: Equatable, Sendable {
    public var bodyFrame: Bool
    public var swapAxes: Bool
    public var xSign: Double
    public var ySign: Double
    public var yawSign: Double
    public var cmPerUnit: Double

    public init(bodyFrame: Bool = true, swapAxes: Bool = false, xSign: Double = 1, ySign: Double = 1,
                yawSign: Double = 1, cmPerUnit: Double = 10) {
        self.bodyFrame = bodyFrame
        self.swapAxes = swapAxes
        self.xSign = xSign
        self.ySign = ySign
        self.yawSign = yawSign
        self.cmPerUnit = cmPerUnit
    }
}

/// Position relative to takeoff, integrated from telemetry. Pure logic, no I/O.
/// x is forward and y is right at yaw 0. A telemetry gap invalidates it until `reset`.
// shortcut: dead reckoning drifts and vg fields are whole dm/s, upgrade with mission pads or object tracking
public struct DeadReckoner: Equatable, Sendable {
    public static let maxGap: TimeInterval = 1
    public static let arriveCM = 50.0

    public var calibration = VelocityCalibration()
    public private(set) var xCM = 0.0
    public private(set) var yCM = 0.0
    public private(set) var isValid = true
    private var lastAt: Date?

    public init() {}

    public mutating func add(vgx: Int, vgy: Int, yaw: Int, at: Date) {
        guard isValid else { return }
        defer { lastAt = at }
        guard let lastAt else { return }
        let dt = at.timeIntervalSince(lastAt)
        guard dt <= Self.maxGap else {
            isValid = false
            return
        }
        let c = calibration
        let forward = Double(c.swapAxes ? vgy : vgx) * c.xSign * c.cmPerUnit
        let right = Double(c.swapAxes ? vgx : vgy) * c.ySign * c.cmPerUnit
        let theta = c.bodyFrame ? heading(yaw) : 0
        xCM += (forward * cos(theta) - right * sin(theta)) * dt
        yCM += (forward * sin(theta) + right * cos(theta)) * dt
    }

    public mutating func reset() {
        xCM = 0
        yCM = 0
        isValid = true
        lastAt = nil
    }

    /// Body-frame sticks pointing home, or nil once within `arriveCM`.
    public func homeSticks(yaw: Int) -> DroneSticks? {
        let dist = hypot(xCM, yCM)
        guard dist > Self.arriveCM else { return nil }
        let magnitude = max(0.4, min(1, dist / 150))
        let theta = heading(yaw)
        let hx = -xCM / dist
        let hy = -yCM / dist
        return DroneSticks(
            yaw: 0,
            throttle: 0,
            roll: Float(magnitude * (-hx * sin(theta) + hy * cos(theta))),
            pitch: Float(magnitude * (hx * cos(theta) + hy * sin(theta)))
        )
    }

    private func heading(_ yaw: Int) -> Double { Double(yaw) * calibration.yawSign * .pi / 180 }
}
