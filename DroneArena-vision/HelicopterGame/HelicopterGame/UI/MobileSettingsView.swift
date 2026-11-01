//
//  MobileSettingsView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/13/25.
//

import Foundation
import SwiftUI
import RealityKit

// MARK: - Mobile Settings View

struct MobileSettingsView: View {
    @Binding var isPresented: Bool
    let worldScene: WorldSceneController
    @Binding var testKillstreakCount: Int
    @State private var showJoystickSettings = false
    @Environment(GameUIModel.self) var gameUIModel

    var body: some View {
        ZStack {
            // Semi-transparent background with night color
            Color.night.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            // Settings panel using SteelCard
            SteelCard(hasHeaderStripe: true, variant: .overlay) {
                VStack(spacing: SteelLayout.lg) {
                    // Header
                    HStack {
                        Text("Game Settings")
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        GlassButton("Close", icon: "xmark") {
                            isPresented = false
                        }
                        .frame(width: 70)
                    }

                    // Scrollable content
                    ScrollView {
                        VStack(spacing: SteelLayout.lg) {
                            ControlSchemeSelector(compact: true)

                            // Edit Joystick Sensitivity button
                            ChromeButton("Edit Joystick Sensitivity", icon: "gamecontroller.fill", size: .large) {
                                showJoystickSettings = true
                            }

                            // Reset drone position button
                            ChromeButton("Reset Position", icon: "arrow.counterclockwise", size: .large) {
                                resetDronePosition()
                            }

                            #if DEBUG
                            // Time Trial - Add Wave button (only show in time trial mode)
                            if gameUIModel.modeManager.currentMode == .playTimeTrial {
                                ChromeButton("Add Wave", icon: "target", size: .large) {
                                    addTimeTrialWave()
                                }
                            }

                            // Spawn enemy button (only show in non-time-trial modes)
                            if gameUIModel.modeManager.currentMode != .playTimeTrial {
                                ChromeButton("Spawn Enemy", icon: "scope", size: .large) {
                                    spawnTestEnemyDrone()
                                }

                                // Spawn boss button (only in practice mode)
                                if gameUIModel.modeManager.currentMode == .playPractice {
                                    ChromeButton("Test Boss Spawn", icon: "crown.fill", size: .large) {
                                        spawnTestBoss()
                                    }
                                }
                            }

                            // Spawn package button
                            ChromeButton("Spawn Package", icon: "shippingbox", size: .large) {
                                spawnTestPackage()
                            }

                            // Test Killstreak button
                            ChromeButton("Test Killstreak", icon: "flame.fill", size: .large) {
                                testKillstreak()
                            }

                            // Test Game Over button
                            ChromeButton("Test Game Over", icon: "flag.checkered", size: .large) {
                                testGameOver()
                            }
                            #endif
                        }
                        .padding(.vertical, SteelLayout.md)
                    }
                    .frame(maxHeight: 300)
                }
            }
            .frame(maxWidth: 350, maxHeight: 400)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(SteelMotion.mediumEaseOut, value: isPresented)
        .sheet(isPresented: $showJoystickSettings) {
            JoystickSensitivitySettingsView(isPresented: $showJoystickSettings)
        }
    }
    
    #if DEBUG
    private func spawnTestEnemyDrone() {
        // Post notification to trigger enemy drone spawning
        NotificationCenter.default.post(
            name: .spawnTestEnemyDrone,
            object: nil,
            userInfo: nil
        )
        gameLog("🎯 [SettingsView] Requesting test enemy drone spawn")
    }

    private func spawnTestBoss() {
        guard let playerDrone = worldScene.playerDrone else {
            gameLog("⚠️ [SettingsView] Cannot spawn boss: no player drone found")
            return
        }

        // Spawn boss 15 meters away from player in a random direction
        let playerPosition = playerDrone.position
        let angle = Float.random(in: 0...(2 * Float.pi))
        let distance: Float = 15.0

        let spawnPosition = SIMD3<Float>(
            playerPosition.x + cos(angle) * distance,
            playerPosition.y + 3.0, // Spawn 3 meters higher up
            playerPosition.z + sin(angle) * distance
        )

        // Create boss entity
        let bossID = "TestBoss_\(UUID().uuidString.prefix(8))"
        let boss = EnemyDroneBossEntity(bossID: bossID, spawnPosition: spawnPosition)

        // Add to scene
        worldScene.rootEntity.addChild(boss)

        gameLog("👑 [SettingsView] Spawned test boss \(bossID) at position \(spawnPosition)")

        // Close settings panel
        isPresented = false
    }

    private func spawnTestPackage() {
        guard let playerDrone = worldScene.playerDrone else {
            gameLog("⚠️ [SettingsView] Cannot spawn package: no player drone found")
            return
        }

        // Get player position and spawn package nearby
        let playerPosition = playerDrone.position
        let spawnOffset = SIMD3<Float>(
            Float.random(in: -2.0...2.0), // Random X offset within 2 meters
            0.5, // Spawn 0.5m above ground
            Float.random(in: -2.0...2.0)  // Random Z offset within 2 meters
        )
        let spawnPosition = playerPosition + spawnOffset

        // Create package with random spec
        let specs = [PackageSpec.small, PackageSpec.medium, PackageSpec.large]
        let randomSpec = specs.randomElement()!
        let packageID = "TestPackage_\(UUID().uuidString.prefix(8))"

        // Delivery location can be random or near the player
        let deliveryLocation = playerPosition + SIMD3<Float>(
            Float.random(in: -5.0...5.0),
            0.0,
            Float.random(in: -5.0...5.0)
        )

        let package = PackageEntity(id: packageID, spec: randomSpec, deliveryLocation: deliveryLocation)
        package.position = spawnPosition

        // Add to scene
        worldScene.rootEntity.addChild(package)

        gameLog("📦 [SettingsView] Spawned test package: \(packageID) at \(spawnPosition) with spec: \(randomSpec.size)")
        gameLog("📦 [SettingsView] Package delivery location: \(deliveryLocation)")

        // Close settings panel
        isPresented = false
    }

    private func addTimeTrialWave() {
        // Advance to next level in time trial mode
        if let timeTrialManager = gameUIModel.modeManager.timeTrialManager {
            let nextLevel = timeTrialManager.currentLevelNumber + 1
            gameLog("⏱️ [MobileSettings] Adding time trial wave - starting level \(nextLevel)")
            timeTrialManager.startLevel(nextLevel)
        }

        // Close settings panel
        isPresented = false
    }
    #endif

    private func resetDronePosition() {
        // Reset drone to origin position
        if let drone = worldScene.playerDrone {
            drone.transform.translation = SIMD3<Float>(0, 0, 0)
            drone.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            gameLog("🚁 Drone position reset to origin (0, 0, 0)")
        }

        // Close settings panel
        isPresented = false
    }

    #if DEBUG
    private func testKillstreak() {
        gameLog("🎯 [SettingsView] Test killstreak triggered!")

        // Get networking for local player ID
        let networking = MultiplayerNetworking()
        let localPlayerID = networking.localPlayerID

        // Register persistent kill (this is what actually counts!)
        GameContext.shared.health.playerKillCounts[localPlayerID, default: 0] += 1
        let currentKills = GameContext.shared.health.playerKillCounts[localPlayerID] ?? 0
        gameLog("🎯 [SettingsView] Registered persistent kill - Total kills: \(currentKills)")

        // Add a fake kill to killfeed
        let killfeedEntry = KillfeedEntry(
            killerPlayerID: localPlayerID,
            killedPlayerID: "Bot_TestEnemy",
            timestamp: CACurrentMediaTime()
        )

        GameContext.shared.health.killfeedEntries.append(killfeedEntry)
        gameLog("🎯 [SettingsView] Added fake kill to killfeed: \(localPlayerID) killed Bot_TestEnemy")

        // Increment the test killstreak counter
        testKillstreakCount += 1
        gameLog("🎯 [SettingsView] Incremented test killstreak count to: \(testKillstreakCount)")

        // Grant XP for kill (10 XP per kill as per PlayerRank.xpForKill())
        let rankManager = PlayerRankManager()
        rankManager.localPlayerRank.addXP(10)
        rankManager.saveRank()
        gameLog("🎯 [SettingsView] Granted 10 XP for test kill")

        // Post killstreak notification (this triggers the killstreak image)
        NotificationCenter.default.post(
            name: .playerKillstreak,
            object: nil,
            userInfo: ["killstreak": testKillstreakCount]
        )
        gameLog("🎯 [SettingsView] Posted killstreak notification with killstreak: \(testKillstreakCount)")

        // Also post kill notification to show "You killed TestEnemy"
        NotificationCenter.default.post(
            name: .playerKilledEnemy,
            object: nil,
            userInfo: ["killedPlayerName": "TestEnemy"]
        )
        gameLog("🎯 [SettingsView] Posted kill notification for TestEnemy")

        // Check win condition immediately
        Task { @MainActor in
            GameContext.shared.battle.checkWinConditionNow()
        }

        // Close settings panel
        isPresented = false
    }

    private func testGameOver() {
        gameLog("🏁 [SettingsView] Test Game Over triggered!")

        // Get networking for local player ID
        let networking = MultiplayerNetworking()
        let localPlayerID = networking.localPlayerID

        // Grant some test XP to show on game over screen (150 XP for testing)
        let rankManager = PlayerRankManager()
        rankManager.localPlayerRank.addXP(150)
        rankManager.saveRank()
        gameLog("🏁 [SettingsView] Granted 150 XP for test")

        // Force set kill count to 2 to meet win condition
        GameContext.shared.health.playerKillCounts[localPlayerID] = 2
        gameLog("🏁 [SettingsView] Set kill count to 2 for local player")

        // Ensure battle is active state before checking win
        if GameContext.shared.battle.currentState != .active {
            gameLog("🏁 [SettingsView] Starting battle first...")
            GameContext.shared.battle.startBattle()

            // Wait a moment for battle to start, then trigger win
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                gameLog("🏁 [SettingsView] Now checking win condition...")
                GameContext.shared.battle.checkWinConditionNow()
            }
        } else {
            // Battle already active, trigger win immediately
            gameLog("🏁 [SettingsView] Battle active, checking win condition...")
            GameContext.shared.battle.checkWinConditionNow()
        }

        // Close settings panel
        isPresented = false
    }
    #endif
}
