//
//  SafariManager.swift
//  HelicopterGame
//
//  Safari game mode: explore a life-size low-poly island, discover areas,
//  pop cute critters with missiles for points + combo within a timed round.
//

import Foundation
import Observation
import QuartzCore
import RealityKit
import simd

@MainActor
@Observable
final class SafariManager {
    static let shared = SafariManager()

    enum Phase { case idle, playing, finished }

    private(set) var phase: Phase = .idle
    private(set) var score = 0
    private(set) var popped = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var timeRemaining: TimeInterval = 0
    private(set) var discovered: Set<SafariArea> = []
    private(set) var lastDiscovery: SafariArea?
    private(set) var highScore = UserDefaults.standard.integer(forKey: "safari.highScore")

    let roundDuration: TimeInterval = 180
    private let critterPerArea = 6
    private let comboWindow: TimeInterval = 2.5
    private let discoveryBonus = 50

    @ObservationIgnored private var worldRoot: Entity?
    @ObservationIgnored private weak var parent: Entity?
    @ObservationIgnored private weak var drone: Entity?
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var lastPopTime: TimeInterval = 0
    @ObservationIgnored private var respawnQueue: [(area: SafariArea, at: TimeInterval)] = []

    var formattedTime: String {
        let t = max(0, Int(timeRemaining))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private init() {}

    static func registerECS() {
        SafariCritterComponent.registerComponent()
        SafariConfettiComponent.registerComponent()
        SafariAreaComponent.registerComponent()
        SafariCritterSystem.registerSystem()
    }

    // MARK: - Lifecycle

    func start(in parent: Entity, drone: Entity?) {
        stop()
        self.parent = parent
        self.drone = drone
        SafariCritterSystem.drone = drone

        let world = worldRoot ?? SafariWorldBuilder.build()
        worldRoot = world
        parent.addChild(world)

        score = 0; popped = 0; combo = 0; bestCombo = 0
        discovered = []; lastDiscovery = nil
        timeRemaining = roundDuration
        respawnQueue = []
        for area in SafariArea.allCases {
            for _ in 0..<critterPerArea { spawnCritter(in: area) }
        }
        phase = .playing
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick(0.25) }
        }
        gameLog("[Safari] started")
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        if let world = worldRoot {
            for child in Array(world.children) where child.components.has(SafariCritterComponent.self) || child.components.has(SafariConfettiComponent.self) {
                child.removeFromParent()
            }
            world.removeFromParent()
        }
        SafariCritterSystem.drone = nil
        if phase == .playing { phase = .idle }
    }

    func restart() {
        guard let parent else { return }
        start(in: parent, drone: drone)
    }

    // MARK: - Gameplay

    private func tick(_ dt: TimeInterval) {
        guard phase == .playing else { return }
        timeRemaining -= dt
        let now = CACurrentMediaTime()
        if combo > 0 && now - lastPopTime > comboWindow { combo = 0 }

        if let p = drone?.position(relativeTo: nil) {
            for area in SafariArea.allCases where !discovered.contains(area) {
                if simd_distance(SIMD2(p.x, p.z), area.center) < area.radius {
                    discovered.insert(area)
                    lastDiscovery = area
                    score += discoveryBonus
                }
            }
        }

        respawnQueue.removeAll { entry in
            guard now >= entry.at else { return false }
            spawnCritter(in: entry.area)
            return true
        }

        if timeRemaining <= 0 { finish() }
    }

    func critterPopped(kind: SafariCritterKind, area: SafariArea, at position: SIMD3<Float>) {
        guard phase == .playing else { return }
        let now = CACurrentMediaTime()
        combo = now - lastPopTime <= comboWindow ? combo + 1 : 1
        lastPopTime = now
        bestCombo = max(bestCombo, combo)
        popped += 1
        score += kind.points * min(combo, 5)
        respawnQueue.append((area, now + 6))
    }

    private func finish() {
        phase = .finished
        tickTimer?.invalidate()
        tickTimer = nil
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(score, forKey: "safari.highScore")
        }
        let rank = PlayerRankManager()
        rank.localPlayerRank.addXP(popped * 2 + discovered.count * 10)
        rank.saveRank()
    }

    private func spawnCritter(in area: SafariArea) {
        guard let world = worldRoot else { return }
        let kind = area.critterMix.randomElement() ?? .bunny
        let critter = SafariCritterFactory.make(kind)
        let a = Float.random(in: 0..<(2 * .pi)), r = sqrt(Float.random(in: 0...1)) * area.radius * 0.8
        let x = area.center.x + cos(a) * r, z = area.center.y + sin(a) * r
        let home = SIMD3<Float>(x, SafariWorldBuilder.height(x: x, z: z), z)
        critter.position = home
        critter.components.set(SafariCritterComponent(kind: kind, area: area, home: home, target: home))
        world.addChild(critter)
    }
}
