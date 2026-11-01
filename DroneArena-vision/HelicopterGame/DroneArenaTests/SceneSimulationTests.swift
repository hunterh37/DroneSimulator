//
//  SceneSimulationTests.swift
//  DroneArenaTests
//
//  Uses ImmersiveTesting to assert on the RealityKit entity graph and to drive
//  deterministic ECS simulation headlessly — the two coverage cases that exercise
//  the spatial side of the game without a headset.
//

import XCTest
import RealityKit
import simd
import ImmersiveTesting
@testable import DroneArena

@MainActor
final class SceneSimulationTests: XCTestCase {

    // MARK: - Scene-state: a combat entity carries the components the game queries on

    func testCombatEntityGraphHasExpectedComponents() {
        // Build a tiny scene the way the game's systems expect to find it: a player
        // entity with health + missile capability, and a live missile in flight.
        let scene = TestScene {
            Entity("player")
                .component(PlayerHealthComponent(maxHealth: 100))
                .component(DroneMissileComponent())
            Entity("missile")
                .component(MissileComponent(velocity: [0, 0, -5],
                                            creationTime: 0,
                                            lifetime: 3.0,
                                            damage: 20))
        }

        XCTAssertHasComponent(scene["player"]!, PlayerHealthComponent.self)
        XCTAssertHasComponent(scene["player"]!, DroneMissileComponent.self)
        XCTAssertHasComponent(scene["missile"]!, MissileComponent.self)

        // The DroneMissileSystem queries for these component types every frame —
        // assert the graph satisfies that contract declaratively.
        SceneStateSpec("combat-ready") {
            Requires(exactly: 1, matching: .hasComponent(MissileComponent.self))
            Requires(entityNamed: "player")
            Expect(entityNamed: "player", "starts at full health") { entity in
                entity.components[PlayerHealthComponent.self]?.currentHealth == 100
            }
        }.assert(against: scene.root)
    }

    // MARK: - System simulation: a missile integrates its velocity over time

    func testMissileMotionIntegratesDeterministically() {
        let scene = TestScene {
            Entity("missile")
                .component(MissileComponent(velocity: [0, 0, -5],
                                            creationTime: 0,
                                            lifetime: 3.0,
                                            damage: 20))
        }

        let harness = SystemHarness(scene: scene)   // default 90 Hz clock

        // Mirror DroneMissileSystem's per-frame position update (position += v * dt).
        harness.registerStep("missile-motion") { entities, dt in
            for e in entities {
                guard let m = e.components[MissileComponent.self] else { continue }
                e.position += m.velocity * dt
            }
        }

        // One second of simulated flight at 5 m/s toward -Z.
        harness.tick(frames: 90,
                     invariants: SceneInvariantSet { SceneInvariant.noNaNTransforms })

        XCTAssertPosition(scene["missile"]!, near: [0, 0, -5], within: 0.05)
    }
}
