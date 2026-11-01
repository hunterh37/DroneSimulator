//
//  GameSessionManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI

// MARK: - Game Session Manager
@MainActor
@Observable
public class GameSessionManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `GameSessionManager.shared` directly; everyone else
    // must go through GameContext.shared.gameSession.
    fileprivate static let shared = GameSessionManager()

    // Global persistent state
    public var playerStats = PlayerStats()
    public var playerSettings = PlayerSettings()
    public var unlockedLevels: Set<LevelID> = ["tutorial", "level1"]
    public var currentRunSession: RunSession?

    private init() {}

    public func startNewRun(levelID: LevelID) {
        currentRunSession = RunSession(levelID: levelID)
    }

    public func endCurrentRun() {
        guard let runSession = currentRunSession else { return }

        // Add coins from run to total
        playerStats.addCoins(runSession.coinsEarned)

        // Track deliveries
        if runSession.jobCompleted {
            playerStats.incrementDeliveries()
        }

        // Award medal based on performance
        if let medal = calculateMedal(for: runSession) {
            playerStats.awardMedal(medal, for: runSession.levelID)
        }

        // Unlock next level if criteria met
        if runSession.jobCompleted && !unlockedLevels.contains("level2") {
            unlockedLevels.insert("level2")
        }

        currentRunSession = nil
    }

    private func calculateMedal(for runSession: RunSession) -> Medal? {
        guard runSession.jobCompleted else { return nil }

        let timeRatio = runSession.elapsedTime / 300.0 // 5 minutes baseline

        if timeRatio <= 0.5 {
            return .gold
        } else if timeRatio <= 0.8 {
            return .silver
        } else {
            return .bronze
        }
    }

    public func resetProgress() {
        playerStats = PlayerStats()
        unlockedLevels = ["tutorial", "level1"]
        currentRunSession = nil
    }
}

// MARK: - Run Session
@MainActor
@Observable
public class RunSession {
    public let levelID: LevelID
    public let startTime: Date
    public var currentJob: GameJob?
    public var coinsEarned: Int = 0
    public var jobCompleted: Bool = false
    public var runActive: Bool = true

    public init(levelID: LevelID) {
        self.levelID = levelID
        self.startTime = Date()

        // Create a dummy job for testing
        self.currentJob = GameJob(
            id: UUID().uuidString,
            pickupLocation: SIMD3<Float>(2, 1, 0),
            deliveryLocation: SIMD3<Float>(-2, 1, 0),
            reward: 50
        )
    }

    public var elapsedTime: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }

    public func completeJob() {
        guard let job = currentJob, !job.isCompleted else { return }

        jobCompleted = true
        coinsEarned += job.reward

        // Bonus for quick completion
        if elapsedTime < 120.0 { // 2 minutes
            coinsEarned += 25
        }
    }

    public func endRun() {
        runActive = false
    }
}

extension GameContext {
    public var gameSession: GameSessionManager { GameSessionManager.shared }
}