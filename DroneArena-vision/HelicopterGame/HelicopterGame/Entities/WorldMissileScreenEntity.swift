//
//  WorldMissileScreenEntity.swift
//  HelicopterGame
//
//  Created by Claude on 11/12/25.
//

import RealityKit
import Foundation

/// Entity that loads the WorldMissileScreenEntity.usdz model
/// This entity can be used to display a physical screen in the game world for the missile targeting interface
public class WorldMissileScreenEntity: Entity, HasModel, HasCollision {

    public required init() {
        super.init()
        Task {
            await loadModel()
        }
    }

    private func loadModel() async {
        do {
            if let loadedEntity = try? await Entity(named: "WorldMissileScreenEntity") {
                self.addChild(loadedEntity)
            }
        } 
    }

    /// Creates a simple fallback visual if the USDZ model fails to load
    private func createFallbackVisual() {
    }

    /// Set the position of the screen entity
    public func setPosition(_ position: SIMD3<Float>) {
        self.position = position
    }

    /// Set the orientation of the screen entity
    public func setOrientation(_ orientation: simd_quatf) {
        self.orientation = orientation
    }

    /// Convenience method to position the screen facing the user
    /// - Parameters:
    ///   - position: World position for the screen
    ///   - lookAtPosition: Position the screen should face towards
    public func positionFacingTarget(at position: SIMD3<Float>, lookAt lookAtPosition: SIMD3<Float>) {
        self.position = position

        // Calculate direction to look at
        let direction = normalize(lookAtPosition - position)

        // Create rotation to face the target
        let defaultForward = SIMD3<Float>(0, 0, -1)
        let rotation = simd_quatf(from: defaultForward, to: direction)

        self.orientation = rotation
    }
}
