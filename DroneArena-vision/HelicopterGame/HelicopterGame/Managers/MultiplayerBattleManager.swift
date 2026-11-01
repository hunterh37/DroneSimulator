//
//  MultiplayerBattleManager.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import Foundation
import Combine
import QuartzCore

// MARK: - Battle State

public enum BattleState {
    case waiting
    case countdown
    case active
    case gameOver
}

// MARK: - Battle Result

public struct BattleResult {
    let winnerPlayerID: String
    let winnerName: String
    let winnerKills: Int
    let winnerDeaths: Int
    let finalStandings: [(playerID: String, kills: Int, deaths: Int)]
    let battleDuration: TimeInterval

    public init(winnerPlayerID: String, winnerName: String, winnerKills: Int, winnerDeaths: Int, finalStandings: [(playerID: String, kills: Int, deaths: Int)], battleDuration: TimeInterval) {
        self.winnerPlayerID = winnerPlayerID
        self.winnerName = winnerName
        self.winnerKills = winnerKills
        self.winnerDeaths = winnerDeaths
        self.finalStandings = finalStandings
        self.battleDuration = battleDuration
    }
}

// MARK: - Multiplayer Battle Manager

@MainActor
@Observable
public class MultiplayerBattleManager {
    // Singleton
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `MultiplayerBattleManager.shared` directly; everyone
    // else must go through GameContext.shared.battle.
    fileprivate static let shared = MultiplayerBattleManager()

    // Battle state
    public var currentState: BattleState = .waiting
    public var battleResult: BattleResult?
    public var showGameOver: Bool = false
    public var showXPRewards: Bool = false

    // XP tracking
    public var oldRank: PlayerRank?
    public var newRank: PlayerRank?
    public var xpEarned: Int = 0

    // Battle configuration
    public var killsToWin: Int = 2
    public var battleStartTime: TimeInterval = 0

    // Player tracking
    private var healthManager = GameContext.shared.health
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupKillTracking()
    }

    // MARK: - Battle Lifecycle

    public func startBattle() {
        gameLog("⚔️ [MultiplayerBattleManager] ===== STARTING BATTLE =====")
        gameLog("⚔️ [MultiplayerBattleManager] Current state: \(currentState)")
        gameLog("⚔️ [MultiplayerBattleManager] Kills to win: \(killsToWin)")
        currentState = .countdown
        battleStartTime = CACurrentMediaTime()
        showGameOver = false
        battleResult = nil

        // Transition to active after countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.currentState = .active
            gameLog("⚔️ [MultiplayerBattleManager] ===== BATTLE IS NOW ACTIVE! =====")
        }
    }

    public func endBattle(winner: BattleResult) {
        gameLog("🏁 [MultiplayerBattleManager] ===== ENDING BATTLE =====")
        gameLog("🏁 [MultiplayerBattleManager] Winner: \(winner.winnerName) with \(winner.winnerKills) kills")
        currentState = .gameOver
        battleResult = winner

        // Calculate XP earned and update rank
        calculateXPRewards(isWinner: winner.winnerPlayerID == MultiplayerNetworking().localPlayerID)

        // Show XP rewards first (game over shown after)
        showXPRewards = true
        showGameOver = false
        gameLog("🏁 [MultiplayerBattleManager] Set showXPRewards = true, showGameOver = false")

        // Post notification for other systems
        NotificationCenter.default.post(
            name: .multiplayerBattleEnded,
            object: nil,
            userInfo: ["battleResult": winner]
        )
        gameLog("🏁 [MultiplayerBattleManager] Posted multiplayerBattleEnded notification")
    }

    public func dismissXPRewards() {
        gameLog("🏁 [MultiplayerBattleManager] Dismissing XP rewards...")
        showXPRewards = false
        showGameOver = true
        gameLog("🏁 [MultiplayerBattleManager] Set showXPRewards = false, showGameOver = true")
    }

    private func calculateXPRewards(isWinner: Bool) {
        // Save old rank
        oldRank = healthManager.localPlayerRank

        // Calculate XP based on outcome and kills
        let baseXP = isWinner ? PlayerRank.xpForWin() : PlayerRank.xpForLoss()

        // Get local player kills from killfeed
        let networking = MultiplayerNetworking()
        let localKills = healthManager.killfeedEntries.filter { $0.killerPlayerID == networking.localPlayerID }.count
        let killXP = localKills * PlayerRank.xpForKill()

        xpEarned = baseXP + killXP

        // Award XP and save new rank
        if isWinner {
            healthManager.awardGameWin()
        } else {
            healthManager.awardGameLoss()
        }

        newRank = healthManager.localPlayerRank

        gameLog("⚔️ [MultiplayerBattleManager] XP Calculation:")
        gameLog("   - Base XP: \(baseXP) (Winner: \(isWinner))")
        gameLog("   - Kill XP: \(killXP) (\(localKills) kills)")
        gameLog("   - Total XP Earned: \(xpEarned)")
        gameLog("   - Old Rank: Level \(oldRank?.level ?? 0) (\(oldRank?.xp ?? 0) XP)")
        gameLog("   - New Rank: Level \(newRank?.level ?? 0) (\(newRank?.xp ?? 0) XP)")
    }

    public func resetBattle() {
        gameLog("⚔️ [MultiplayerBattleManager] Resetting battle")
        currentState = .waiting
        battleResult = nil
        showGameOver = false
        showXPRewards = false
        battleStartTime = 0
        oldRank = nil
        newRank = nil
        xpEarned = 0

        // Clear killfeed
        healthManager.killfeedEntries.removeAll()
    }

    // MARK: - Kill Tracking

    private func setupKillTracking() {
        // Monitor killfeed entries for win condition
        // Using a timer to check periodically since @Observable doesn't support KVO on arrays
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkWinCondition()
            }
            .store(in: &cancellables)
    }

    /// Public method to check win condition immediately (called after every kill)
    public func checkWinConditionNow() {
        checkWinCondition()
    }

    private func checkWinCondition() {
        // Only check during active battle
        guard currentState == .active else {
            gameLog("⚔️ [MultiplayerBattleManager] Not checking win condition - Battle state: \(currentState)")
            return
        }

        gameLog("🔍 [MultiplayerBattleManager] Checking win condition...")
        gameLog("   - Kills to win: \(killsToWin)")
        gameLog("   - PlayerKillCounts: \(healthManager.playerKillCounts)")
        gameLog("   - PlayerDeathCounts: \(healthManager.playerDeathCounts)")

        // Use persistent kill counts instead of killfeed (killfeed expires after 5 seconds)
        let allPlayerIDs = Set(healthManager.playerKillCounts.keys).union(Set(healthManager.playerDeathCounts.keys))
        gameLog("   - All player IDs: \(allPlayerIDs)")

        // Calculate kills for each player using persistent counts
        var playerKills: [(playerID: String, kills: Int, deaths: Int)] = []

        for playerID in allPlayerIDs {
            let kills = healthManager.playerKillCounts[playerID] ?? 0
            let deaths = healthManager.playerDeathCounts[playerID] ?? 0
            playerKills.append((playerID: playerID, kills: kills, deaths: deaths))
            gameLog("   - Player \(playerID): \(kills) kills, \(deaths) deaths")
        }

        // Sort by kills (descending)
        playerKills.sort { $0.kills > $1.kills }

        // Check if anyone reached killsToWin
        if let topPlayer = playerKills.first, topPlayer.kills >= killsToWin {
            // We have a winner!
            let winnerName = getPlayerName(for: topPlayer.playerID)
            let battleDuration = CACurrentMediaTime() - battleStartTime

            gameLog("⚔️ [MultiplayerBattleManager] WIN CONDITION MET!")
            gameLog("   - Winner: \(winnerName) (Player ID: \(topPlayer.playerID))")
            gameLog("   - Kills: \(topPlayer.kills) / \(killsToWin)")
            gameLog("   - Deaths: \(topPlayer.deaths)")

            let result = BattleResult(
                winnerPlayerID: topPlayer.playerID,
                winnerName: winnerName,
                winnerKills: topPlayer.kills,
                winnerDeaths: topPlayer.deaths,
                finalStandings: playerKills,
                battleDuration: battleDuration
            )

            endBattle(winner: result)
        }
    }

    private func getPlayerName(for playerID: String) -> String {
        // Check if it's the local player
        let networking = MultiplayerNetworking()
        if playerID == networking.localPlayerID {
            return GameContext.shared.playerProfile.playerName
        }

        // Check if it's a bot
        if playerID.hasPrefix("Bot_") {
            let botName = String(playerID.dropFirst(4))
            return botName.isEmpty ? "Enemy Drone" : botName
        }

        // Default to "Player"
        // TODO: Get remote player names from multiplayer session
        return "Player"
    }

    // MARK: - Utility

    public func getBattleDuration() -> TimeInterval {
        guard currentState != .waiting else { return 0 }
        return CACurrentMediaTime() - battleStartTime
    }

    public func getFormattedBattleDuration() -> String {
        let duration = currentState == .gameOver
            ? (battleResult?.battleDuration ?? 0)
            : getBattleDuration()

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let multiplayerBattleEnded = Notification.Name("multiplayerBattleEnded")
}

extension GameContext {
    public var battle: MultiplayerBattleManager { MultiplayerBattleManager.shared }
}
