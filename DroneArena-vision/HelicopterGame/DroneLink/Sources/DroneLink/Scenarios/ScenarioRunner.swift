import Foundation

/// One failed check with the frame it happened on.
public struct ScenarioFailure: Sendable, CustomStringConvertible {
    public var check: String
    public var t: Double
    public var detail: String
    public var description: String { String(format: "FAIL %@ t=%.2fs %@", check, t, detail) }
}

public struct ScenarioReport: Sendable {
    public var name: String
    public var failures: [ScenarioFailure] = []
    public var log: [String] = []
    public var logURL: URL?
    public var passed: Bool { failures.isEmpty }
    public var summary: String {
        let head = "\(name): \(passed ? "PASS" : "FAIL \(failures.count)")"
        let lines = [head] + failures.prefix(8).map(\.description)
        return (lines + (logURL.map { ["log \($0.path)"] } ?? [])).joined(separator: "\n")
    }
}

/// Runs an ObstacleScenario headless through tracker, memory, planner and follower.
/// Writes a per-frame trace to $DRONELINK_SCENARIO_LOGS (default tmp/DroneLinkScenarios).
public enum ScenarioRunner {
    public static var logDir: URL {
        if let p = ProcessInfo.processInfo.environment["DRONELINK_SCENARIO_LOGS"] { return URL(fileURLWithPath: p) }
        return FileManager.default.temporaryDirectory.appendingPathComponent("DroneLinkScenarios")
    }

    public static func run(_ sc: ObstacleScenario) -> ScenarioReport {
        var rep = ScenarioReport(name: sc.name)
        func log(_ t: Double, _ s: String) { rep.log.append(String(format: "%6.2f ", t) + s) }
        func fail(_ c: String, _ t: Double, _ d: String) {
            rep.failures.append(ScenarioFailure(check: c, t: t, detail: d)); log(t, "FAIL \(c) \(d)")
        }
        var w = DemoWorld()
        w.poles = sc.poles
        w.pose = sc.start
        var tracker = ObstacleTracker()
        var mem = ObstacleMemory()
        var f = PathFollower()
        var pops = sc.popUpAt
        var minGap = Double.infinity, braked = false, detectedAt: [Int: Double] = [:]
        var rangeErrs = 0, bearingErrs = 0, replans = 0
        let dt = 1 / sc.fps
        log(0, "start pose=\(fmt(sc.start.xy)) yaw=\(fmt(sc.start.yaw)) goal=\(fmt(sc.goal)) poles=\(sc.poles.map { fmt($0.at) })")
        var t = 0.0
        while t < sc.maxSeconds {
            if let p = pops.first, t >= p {
                pops.removeFirst(); w.popUp()
                log(t, "popUp pole#\(w.poles.count - 1) at \(fmt(w.poles.last!.at))")
            }
            let dets = w.detections()
            let obs = tracker.update(dets, at: t, speedCMS: w.speedCMS)
            for o in obs {
                if o.threat == .brake, !braked { braked = true; log(t, "BRAKE id=\(o.id) range=\(fmt(o.distanceM)) ttc=\(fmt(o.ttc))") }
                guard let pi = nearestPole(w, o), let d = o.distanceM else { continue }
                let b = w.pose.toBody(w.poles[pi].at)
                let trueR = b.x, trueB = atan2(b.y, b.x)
                if abs(d - trueR) > sc.maxRangeErrFrac * trueR, trueR > 0.6 {
                    rangeErrs += 1
                    if rangeErrs <= 5 { fail("range", t, "pole#\(pi) tracked=\(fmt(d)) true=\(fmt(trueR))") }
                }
                if abs(o.bearing - trueB) > sc.maxBearingErr {
                    bearingErrs += 1
                    if bearingErrs <= 5 { fail("bearing", t, "pole#\(pi) tracked=\(fmt(o.bearing)) true=\(fmt(trueB))") }
                }
            }
            if mem.ingest(obs, pose: w.pose, at: t) {
                for m in mem.items {
                    guard let pi = w.poles.indices.min(by: { simd_len(w.poles[$0].at - m.center) < simd_len(w.poles[$1].at - m.center) })
                    else { fail("ghost", t, "obstacle id=\(m.id) at \(fmt(m.center)) with no poles"); continue }
                    let err = simd_len(w.poles[pi].at - m.center)
                    if detectedAt[pi] == nil, err < sc.maxFuseErrM { detectedAt[pi] = t; log(t, "fused pole#\(pi) err=\(fmt(err))") }
                    if err > sc.maxFuseErrM * 2 { fail("ghost", t, "obstacle id=\(m.id) at \(fmt(m.center)) nearest pole#\(pi) \(fmt(err))m") }
                }
                if !sc.straightLine { f.set(PathPlanner.plan(from: w.pose.xy, to: sc.goal, obstacles: mem.items)); replans += 1
                    log(t, "replan path=\(f.path.map(fmt))") }
            }
            if !sc.straightLine, f.path.isEmpty {
                f.set(PathPlanner.plan(from: w.pose.xy, to: sc.goal, obstacles: mem.items))
                log(t, "plan path=\(f.path.map(fmt))")
            }
            let sticks: DroneSticks = sc.straightLine
                ? (braked ? .zero : DroneSticks(yaw: 0, throttle: 0, roll: 0, pitch: 1)) : f.sticks(pose: w.pose)
            let before = w.pose.xy
            w.step(sticks, dt: dt)
            if !sc.straightLine, simd_len(w.pose.xy - before) < 1e-9, sticks != .zero {
                fail("blocked", t, "drone stuck at \(fmt(w.pose.xy)) by pole contact")
            }
            for (i, p) in w.poles.enumerated() {
                let g = simd_len(p.at - w.pose.xy)
                if g < minGap { minGap = g }
                if g < sc.minGapM, sc.minGapM > 0 { fail("collision", t, "pole#\(i) gap=\(fmt(g))"); break }
            }
            if Int(t * sc.fps) % Int(sc.fps) == 0 {
                log(t, "pose=\(fmt(w.pose.xy)) dets=\(dets.count) tracks=\(obs.count) mem=\(mem.items.count) wp=\(f.index)/\(f.path.count)")
            }
            t += dt
            if sc.straightLine ? (braked && w.speedCMS == 0) : f.isDone { break }
            if rep.failures.count > 20 { break }
        }
        let end = simd_len(w.pose.xy - sc.goal)
        log(t, "end pose=\(fmt(w.pose.xy)) goalErr=\(fmt(end)) minGap=\(fmt(minGap)) replans=\(replans)")
        if !sc.straightLine, end > sc.goalToleranceM { fail("goal", t, "ended \(fmt(end))m from goal at \(fmt(w.pose.xy))") }
        if sc.expectBrake, !braked { fail("brake", t, "no brake before contact, minGap=\(fmt(minGap))") }
        for i in sc.mustDetect where detectedAt[i] == nil {
            fail("detect", t, "pole#\(i) at \(fmt(w.poles[i].at)) never fused")
        }
        if !sc.popUpAt.isEmpty, detectedAt.isEmpty { fail("detect", t, "pop-up pole never fused") }
        rep.logURL = write(rep)
        FileLog.shared.write("SCENARIO", rep.summary.replacingOccurrences(of: "\n", with: " | "))
        return rep
    }

    private static func nearestPole(_ w: DemoWorld, _ o: Obstacle) -> Int? {
        let x = o.rect.midX
        return w.poles.indices.filter { w.pose.toBody(w.poles[$0].at).x > 0.3 }.min {
            abs(projX(w, $0) - x) < abs(projX(w, $1) - x)
        }.flatMap { abs(projX(w, $0) - x) < 0.1 ? $0 : nil }
    }

    private static func projX(_ w: DemoWorld, _ i: Int) -> Double {
        let b = w.pose.toBody(w.poles[i].at)
        return 0.5 + TelloCamera.fx * b.y / b.x
    }

    private static func write(_ r: ScenarioReport) -> URL? {
        let dir = logDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent("\(r.name).log")
        let body = ([r.summary, "---"] + r.log).joined(separator: "\n") + "\n"
        return (try? body.write(to: u, atomically: true, encoding: .utf8)) != nil ? u : nil
    }
}

func fmt(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "nil" }
func fmt(_ v: SIMD2<Double>) -> String { String(format: "(%.2f,%.2f)", v.x, v.y) }
