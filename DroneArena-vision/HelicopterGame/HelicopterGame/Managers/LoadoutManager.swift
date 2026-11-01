//
//  LoadoutManager.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import Foundation

/// Singleton manager that tracks the player's current drone and weapon loadout
/// This ensures the same selections are used across the game session
@MainActor
@Observable
public class LoadoutManager {

    // MARK: - Singleton

    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `LoadoutManager.shared` directly; everyone else must
    // go through GameContext.shared.loadout.
    fileprivate static let shared = LoadoutManager()

    // MARK: - Properties

    /// Currently selected drone
    public private(set) var selectedDrone: Drone?

    /// Currently selected missile weapon (slot 1)
    public private(set) var selectedWeapon: MissileWeapon?

    /// Currently selected missile weapon (slot 2)
    public private(set) var selectedWeapon2: MissileWeapon?

    // MARK: - Registries

    private let droneRegistry = DroneRegistry()
    private let weaponRegistry = WeaponRegistry()
    private let droneSelectionManager = DroneSelectionManager()
    private let weaponSelectionManager = WeaponSelectionManager()
    private let weaponSelectionManager2 = WeaponSelectionManager(selectedWeaponKey: "SelectedWeaponId2")

    // MARK: - Initialization

    private init() {
        // Load saved selections from UserDefaults
        loadSavedSelections()
    }

    // MARK: - Public Methods

    /// Select a drone for the current loadout
    public func selectDrone(_ drone: Drone) {
        selectedDrone = drone
        droneSelectionManager.selectDrone(drone.id)
        gameLog("🎮 [LoadoutManager] Selected drone: \(drone.displayName)")
    }

    /// Select a weapon for the current loadout (slot 1)
    public func selectWeapon(_ weapon: MissileWeapon) {
        selectedWeapon = weapon
        weaponSelectionManager.selectWeapon(weapon.id)
        gameLog("🎮 [LoadoutManager] Selected weapon slot 1: \(weapon.displayName)")
    }

    /// Select a weapon for slot 2
    public func selectWeapon2(_ weapon: MissileWeapon) {
        selectedWeapon2 = weapon
        weaponSelectionManager2.selectWeapon(weapon.id)
        gameLog("🎮 [LoadoutManager] Selected weapon slot 2: \(weapon.displayName)")
    }

    /// Get the USDZ model name for the currently selected weapon
    /// - Parameter slot: The weapon slot (1 or 2, defaults to 1)
    public func getCurrentWeaponModelName(slot: Int = 1) -> String {
        let weapon: MissileWeapon?

        if slot == 2 {
            weapon = selectedWeapon2
        } else {
            weapon = selectedWeapon
        }

        guard let weapon = weapon else {
            gameLog("⚠️ [LoadoutManager] No weapon selected for slot \(slot), using default missile model")
            return "Missile" // Fallback to default
        }

        // Map weapon ID to USDZ file name
        let modelName = weaponModelName(for: weapon)
        gameLog("🚀 [LoadoutManager] Current weapon model for slot \(slot): \(modelName)")
        return modelName
    }

    /// Get weapon stats for the currently selected weapon
    /// - Parameter slot: The weapon slot (1 or 2, defaults to 1)
    public func getCurrentWeaponStats(slot: Int = 1) -> (damage: Int, speed: Float, collisionRadius: Float, missileCount: Int, missileRows: Int, missilesPerRow: Int, trailColor: String, horizontalSpacing: Float, verticalSpacing: Float)? {
        let weapon: MissileWeapon?

        if slot == 2 {
            weapon = selectedWeapon2
        } else {
            weapon = selectedWeapon
        }

        guard let weapon = weapon else {
            return nil
        }

        // Convert weapon stats to game-usable values
        let damage = weapon.damage
        let speed = weaponSpeedMultiplier(for: weapon)
        let collisionRadius = weaponCollisionRadius(for: weapon)
        let missileCount = weapon.missileCount
        let missileRows = weapon.missileRows
        let missilesPerRow = weapon.missilesPerRow
        let trailColor = weapon.trailColor
        let horizontalSpacing = weapon.horizontalSpacing
        let verticalSpacing = weapon.verticalSpacing

        return (damage, speed, collisionRadius, missileCount, missileRows, missilesPerRow, trailColor, horizontalSpacing, verticalSpacing)
    }

    /// Reset to default selections
    public func resetToDefaults() {
        droneSelectionManager.resetToDefault()
        weaponSelectionManager.resetToDefault()
        loadSavedSelections()
    }

    // MARK: - Private Methods

    private func loadSavedSelections() {
        // Load drone from saved selection
        if let drone = droneSelectionManager.selectedDrone(from: droneRegistry) {
            selectedDrone = drone
            gameLog("🎮 [LoadoutManager] Loaded saved drone: \(drone.displayName)")
        } else {
            gameLog("⚠️ [LoadoutManager] No saved drone found")
        }

        // Load weapon slot 1 from saved selection
        if let weapon = weaponSelectionManager.selectedWeapon(from: weaponRegistry) {
            selectedWeapon = weapon
            gameLog("🎮 [LoadoutManager] Loaded saved weapon slot 1: \(weapon.displayName)")
        } else {
            gameLog("⚠️ [LoadoutManager] No saved weapon found for slot 1")
        }

        // Load weapon slot 2 from saved selection
        if let weapon2 = weaponSelectionManager2.selectedWeapon(from: weaponRegistry) {
            selectedWeapon2 = weapon2
            gameLog("🎮 [LoadoutManager] Loaded saved weapon slot 2: \(weapon2.displayName)")
        } else {
            gameLog("⚠️ [LoadoutManager] No saved weapon found for slot 2")
        }
    }

    /// Map weapon to its USDZ model file name
    private func weaponModelName(for weapon: MissileWeapon) -> String {
        switch weapon.id {
        case "standard":
            return "StandardMissile"
        case "rapid":
            return "RapidMissile"
        case "big":
            return "BigMissile"
        case "damage":
            return "DamageMissile"
        case "barrage_precision":
            return "BigMissile"
        case "barrage_heavy":
            return "BigMissile"
        case "barrage_standard":
            return "StandardMissile"
        case "barrage_light":
            return "RapidMissile"
        default:
            return "StandardMissile" // Fallback
        }
    }

    /// Calculate missile speed multiplier based on weapon stats
    /// Standard baseline is 2.5, rapid is faster, big is slower
    private func weaponSpeedMultiplier(for weapon: MissileWeapon) -> Float {
        let baseSpeed: Float = 2.5 // Reduced from 5.0 for better visual feel

        // Convert speed stat (0-100) to multiplier (0.5x to 2.0x)
        // Speed 50 = 1.0x (baseline) = 2.5 m/s
        // Speed 85 (rapid) = 1.7x = 4.25 m/s
        // Speed 40 (big) = 0.8x = 2.0 m/s
        // Speed 60 (damage) = 1.2x = 3.0 m/s
        let speedStat = Float(weapon.speed)
        let multiplier = 0.5 + (speedStat / 100.0) * 1.5

        return baseSpeed * multiplier
    }

    /// Calculate collision radius based on weapon stats
    /// Standard baseline is 0.2, big has larger radius, damage has smaller
    private func weaponCollisionRadius(for weapon: MissileWeapon) -> Float {
        let baseRadius: Float = 0.2

        // Convert collision size stat (0-100) to radius (0.1 to 0.5)
        // Size 50 = 0.2 (baseline)
        // Size 90 (big) = 0.45
        // Size 30 (damage) = 0.12
        let sizeStat = Float(weapon.collisionSize)
        let radius = 0.1 + (sizeStat / 100.0) * 0.4

        return radius
    }

    /// Get missile damage multiplier based on weapon
    public func getDamageMultiplier() -> Float {
        guard let weapon = selectedWeapon else {
            return 1.0 // Default damage
        }

        // Convert damage stat (0-100) to multiplier (0.5x to 2.0x)
        // Damage 50 = 1.0x (baseline)
        // Damage 95 (damage missile) = 1.9x
        // Damage 35 (rapid) = 0.7x
        let damageStat = Float(weapon.damage)
        let multiplier = 0.5 + (damageStat / 100.0) * 1.5

        return multiplier
    }

    /// Get missile fire rate based on weapon
    /// - Parameter slot: The weapon slot (1 or 2, defaults to 1)
    public func getFireRate(slot: Int = 1) -> Float {
        let weapon: MissileWeapon?

        if slot == 2 {
            weapon = selectedWeapon2
        } else {
            weapon = selectedWeapon
        }

        guard let weapon = weapon else {
            return 0.5 // Default fire rate (2 missiles per second)
        }

        // Fire rate is inversely proportional to speed stat
        // Higher speed = faster fire rate (lower cooldown)
        // Speed 50 = 0.5s cooldown (2/sec)
        // Speed 85 (rapid) = 0.3s cooldown (3.3/sec)
        // Speed 40 (big) = 0.6s cooldown (1.67/sec)
        let speedStat = Float(weapon.speed)
        let fireRate = 0.7 - (speedStat / 100.0) * 0.4

        return max(0.2, fireRate) // Minimum 0.2s between shots
    }

    // MARK: - Weapon Lookup by ID (for multiplayer)

    /// Get weapon stats by weapon ID (used for reconstructing remote player missiles)
    public func getWeaponStats(weaponId: String) -> WeaponStats? {
        guard let weapon = weaponRegistry.allWeapons.first(where: { $0.id == weaponId }) else {
            return nil
        }

        return WeaponStats(
            damage: weapon.damage,
            speed: weaponSpeedMultiplier(for: weapon),
            collisionRadius: weaponCollisionRadius(for: weapon),
            missileCount: weapon.missileCount,
            missileRows: weapon.missileRows,
            missilesPerRow: weapon.missilesPerRow,
            trailColor: weapon.trailColor,
            horizontalSpacing: weapon.horizontalSpacing,
            verticalSpacing: weapon.verticalSpacing
        )
    }

    /// Get weapon model name by weapon ID
    public func getWeaponModelName(weaponId: String) -> String? {
        guard let weapon = weaponRegistry.allWeapons.first(where: { $0.id == weaponId }) else {
            return nil
        }

        return weaponModelName(for: weapon)
    }
}

/// Weapon stats structure for passing around weapon configuration
public struct WeaponStats {
    public let damage: Int
    public let speed: Float
    public let collisionRadius: Float
    public let missileCount: Int
    public let missileRows: Int
    public let missilesPerRow: Int
    public let trailColor: String
    public let horizontalSpacing: Float
    public let verticalSpacing: Float
}

extension GameContext {
    public var loadout: LoadoutManager { LoadoutManager.shared }
}
