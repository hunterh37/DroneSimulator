//
//  GameUIModel.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI
import Observation

@Observable
public class GameUIModel {
    public let buildModeManager = BuildModeManager()
    public let placementManager = PlacementManager()
    public let economyModel = EconomyModel()
    public let modeManager: ModeManager
    public let multiplayerManager = MultiplayerManager()
    private let weaponRegistry = WeaponRegistry()

    public init() {
        self.modeManager = ModeManager(buildModeManager: buildModeManager)

        // Preload all missile models and boss projectiles asynchronously at startup
        Task {
            // Preload missiles
            await GameContext.shared.missilePreloader.preloadAllMissiles(weapons: weaponRegistry.allWeapons)
            gameLog("✅ [GameUIModel] Missile preloading complete")

            // Preload boss projectiles
            await GameContext.shared.bossProjectilePreloader.preloadAllProjectiles()
            gameLog("✅ [GameUIModel] Boss projectile preloading complete")
        }
    }

    public func handleModeChange(_ mode: GameMode) {
        modeManager.switchToMode(mode)
    }

    public func handleBuildToolbarActions() -> BuildToolbarActions {
        return BuildToolbarActions(
            onConfirm: {
                self.placementManager.confirmPlacement()
            },
            onCancel: {
                self.placementManager.cancelPlacement()
            },
            onRotate: {
                self.placementManager.rotateGhost()
            },
            onDelete: {
                // Handle delete mode
            }
        )
    }
}

public struct BuildToolbarActions {
    public let onConfirm: () -> Void
    public let onCancel: () -> Void
    public let onRotate: () -> Void
    public let onDelete: () -> Void
}