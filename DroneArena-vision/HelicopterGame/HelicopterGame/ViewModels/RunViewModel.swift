//
//  RunViewModel.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI

@MainActor
@Observable
public class RunViewModel {
    public var isRunning: Bool = false
    public var showSummary: Bool = false
    public var showSettings: Bool = false

    private let gameSessionManager: GameSessionManager

    public init(gameSessionManager: GameSessionManager = GameContext.shared.gameSession) {
        self.gameSessionManager = gameSessionManager
    }

    public func startRun(levelID: LevelID = "tutorial") {
        gameSessionManager.startNewRun(levelID: levelID)
        isRunning = true
    }

    public func endRun() {
        gameSessionManager.endCurrentRun()
        isRunning = false
        showSummary = true
    }

    public func dismissSummary() {
        showSummary = false
    }

    public func showSettingsView() {
        showSettings = true
    }

    public func dismissSettings() {
        showSettings = false
    }

    public var currentRunSession: RunSession? {
        return gameSessionManager.currentRunSession
    }

    public var playerStats: PlayerStats {
        return gameSessionManager.playerStats
    }

    public var playerSettings: PlayerSettings {
        return gameSessionManager.playerSettings
    }
}