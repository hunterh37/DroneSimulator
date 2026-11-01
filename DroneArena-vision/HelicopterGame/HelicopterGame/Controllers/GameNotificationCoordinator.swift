//
//  GameNotificationCoordinator.swift
//  HelicopterGame
//
//  Coordinates all game notification listeners and event handling
//

import Foundation
import SwiftUI

@Observable
class GameNotificationCoordinator {

    // State bindings for UI updates
    var currentKillstreakImage: String?
    var showKillstreakImage = false
    var killstreakImageOffset: CGFloat = -100

    var showKillNotification = false
    var killedPlayerName: String = ""
    var killNotificationOpacity: Double = 0.0

    var enemiesDefeated: Int = 0
    var damageFlashOpacity: Double = 0.0

    // Callbacks for view updates
    var onPlayerDeath: (() -> Void)?

    // MARK: - Setup

    func setupAllListeners() {
        setupEnemySpawnListener()
        setupKillstreakListener()
        setupKillNotificationListener()
        setupPracticeModeKillListener()
        setupPlayerDeathListener()
        setupDamageFlashListener()
    }

    func removeAllListeners() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Enemy Spawn Listener

    private func setupEnemySpawnListener() {
        NotificationCenter.default.addObserver(
            forName: .spawnTestEnemyDrone,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // This will be handled by the view since it needs access to worldScene
            // We keep the notification registration here for completeness
        }
    }

    // MARK: - Killstreak Listener

    private func setupKillstreakListener() {
        NotificationCenter.default.addObserver(
            forName: .playerKillstreak,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            gameLog("🎯 [NotificationCoordinator] Killstreak notification received!")
            if let killstreak = notification.userInfo?["killstreak"] as? Int {
                gameLog("🎯 [NotificationCoordinator] Killstreak value: \(killstreak)")
                self?.showKillstreakImage(for: killstreak)
            } else {
                gameLog("❌ [NotificationCoordinator] No killstreak value in notification userInfo")
            }
        }
    }

    private func showKillstreakImage(for killstreak: Int) {
        // Map killstreak to image name
        let imageName: String
        if killstreak == 1 {
            imageName = "1xkill"
        } else {
            // For killstreaks 2+, use killstreak images (max 5, use 5 for anything above)
            let imageNumber = min(killstreak, 5)
            imageName = "\(imageNumber)_killstreak"
        }

        gameLog("🎯 [NotificationCoordinator] showKillstreakImage called")
        gameLog("🎯 [NotificationCoordinator] Killstreak: \(killstreak) -> Image: \(imageName)")

        currentKillstreakImage = imageName
        killstreakImageOffset = -100 // Start above screen

        gameLog("🎯 [NotificationCoordinator] Set currentKillstreakImage to: \(currentKillstreakImage ?? "nil")")

        // Slide down and fade in
        withAnimation(.easeOut(duration: 0.5)) {
            showKillstreakImage = true
            killstreakImageOffset = 0
        }

        gameLog("🎯 [NotificationCoordinator] Animation started - showKillstreakImage: \(showKillstreakImage)")

        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            gameLog("🎯 [NotificationCoordinator] Hiding killstreak image after 2 seconds")
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.showKillstreakImage = false
                self?.killstreakImageOffset = 100 // Slide down and out
            }

            // Clean up after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                gameLog("🎯 [NotificationCoordinator] Cleaning up killstreak image")
                self?.currentKillstreakImage = nil
                self?.killstreakImageOffset = -100 // Reset for next time
            }
        }
    }

    // MARK: - Kill Notification Listener

    private func setupKillNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: .playerKilledEnemy,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            gameLog("💀 [NotificationCoordinator] Kill notification received!")
            if let killedPlayerName = notification.userInfo?["killedPlayerName"] as? String {
                gameLog("💀 [NotificationCoordinator] Killed player: \(killedPlayerName)")
                self?.showKillNotification(killedPlayerName: killedPlayerName)
            } else {
                gameLog("❌ [NotificationCoordinator] No killedPlayerName in notification userInfo")
            }
        }
    }

    private func showKillNotification(killedPlayerName: String) {
        gameLog("💀 [NotificationCoordinator] Showing kill notification for: \(killedPlayerName)")

        // Set the player name
        self.killedPlayerName = killedPlayerName

        // Reset opacity to 0
        killNotificationOpacity = 0.0

        // Show the notification
        showKillNotification = true

        // Fade in animation
        withAnimation(.easeOut(duration: 0.3)) {
            killNotificationOpacity = 1.0
        }

        // Hold for 3 seconds, then fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.killNotificationOpacity = 0.0
            }

            // Clean up after fade out animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showKillNotification = false
                self?.killedPlayerName = ""
                gameLog("💀 [NotificationCoordinator] Kill notification cleaned up")
            }
        }
    }

    // MARK: - Practice Mode Kill Listener

    private func setupPracticeModeKillListener() {
        NotificationCenter.default.addObserver(
            forName: .playerKilledEnemy,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Increment counter (view will check if in practice mode)
            self?.enemiesDefeated += 1
            gameLog("🎯 [NotificationCoordinator] Practice mode kill count: \(self?.enemiesDefeated ?? 0)")

            // Record kill in WaveManager (handles wave progression)
            GameContext.shared.waves.recordEnemyKill()
            gameLog("🌊 [NotificationCoordinator] Recorded kill in WaveManager - Wave \(GameContext.shared.waves.currentWave): \(GameContext.shared.waves.waveProgressText)")
        }
    }

    // MARK: - Player Death Listener

    private func setupPlayerDeathListener() {
        NotificationCenter.default.addObserver(
            forName: .playerDied,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            gameLog("💀 [NotificationCoordinator] Player death notification received")
            self?.onPlayerDeath?()
        }
    }

    // MARK: - Damage Flash Listener

    private func setupDamageFlashListener() {
        NotificationCenter.default.addObserver(
            forName: .playerTookDamage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            gameLog("💥 [NotificationCoordinator] Damage notification received!")
            self?.showDamageFlash()
        }
    }

    private func showDamageFlash() {
        gameLog("💥 [NotificationCoordinator] Showing damage flash")

        // Quick flash in (0.1s), then fade out (0.3s)
        damageFlashOpacity = 0.7  // Peak opacity

        withAnimation(.easeIn(duration: 0.1)) {
            damageFlashOpacity = 0.7
        }

        // Fade out after brief hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.damageFlashOpacity = 0.0
            }
        }
    }

    // MARK: - Reset Methods

    func resetPracticeMode() {
        enemiesDefeated = 0
    }
}
