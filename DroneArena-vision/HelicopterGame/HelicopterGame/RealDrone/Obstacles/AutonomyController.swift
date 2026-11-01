#if os(visionOS)
import DroneLink
import Foundation
import Observation
import QuartzCore

enum ControlMode: String, CaseIterable { case joystick = "Joystick", autonomous = "Autonomous" }

/// Obstacle pipeline and autonomous flight. One tick per stick sample:
/// pose -> detections -> tracker -> world memory -> replan -> follower or pilot sticks -> brake.
/// Demo runs the same pipeline on DemoWorld (simulated drone and light poles).
@MainActor @Observable
final class AutonomyController {
    static let shared = AutonomyController()

    var mode: ControlMode = .joystick { didSet { if mode != oldValue { cancelTarget() } } }
    var demo = false { didSet { if demo != oldValue { resetWorld() } } }
    var scanEnabled = true
    /// Joystick mode only: zero forward pitch when a collision is imminent.
    var autoBrake = true

    private(set) var pose = DronePose()
    private(set) var obstacles: [Obstacle] = []
    private(set) var rawDetections: [ObstacleDetection] = []
    private(set) var world: [WorldObstacle] = []
    private(set) var path: [SIMD2<Double>] = []
    private(set) var pathVersion = 0
    private(set) var target: SIMD2<Double>?
    /// Where the drone hits the first in-path obstacle if it keeps going.
    private(set) var impact: SIMD2<Double>?
    private(set) var threat: ThreatLevel = .clear
    private(set) var braking = false
    private(set) var rerouted = false
    private(set) var scanMS = 0.0
    private(set) var output = DroneSticks.zero

    let scanner = ObstacleScanner()
    @ObservationIgnored private var tracker = ObstacleTracker()
    @ObservationIgnored private var memory = ObstacleMemory()
    @ObservationIgnored private var follower = PathFollower()
    @ObservationIgnored private var demoWorld = DemoWorld()
    @ObservationIgnored private var pending: [ObstacleDetection]?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastTick = CACurrentMediaTime()
    @ObservationIgnored private var demoPopped = false

    private init() {
        scanner.onDetections = { dets, ms in
            AutonomyController.shared.pending = dets
            AutonomyController.shared.scanMS = ms
        }
    }

    /// Attach the video tap and start the standalone tick used while no drone link is active.
    func start(link: TelloLink) {
        link.video.onSample = { [scanner] sb in scanner.decode(sb) }
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                let b = RealDroneBridge.shared
                if !b.isActive { _ = AutonomyController.shared.tick(joystick: b.readJoystick(), link: b.link) }
            }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        scanner.reset()
        cancelTarget()
    }

    func setTarget(_ p: SIMD2<Double>) {
        guard mode == .autonomous else { return }
        target = p
        demoPopped = false
        replan()
    }

    func cancelTarget() {
        target = nil
        follower.set([])
        path = []; pathVersion += 1
        rerouted = false
    }

    /// Returns the sticks to send this tick.
    func tick(joystick: DroneSticks, link: TelloLink) -> DroneSticks {
        let now = CACurrentMediaTime()
        let dt = min(0.1, now - lastTick)
        lastTick = now
        let newPose = demo ? demoWorld.pose : Self.realPose(link)
        if newPose != pose { pose = newPose }
        let speed = demo ? demoWorld.speedCMS : Self.realSpeed(link)

        if demo { pending = demoWorld.detections() }
        if let dets = pending, scanEnabled {
            pending = nil
            rawDetections = dets
            obstacles = tracker.update(dets, at: now, speedCMS: speed)
            let added = memory.ingest(obstacles, pose: pose, at: now)
            world = memory.items
            if added, target != nil { rerouted = true; replan() }
        } else if !scanEnabled, !obstacles.isEmpty {
            obstacles = []; rawDetections = []; tracker.reset()
        }
        let newThreat = obstacles.map(\.threat).max() ?? .clear
        if newThreat != threat { threat = newThreat }
        let newImpact = obstacles.first { $0.inPath && $0.distanceM != nil }
            .map { pose.toWorld(forward: max(0, $0.distanceM! - 0.2), right: $0.distanceM! * tan($0.bearing)) }
        if newImpact != impact { impact = newImpact }

        var out: DroneSticks
        switch mode {
        case .joystick:
            out = joystick
            let b = autoBrake && threat == .brake && out.pitch > 0
            if b != braking { braking = b }
            if b { out.pitch = 0 }
        case .autonomous:
            if target != nil, let next = follower.path.dropFirst(follower.index).first,
               PathPlanner.firstBlock(pose.xy, next, world, 0.35) != nil { rerouted = true; replan() }
            out = follower.sticks(pose: pose)
            if braking { braking = false }
            if follower.isDone, target != nil { cancelTarget() }
            // Demo: a pole pops up mid-flight to show live rerouting.
            if demo, target != nil, !demoPopped, PathPlanner.length(path) > 3 {
                demoPopped = true
                demoWorld.popUp()
            }
        }
        if demo { demoWorld.step(out, dt: dt) }
        if output != out { output = out }
        return out
    }

    private func replan() {
        guard let target else { return }
        let p = PathPlanner.plan(from: pose.xy, to: target, obstacles: world)
        follower.set(p)
        path = p
        pathVersion += 1
    }

    private func resetWorld() {
        cancelTarget()
        tracker.reset(); memory.reset()
        demoWorld = DemoWorld()
        obstacles = []; world = []; rawDetections = []
    }

    static func realPose(_ link: TelloLink) -> DronePose {
        let r = link.reckoner
        let yaw = r.heading(link.stateFields["yaw"] ?? 0)
        return DronePose(x: r.xCM / 100, y: r.yCM / 100, yaw: yaw, heightM: Double(link.heightCM ?? 0) / 100)
    }

    static func realSpeed(_ link: TelloLink) -> Double {
        Double(link.stateFields["vgx"] ?? 0) * link.reckoner.calibration.cmPerUnit
    }
}
#endif
