//
//  DemoDirector.swift
//  HelicopterGame
//
//  DEBUG-only scripted flight + camera for capturing demo footage in the
//  visionOS simulator. Launch with env:
//    DEMO_SCRIPT=race|safari|crate|freeflight|all|<file in Documents/demo/scripts>
//    DEMO_LIVE=1       (no script; wait for live commands)
//    DEMO_HIDEUI=1     (dismiss the main window once flying)
//  Live control: write a DemoOp (or array) as JSON to Documents/demo/cmd.json.
//  Status: Documents/demo/state.json (mode, phase, drone pose, marks).
//  Tools/demo.sh wraps both from the host.
//

#if os(visionOS)
import Foundation
import RealityKit
import DicyaninThumbController

@MainActor
enum DemoDirector {
    // MARK: Activation

    static var scriptName: String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DEMO_SCRIPT"]
        #else
        return nil
        #endif
    }

    static var isActive: Bool {
        #if DEBUG
        return scriptName != nil || ProcessInfo.processInfo.environment["DEMO_LIVE"] == "1"
        #else
        return false
        #endif
    }

    static var hideUI: Bool { ProcessInfo.processInfo.environment["DEMO_HIDEUI"] == "1" }

    /// True while the director feeds DualThumbController; InputRouter skips its sync.
    static private(set) var ownsInput = false

    // MARK: State

    struct Sticks { var thr: Float = 0, yaw: Float = 0, fwd: Float = 0, strafe: Float = 0 }

    private static weak var root: Entity?
    private static weak var drone: Entity?
    private static var switchMode: ((GameMode) -> Void)?
    private static var currentMode: () -> GameMode = { .menu }

    static var sticks = Sticks()
    /// Root-space point the autopilot flies to; nil = manual sticks.
    static var autopilotTarget: SIMD3<Float>?
    static var autopilotSpeed: Float = 0.8
    static let camera = DemoCamera()

    private static var runner: Task<Void, Never>?
    private static var activeOp = "idle"
    private static var marks: [[String: Any]] = []
    private static let clock = ContinuousClock()
    private static let t0 = ContinuousClock.now
    private static var elapsed: Double {
        let d = clock.now - t0
        return Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
    }

    /// Call from App.init: suppress first-launch gates.
    static func prepareDefaults() {
        guard isActive else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: "HasSeenBetaDisclaimer")
        d.set(true, forKey: "HasShownDronePermissionsGate")
        d.set(true, forKey: "HasSeenDroneTutorial")
        d.set(true, forKey: "hasSeenHandControlsHelp")
        // Hand scheme: no joystick stand in frame. The director owns the sticks.
        ControlSchemeConfig.current = .handJoystick
    }

    static func stage(root: Entity, drone: Entity?, mode: @escaping () -> GameMode,
                      switchMode: @escaping (GameMode) -> Void) {
        guard isActive, runner == nil else { return }
        self.root = root
        self.drone = drone
        self.currentMode = mode
        self.switchMode = switchMode
        ownsInput = true
        if let cmd = DemoPaths.command { try? FileManager.default.removeItem(at: cmd) }
        NSLog("[Demo] staged, docs=\(DemoPaths.root?.path ?? "-")")

        Task { @MainActor in
            var last = clock.now
            var stateTick = 0
            while true {
                let now = clock.now
                let dt = Float((now - last).components.attoseconds) / 1e18 + Float((now - last).components.seconds)
                last = now
                pump(dt: min(dt, 0.05))
                stateTick += 1
                if stateTick % 6 == 0 { pollCommands() }
                if stateTick % 15 == 0 { writeState() }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        if let name = scriptName { run(DemoScript.load(name)) }
    }

    // MARK: Per-frame

    private static func pump(dt: Float) {
        guard let root, let drone, drone.parent != nil else { return }
        if let target = autopilotTarget { sticks = DemoAutopilot.sticks(drone: drone, root: root, target: target,
                                                                       speed: autopilotSpeed) }
        let left = SIMD2<Float>(sticks.yaw, sticks.thr)
        // Drone forward is local -Z; DualThumb maps right.y to +Z, so invert fwd.
        let right = SIMD2<Float>(sticks.strafe, -sticks.fwd)
        let lm = min(1, simd_length(left)), rm = min(1, simd_length(right))
        let ld = lm > 0.001 ? simd_normalize(left) : .zero
        let rd = rm > 0.001 ? simd_normalize(right) : .zero
        // Director is the sole writer; raw hand tracking would zero the sticks.
        if DualThumbController.shared.isHandTrackingInputEnabled {
            DualThumbController.shared.isHandTrackingInputEnabled = false
        }
        DualThumbController.shared.setVirtualJoystickInput(
            leftDirection: [ld.x, ld.y, 0], leftMagnitude: lm, leftActive: lm > 0.001,
            rightDirection: [rd.x, rd.y, 0], rightMagnitude: rm, rightActive: rm > 0.001)
        camera.update(root: root, drone: drone, dt: dt)
    }

    // MARK: Script runner

    static func run(_ ops: [DemoOp]) {
        runner?.cancel()
        runner = Task { @MainActor in
            await execute(ops)
            activeOp = "done"
            NSLog("[Demo] script done")
        }
    }

    private static func execute(_ ops: [DemoOp]) async {
        var i = 0
        while i < ops.count, !Task.isCancelled {
            let op = ops[i]
            activeOp = op.op + (op.value.map { ":\($0)" } ?? "") + (op.target.map { ":\($0)" } ?? "")
            NSLog("[Demo] op \(activeOp)")
            await perform(op)
            i += 1
            if op.op == "loop" { i = 0 }
        }
    }

    private static func perform(_ op: DemoOp) async {
        switch op.op {
        case "mode":
            autopilotTarget = nil; sticks = Sticks()
            if let m = mode(named: op.value ?? "menu") { switchMode?(m) }
            await sleep(op.dur ?? 1.5)
        case "wait":
            await sleep(op.dur ?? 1)
        case "stick":
            autopilotTarget = nil
            sticks = Sticks(thr: op.thr ?? 0, yaw: op.yaw ?? 0, fwd: op.fwd ?? 0, strafe: op.strafe ?? 0)
            await sleep(op.dur ?? 1)
            sticks = Sticks()
        case "goto":
            guard let p = op.pos, p.count == 3 else { return }
            autopilotSpeed = op.speed ?? 0.8
            autopilotTarget = [p[0], p[1], p[2]]
            await sleep(op.dur ?? 5)
            autopilotTarget = nil; sticks = Sticks()
        case "seek":
            await seek(op.target ?? "gates", dur: op.dur ?? 10, speed: op.speed ?? 0.8, alt: op.alt ?? 0)
        case "deliver":
            for _ in 0..<(op.count ?? 1) where !Task.isCancelled { await deliverOne() }
        case "cam":
            camera.apply(op)
        case "beginRace":
            RaceLeagueManager.shared.beginRace()
        case "crateShift":
            let m = CrateDeliveryManager.shared
            if m.phase == .briefing || m.phase == .tutorial { m.beginShift() }
        case "claw":
            CrateDeliveryManager.shared.clawButton()
        case "reset":
            autopilotTarget = nil; sticks = Sticks()
            if let root { drone?.setPosition([0, 0.3, -1.3], relativeTo: root) }
        case "mark":
            marks.append(["label": op.label ?? "mark", "t": elapsed, "wall": Date().timeIntervalSince1970])
            NSLog("[Demo] MARK \(op.label ?? "mark") t=\(elapsed)")
        case "run":
            await execute(DemoScript.load(op.value ?? ""))
        case "stop":
            autopilotTarget = nil; sticks = Sticks()
        default:
            NSLog("[Demo] unknown op \(op.op)")
        }
    }

    private static func sleep(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    static func mode(named name: String) -> GameMode? {
        switch name {
        case "race": return .playRaceLeague
        case "safari": return .playSafari
        case "crate", "freight": return .playCrateDelivery
        case "practice": return .playPractice
        case "timetrial": return .playTimeTrial
        case "sandbox": return .playSandbox
        case "menu": return .menu
        default: return nil
        }
    }

    // MARK: Seek / deliver

    private static func seek(_ target: String, dur: Double, speed: Float, alt: Float) async {
        autopilotSpeed = speed
        let end = elapsed + dur
        while elapsed < end, !Task.isCancelled {
            if let root, let drone, let p = DemoTargets.resolve(target, root: root, from: drone) {
                autopilotTarget = p + [0, alt, 0]
            } else {
                autopilotTarget = nil; sticks = Sticks()
            }
            await sleep(0.1)
        }
        autopilotTarget = nil; sticks = Sticks()
    }

    private static func deliverOne() async {
        let m = CrateDeliveryManager.shared
        guard let root, let drone else { return }
        // 1. Hover over the nearest loose crate.
        guard let crate = DemoTargets.nearest(prefix: "FoldCrate_", root: root, from: drone) else {
            await sleep(1); return
        }
        autopilotSpeed = 0.6
        for _ in 0..<60 where !Task.isCancelled {
            let c = crate.position(relativeTo: root)
            autopilotTarget = c + [0, 0.45, 0]
            let d = drone.position(relativeTo: root) - autopilotTarget!
            if simd_length(SIMD2(d.x, d.z)) < 0.03 && abs(d.y) < 0.05 { break }
            await sleep(0.1)
        }
        // 2. Drop the claw and wait for a hook.
        m.clawButton()
        for _ in 0..<30 where m.carrying == nil && !Task.isCancelled {
            autopilotTarget = crate.position(relativeTo: root) + [0, 0.45, 0]
            await sleep(0.1)
        }
        guard let color = m.carrying else { autopilotTarget = nil; return }
        await sleep(0.8)
        // 3. Fly to the matching gate; the claw auto-releases over it.
        guard let gate = DemoTargets.nearest(prefix: "RelayGate_\(color)", root: root, from: drone) else { return }
        autopilotSpeed = 0.7
        for _ in 0..<120 where m.carrying != nil && !Task.isCancelled {
            autopilotTarget = gate.position(relativeTo: root) + [0, 0.6, 0]
            await sleep(0.1)
        }
        autopilotTarget = nil; sticks = Sticks()
        await sleep(0.6)
    }

    // MARK: Live channel + state surface

    private static func pollCommands() {
        guard let url = DemoPaths.command, let data = try? Data(contentsOf: url) else { return }
        try? FileManager.default.removeItem(at: url)
        let dec = JSONDecoder()
        if let ops = try? dec.decode([DemoOp].self, from: data) {
            run(ops)
        } else if let op = try? dec.decode(DemoOp.self, from: data) {
            if op.op == "cam" { camera.apply(op) } else { run([op]) }
        } else {
            NSLog("[Demo] bad command json")
        }
    }

    private static func writeState() {
        guard let url = DemoPaths.state else { return }
        var s: [String: Any] = ["t": elapsed, "op": activeOp, "mode": "\(currentMode())", "marks": marks,
                                "race": "\(RaceLeagueManager.shared.phase)",
                                "raceLap": RaceLeagueManager.shared.lap,
                                "raceGate": RaceLeagueManager.shared.nextGate,
                                "safari": "\(SafariManager.shared.phase)", "safariScore": SafariManager.shared.score,
                                "crate": "\(CrateDeliveryManager.shared.phase)",
                                "crateDelivered": CrateDeliveryManager.shared.delivered,
                                "camera": camera.presetName]
        if let root, let drone {
            let p = drone.position(relativeTo: root)
            s["drone"] = [p.x, p.y, p.z]
            if let t = autopilotTarget { s["target"] = [t.x, t.y, t.z] }
        }
        if let data = try? JSONSerialization.data(withJSONObject: s, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
#endif
