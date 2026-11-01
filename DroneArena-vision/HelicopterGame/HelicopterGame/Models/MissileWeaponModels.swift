//
//  MissileWeaponModels.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import Foundation
import SwiftUI

// MARK: - Missile Weapon Model System

/// Core missile weapon definition with stats and visual properties
public struct MissileWeapon: Identifiable, Codable {
    public let id: String
    public let name: String
    public let displayName: String
    public let description: String
    public let imageName: String // Asset name for weapon image

    // Core stats (0-100 scale)
    public let damage: Int
    public let speed: Int
    public let collisionSize: Int
    public let missileCount: Int // Number of missiles fired per shot

    // Missile pattern configuration (for barrage missiles)
    public let missileRows: Int // Number of rows in grid pattern
    public let missilesPerRow: Int // Missiles per row
    public let horizontalSpacing: Float // Horizontal spacing between missiles (in meters)
    public let verticalSpacing: Float // Vertical spacing between missiles (in meters)

    // Visual properties
    public let primaryColor: String // Hex color
    public let accentColor: String // Hex color
    public let trailColor: String // Hex color for particle trail
    public let iconName: String // SF Symbol

    public init(
        id: String,
        name: String,
        displayName: String,
        description: String,
        imageName: String,
        damage: Int,
        speed: Int,
        collisionSize: Int,
        missileCount: Int = 2,
        missileRows: Int = 1,
        missilesPerRow: Int = 2,
        horizontalSpacing: Float = 0.2,
        verticalSpacing: Float = 0.2,
        primaryColor: String,
        accentColor: String,
        trailColor: String? = nil,
        iconName: String
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.imageName = imageName
        self.damage = max(0, min(100, damage))
        self.speed = max(0, min(100, speed))
        self.collisionSize = max(0, min(100, collisionSize))
        self.missileCount = max(1, min(12, missileCount)) // Clamp between 1-12 missiles for barrage
        self.missileRows = max(1, min(4, missileRows)) // Max 4 rows
        self.missilesPerRow = max(1, min(6, missilesPerRow)) // Max 6 per row
        self.horizontalSpacing = max(0.05, min(0.5, horizontalSpacing)) // Clamp between 5cm and 50cm
        self.verticalSpacing = max(0.05, min(0.5, verticalSpacing)) // Clamp between 5cm and 50cm
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.trailColor = trailColor ?? primaryColor // Default to primaryColor if not specified
        self.iconName = iconName
    }

    /// Overall weapon effectiveness score
    public var effectivenessRating: Int {
        return (damage + speed + collisionSize) / 3
    }
}

// MARK: - Weapon Registry

/// Central registry for all available missile weapons
@MainActor
@Observable
public class WeaponRegistry {
    public private(set) var allWeapons: [MissileWeapon] = []

    public init() {
        loadDefaultWeapons()
    }

    /// Get weapon by ID
    public func weapon(withId id: String) -> MissileWeapon? {
        return allWeapons.first { $0.id == id }
    }

    private func loadDefaultWeapons() {
        allWeapons = [
            // Standard Missile - Balanced
            MissileWeapon(
                id: "standard",
                name: "standard",
                displayName: "Standard Missile",
                description: "Balanced all-purpose missile. Reliable performance across all combat scenarios.",
                imageName: "Missile", // Using existing Missile asset
                damage: 50,
                speed: 50,
                collisionSize: 2,
                missileCount: 2, // Fires 2 missiles
                missileRows: 1,
                missilesPerRow: 2,
                primaryColor: "8B96A6", // Steel
                accentColor: "2E86FF", // Core Blue
                iconName: "scope"
            ),

            // Rapid Missile - High Fire Rate
            MissileWeapon(
                id: "rapid",
                name: "rapid",
                displayName: "Rapid Missile",
                description: "High-velocity missile with enhanced fire rate. Lower damage per shot, but fires faster for sustained damage.",
                imageName: "RapidMissile",
                damage: 35,
                speed: 85,
                collisionSize: 2,
                missileCount: 4, // Fires 4 missiles for rapid fire
                missileRows: 1,
                missilesPerRow: 4,
                primaryColor: "69C4FF", // Neon Blue
                accentColor: "BDE9FF", // Ice Cyan
                iconName: "bolt.fill"
            ),

            // Big Missile - Large Collision Radius
            MissileWeapon(
                id: "big",
                name: "big",
                displayName: "Big Missile",
                description: "Heavy ordnance with massive blast radius. Easier to hit targets with larger collision zone.",
                imageName: "BigMissile",
                damage: 55,
                speed: 40,
                collisionSize: 90,
                missileCount: 2, // Fires 2 large missiles
                missileRows: 1,
                missilesPerRow: 2,
                primaryColor: "F4B847", // Warning Yellow
                accentColor: "FF5E7E", // Danger Red
                iconName: "circle.circle.fill"
            ),

            // Damage Missile - High Damage Output
            MissileWeapon(
                id: "damage",
                name: "damage",
                displayName: "Damage Missile",
                description: "Precision-guided high-explosive warhead. Maximum damage output with focused impact.",
                imageName: "DamageMissile",
                damage: 95,
                speed: 60,
                collisionSize: 2,
                missileCount: 3, // Fires 3 focused missiles
                missileRows: 1,
                missilesPerRow: 3,
                primaryColor: "FF5E7E", // Danger Red
                accentColor: "F4B847", // Warning Yellow
                iconName: "flame.fill"
            ),

            // BARRAGE MISSILES - Multi-row grid patterns

            // Barrage Light - 2x3 Grid (6 missiles)
            MissileWeapon(
                id: "barrage_light",
                name: "barrage_light",
                displayName: "Light Barrage",
                description: "Launches a compact 2x3 grid of missiles. Perfect for saturating small areas with sustained firepower.",
                imageName: "BarrageMissile1",
                damage: 30,
                speed: 55,
                collisionSize: 2,
                missileCount: 12,
                missileRows: 3,
                missilesPerRow: 4,
                horizontalSpacing: 0.4, // Tight horizontal spacing
                verticalSpacing: 0.70, // Tight vertical spacing
                primaryColor: "69C4FF", // Neon Blue
                accentColor: "8B96A6", // Steel
                trailColor: "00D9FF", // Bright Cyan Trail
                iconName: "square.grid.2x2.fill"
            ),

            // Barrage Standard - 2x4 Grid (8 missiles)
            MissileWeapon(
                id: "barrage_standard",
                name: "barrage_standard",
                displayName: "Standard Barrage",
                description: "Fires an 8-missile salvo in a 2x4 formation. Balanced spread for area denial and suppression.",
                imageName: "BarrageMissile2",
                damage: 25,
                speed: 50,
                collisionSize: 2,
                missileCount: 8,
                missileRows: 2,
                missilesPerRow: 4,
                horizontalSpacing: 0.15, // Standard horizontal spacing (default)
                verticalSpacing: 0.12, // Standard vertical spacing (default)
                primaryColor: "8B96A6", // Steel
                accentColor: "69C4FF", // Neon Blue
                trailColor: "A8B3C1", // Silver-White Trail
                iconName: "square.grid.3x2.fill"
            ),

            // Barrage Heavy - 3x4 Grid (12 missiles)
            MissileWeapon(
                id: "barrage_heavy",
                name: "barrage_heavy",
                displayName: "Heavy Barrage",
                description: "Maximum payload barrage with 12 missiles in a 3x4 grid. Devastates large areas with overwhelming firepower.",
                imageName: "BarrageMissile4",
                damage: 22,
                speed: 40,
                collisionSize: 2,
                missileCount: 12,
                missileRows: 3,
                missilesPerRow: 4,
                horizontalSpacing: 0.18, // Wide horizontal spacing for heavy spread
                verticalSpacing: 0.15, // Wide vertical spacing for heavy spread
                primaryColor: "F4B847", // Warning Yellow
                accentColor: "FF5E7E", // Danger Red
                trailColor: "FFD700", // Gold Trail
                iconName: "square.grid.4x3.fill"
            ),

            // Barrage Precision - 2x5 Grid (10 missiles)
            MissileWeapon(
                id: "barrage_precision",
                name: "barrage_precision",
                displayName: "Precision Barrage",
                description: "Tight 2x5 missile formation for concentrated firepower. Higher accuracy with focused impact pattern.",
                imageName: "BarrageMissile3",
                damage: 35,
                speed: 60,
                collisionSize: 2,
                missileCount: 10,
                missileRows: 2,
                missilesPerRow: 5,
                horizontalSpacing: 0.10, // Very tight horizontal spacing for precision
                verticalSpacing: 0.08, // Very tight vertical spacing for precision
                primaryColor: "FF5E7E", // Danger Red
                accentColor: "BDE9FF", // Ice Cyan
                trailColor: "FF3366", // Hot Pink Trail
                iconName: "square.split.2x1.fill"
            )
        ]
    }
}

// MARK: - Weapon Selection Manager

/// Manages weapon selection and persistence
@MainActor
@Observable
public class WeaponSelectionManager {
    public var selectedWeaponId: String {
        didSet {
            saveToPersistence()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let selectedWeaponKey: String
    private let defaultWeaponId = "standard"

    public init(selectedWeaponKey: String = "SelectedWeaponId") {
        self.selectedWeaponKey = selectedWeaponKey
        // Load from persistence or use default
        self.selectedWeaponId = userDefaults.string(forKey: selectedWeaponKey) ?? defaultWeaponId
    }

    /// Get currently selected weapon
    public func selectedWeapon(from registry: WeaponRegistry) -> MissileWeapon? {
        return registry.weapon(withId: selectedWeaponId)
    }

    /// Select a new weapon
    public func selectWeapon(_ weaponId: String) {
        selectedWeaponId = weaponId
    }

    /// Reset to default weapon
    public func resetToDefault() {
        selectedWeaponId = defaultWeaponId
    }

    /// Get next weapon in list (for cycling)
    public func nextWeapon(from registry: WeaponRegistry) -> MissileWeapon? {
        guard let currentIndex = registry.allWeapons.firstIndex(where: { $0.id == selectedWeaponId }) else {
            return registry.allWeapons.first
        }
        let nextIndex = (currentIndex + 1) % registry.allWeapons.count
        return registry.allWeapons[nextIndex]
    }

    /// Get previous weapon in list (for cycling)
    public func previousWeapon(from registry: WeaponRegistry) -> MissileWeapon? {
        guard let currentIndex = registry.allWeapons.firstIndex(where: { $0.id == selectedWeaponId }) else {
            return registry.allWeapons.first
        }
        let previousIndex = (currentIndex - 1 + registry.allWeapons.count) % registry.allWeapons.count
        return registry.allWeapons[previousIndex]
    }

    private func saveToPersistence() {
        userDefaults.set(selectedWeaponId, forKey: selectedWeaponKey)
    }
}
