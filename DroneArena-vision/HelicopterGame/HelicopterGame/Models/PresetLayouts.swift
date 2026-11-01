//
//  PresetLayouts.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import simd
import UIKit

/// Provides preset layouts for quick setup in Build Mode v2
public struct PresetLayouts {

    // MARK: - Layout Creation

    public static func createBasicLayout() -> LevelLayout {
        var layout = LevelLayout()

        // Hub Zone (center)
        let hubPlacement = EntityPlacement(
            type: .hub,
            position: SIMD3<Float>(0, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "hub_central"
        )

        // Cargo Zone (left side)
        let cargoPlacement = EntityPlacement(
            type: .cargo,
            position: SIMD3<Float>(-3, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "cargo_left"
        )

        // Delivery Zone (right side)
        let deliveryPlacement = EntityPlacement(
            type: .delivery,
            position: SIMD3<Float>(3, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "delivery_right"
        )

        layout.addPlacement(hubPlacement)
        layout.addPlacement(cargoPlacement)
        layout.addPlacement(deliveryPlacement)

        return layout
    }

    public static func createTriangleLayout() -> LevelLayout {
        var layout = LevelLayout()

        // Hub Zone (center)
        let hubPlacement = EntityPlacement(
            type: .hub,
            position: SIMD3<Float>(0, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "hub_central"
        )

        // Three points of triangle
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, -3),      // North
            SIMD3<Float>(-2.6, 0, 1.5),  // Southwest
            SIMD3<Float>(2.6, 0, 1.5)    // Southeast
        ]

        // Cargo zones
        let cargoPlacement1 = EntityPlacement(
            type: .cargo,
            position: positions[0],
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "cargo_north"
        )

        let cargoPlacement2 = EntityPlacement(
            type: .cargo,
            position: positions[1],
            rotation: simd_quatf(angle: Float.pi * 2/3, axis: [0, 1, 0]),
            zoneID: "cargo_southwest"
        )

        // Delivery zone
        let deliveryPlacement = EntityPlacement(
            type: .delivery,
            position: positions[2],
            rotation: simd_quatf(angle: -Float.pi * 2/3, axis: [0, 1, 0]),
            zoneID: "delivery_southeast"
        )

        layout.addPlacement(hubPlacement)
        layout.addPlacement(cargoPlacement1)
        layout.addPlacement(cargoPlacement2)
        layout.addPlacement(deliveryPlacement)

        return layout
    }

    public static func createAdvancedLayout() -> LevelLayout {
        var layout = LevelLayout()

        // Central Hub
        let hubPlacement = EntityPlacement(
            type: .hub,
            position: SIMD3<Float>(0, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "hub_central"
        )

        // Multiple cargo zones in a line
        let cargoPositions: [SIMD3<Float>] = [
            SIMD3<Float>(-4, 0, -2),
            SIMD3<Float>(-2, 0, -3),
            SIMD3<Float>(0, 0, -4)
        ]

        // Multiple delivery zones
        let deliveryPositions: [SIMD3<Float>] = [
            SIMD3<Float>(2, 0, 3),
            SIMD3<Float>(4, 0, 1),
            SIMD3<Float>(3, 0, -1)
        ]

        layout.addPlacement(hubPlacement)

        // Add cargo zones
        for (index, position) in cargoPositions.enumerated() {
            let cargoPlacement = EntityPlacement(
                type: .cargo,
                position: position,
                rotation: simd_quatf(angle: Float.random(in: 0...(2 * Float.pi)), axis: [0, 1, 0]),
                zoneID: "cargo_\(index + 1)"
            )
            layout.addPlacement(cargoPlacement)
        }

        // Add delivery zones
        for (index, position) in deliveryPositions.enumerated() {
            let deliveryPlacement = EntityPlacement(
                type: .delivery,
                position: position,
                rotation: simd_quatf(angle: Float.random(in: 0...(2 * Float.pi)), axis: [0, 1, 0]),
                zoneID: "delivery_\(index + 1)"
            )
            layout.addPlacement(deliveryPlacement)
        }

        return layout
    }

    public static func createTestingLayout() -> LevelLayout {
        var layout = LevelLayout()

        // Hub in corner for testing
        let hubPlacement = EntityPlacement(
            type: .hub,
            position: SIMD3<Float>(-3, 0, -3),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "hub_corner"
        )

        // Long distance cargo
        let cargoPlacement = EntityPlacement(
            type: .cargo,
            position: SIMD3<Float>(-3, 0, 3),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "cargo_far"
        )

        // Very distant delivery
        let deliveryPlacement = EntityPlacement(
            type: .delivery,
            position: SIMD3<Float>(5, 0, 2),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "delivery_distant"
        )

        layout.addPlacement(hubPlacement)
        layout.addPlacement(cargoPlacement)
        layout.addPlacement(deliveryPlacement)

        return layout
    }

    public static func createCompactLayout() -> LevelLayout {
        var layout = LevelLayout()

        // Everything close together for quick testing
        let hubPlacement = EntityPlacement(
            type: .hub,
            position: SIMD3<Float>(0, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "hub_compact"
        )

        let cargoPlacement = EntityPlacement(
            type: .cargo,
            position: SIMD3<Float>(-1.5, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "cargo_close"
        )

        let deliveryPlacement = EntityPlacement(
            type: .delivery,
            position: SIMD3<Float>(1.5, 0, 0),
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            zoneID: "delivery_close"
        )

        layout.addPlacement(hubPlacement)
        layout.addPlacement(cargoPlacement)
        layout.addPlacement(deliveryPlacement)

        return layout
    }

    // MARK: - Preset Collection

    public static var allPresets: [LayoutPreset] {
        return [
            LayoutPreset(
                name: "Basic",
                description: "Simple hub with one cargo and delivery zone",
                difficulty: .beginner,
                layout: createBasicLayout()
            ),
            LayoutPreset(
                name: "Triangle",
                description: "Triangular layout with multiple cargo zones",
                difficulty: .intermediate,
                layout: createTriangleLayout()
            ),
            LayoutPreset(
                name: "Advanced",
                description: "Complex layout with multiple cargo and delivery zones",
                difficulty: .advanced,
                layout: createAdvancedLayout()
            ),
            LayoutPreset(
                name: "Testing",
                description: "Long distances and path challenges",
                difficulty: .expert,
                layout: createTestingLayout()
            ),
            LayoutPreset(
                name: "Compact",
                description: "Quick setup for rapid testing",
                difficulty: .beginner,
                layout: createCompactLayout()
            )
        ]
    }
}

// MARK: - Supporting Types

public struct LayoutPreset: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let description: String
    public let difficulty: DifficultyLevel
    public let layout: LevelLayout

    public init(name: String, description: String, difficulty: DifficultyLevel, layout: LevelLayout) {
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.layout = layout
    }
}

public enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"

    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }

    public var color: UIColor {
        switch self {
        case .beginner: return .systemGreen
        case .intermediate: return .systemBlue
        case .advanced: return .systemOrange
        case .expert: return .systemRed
        }
    }

    public var estimatedTime: String {
        switch self {
        case .beginner: return "2-5 min"
        case .intermediate: return "5-10 min"
        case .advanced: return "10-15 min"
        case .expert: return "15+ min"
        }
    }
}