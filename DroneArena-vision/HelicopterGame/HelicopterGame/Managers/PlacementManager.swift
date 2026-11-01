//
//  PlacementManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import RealityKit
import simd

@MainActor
@Observable
public class PlacementManager {
    public var selectedPlaceableType: PlaceableType = .hub
    public var isPlacing = false
    public var ghostEntity: ZoneAnchorEntity?
    public var currentPosition: SIMD3<Float>?

    private weak var contentEntity: Entity?
    private weak var buildModeManager: BuildModeManager?

    public init() {}

    public func setup(contentEntity: Entity, buildModeManager: BuildModeManager) {
        self.contentEntity = contentEntity
        self.buildModeManager = buildModeManager
    }

    public func startPlacement(type: PlaceableType) {
        selectedPlaceableType = type
        isPlacing = true
        createGhostEntity()

        // Set a default position immediately so the user doesn't have to tap first
        let defaultPosition = SIMD3<Float>(0, 0, -2) // 2 meters in front
        setPlacementPosition(defaultPosition)
        gameLog("🎯 PlacementManager: Started placement for \(type.rawValue) at default position")
    }

    public func stopPlacement() {
        isPlacing = false
        removeGhostEntity()
        currentPosition = nil
    }

    public func confirmPlacement() {
        guard let position = currentPosition,
              let buildModeManager = buildModeManager else {
            gameLog("❌ PlacementManager: Cannot confirm placement - position: \(currentPosition?.debugDescription ?? "nil"), buildModeManager: \(buildModeManager != nil ? "exists" : "nil")")
            return
        }
        gameLog("✅ PlacementManager: Confirming placement at position: \(position)")

        let rotation = simd_quatf(angle: 0, axis: [0, 1, 0]) // Default rotation
        let zoneID = UUID().uuidString

        let placement = EntityPlacement(
            type: selectedPlaceableType,
            position: position,
            rotation: rotation,
            zoneID: zoneID
        )

        buildModeManager.addPlacement(placement)

        // Create the actual zone entity in the world scene immediately
        createZoneEntity(from: placement)

        stopPlacement()
    }

    public func cancelPlacement() {
        stopPlacement()
    }

    public func rotateGhost() {
        guard let ghost = ghostEntity else { return }
        let currentRotation = ghost.transform.rotation
        let additionalRotation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
        ghost.transform.rotation = currentRotation * additionalRotation
    }

    public func updateGhostPosition(to position: SIMD3<Float>) {
        currentPosition = position

        guard let ghost = ghostEntity else { return }

        ghost.transform.translation = position
    }

    public func setPlacementPosition(_ position: SIMD3<Float>) {
        gameLog("📍 PlacementManager: Setting placement position to: \(position)")
        updateGhostPosition(to: position)
    }

    private func createGhostEntity() {
        removeGhostEntity()

       // ghostEntity = ZoneAnchorEntity(zoneID: "ghost", type: selectedPlaceableType)
        ghostEntity?.setHighlighted(true)

        // Make it semi-transparent and add to content
        if let ghost = ghostEntity {
            // In a real implementation, you'd set opacity/transparency here
            contentEntity?.addChild(ghost)
        }
    }

    private func removeGhostEntity() {
        ghostEntity?.removeFromParent()
        ghostEntity = nil
    }

    public func deleteZone(at position: SIMD3<Float>, tolerance: Float = 0.5) -> Bool {
        guard let buildModeManager = buildModeManager else { return false }

        let allPlacements = buildModeManager.currentLevelLayout.getAllPlacements()

        for placement in allPlacements {
            let distance = length(placement.position - position)
            if distance <= tolerance {
                buildModeManager.removePlacement(ofType: placement.type, withID: placement.zoneID)
                return true
            }
        }

        return false
    }

    public func findNearestZone(to position: SIMD3<Float>) -> EntityPlacement? {
        guard let buildModeManager = buildModeManager else { return nil }

        let allPlacements = buildModeManager.currentLevelLayout.getAllPlacements()

        var nearestPlacement: EntityPlacement?
        var nearestDistance: Float = Float.greatestFiniteMagnitude

        for placement in allPlacements {
            let distance = length(placement.position - position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestPlacement = placement
            }
        }

        return nearestPlacement
    }

    private func createZoneEntity(from placement: EntityPlacement) {
        guard let contentEntity = contentEntity else { return }

        let zoneEntity: ZoneAnchorEntity

        // Create the appropriate zone entity type
        switch placement.type {
        case .hub:
            zoneEntity = HubZoneEntity(zoneID: placement.zoneID)
        case .cargo:
            zoneEntity = CargoZoneEntity(zoneID: placement.zoneID)
        case .delivery:
            zoneEntity = DeliveryZoneEntity(zoneID: placement.zoneID)
        }

        // Set position and rotation
        zoneEntity.transform.translation = placement.position
        zoneEntity.transform.rotation = placement.rotation

        // Add to the scene
        contentEntity.addChild(zoneEntity)
    }
}
