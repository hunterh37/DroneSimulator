//
//  WaveManager.swift
//  HelicopterGame
//
//  Created by Claude on 10/15/25.
//  Manages endless wave progression for practice mode
//

import Foundation
import Observation

/// Manages wave-based enemy spawning with progressive difficulty
@Observable
public class WaveManager {
    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `WaveManager.shared` directly; everyone else must go
    // through GameContext.shared.waves.
    fileprivate static let shared = WaveManager()

    // MARK: - Properties

    /// Current wave number (starts at 1)
    public var currentWave: Int = 1

    /// Total enemies defeated across all waves
    public var totalEnemiesDefeated: Int = 0

    /// Enemies defeated in current wave
    public var enemiesDefeatedThisWave: Int = 0

    /// Whether a wave is currently active
    public var isWaveActive: Bool = false

    /// Whether a boss wave is active
    public var isBossWave: Bool = false

    // Wave configuration
    private let baseEnemiesPerWave: Int = 5
    private let bossWaveInterval: Int = 6 // Boss spawns every 6 waves
    private let difficultyScaleRate: Float = 0.2 // 20% increase per wave

    // MARK: - Initialization

    private init() {
        gameLog("🌊 [WaveManager] Initialized")
    }

    // MARK: - Wave Control

    /// Start practice mode wave system
    public func startWaveSystem() {
        currentWave = 1
        totalEnemiesDefeated = 0
        enemiesDefeatedThisWave = 0
        isWaveActive = true
        isBossWave = false

        gameLog("🌊 [WaveManager] Started wave system - Wave 1")
    }

    /// Stop wave system (when exiting practice mode)
    public func stopWaveSystem() {
        isWaveActive = false
        gameLog("🌊 [WaveManager] Stopped wave system")
    }

    /// Reset wave system
    public func reset() {
        currentWave = 1
        totalEnemiesDefeated = 0
        enemiesDefeatedThisWave = 0
        isWaveActive = false
        isBossWave = false
        gameLog("🌊 [WaveManager] Reset wave system")
    }

    /// Record an enemy kill
    public func recordEnemyKill() {
        enemiesDefeatedThisWave += 1
        totalEnemiesDefeated += 1

        gameLog("🌊 [WaveManager] Enemy defeated - Wave \(currentWave): \(enemiesDefeatedThisWave)/\(getEnemiesRequiredForWave(currentWave)), Total: \(totalEnemiesDefeated)")

        // Check if wave is complete
        if enemiesDefeatedThisWave >= getEnemiesRequiredForWave(currentWave) {
            completeWave()
        }
    }

    /// Complete current wave and advance to next
    private func completeWave() {
        gameLog("🌊 [WaveManager] Wave \(currentWave) completed!")

        currentWave += 1
        enemiesDefeatedThisWave = 0

        // Play wave start sound on root entity for spatial audio
        GameContext.shared.sound.playWaveStartSound(entity: rootEntity)

        // Check if next wave is a boss wave
        isBossWave = (currentWave % bossWaveInterval == 0)

        if isBossWave {
            gameLog("👑 [WaveManager] Wave \(currentWave) is a BOSS WAVE!")
        }

        gameLog("🌊 [WaveManager] Starting Wave \(currentWave)")
    }

    // MARK: - Difficulty Scaling

    /// Get number of enemies required to complete a wave
    public func getEnemiesRequiredForWave(_ wave: Int) -> Int {
        // Progressive scaling: base + (wave * scale rate)
        let scaled = Float(baseEnemiesPerWave) * (1.0 + Float(wave - 1) * difficultyScaleRate)
        return max(baseEnemiesPerWave, Int(scaled))
    }

    /// Get max concurrent enemies for current wave
    public func getMaxConcurrentEnemies() -> Int {
        // Start with 10, add 2 per wave, cap at 25
        let maxEnemies = 10 + (currentWave - 1) * 2
        return min(maxEnemies, 25)
    }

    /// Get spawn cooldown for current wave (decreases as waves progress)
    public func getSpawnCooldown() -> TimeInterval {
        // Start at 2.0 seconds, decrease to 0.5 seconds
        let baseCooldown: TimeInterval = 2.0
        let minCooldown: TimeInterval = 0.5
        let decreasePerWave: TimeInterval = 0.1

        let cooldown = baseCooldown - (TimeInterval(currentWave - 1) * decreasePerWave)
        return max(cooldown, minCooldown)
    }

    /// Get spawn radius for current wave
    public func getSpawnRadius() -> Float {
        // Radius increases slightly with waves to give player more space
        let baseRadius: Float = 15.0
        let radiusIncrease = Float(currentWave - 1) * 0.5
        return min(baseRadius + radiusIncrease, 25.0) // Cap at 25m
    }

    /// Check if it's time to spawn a boss
    public func shouldSpawnBoss() -> Bool {
        return isBossWave
    }

    // MARK: - Progress Info

    /// Get progress percentage for current wave
    public var waveProgress: Float {
        let required = getEnemiesRequiredForWave(currentWave)
        return Float(enemiesDefeatedThisWave) / Float(required)
    }

    /// Get display text for wave progress
    public var waveProgressText: String {
        return "\(enemiesDefeatedThisWave)/\(getEnemiesRequiredForWave(currentWave))"
    }

    /// Check if current wave is a boss wave
    public var isBossWaveActive: Bool {
        return currentWave % bossWaveInterval == 0
    }
}

extension GameContext {
    public var waves: WaveManager { WaveManager.shared }
}
