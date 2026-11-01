//
//  BuildModeManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI
import RealityKit

public enum GameMode {
    case menu
    case build
    case playSandbox
    case playDelivery
    case playMultiplayer
    case playPractice
    case playTimeTrial
    case playSafari
    case playRaceLeague
    case playCrateDelivery
    case results

    // Legacy support for existing code
    case play

    public var isPlayMode: Bool {
        switch self {
        case .playSandbox, .playDelivery, .playMultiplayer, .playPractice, .playTimeTrial, .playSafari, .playRaceLeague, .playCrateDelivery, .play:
            return true
        default:
            return false
        }
    }

    public var isBuildMode: Bool {
        return self == .build
    }
}

@MainActor
@Observable
public class BuildModeManager {
    public var currentMode: GameMode = .play
    public var currentLevelLayout = LevelLayout()
    public var isLayoutValid: Bool { currentLevelLayout.isValid }

    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var layoutURL: URL {
        documentsPath.appendingPathComponent("level_layout.json")
    }

    public init() {
       // loadLayout()
    }

    public func toggleMode() {
        switch currentMode {
        case .build:
            currentMode = .play
        case .play, .playDelivery:
            currentMode = .build
        case .menu, .playSandbox, .playMultiplayer, .playPractice, .playTimeTrial, .playSafari, .playRaceLeague, .playCrateDelivery, .results:
            // For new modes, default to build mode
            currentMode = .build
        }
    }

    public func switchToMode(_ mode: GameMode) {
        currentMode = mode
    }

    public func addPlacement(_ placement: EntityPlacement) {
        currentLevelLayout.addPlacement(placement)
        saveLayout()
    }

    public func removePlacement(ofType type: PlaceableType, withID zoneID: String) {
        currentLevelLayout.removePlacement(ofType: type, withID: zoneID)
        saveLayout()
    }

    public func clearLayout() {
        currentLevelLayout = LevelLayout()
        saveLayout()
    }

    public func updateEntityPosition(entityID: String, newPosition: SIMD3<Float>) {
        // Update the position in the current layout
        let allPlacements = currentLevelLayout.getAllPlacements()

        for (index, placement) in allPlacements.enumerated() {
            if placement.zoneID == entityID {
                // Create a new placement with updated position
                let updatedPlacement = EntityPlacement(
                    type: placement.type,
                    position: newPosition,
                    rotation: placement.rotation,
                    zoneID: placement.zoneID
                )

                // Remove old placement and add updated one
                currentLevelLayout.removePlacement(ofType: placement.type, withID: entityID)
                currentLevelLayout.addPlacement(updatedPlacement)
                break
            }
        }

        saveLayout()
    }

    public func saveLayout() {
        do {
            let data = try JSONEncoder().encode(currentLevelLayout)
            try data.write(to: layoutURL)
            gameLog("Layout saved successfully")
        } catch {
            gameLog("Failed to save layout: \(error)")
        }
    }

    public func loadLayout() {
        do {
            let data = try Data(contentsOf: layoutURL)
            currentLevelLayout = try JSONDecoder().decode(LevelLayout.self, from: data)
            gameLog("Layout loaded successfully")
        } catch {
            gameLog("Failed to load layout (using empty): \(error)")
            currentLevelLayout = LevelLayout()
        }
    }

    public func exportLayout() -> Data? {
        do {
            return try JSONEncoder().encode(currentLevelLayout)
        } catch {
            gameLog("Failed to export layout: \(error)")
            return nil
        }
    }

    public func importLayout(from data: Data) -> Bool {
        do {
            let layout = try JSONDecoder().decode(LevelLayout.self, from: data)
            currentLevelLayout = layout
            saveLayout()
            return true
        } catch {
            gameLog("Failed to import layout: \(error)")
            return false
        }
    }
}
