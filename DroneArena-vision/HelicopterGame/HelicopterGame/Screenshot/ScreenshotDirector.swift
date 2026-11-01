//
//  ScreenshotDirector.swift
//  HelicopterGame
//
//  DEBUG-only App Store capture hook. Launch with env:
//    SCREENSHOT_MODE=race|safari   SCREENSHOT_ANGLE=0..3
//  Skips onboarding, opens the immersive space, starts the mode, then
//  reframes the world root so the simulator's fixed camera sees a new angle.
//

import Foundation
import RealityKit

enum ScreenshotDirector {
    static var mode: GameMode? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] {
        case "race": return .playRaceLeague
        case "safari": return .playSafari
        default: return nil
        }
        #else
        return nil
        #endif
    }

    static var isActive: Bool { mode != nil }

    static var hideUI: Bool { ProcessInfo.processInfo.environment["SCREENSHOT_HIDEUI"] == "1" }

    static var angle: Int {
        Int(ProcessInfo.processInfo.environment["SCREENSHOT_ANGLE"] ?? "0") ?? 0
    }

    /// Call from App.init: suppress disclaimer, permissions gate, tutorial.
    static func prepareDefaults() {
        guard isActive else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: "HasSeenBetaDisclaimer")
        d.set(true, forKey: "HasShownDronePermissionsGate")
        d.set(true, forKey: "HasSeenDroneTutorial")
    }

    /// Camera framings around the player drone: yaw of the drone relative to
    /// the viewer (0 = chase cam, drone faces away) and where the drone sits
    /// in viewer space (metres; simulator eye sits near y 0.4).
    private static let framings: [(yaw: Float, target: SIMD3<Float>)] = [
        (.pi * 0.08, [0.0, 0.3, -1.05]),
        (.pi * 0.78, [0.15, 0.38, -0.95]),
        (.pi * 0.5, [-0.1, 0.34, -1.0]),
        (-.pi * 0.25, [0.25, 0.28, -1.2]),
    ]

    @MainActor private static weak var root: Entity?
    @MainActor private static weak var drone: Entity?
    @MainActor private static var logTick = 0

    @MainActor
    static func stage(root: Entity, drone: Entity?) {
        guard isActive else { return }
        self.root = root
        self.drone = drone
        Task { @MainActor in
            // Follow cam: keep the player drone framed for the whole session.
            while true {
                frameDrone()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    @MainActor
    private static func frameDrone() {
        guard let root, let drone, drone.parent != nil else { return }
        let f = framings[angle % framings.count]
        let p = drone.position(relativeTo: root)
        let fwd = drone.orientation(relativeTo: root).act([0, 0, -1])
        let droneYaw = atan2(-fwd.x, -fwd.z)
        let rot = simd_quatf(angle: f.yaw - droneYaw, axis: [0, 1, 0])
        var target = f.target
        if let y = ProcessInfo.processInfo.environment["SCREENSHOT_Y"].flatMap(Float.init) { target.y += y }
        root.transform = Transform(rotation: rot, translation: target - rot.act(p))
        logTick += 1
        if logTick % 40 == 0 { NSLog("[Shot] drone local=\(p) world=\(drone.position(relativeTo: nil))") }
    }

    @MainActor
    static func startRaceIfNeeded() async {
        guard mode == .playRaceLeague else { return }
        let league = RaceLeagueManager.shared
        for _ in 0..<60 {
            try? await Task.sleep(for: .seconds(1))
            if league.phase == .setup { league.beginRace() }
        }
    }
}
