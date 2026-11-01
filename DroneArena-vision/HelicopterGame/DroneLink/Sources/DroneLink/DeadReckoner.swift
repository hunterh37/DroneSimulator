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
    /// Learns frame/swap/signs in flight from commanded sticks. Off when false.
    public var autoCalibrate = true
    public private(set) var calibrator = AutoCalibrator()
    private var log: [Sample] = []
    private struct Sample: Equatable, Sendable { var vgx: Int, vgy: Int, yaw: Int, dt: Double }
    public private(set) var xCM = 0.0
    public private(set) var yCM = 0.0
    public private(set) var isValid = true
    /// Raw Tello yaw at the first sample after reset. Tello yaw is relative to power-on heading,
    /// so headings are taken relative to this to keep x pointing along the takeoff nose.
    public private(set) var yawZero: Int?
    private var lastAt: Date?

    public init() {}

    /// Returns true when auto-calibration changed `calibration` (position is re-integrated).
    @discardableResult
    public mutating func add(vgx: Int, vgy: Int, yaw: Int, at: Date, commanded: DroneSticks? = nil) -> Bool {
        guard isValid else { return false }
        if yawZero == nil { yawZero = yaw }
        defer { lastAt = at }
        guard let lastAt else { return false }
        let dt = at.timeIntervalSince(lastAt)
        guard dt <= Self.maxGap else {
            isValid = false
            return false
        }
        integrate(vgx: vgx, vgy: vgy, yaw: yaw, dt: dt)
        if log.count < 30_000 { log.append(Sample(vgx: vgx, vgy: vgy, yaw: yaw, dt: dt)) }
        guard autoCalibrate, let commanded else { return false }
        calibrator.add(commanded: commanded, vgx: vgx, vgy: vgy, headingBody: heading(yaw),
                       yawRaw: Double(yaw) * calibration.yawSign * .pi / 180)
        guard let c = calibrator.result(base: calibration), c != calibration else { return false }
        calibration = c
        xCM = 0; yCM = 0
        for s in log { integrate(vgx: s.vgx, vgy: s.vgy, yaw: s.yaw, dt: s.dt) }
        return true
    }

    private mutating func integrate(vgx: Int, vgy: Int, yaw: Int, dt: Double) {
        let c = calibration
        let forward = Double(c.swapAxes ? vgy : vgx) * c.xSign * c.cmPerUnit
        let right = Double(c.swapAxes ? vgx : vgy) * c.ySign * c.cmPerUnit
        // Body frame: rotate by heading. World frame: velocities are in the power-on frame,
        // rotate back by the takeoff yaw so x stays along the takeoff nose.
        let theta = c.bodyFrame ? heading(yaw) : -Double(yawZero ?? 0) * c.yawSign * .pi / 180
        xCM += (forward * cos(theta) - right * sin(theta)) * dt
        yCM += (forward * sin(theta) + right * cos(theta)) * dt
    }

    public mutating func reset() {
        xCM = 0
        yCM = 0
        isValid = true
        yawZero = nil
        lastAt = nil
        log = []
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

    /// Heading in radians relative to the takeoff nose, wrapped to -pi...pi.
    public func heading(_ yaw: Int) -> Double {
        var d = Double(yaw - (yawZero ?? yaw))
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d * calibration.yawSign * .pi / 180
    }
}
