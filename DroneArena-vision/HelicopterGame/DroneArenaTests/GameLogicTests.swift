//
//  GameLogicTests.swift
//  DroneArenaTests
//
//  Top-10 unit coverage for DroneArena's pure game logic.
//  These run hostless on the visionOS simulator — no headset, no live ARKit.
//

import XCTest
@testable import DroneArena

final class GameLogicTests: XCTestCase {

    // MARK: - 1. Player health: damage, clamping, death signal

    func testPlayerHealthTakeDamageClampsAndReportsDeath() {
        var health = PlayerHealthComponent(maxHealth: 100)

        // Non-lethal hit returns false and subtracts exactly.
        XCTAssertFalse(health.takeDamage(30))
        XCTAssertEqual(health.currentHealth, 70)
        XCTAssertTrue(health.isAlive)

        // Overkill clamps to 0, flips isAlive, and reports death once.
        XCTAssertTrue(health.takeDamage(999))
        XCTAssertEqual(health.currentHealth, 0)
        XCTAssertFalse(health.isAlive)

        // A dead player can't take further damage.
        XCTAssertFalse(health.takeDamage(10))
        XCTAssertEqual(health.currentHealth, 0)
    }

    // MARK: - 2. Player health: heal clamps and ignores the dead

    func testPlayerHealthHealRespectsMaxAndDeath() {
        var health = PlayerHealthComponent(maxHealth: 100)
        _ = health.takeDamage(40)            // -> 60

        health.heal(20)
        XCTAssertEqual(health.currentHealth, 80)

        health.heal(1000)                    // clamps at max
        XCTAssertEqual(health.currentHealth, 100)

        _ = health.takeDamage(1000)          // dead
        health.heal(50)                      // no-op while dead
        XCTAssertEqual(health.currentHealth, 0)
    }

    // MARK: - 3. Player health: respawn restores full state

    func testPlayerHealthRespawnRestoresState() {
        var health = PlayerHealthComponent(maxHealth: 80)
        _ = health.takeDamage(1000)
        XCTAssertFalse(health.isAlive)

        health.respawn()
        XCTAssertTrue(health.isAlive)
        XCTAssertEqual(health.currentHealth, 80)
        XCTAssertEqual(health.healthPercentage, 1.0, accuracy: 0.0001)
    }

    // MARK: - 4. Rank: XP thresholds drive level-ups and cap at 10

    func testPlayerRankLevelsUpAcrossThresholdsAndCaps() {
        var rank = PlayerRank()
        XCTAssertEqual(rank.level, 1)

        rank.addXP(99)
        XCTAssertEqual(rank.level, 1)        // 100 required for L2

        rank.addXP(1)                        // exactly 100 -> L2
        XCTAssertEqual(rank.level, 2)

        rank.addXP(10_000)                   // way past everything
        XCTAssertEqual(rank.level, 10)       // hard cap

        rank.addXP(10_000)                   // can't exceed 10
        XCTAssertEqual(rank.level, 10)
    }

    // MARK: - 5. Rank: KDR and progress fraction

    func testPlayerRankKDRAndProgress() {
        var rank = PlayerRank(level: 1, xp: 0)

        // No deaths -> KDR equals kill count.
        rank.addKill(); rank.addKill()
        XCTAssertEqual(rank.kdr, 2.0, accuracy: 0.0001)

        rank.addDeath()
        XCTAssertEqual(rank.kdr, 2.0, accuracy: 0.0001) // 2 kills / 1 death

        // Halfway between L1 (0xp) and L2 (100xp).
        var p = PlayerRank(level: 1, xp: 50)
        XCTAssertEqual(p.progressToNextLevel, 0.5, accuracy: 0.0001)

        // Maxed rank is always 100% progress.
        p = PlayerRank(level: 10, xp: 5000)
        XCTAssertEqual(p.progressToNextLevel, 1.0, accuracy: 0.0001)
    }

    // MARK: - 6. Weapon stats are clamped at construction

    func testMissileWeaponClampsStatsAndRatesEffectiveness() {
        let absurd = MissileWeapon(
            id: "x", name: "x", displayName: "X", description: "",
            imageName: "", damage: 250, speed: -10, collisionSize: 50,
            missileCount: 99, missileRows: 99, missilesPerRow: 99,
            horizontalSpacing: 5.0, verticalSpacing: 0.0,
            primaryColor: "FFFFFF", accentColor: "000000", iconName: "scope"
        )

        XCTAssertEqual(absurd.damage, 100)            // clamped 0...100
        XCTAssertEqual(absurd.speed, 0)
        XCTAssertEqual(absurd.missileCount, 12)       // clamped 1...12
        XCTAssertEqual(absurd.missileRows, 4)         // clamped 1...4
        XCTAssertEqual(absurd.missilesPerRow, 6)      // clamped 1...6
        XCTAssertEqual(absurd.horizontalSpacing, 0.5, accuracy: 0.0001) // 0.05...0.5
        XCTAssertEqual(absurd.verticalSpacing, 0.05, accuracy: 0.0001)

        // effectivenessRating is the mean of the three core stats.
        XCTAssertEqual(absurd.effectivenessRating, (100 + 0 + 50) / 3)
    }

    // MARK: - 7. Weapon trail-color default and grid-capacity invariant

    // NOTE: This stays on the value type `MissileWeapon`. Going through `WeaponRegistry`
    // (a `@MainActor @Observable` class) aborts the test runner: the Swift runtime
    // double-frees in `__deallocating_deinit` (`swift_task_deinitOnExecutorImpl`) when any
    // main-actor-isolated class deinits on this visionOS runtime. Tracked separately.
    func testWeaponTrailColorDefaultsAndGridFits() {
        // trailColor falls back to primaryColor when not supplied.
        let noTrail = MissileWeapon(
            id: "a", name: "a", displayName: "A", description: "", imageName: "",
            damage: 40, speed: 40, collisionSize: 40,
            primaryColor: "ABCDEF", accentColor: "000000", iconName: "scope")
        XCTAssertEqual(noTrail.trailColor, "ABCDEF")

        // An explicit trailColor is preserved.
        let withTrail = MissileWeapon(
            id: "b", name: "b", displayName: "B", description: "", imageName: "",
            damage: 40, speed: 40, collisionSize: 40,
            primaryColor: "ABCDEF", accentColor: "000000",
            trailColor: "FF0000", iconName: "scope")
        XCTAssertEqual(withTrail.trailColor, "FF0000")

        // A barrage's grid must be able to hold every missile it claims to fire.
        let barrage = MissileWeapon(
            id: "c", name: "c", displayName: "C", description: "", imageName: "",
            damage: 30, speed: 50, collisionSize: 2,
            missileCount: 8, missileRows: 2, missilesPerRow: 4,
            primaryColor: "ABCDEF", accentColor: "000000", iconName: "scope")
        XCTAssertLessThanOrEqual(barrage.missileCount,
                                 barrage.missileRows * barrage.missilesPerRow)
    }

    // MARK: - 8. Drone combat rating and class classification

    func testDroneCombatRatingAndClassThresholds() {
        func drone(speed: Int, damage: Int, health: Int) -> Drone {
            Drone(id: "d", name: "d", modelName: "m", displayName: "D", description: "",
                  speed: speed, damage: damage, health: health,
                  primaryColor: "FFF", accentColor: "000", iconName: "scope")
        }

        XCTAssertEqual(drone(speed: 90, damage: 90, health: 90).droneClass, .elite)
        XCTAssertEqual(drone(speed: 65, damage: 60, health: 60).droneClass, .advanced)
        XCTAssertEqual(drone(speed: 45, damage: 40, health: 40).droneClass, .standard)
        XCTAssertEqual(drone(speed: 10, damage: 10, health: 10).droneClass, .basic)

        // Stats above 100 clamp, so rating can't exceed 100.
        let maxed = drone(speed: 200, damage: 200, health: 200)
        XCTAssertEqual(maxed.combatRating, 100)
    }

    // MARK: - 9. Unlock requirements evaluate against a profile

    func testUnlockRequirementEvaluation() {
        var profile = PlayerProfile()
        profile.coins = 150

        XCTAssertTrue(UnlockRequirement.default.isUnlocked(with: profile))
        XCTAssertTrue(UnlockRequirement.coins(amount: 100).isUnlocked(with: profile))
        XCTAssertFalse(UnlockRequirement.coins(amount: 500).isUnlocked(with: profile))

        // Gold-medal gate: only gold medals count.
        profile.medals = ["level1": .gold, "level2": .silver]
        XCTAssertTrue(UnlockRequirement.goldMedals(count: 1).isUnlocked(with: profile))
        XCTAssertFalse(UnlockRequirement.goldMedals(count: 2).isUnlocked(with: profile))
    }

    // MARK: - 10. Profile spendCoins guards against overdraw

    func testProfileSpendCoinsGuardsBalance() {
        var profile = PlayerProfile()
        profile.addCoins(100)
        XCTAssertEqual(profile.coins, 100)

        XCTAssertFalse(profile.spendCoins(150))   // declined, balance untouched
        XCTAssertEqual(profile.coins, 100)

        XCTAssertTrue(profile.spendCoins(60))      // succeeds
        XCTAssertEqual(profile.coins, 40)

        profile.addCoins(-1000)                    // can't go negative
        XCTAssertEqual(profile.coins, 0)
    }
}
