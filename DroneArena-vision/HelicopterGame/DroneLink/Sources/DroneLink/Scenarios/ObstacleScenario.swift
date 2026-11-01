import Foundation

/// Scripted headless flight through DemoWorld: poles, start pose, goal and pass criteria.
public struct ObstacleScenario: Sendable {
    public var name: String
    public var poles: [DemoWorld.Pole]
    public var start = DronePose(heightM: 1.2)
    public var goal: SIMD2<Double>
    public var maxSeconds = 30.0
    public var fps = 30.0
    /// Pole indices that must be detected and fused into memory.
    public var mustDetect: [Int]
    /// Expected tracker brake on some frame (straight run at a pole, no planner).
    public var expectBrake = false
    /// Fly straight at full pitch instead of planning (raw detection test).
    public var straightLine = false
    public var minGapM = 0.2
    public var goalToleranceM = 0.5
    /// Max world-position error of a fused obstacle against the true pole.
    public var maxFuseErrM = 0.6
    /// Max tracked range error, fraction of true range.
    public var maxRangeErrFrac = 0.25
    /// Max tracked bearing error, radians.
    public var maxBearingErr = 5 * Double.pi / 180
    /// Seconds after which pops are inserted ahead of the drone.
    public var popUpAt: [Double] = []

    public init(name: String, poles: [SIMD2<Double>], goal: SIMD2<Double>, mustDetect: [Int]? = nil) {
        self.name = name
        self.poles = poles.map { DemoWorld.Pole(at: $0) }
        self.goal = goal
        self.mustDetect = mustDetect ?? Array(poles.indices)
    }

    public static let all: [ObstacleScenario] = {
        var s: [ObstacleScenario] = []
        s.append(.init(name: "open-field", poles: [], goal: SIMD2(6, 0)))
        s.append(.init(name: "single-pole-dead-ahead", poles: [SIMD2(3, 0)], goal: SIMD2(6, 0)))
        s.append(.init(name: "single-pole-offset-left", poles: [SIMD2(3, -0.3)], goal: SIMD2(6, 0)))
        s.append(.init(name: "single-pole-offset-right", poles: [SIMD2(3, 0.3)], goal: SIMD2(6, 0)))
        s.append(.init(name: "demo-default", poles: [SIMD2(3.5, 0.3), SIMD2(6, -1.6), SIMD2(5, 2.4)],
                       goal: SIMD2(8, 0.5), mustDetect: [0]))
        s.append(.init(name: "slalom", poles: [SIMD2(2.5, 0.2), SIMD2(4.5, -0.2), SIMD2(6.5, 0.2)],
                       goal: SIMD2(9, 0)))
        s.append(.init(name: "gate-wide", poles: [SIMD2(3, -0.9), SIMD2(3, 0.9)], goal: SIMD2(6, 0)))
        var yawed = ObstacleScenario(name: "yawed-start", poles: [SIMD2(2.1, 2.1)], goal: SIMD2(4.5, 4.5))
        yawed.start = DronePose(yaw: .pi / 4, heightM: 1.2)
        s.append(yawed)
        var brake = ObstacleScenario(name: "straight-brake", poles: [SIMD2(5, 0)], goal: SIMD2(4.5, 0))
        brake.straightLine = true
        brake.expectBrake = true
        brake.minGapM = 0
        brake.goalToleranceM = 1
        s.append(brake)
        var pop = ObstacleScenario(name: "pop-up", poles: [], goal: SIMD2(8, 0), mustDetect: [])
        pop.popUpAt = [1.5]
        s.append(pop)
        return s
    }()
}
