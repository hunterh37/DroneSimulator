//
//  DroneModels.swift
//  HelicopterGame
//
//  Created by Claude on 10/6/25.
//

import Foundation
import SwiftUI

// MARK: - Drone Model System

/// Core drone definition with stats and 3D model reference
public struct Drone: Identifiable, Codable {
    public let id: String
    public let name: String
    public let modelName: String // USDZ file name
    public let displayName: String
    public let description: String

    // Core stats (0-100 scale)
    public let speed: Int
    public let damage: Int
    public let health: Int

    // Visual properties
    public let primaryColor: String // Hex color
    public let accentColor: String // Hex color
    public let iconName: String // SF Symbol

    // Unlock requirements
    public let unlockRequirement: UnlockRequirement

    public init(
        id: String,
        name: String,
        modelName: String,
        displayName: String,
        description: String,
        speed: Int,
        damage: Int,
        health: Int,
        primaryColor: String,
        accentColor: String,
        iconName: String,
        unlockRequirement: UnlockRequirement = .default
    ) {
        self.id = id
        self.name = name
        self.modelName = modelName
        self.displayName = displayName
        self.description = description
        self.speed = max(0, min(100, speed))
        self.damage = max(0, min(100, damage))
        self.health = max(0, min(100, health))
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.unlockRequirement = unlockRequirement
    }

    /// Total combat effectiveness score
    public var combatRating: Int {
        return (speed + damage + health) / 3
    }

    /// Drone class based on stats
    public var droneClass: DroneClass {
        let avgStat = combatRating
        if avgStat >= 80 {
            return .elite
        } else if avgStat >= 60 {
            return .advanced
        } else if avgStat >= 40 {
            return .standard
        } else {
            return .basic
        }
    }

    /// Determines if this drone needs X-axis rotation correction for proper display orientation
    /// Some drone models need -90 degree rotation to display correctly
    public var needsModelRotationX: Bool {
        // Apply -90 degree rotation for these specific drones
        switch self.id {
        case "interceptor", "ranger":
            return true
        default:
            return false
        }
    }

    /// Returns the X-axis rotation value in radians for proper display orientation
    public var modelRotationX: Float {
        return needsModelRotationX ? -Float.pi / 2 : 0 // -90 degrees or 0
    }
}

/// Drone classification based on overall stats
public enum DroneClass: String, CaseIterable, Codable {
    case basic = "basic"
    case standard = "standard"
    case advanced = "advanced"
    case elite = "elite"

    public var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .standard: return "Standard"
        case .advanced: return "Advanced"
        case .elite: return "Elite"
        }
    }

    public var color: Color {
        switch self {
        case .basic: return .gunmetal
        case .standard: return .steel
        case .advanced: return .coreBlue
        case .elite: return .neonBlue
        }
    }
}

/// Requirements to unlock a drone
public enum UnlockRequirement: Codable, Equatable {
    case `default` // Available by default
    case coins(amount: Int)
    case medals(count: Int)
    case goldMedals(count: Int)
    case deliveries(count: Int)
    case combatWins(count: Int)
    case timeTrial(bestTime: TimeInterval)

    public var description: String {
        switch self {
        case .default:
            return "Available"
        case .coins(let amount):
            return "Cost: \(amount) coins"
        case .medals(let count):
            return "Earn \(count) medals"
        case .goldMedals(let count):
            return "Earn \(count) gold medals"
        case .deliveries(let count):
            return "Complete \(count) deliveries"
        case .combatWins(let count):
            return "Win \(count) combat matches"
        case .timeTrial(let bestTime):
            return "Time trial: \(String(format: "%.1f", bestTime))s"
        }
    }

    public func isUnlocked(with profile: PlayerProfile) -> Bool {
        switch self {
        case .default:
            return true
        case .coins(let amount):
            return profile.coins >= amount
        case .medals(let count):
            return profile.medals.count >= count
        case .goldMedals(let count):
            return profile.medals.values.filter { $0 == .gold }.count >= count
        case .deliveries(let count):
            return profile.totalDeliveries >= count
        case .combatWins:
            return true // TODO: Implement combat wins tracking
        case .timeTrial:
            return true // TODO: Implement time trial records
        }
    }
}

// MARK: - Drone Registry

/// Central registry for all available drones
@MainActor
@Observable
public class DroneRegistry {
    public private(set) var allDrones: [Drone] = []

    public init() {
        loadDefaultDrones()
    }

    /// Get drones available to the player
    public func availableDrones(for profile: PlayerProfile) -> [Drone] {
        return allDrones.filter { drone in
            drone.unlockRequirement.isUnlocked(with: profile)
        }
    }

    /// Get drone by ID
    public func drone(withId id: String) -> Drone? {
        return allDrones.first { $0.id == id }
    }

    /// Check if drone is unlocked
    public func isDroneUnlocked(_ droneId: String, for profile: PlayerProfile) -> Bool {
        guard let drone = drone(withId: droneId) else { return false }
        return drone.unlockRequirement.isUnlocked(with: profile)
    }

    private func loadDefaultDrones() {
        allDrones = [
            // Standard Drone - Basic Model
            Drone(
                id: "standard",
                name: "standard",
                modelName: "Drone",
                displayName: "Standard Drone",
                description: "The original combat drone. Proven design with reliable performance for all mission types.",
                speed: 55,
                damage: 45,
                health: 55,
                primaryColor: "8B96A6", // Steel
                accentColor: "2E86FF", // Core Blue
                iconName: "airplane",
                unlockRequirement: .default
            ),

            // Starter Drone - Balanced
            Drone(
                id: "scout",
                name: "scout",
                modelName: "ScoutDrone",
                displayName: "Scout MK-I",
                description: "Reliable starter drone with balanced capabilities. Perfect for learning flight controls and basic missions.",
                speed: 50,
                damage: 40,
                health: 60,
                primaryColor: "8B96A6", // Steel
                accentColor: "2E86FF", // Core Blue
                iconName: "airplane.circle",
                unlockRequirement: .default
            ),

            // Speed Specialist - Lightweight Build
            Drone(
                id: "interceptor",
                name: "interceptor",
                modelName: "InterceptorDrone",
                displayName: "Interceptor X-7",
                description: "Lightning-fast reconnaissance drone. Stripped-down frame for maximum speed and agility.",
                speed: 90,
                damage: 30,
                health: 40,
                primaryColor: "69C4FF", // Neon Blue
                accentColor: "BDE9FF", // Ice Cyan
                iconName: "bolt.circle",
                unlockRequirement: .default
            ),

            // Tank Build - Armored Variant
            Drone(
                id: "guardian",
                name: "guardian",
                modelName: "GuardianDrone",
                displayName: "Guardian MK-III",
                description: "Heavy-duty combat drone with reinforced armor plating. Same frame, enhanced shielding.",
                speed: 30,
                damage: 50,
                health: 95,
                primaryColor: "2E3441", // Gunmetal
                accentColor: "4AD6B6", // Success Green
                iconName: "shield.fill",
                unlockRequirement: .default
            ),

            // Damage Dealer - Weapons Platform
            Drone(
                id: "devastator",
                name: "devastator",
                modelName: "DevastatorDrone",
                displayName: "Devastator Prime",
                description: "High-output weapons platform. Standard frame loaded with advanced targeting systems.",
                speed: 45,
                damage: 95,
                health: 50,
                primaryColor: "FF5E7E", // Danger Red
                accentColor: "F4B847", // Warning Yellow
                iconName: "scope",
                unlockRequirement: .goldMedals(count: 2)
            ),

            // Balanced Advanced
            Drone(
                id: "ranger",
                name: "ranger",
                modelName: "RangerDrone",
                displayName: "Ranger MK-V",
                description: "Versatile field operations drone. Proven reliability with enhanced performance across all metrics.",
                speed: 65,
                damage: 60,
                health: 70,
                primaryColor: "4AD6B6", // Success Green
                accentColor: "BDE9FF", // Ice Cyan
                iconName: "location.circle",
                unlockRequirement: .default
            ),

            // Elite All-Rounder
            Drone(
                id: "phantom",
                name: "phantom",
                modelName: "PhantomDrone",
                displayName: "Phantom Elite",
                description: "Top-tier military drone with cutting-edge technology. Premium materials and advanced systems.",
                speed: 85,
                damage: 80,
                health: 85,
                primaryColor: "F2F5F8", // Chrome Hi
                accentColor: "69C4FF", // Neon Blue
                iconName: "star.circle.fill",
                unlockRequirement: .deliveries(count: 75)
            ),

            // Stealth Variant
            Drone(
                id: "wraith",
                name: "wraith",
                modelName: "WraithDrone",
                displayName: "Wraith Shadow",
                description: "Stealth operations specialist. Standard frame with advanced ECM and noise suppression.",
                speed: 75,
                damage: 70,
                health: 55,
                primaryColor: "07090E", // Night
                accentColor: "C9D2DD", // Chrome Lo
                iconName: "eye.slash.circle",
                unlockRequirement: .coins(amount: 1500)
            ),

            // Experimental Prototype
            Drone(
                id: "vortex",
                name: "vortex",
                modelName: "VortexDrone",
                displayName: "Vortex Prototype",
                description: "Experimental next-gen drone. Cutting-edge tech in familiar frame pushes performance limits.",
                speed: 80,
                damage: 85,
                health: 65,
                primaryColor: "BDE9FF", // Ice Cyan
                accentColor: "69C4FF", // Neon Blue
                iconName: "gear.circle",
                unlockRequirement: .goldMedals(count: 5)
            ),

            // Support Specialist
            Drone(
                id: "medic",
                name: "medic",
                modelName: "MedicDrone",
                displayName: "Medic Support",
                description: "Field support drone with enhanced defensive systems. Built for survival and mission assistance.",
                speed: 40,
                damage: 35,
                health: 90,
                primaryColor: "F4B847", // Warning Yellow
                accentColor: "4AD6B6", // Success Green
                iconName: "cross.circle",
                unlockRequirement: .deliveries(count: 50)
            ),

            // Racing Build
            Drone(
                id: "racer",
                name: "racer",
                modelName: "RacerDrone",
                displayName: "Racer Velocity",
                description: "Pure speed demon. Everything non-essential stripped away for maximum velocity and responsiveness.",
                speed: 95,
                damage: 25,
                health: 35,
                primaryColor: "F4B847", // Warning Yellow
                accentColor: "FF5E7E", // Danger Red
                iconName: "speedometer",
                unlockRequirement: .coins(amount: 1000)
            )
        ] + LowPolyDroneStyle.allCases.map(Self.lowPolyDrone)
    }

    /// Procedural low-poly drones (modelName "lp.<style>"), built at runtime by LowPolyDroneFactory.
    private static func lowPolyDrone(_ style: LowPolyDroneStyle) -> Drone {
        let spec: (String, Int, Int, Int, String, String, String) = {
            switch style {
            case .razor: return ("5 inch true-X freestyle racer. Snappy, balanced and forgiving on the throttle.", 82, 40, 50, "ED3833", "FFD933", "bolt.fill")
            case .hornet: return ("Stretched-X race frame with an aero canopy. Built for long straights.", 88, 35, 45, "1F73F2", "66F2FF", "hare.fill")
            case .cinewhoop: return ("Ducted cinewhoop. Prop guards shrug off gate clips, slower top end.", 60, 30, 85, "26CC73", "E6FF4D", "shield.fill")
            case .falcon: return ("Hexacopter with six-rotor stability and smooth cornering grip.", 70, 55, 70, "FA8C1A", "FFFFFF", "hexagon.fill")
            case .wasp: return ("H-frame speed build. The fastest frame in the league, twitchy in corners.", 95, 30, 35, "9E40F2", "FF66D9", "tornado")
            case .titan: return ("X8 coaxial heavy lifter. Eight motors, tank armor, big punch.", 55, 80, 95, "1A1A1F", "FF3347", "shield.lefthalf.filled")
            }
        }()
        return Drone(
            id: "lp_\(style.rawValue)",
            name: style.rawValue,
            modelName: style.modelName,
            displayName: style.displayName,
            description: spec.0,
            speed: spec.1,
            damage: spec.2,
            health: spec.3,
            primaryColor: spec.4,
            accentColor: spec.5,
            iconName: spec.6,
            unlockRequirement: .default
        )
    }
}

// MARK: - Drone Selection Manager

/// Manages drone selection and persistence
@MainActor
@Observable
public class DroneSelectionManager {
    public var selectedDroneId: String {
        didSet {
            saveToPersistence()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let selectedDroneKey = "SelectedDroneId"
    private let defaultDroneId = "scout"

    public init() {
        // Load from persistence or use default
        self.selectedDroneId = userDefaults.string(forKey: selectedDroneKey) ?? defaultDroneId
    }

    /// Get currently selected drone
    public func selectedDrone(from registry: DroneRegistry) -> Drone? {
        return registry.drone(withId: selectedDroneId)
    }

    /// Select a new drone
    public func selectDrone(_ droneId: String) {
        selectedDroneId = droneId
    }

    /// Reset to default drone
    public func resetToDefault() {
        selectedDroneId = defaultDroneId
    }

    private func saveToPersistence() {
        userDefaults.set(selectedDroneId, forKey: selectedDroneKey)
    }
}
