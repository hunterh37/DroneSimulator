//
//  ModeManager.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI
import Observation
import QuartzCore
import RealityKit

/// Central state machine manager for Step 3 game flow
@MainActor
@Observable
public class ModeManager {
    public var currentMode: GameMode = .menu
    public var previousMode: GameMode = .menu

    // Mode-specific state
    public var isTransitioning: Bool = false
    public var currentSessionResults: SessionResults?

    // Dependencies
    public let economyModel = EconomyModel()
    public var buildModeManager: BuildModeManager
    public var sandboxManager: SandboxManager?
    public var deliveryDirector: DeliveryDirector?
    public var timeTrialManager: TimeTrialManager?

    // Dependencies for spawning
    private var worldScene: Entity?
    private var packageSpawner: PackageSpawner?

    public init(buildModeManager: BuildModeManager) {
        self.buildModeManager = buildModeManager
    }

    // MARK: - Setup

    public func setupDependencies(worldScene: Entity, packageSpawner: PackageSpawner) {
        self.worldScene = worldScene
        self.packageSpawner = packageSpawner
    }

    // MARK: - Mode Transitions

    public func switchToMode(_ newMode: GameMode) {
        guard !isTransitioning else { return }

        isTransitioning = true
        previousMode = currentMode

        // Perform cleanup for old mode
        cleanupCurrentMode()

        // Set new mode
        currentMode = newMode

        // Setup new mode
        setupNewMode()

        isTransitioning = false

        gameLog("Mode changed from \(previousMode) to \(currentMode)")
    }

    private func cleanupCurrentMode() {
        switch currentMode {
        case .playSandbox:
            sandboxManager?.cleanup()
        case .playDelivery:
            deliveryDirector?.cleanup()
        case .build:
            buildModeManager.saveLayout()
        case .playMultiplayer:
            // Multiplayer cleanup handled separately
            break
        case .playTimeTrial:
            timeTrialManager?.pauseGame()
        case .playSafari:
            SafariManager.shared.stop()
        case .playRaceLeague:
            RaceLeagueManager.shared.stop()
        case .playCrateDelivery:
            CrateDeliveryManager.shared.stop()
        default:
            break
        }
    }

    private func setupNewMode() {
        switch currentMode {
        case .menu:
            setupMainMenu()
        case .build:
            setupBuildMode()
        case .playSandbox:
            setupSandboxMode()
        case .playDelivery:
            setupDeliveryMode()
        case .playMultiplayer:
            setupMultiplayerMode()
        case .playPractice:
            setupPracticeMode()
        case .playTimeTrial:
            setupTimeTrialMode()
        case .playSafari:
            gameLog("[ModeManager] Safari")
        case .playRaceLeague:
            gameLog("[ModeManager] Race League")
        case .playCrateDelivery:
            gameLog("[ModeManager] Fold Freight")
        case .results:
            setupResultsMode()
        case .play:
            // Legacy support - default to delivery mode
            currentMode = .playDelivery
            setupDeliveryMode()
        }
    }

    // MARK: - Mode Setup Methods

    private func setupMainMenu() {
        // Reset any temporary state
        currentSessionResults = nil
    }

    private func setupBuildMode() {
        buildModeManager.switchToMode(.build)
        buildModeManager.loadLayout()
    }

    private func setupSandboxMode() {
        if sandboxManager == nil {
            sandboxManager = SandboxManager()
        }

        // Setup sandbox manager with world scene and package spawner
        if let worldScene = worldScene, let packageSpawner = packageSpawner {
            sandboxManager?.setup(worldScene: worldScene, packageSpawner: packageSpawner)
        }

        sandboxManager?.startSession()
    }

    private func setupDeliveryMode() {
        // Validate layout before starting delivery mode
        guard buildModeManager.isLayoutValid else {
            gameLog("Cannot start delivery mode: layout is invalid")
            switchToMode(.build)
            return
        }

        if deliveryDirector == nil {
            deliveryDirector = DeliveryDirector()
        }
        deliveryDirector?.startSession(with: buildModeManager.currentLevelLayout)
    }

    private func setupMultiplayerMode() {
        // Multiplayer setup handled by multiplayer UI components
        gameLog("🌐 Multiplayer mode setup")
    }

    private func setupPracticeMode() {
        // Practice mode setup - combat training against AI drones
        gameLog("🎯 [ModeManager] Setting up Practice mode")
    }

    private func setupTimeTrialMode() {
        // Time trial mode setup - ring collection challenge
        if timeTrialManager == nil {
            timeTrialManager = TimeTrialManager()
        }

        // Setup time trial manager with world scene if available
        if let worldScene = worldScene {
            // We'll need to get the player drone reference - this will be set up in MobileRealityView
            gameLog("⏱️ [ModeManager] Setting up Time Trial mode")
        }
    }

    private func setupResultsMode() {
        // Results should be set before transitioning to this mode
    }

    // MARK: - Session Management

    public func completeDeliverySession(with results: SessionResults) {
        currentSessionResults = results

        // Award progression based on results
        awardProgressionForResults(results)

        // Transition to results screen
        switchToMode(.results)
    }

    public func completeSandboxSession(timeSpent: TimeInterval) {
        economyModel.playerProfile.totalSandboxTime += timeSpent
        economyModel.saveProfile()

        // Award small coin bonus for sandbox time
        let coinBonus = Int(timeSpent / 60.0) * 5 // 5 coins per minute
        if coinBonus > 0 {
            economyModel.awardCoins(coinBonus, reason: "Sandbox playtime")
        }

        switchToMode(.menu)
    }

    private func awardProgressionForResults(_ results: SessionResults) {
        // Award coins for completed deliveries
        for delivery in results.completedDeliveries {
            let baseCoins = 25
            let typeMultiplier = delivery.packageType.coinMultiplier
            let coins = Int(Float(baseCoins) * typeMultiplier)

            economyModel.awardCoins(coins, reason: "Delivery: \(delivery.packageType.displayName)")
        }

        // Award medal based on performance
        if let levelID = results.levelID {
            let medal = calculateMedal(for: results)
            economyModel.awardMedal(medal, for: levelID)
        }

        // Update delivery count
        economyModel.playerProfile.totalDeliveries += results.completedDeliveries.count
        economyModel.saveProfile()
    }

    private func calculateMedal(for results: SessionResults) -> Medal {
        let completionRate = Float(results.completedDeliveries.count) / Float(results.totalJobs)
        let timeBonus: Float = results.averageDeliveryTime < 30.0 ? 0.2 : 0.0
        let score = completionRate + timeBonus

        if score >= 0.9 {
            return .gold
        } else if score >= 0.7 {
            return .silver
        } else {
            return .bronze
        }
    }

    // MARK: - Utility Methods

    public func canStartDeliveryMode() -> Bool {
        return buildModeManager.isLayoutValid
    }

    public func returnToMenu() {
        switchToMode(.menu)
    }

    public func restartCurrentSession() {
        let currentModeToRestart = currentMode
        switchToMode(.menu)
        switchToMode(currentModeToRestart)
    }
}

// MARK: - Session Results

public struct SessionResults {
    public let levelID: String?
    public let completedDeliveries: [CompletedDelivery]
    public let totalJobs: Int
    public let sessionDuration: TimeInterval
    public let averageDeliveryTime: TimeInterval
    public let coinsEarned: Int
    public let medalAwarded: Medal?

    public init(levelID: String?, completedDeliveries: [CompletedDelivery], totalJobs: Int, sessionDuration: TimeInterval) {
        self.levelID = levelID
        self.completedDeliveries = completedDeliveries
        self.totalJobs = totalJobs
        self.sessionDuration = sessionDuration
        self.averageDeliveryTime = completedDeliveries.isEmpty ? 0 :
            completedDeliveries.reduce(0) { $0 + $1.deliveryTime } / Double(completedDeliveries.count)
        self.coinsEarned = completedDeliveries.reduce(0) { sum, delivery in
            let baseCoins = 25
            return sum + Int(Float(baseCoins) * delivery.packageType.coinMultiplier)
        }
        self.medalAwarded = nil // Calculated later by ModeManager
    }
}

public struct CompletedDelivery {
    public let packageType: PackageType
    public let deliveryTime: TimeInterval
    public let wasPriority: Bool

    public init(packageType: PackageType, deliveryTime: TimeInterval, wasPriority: Bool = false) {
        self.packageType = packageType
        self.deliveryTime = deliveryTime
        self.wasPriority = wasPriority
    }
}

// MARK: - Enhanced Sandbox Manager

@MainActor
@Observable
public class SandboxManager {
    public var isActive: Bool = false
    private var sessionStartTime: TimeInterval = 0
    private var spawnedPackages: [PackageEntity] = []
    private var despawnTimer: Timer?

    // Sandbox-specific properties
    public var critterManager = CritterManager()
    public var totalCratesSpawned: Int = 0
    public var totalCratesDespawned: Int = 0

    // Configuration
    private let maxConcurrentCrates: Int = 15
    private let crateDespawnTime: TimeInterval = 60.0 // 60 seconds
    private weak var worldScene: Entity?
    private weak var packageSpawner: PackageSpawner?

    public init() {}

    public func setup(worldScene: Entity, packageSpawner: PackageSpawner) {
        self.worldScene = worldScene
        self.packageSpawner = packageSpawner
        critterManager.setup(worldScene: worldScene)
    }

    public func startSession() {
        isActive = true
        sessionStartTime = CACurrentMediaTime()
        spawnedPackages.removeAll()
        totalCratesSpawned = 0
        totalCratesDespawned = 0

        // Spawn initial critters
        critterManager.spawnRandomCritters(count: 3)

        // Start despawn timer
        startDespawnTimer()

        gameLog("Sandbox session started with critters")
    }

    public func cleanup() {
        isActive = false
        despawnTimer?.invalidate()
        despawnTimer = nil

        // Clean up all spawned crates
        despawnAllCrates()

        // Clear critters
        critterManager.clearAllCritters()

        gameLog("Sandbox session ended")
    }

    public var sessionDuration: TimeInterval {
        guard isActive else { return 0 }
        return CACurrentMediaTime() - sessionStartTime
    }

    // MARK: - Crate Management

    public func spawnCrate(spec: PackageSpec, type: PackageType, at position: SIMD3<Float>? = nil) -> PackageEntity? {
        guard isActive else { return nil }
        guard spawnedPackages.count < maxConcurrentCrates else {
            gameLog("Maximum crates reached in sandbox")
            return nil
        }

        // Use provided position or random position near player
        let spawnPosition = position ?? generateRandomSpawnPosition()

        // Create package entity
        let package = PackageEntity(
            id: "sandbox_\(UUID().uuidString)",
            spec: spec,
            deliveryLocation: spawnPosition // Not used in sandbox
        )

        package.transform.translation = spawnPosition
        package.components.set(SandboxCrateComponent(
            spawnTime: CACurrentMediaTime(),
            packageType: type
        ))

        // Add to world and tracking
        worldScene?.addChild(package)
        spawnedPackages.append(package)
        totalCratesSpawned += 1

        // Notify critters of new crate
        critterManager.notifyActivity(position: spawnPosition, type: .crateDrop)

        gameLog("Spawned \(type.displayName) crate at \(spawnPosition)")
        return package
    }

    public func spawnCritter(type: CritterType, at position: SIMD3<Float>? = nil) -> CritterEntity? {
        let spawnPosition = position ?? generateRandomSpawnPosition()
        return critterManager.spawnCritter(type: type, at: spawnPosition)
    }

    private func generateRandomSpawnPosition() -> SIMD3<Float> {
        // Spawn in a circle around origin with some height variation
        let angle = Float.random(in: 0...(2 * Float.pi))
        let radius = Float.random(in: 1.5...4.0)
        let height = Float.random(in: 0.5...2.0)

        return SIMD3<Float>(
            cos(angle) * radius,
            height,
            sin(angle) * radius
        )
    }

    private func startDespawnTimer() {
        despawnTimer?.invalidate()
        despawnTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForDespawn()
        }
    }

    private func checkForDespawn() {
        let currentTime = CACurrentMediaTime()

        for i in (0..<spawnedPackages.count).reversed() {
            let package = spawnedPackages[i]

            if let sandboxComponent = package.components[SandboxCrateComponent.self],
               currentTime - sandboxComponent.spawnTime > crateDespawnTime {
                despawnCrate(at: i)
            }
        }
    }

    private func despawnCrate(at index: Int) {
        guard index < spawnedPackages.count else { return }

        let package = spawnedPackages[index]
        package.removeFromParent()
        spawnedPackages.remove(at: index)
        totalCratesDespawned += 1

        gameLog("Despawned crate due to timeout")
    }

    public func despawnAllCrates() {
        for package in spawnedPackages {
            package.removeFromParent()
        }
        spawnedPackages.removeAll()
    }

    public func getSessionStats() -> SandboxSessionStats {
        return SandboxSessionStats(
            duration: sessionDuration,
            cratesSpawned: totalCratesSpawned,
            cratesDespawned: totalCratesDespawned,
            activeCrates: spawnedPackages.count,
            activeCritters: critterManager.activeCritters.count
        )
    }
}

// MARK: - Supporting Components and Types

public struct SandboxCrateComponent: Component {
    public let spawnTime: TimeInterval
    public let packageType: PackageType

    public init(spawnTime: TimeInterval, packageType: PackageType) {
        self.spawnTime = spawnTime
        self.packageType = packageType
    }
}

public struct SandboxSessionStats {
    public let duration: TimeInterval
    public let cratesSpawned: Int
    public let cratesDespawned: Int
    public let activeCrates: Int
    public let activeCritters: Int

    public var efficiency: Double {
        guard cratesSpawned > 0 else { return 0 }
        return Double(cratesSpawned - cratesDespawned) / Double(cratesSpawned)
    }
}