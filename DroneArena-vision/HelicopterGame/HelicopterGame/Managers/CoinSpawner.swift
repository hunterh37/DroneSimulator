//
//  CoinSpawner.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import RealityKit
import simd
import QuartzCore

@MainActor
@Observable
public class CoinSpawner {
    private weak var worldScene: WorldSceneController?
    private var spawnTimer: Timer?
    private var activeCoins: [CoinEntity] = []

    // Spawn parameters
    private let spawnInterval: TimeInterval = 5.0 // Spawn a coin every 5 seconds
    private let maxCoins: Int = 8 // Maximum coins in the scene at once
    private let spawnRange: Float = 10.0 // Spawn within 10 units from center
    private let heightRange: (min: Float, max: Float) = (0.5, 3.0) // Height range for spawning

    public init() {}

    public func setup(worldScene: WorldSceneController) {
        self.worldScene = worldScene
    }

    public func startSpawning() {
        stopSpawning()

        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.spawnCoin()
            }
        }

        // Spawn initial coins
        spawnInitialCoins()
    }

    public func stopSpawning() {
        spawnTimer?.invalidate()
        spawnTimer = nil

        // Remove all active coins
        clearAllCoins()
    }

    private func spawnInitialCoins() {
        // Spawn 2-3 coins immediately when starting
        let initialCount = Int.random(in: 2...3)
        for _ in 0..<initialCount {
            spawnCoin()
        }
    }

    private func spawnCoin() {
        guard let worldScene = worldScene else { return }
        guard activeCoins.count < maxCoins else { return }

        // Generate random spawn position
        let spawnPosition = generateRandomSpawnPosition()

        // Create coin entity
        let coin = CoinEntity(coinID: UUID().uuidString, value: 10)
        coin.transform.translation = spawnPosition

        // Add to scene
        worldScene.rootEntity.addChild(coin)
        activeCoins.append(coin)
    }

    private func generateRandomSpawnPosition() -> SIMD3<Float> {
        // Generate random position within spawn range
        let x = Float.random(in: -spawnRange...spawnRange)
        let z = Float.random(in: -spawnRange...spawnRange)
        let y = Float.random(in: heightRange.min...heightRange.max)

        return SIMD3<Float>(x, y, z)
    }

    public func collectCoin(_ coin: CoinEntity) -> Int {
        // Remove from active coins list
        if let index = activeCoins.firstIndex(where: { $0.coinID == coin.coinID }) {
            activeCoins.remove(at: index)
        }

        // Remove from scene
        coin.collect()

        return coin.coinValue
    }

    public func clearAllCoins() {
        for coin in activeCoins {
            coin.removeFromParent()
        }
        activeCoins.removeAll()
    }

    public func updateCoins(deltaTime: Float) {
        // Update coin rotations if manual rotation is needed
        for coin in activeCoins {
            coin.updateRotation(deltaTime: deltaTime)
        }

        // Remove coins that have been removed from the scene
        activeCoins.removeAll { coin in
            coin.parent == nil
        }
    }

    // MARK: - Public Accessors

    public var coinCount: Int {
        return activeCoins.count
    }

    public func getCoinAt(position: SIMD3<Float>, tolerance: Float = 0.5) -> CoinEntity? {
        return activeCoins.first { coin in
            let distance = length(coin.transform.translation - position)
            return distance <= tolerance
        }
    }
}