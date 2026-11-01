//
//  CrateDeliveryManager.swift
//  HelicopterGame
//
//  Fold Freight game mode: briefing, skippable tutorial, endless shift.
//  Crates fall from ceiling rifts, bounce on the real room mesh, and must
//  be hooked and delivered to the Relay Gate of their color.
//

import Foundation
import Observation
import QuartzCore
import RealityKit
import simd
import UIKit

@MainActor
@Observable
final class CrateDeliveryManager {
    static let shared = CrateDeliveryManager()

    enum Phase { case idle, briefing, tutorial, playing, finished }

    private(set) var phase: Phase = .idle
    private(set) var tutorialStep: CrateTutorialStep = .hover
    private(set) var score = 0
    private(set) var delivered = 0
    private(set) var misroutes = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var level = 1
    private(set) var timeRemaining: Double = CrateDifficulty.startTime
    private(set) var carrying: CrateColor?
    private(set) var lastEvent: String?
    private(set) var highScore = UserDefaults.standard.integer(forKey: "foldFreight.highScore")
    private(set) var bestLevel = max(1, UserDefaults.standard.integer(forKey: "foldFreight.bestLevel"))

    var isActive: Bool { phase == .tutorial || phase == .playing }
    var difficulty: CrateDifficulty { CrateDifficulty(level: level) }
    var rankTitle: String { CrateLore.rank(for: level) }
    var timeFraction: Double { min(1, timeRemaining / 60) }
    var hasSeenTutorial: Bool { UserDefaults.standard.bool(forKey: "foldFreight.tutorialSeen") }

    @ObservationIgnored private var worldRoot: Entity?
    @ObservationIgnored private weak var parent: Entity?
    @ObservationIgnored private weak var drone: Entity?
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var spawnClock: Double = 0
    @ObservationIgnored private var jitterClock: Double = 0
    @ObservationIgnored private var riftPoints: [SIMD3<Float>] = []
    @ObservationIgnored private var gates: [CrateColor: Entity] = [:]
    @ObservationIgnored private var eventToken = 0

    private init() {}

    static func registerECS() {
        CrateComponent.registerComponent()
        CrateClawComponent.registerComponent()
        CrateGateComponent.registerComponent()
        CratePopComponent.registerComponent()
        CratePropComponent.registerComponent()
        CrateDeliverySystem.registerSystem()
    }

    // MARK: - Lifecycle

    func start(in parent: Entity, drone: Entity?) {
        stop()
        self.parent = parent
        self.drone = drone
        let world = Entity()
        world.name = "FoldFreightWorld"
        parent.addChild(world)
        worldRoot = world
        CrateDeliverySystem.worldRoot = world
        CrateDeliverySystem.drone = drone

        world.addChild(makeFloor())
        for c in CrateColor.allCases {
            let g = CrateWorldBuilder.makeGate(c)
            world.addChild(g)
            gates[c] = g
        }
        let rig = CrateWorldBuilder.makeClawRig()
        rig.components.set(CrateClawComponent())
        world.addChild(rig)

        riftPoints = CrateRoomDresser.defaultRiftPoints
        CrateRoomDresser.dress(world, rifts: riftPoints)
        // Scene mesh streams in over the first seconds. Re-dress onto real surfaces.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, let world = self.worldRoot else { return }
            self.riftPoints = CrateRoomDresser.redressOnRoom(world)
        }

        resetStats()
        phase = .briefing
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick(0.1) }
        }
        gameLog("[FoldFreight] started")
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        worldRoot?.removeFromParent()
        worldRoot = nil
        gates = [:]
        CrateDeliverySystem.worldRoot = nil
        CrateDeliverySystem.drone = nil
        CrateDeliverySystem.pressQueued = false
        carrying = nil
        if phase != .finished { phase = .idle }
    }

    func restart() {
        guard let parent else { return }
        start(in: parent, drone: drone)
        beginShift()
    }

    private func resetStats() {
        score = 0; delivered = 0; misroutes = 0; streak = 0; bestStreak = 0
        level = 1; timeRemaining = CrateDifficulty.startTime
        spawnClock = 0; jitterClock = 0; carrying = nil; lastEvent = nil
    }

    // MARK: - Flow

    func beginTutorial() {
        clearCrates()
        phase = .tutorial
        tutorialStep = .hover
        spawnTrainingCrate(at: [-0.05, 0.3, -1.55])
        ArenaSound.shared.play(.confirm)
    }

    func skipTutorial() {
        UserDefaults.standard.set(true, forKey: "foldFreight.tutorialSeen")
        beginShift()
    }

    func beginShift() {
        clearCrates()
        resetStats()
        phase = .playing
        for i in 0..<3 { spawnCrate(delay: Double(i) * 0.4) }
        flash("Shift open. Hold the Fold.")
        ArenaSound.shared.play(.launch)
    }

    /// Control panel red button.
    func clawButton() {
        guard isActive else { return }
        CrateDeliverySystem.pressQueued = true
    }

    // MARK: - Tick

    private func tick(_ dt: Double) {
        switch phase {
        case .tutorial:
            if tutorialStep == .hover, let d = drone?.position(relativeTo: nil),
               let crate = crates().first(where: { $0.components[CrateComponent.self]?.state == .loose }) {
                let p = crate.position(relativeTo: nil)
                if simd_distance(SIMD2(d.x, d.z), SIMD2(p.x, p.z)) < 0.14 { advanceTutorial(to: .drop) }
            }
            contain(dt)
        case .playing:
            let diff = difficulty
            timeRemaining -= dt * diff.drainRate
            spawnClock += dt
            jitterClock += dt
            let loose = crates().filter { $0.components[CrateComponent.self]?.state == .loose }
            if spawnClock >= diff.spawnInterval && loose.count < diff.maxLooseCrates {
                spawnClock = 0
                spawnCrate()
            }
            if loose.isEmpty && carrying == nil { spawnCrate() }
            if jitterClock >= diff.jitterInterval {
                jitterClock = 0
                kick(loose, impulse: diff.jitterImpulse)
            }
            contain(dt)
            if timeRemaining <= 0 { finish() }
        default:
            break
        }
    }

    // MARK: - Events from the system

    func clawDropped() { ArenaSound.shared.tick() }

    func clawWhiffed() {
        if phase == .tutorial && tutorialStep == .drop { flash("Missed. Line up right on top.") }
    }

    func crateHooked(_ crate: Entity, color: CrateColor) {
        carrying = color
        ArenaSound.shared.play(.select, volume: 0.7)
        spawnPop(CrateWorldBuilder.makeTextPop("HOOKED", color: color.ui, at: crate.position(relativeTo: worldRoot) + [0, 0.12, 0]))
        if phase == .tutorial {
            if tutorialStep == .drop || tutorialStep == .hover { advanceTutorial(to: .deliver) }
        }
    }

    func crateDelivered(_ crate: Entity, color: CrateColor, gate: CrateColor, gateEntity: Entity,
                        stackIndex: Int, at worldPos: SIMD3<Float>) {
        carrying = nil
        let local = worldRoot.map { $0.convert(position: worldPos, from: nil) } ?? worldPos
        guard color == gate else { misroute(crate, at: local); return }

        if var g = gateEntity.components[CrateGateComponent.self] {
            g.pulse = 1
            gateEntity.components.set(g)
        }
        streak += 1
        bestStreak = max(bestStreak, streak)
        delivered += 1
        let stackMult = 1 + stackIndex
        let streakMult = min(1 + Double(streak - 1) * 0.25, 3)
        let points = Int(Double((100 + 25 * (level - 1)) * stackMult) * streakMult)
        score += points

        var caption: String?
        if stackIndex > 0 { caption = "STACK x\(stackMult)" } else if streak >= 3 { caption = "STREAK \(streak)" }
        let big = stackIndex > 0 || streak >= 3
        spawnPop(CrateWorldBuilder.makeScorePop(points: points, caption: caption, color: color.ui,
                                                at: local + [0, 0.2, 0], big: big))
        spawnPop(CrateWorldBuilder.makeBurst(color: color.ui, at: local, count: big ? 220 : 120))
        ArenaSound.shared.play(.confirm, volume: 0.8)

        if phase == .tutorial {
            handleTutorialDelivery(stackIndex: stackIndex)
            return
        }

        timeRemaining = min(90, timeRemaining + difficulty.timeBonus)
        if stackIndex + 1 >= 4 { sealShipment(on: gateEntity, color: color) }
        if delivered % CrateDifficulty.deliveriesPerLevel == 0 { levelUp() }
    }

    func crateLost(_ crate: Entity) {
        crate.removeFromParent()
        if crate.components[CrateComponent.self]?.state == .carried { carrying = nil }
        if phase == .tutorial { spawnTrainingCrate(at: [-0.05, 0.3, -1.55]) }
    }

    // MARK: - Scoring helpers

    private func misroute(_ crate: Entity, at local: SIMD3<Float>) {
        if var c = crate.components[CrateComponent.self] {
            c.state = .loose
            crate.components.set(c)
        }
        streak = 0
        guard phase == .playing else {
            flash("Wrong gate. Match the crate color.")
            return
        }
        misroutes += 1
        let penalty = difficulty.misroutePenalty
        timeRemaining -= penalty
        spawnPop(CrateWorldBuilder.makeTextPop("MISROUTE -\(Int(penalty))s", color: .systemRed, at: local + [0, 0.22, 0]))
        ArenaSound.shared.play(.tickB, volume: 0.8)
    }

    private func sealShipment(on gate: Entity, color: CrateColor) {
        let bonus = 400 + 100 * level
        score += bonus
        timeRemaining = min(90, timeRemaining + 6)
        let gp = gate.position
        spawnPop(CrateWorldBuilder.makeScorePop(points: bonus, caption: "SHIPMENT SEALED", color: .white,
                                                at: gp + [0, 0.75, 0], big: true))
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self else { return }
            let gp2 = SIMD2(gp.x, gp.z)
            for crate in self.crates() {
                guard crate.components[CrateComponent.self]?.state == .delivered else { continue }
                let p = crate.position
                guard simd_distance(SIMD2(p.x, p.z), gp2) < CrateWorldBuilder.gateRadius * 1.4 else { continue }
                self.spawnPop(CrateWorldBuilder.makeBurst(color: color.ui, at: p, count: 90))
                crate.removeFromParent()
            }
            ArenaSound.shared.play(.launch, volume: 0.6)
        }
    }

    private func levelUp() {
        level += 1
        flash("Level \(level): \(rankTitle)")
        spawnPop(CrateWorldBuilder.makeTextPop("LEVEL \(level)  \(rankTitle.uppercased())", color: .white,
                                               at: [0, 1.25, -1.4]))
        ArenaSound.shared.play(.launch, volume: 0.7)
    }

    private func finish() {
        phase = .finished
        timeRemaining = 0
        tickTimer?.invalidate()
        tickTimer = nil
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: "foldFreight.highScore")
        }
        if level > bestLevel {
            bestLevel = level
            UserDefaults.standard.set(level, forKey: "foldFreight.bestLevel")
        }
        let rank = PlayerRankManager()
        rank.localPlayerRank.addXP(delivered * 3 + level * 10)
        rank.saveRank()
    }

    // MARK: - Tutorial

    private func advanceTutorial(to step: CrateTutorialStep) {
        tutorialStep = step
        ArenaSound.shared.tick()
    }

    private func handleTutorialDelivery(stackIndex: Int) {
        switch tutorialStep {
        case .deliver:
            advanceTutorial(to: .stack)
            spawnTrainingCrate(at: [0.1, 0.3, -1.6])
        case .stack:
            if stackIndex >= 1 {
                advanceTutorial(to: .done)
                UserDefaults.standard.set(true, forKey: "foldFreight.tutorialSeen")
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(2.2))
                    guard let self, self.phase == .tutorial else { return }
                    self.beginShift()
                }
            } else {
                flash("Set it on top of the first crate.")
            }
        default:
            break
        }
    }

    // MARK: - Spawning

    private func crates() -> [Entity] {
        worldRoot?.children.filter { $0.components.has(CrateComponent.self) } ?? []
    }

    private func clearCrates() {
        for c in crates() { c.removeFromParent() }
        if let rig = worldRoot?.children.first(where: { $0.components.has(CrateClawComponent.self) }) {
            rig.findEntity(named: "Head")?.children.filter { $0.components.has(CrateComponent.self) }.forEach { $0.removeFromParent() }
            rig.components.set(CrateClawComponent())
        }
        carrying = nil
    }

    private func spawnTrainingCrate(at pos: SIMD3<Float>) {
        guard let world = worldRoot else { return }
        let crate = CrateWorldBuilder.makeCrate(.red, training: true)
        crate.position = pos
        world.addChild(crate)
        spawnPop(CrateWorldBuilder.makeBurst(color: .white, at: pos, count: 60))
    }

    private func spawnCrate(delay: Double = 0) {
        guard let world = worldRoot else { return }
        let color = CrateColor.allCases.randomElement() ?? .red
        let rift = riftPoints.randomElement() ?? [0, 2.2, -1.8]
        let spawn = rift + SIMD3<Float>(.random(in: -0.08...0.08), -0.2, .random(in: -0.08...0.08))
        Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard let self, self.phase == .playing, self.worldRoot === world else { return }
            let crate = CrateWorldBuilder.makeCrate(color)
            crate.position = spawn
            crate.orientation = simd_quatf(angle: .random(in: 0...(2 * .pi)), axis: simd_normalize([.random(in: -1...1), 1, .random(in: -1...1)]))
            crate.components.set(PhysicsMotionComponent(
                linearVelocity: [.random(in: -0.7...0.7), -0.4, .random(in: -0.7...0.7)],
                angularVelocity: [.random(in: -4...4), .random(in: -4...4), .random(in: -4...4)]))
            world.addChild(crate)
            self.spawnPop(CrateWorldBuilder.makeBurst(color: color.ui, at: spawn, count: 70))
        }
    }

    /// Transit charge: loose crates hop and skitter.
    private func kick(_ loose: [Entity], impulse: Float) {
        for crate in loose where Bool.random() {
            guard let body = crate as? ModelEntity else { continue }
            let dir = SIMD3<Float>(.random(in: -1...1), .random(in: 1.2...2.0), .random(in: -1...1))
            body.applyLinearImpulse(simd_normalize(dir) * impulse * 0.4, relativeTo: nil)
            body.applyAngularImpulse([.random(in: -0.02...0.02), .random(in: -0.02...0.02), .random(in: -0.02...0.02)], relativeTo: nil)
        }
    }

    /// Soft boundary for rooms without scanned walls (simulator, open spaces).
    private func contain(_ dt: Double) {
        for crate in crates() {
            guard crate.components[CrateComponent.self]?.state == .loose, let body = crate as? ModelEntity else { continue }
            let p = crate.position
            let r = simd_length(SIMD2(p.x, p.z + 1.2))
            if r > 2.4 {
                let back = simd_normalize(SIMD3<Float>(-p.x, 0, -(p.z + 1.2)))
                body.applyLinearImpulse(back * 0.05, relativeTo: nil)
            }
        }
    }

    // MARK: - Utils

    private func makeFloor() -> Entity {
        let floor = Entity()
        floor.name = "FoldFloor"
        floor.position = [0, -0.01, -1.2]
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [10, 0.02, 10])]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default,
                                                   material: .generate(staticFriction: 0.8, dynamicFriction: 0.6, restitution: 0.5),
                                                   mode: .static))
        return floor
    }

    private func spawnPop(_ e: Entity) { worldRoot?.addChild(e) }

    private func flash(_ text: String) {
        eventToken += 1
        let token = eventToken
        lastEvent = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard let self, self.eventToken == token else { return }
            self.lastEvent = nil
        }
    }
}
