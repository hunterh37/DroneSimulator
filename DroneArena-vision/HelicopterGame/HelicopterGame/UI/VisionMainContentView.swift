//
//  VisionMainContentView.swift
//  HelicopterGame
//
//  Created by Claude Code on 10/19/25.
//

import SwiftUI
import DicyaninVirtualJoystick

#if os(visionOS)
import RealityKit

struct VisionMainContentView: View {
    @Environment(GameUIModel.self) var gameUIModel
    @Environment(AppModel.self) var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Binding var showThumbControllerSettings: Bool
    @Binding var showThumbJoystickHelp: Bool
    @Binding var isDroneLaunched: Bool
    @State private var showSettings = false
    @State private var testKillstreakCount = 0
    @State private var showWeaponSelection1 = false
    @State private var showWeaponSelection2 = false
    @State private var currentWeaponSlot: Int = 1
    @State private var showExitConfirmation = false

    // Killstreak display state
    @State private var currentKillstreakImage: String?
    @State private var showKillstreakImage = false
    @State private var killstreakImageOffset: CGFloat = -100

    // Kill notification display state
    @State private var showKillNotification = false
    @State private var killedPlayerName: String = ""
    @State private var killNotificationOpacity: Double = 0.0

    // Battle announcement display state
    @State private var showBattleAnnouncement = false
    @State private var battleAnnouncementScale: CGFloat = 100.0
    @State private var battleAnnouncementOpacity: Double = 0.0

    // Drone stats state
    @State private var droneSpeed: Float = 0.0
    @State private var droneAltitude: Float = 0.0
    @State private var lastDronePosition: SIMD3<Float>?
    @State private var statsUpdateTimer: Timer?
    @State private var smoothedSpeed: Float = 0.0  // Smoothed speed for display

    private var eventName: String {
        switch gameUIModel.modeManager.currentMode {
        case .playSafari: return "Safari"
        case .playCrateDelivery: return "Fold Freight"
        default: return "Race League"
        }
    }
    private var eventTint: Color {
        switch gameUIModel.modeManager.currentMode {
        case .playSafari: return Arena.go
        case .playCrateDelivery: return Arena.ice
        default: return Arena.volt
        }
    }

    var body: some View {
        ZStack {
            Arena.ink.opacity(0.6).ignoresSafeArea()

            // Mode HUD sits under the chrome so its panels center in the window.
            if gameUIModel.modeManager.currentMode == .playSafari {
                SafariHUDView(onMainMenu: { gameUIModel.modeManager.switchToMode(.menu) })
            }
            if gameUIModel.modeManager.currentMode == .playCrateDelivery && isDroneLaunched {
                CrateDeliveryHUDView(onMainMenu: { gameUIModel.modeManager.switchToMode(.menu) })
            }
            if gameUIModel.modeManager.currentMode == .playRaceLeague {
                RaceLeagueHUDView(onMainMenu: { gameUIModel.modeManager.switchToMode(.menu) })
            }

            // Chrome: armor + controls top-left, system buttons top-right.
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        BattleHealthGauge()
                        ControlSchemeBadge()
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ArenaIconButton(icon: "questionmark", size: 38, tint: Arena.textDim) { showThumbJoystickHelp = true }
                        ArenaIconButton(icon: "gearshape.fill", size: 38, tint: Arena.textDim) { showSettings = true }
                        ArenaIconButton(icon: "xmark", size: 38, tint: Arena.hostile) { handleExit() }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                Spacer()
            }

            // Bottom cluster: hardpoint A, telemetry, hardpoint B.
            if isDroneLaunched {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 10) {
                        HardpointButton(
                            slot: 1, weapon: GameContext.shared.loadout.selectedWeapon, armed: currentWeaponSlot == 1,
                            onFire: { currentWeaponSlot = 1; fireMissile(slot: 1) },
                            onSwap: { showWeaponSelection1 = true }
                        )
                        Spacer(minLength: 0)
                        CurrentDroneStatsView(speed: droneSpeed, altitude: droneAltitude)
                        Spacer(minLength: 0)
                        HardpointButton(
                            slot: 2, weapon: GameContext.shared.loadout.selectedWeapon2, armed: currentWeaponSlot == 2,
                            onFire: { currentWeaponSlot = 2; fireMissile(slot: 2) },
                            onSwap: { showWeaponSelection2 = true }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
                }
            }

            if showKillstreakImage, let imageName = currentKillstreakImage {
                VStack {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .offset(y: killstreakImageOffset)
                        .padding(.top, 140)
                    Spacer()
                }
            }
            if showBattleAnnouncement {
                BattleAnnouncementView(scale: battleAnnouncementScale, opacity: battleAnnouncementOpacity)
            }
            if showKillNotification {
                KillNotificationView(killedPlayerName: killedPlayerName, opacity: killNotificationOpacity)
            }

            if !isDroneLaunched {
                LaunchGridOverlay(
                    eventName: eventName,
                    tint: eventTint,
                    onLaunch: {
                        withAnimation(Arena.snap) { isDroneLaunched = true }
                        Task { try? await appModel.inputRouter.startInputSystem() }
                    },
                    onHelp: { openWindow(id: "joystick-help") }
                )
                .task {
                    guard ScreenshotDirector.isActive || DemoDirector.isActive else { return }
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(Arena.snap) { isDroneLaunched = true }
                    Task { try? await appModel.inputRouter.startInputSystem() }
                    Task { @MainActor in await ScreenshotDirector.startRaceIfNeeded() }
                    if ScreenshotDirector.hideUI || DemoDirector.hideUI {
                        try? await Task.sleep(for: .seconds(4))
                        dismissWindow(id: "MainWindow")
                    }
                }
                .transition(.opacity)
            }

            RespawnOverlayView()

            if showSettings {
                MobileSettingsView(
                    isPresented: $showSettings,
                    worldScene: appModel.worldSceneController ?? WorldSceneController(),
                    testKillstreakCount: $testKillstreakCount
                )
                .environment(gameUIModel)
            }

            if showExitConfirmation {
                ExitConfirmPanel(onStay: { showExitConfirmation = false }, onExit: { confirmExit() })
                    .transition(.opacity)
            }
        }
        .animation(Arena.snap, value: showExitConfirmation)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWeaponSelection1) {
            WeaponSelectionView(
                slot: 1,
                onWeaponSelected: { weapon, _ in
                    GameContext.shared.loadout.selectWeapon(weapon)
                    showWeaponSelection1 = false
                },
                onCancel: { showWeaponSelection1 = false }
            )
        }
        .sheet(isPresented: $showWeaponSelection2) {
            WeaponSelectionView(
                slot: 2,
                onWeaponSelected: { weapon, _ in
                    GameContext.shared.loadout.selectWeapon2(weapon)
                    showWeaponSelection2 = false
                },
                onCancel: { showWeaponSelection2 = false }
            )
        }
        .onAppear {
            setupKillstreakListener()
            setupKillNotificationListener()
            setupDroneStatsTimer()
        }
        .onDisappear {
            statsUpdateTimer?.invalidate()
            statsUpdateTimer = nil
        }
    }

    // MARK: - Helper Functions

    private func handleExit() {
        // Show confirmation for multiplayer mode
        showExitConfirmation = true
    }

    private func confirmExit() {
        Task {
            // Switch to menu mode
            await MainActor.run {
                gameUIModel.modeManager.switchToMode(.menu)
                showExitConfirmation = false
            }

            // Dismiss immersive space
            await dismissImmersiveSpace()
        }
    }

    private func fireMissile(slot: Int = 1) {
        if gameUIModel.modeManager.currentMode == .playCrateDelivery {
            CrateDeliveryManager.shared.clawButton()
            return
        }
        guard let worldScene = appModel.worldSceneController,
              let drone = worldScene.playerDrone else {
            gameLog("⚠️ Cannot fire missile: no drone available")
            return
        }

        // Get weapon stats for the selected slot
        let weaponStats = GameContext.shared.loadout.getCurrentWeaponStats(slot: slot)
        let weaponModelName = GameContext.shared.loadout.getCurrentWeaponModelName(slot: slot)

        gameLog("🚀 Using weapon from slot \(slot): \(weaponModelName)")
        if let stats = weaponStats {
            gameLog("🚀 Weapon stats - damage: \(stats.damage), speed: \(stats.speed), radius: \(stats.collisionRadius)")
        }

        // Fire missile from local drone (using weapon-specific stats from the specified slot)
        DroneMissileSystem.fireMissile(from: drone, addingTo: worldScene.rootEntity, slot: slot)

        if gameUIModel.multiplayerManager.isMultiplayerEnabled {
            Task {
                let spawnOffset: SIMD3<Float> = SIMD3<Float>(0, 0, -0.03)
                let worldSpawnOffset = drone.orientation.act(spawnOffset)
                let spawnPosition = drone.position + worldSpawnOffset
                let forwardDirection = drone.orientation.act(SIMD3<Float>(0, 0, -1))
                let missileSpeed: Float = weaponStats?.speed ?? 5.0
                let missileVelocity = forwardDirection * missileSpeed

                await gameUIModel.multiplayerManager.networking.sendFireDroneMissile(
                    position: spawnPosition,
                    velocity: missileVelocity
                )
            }
        }
    }

    // MARK: - Drone Stats Update

    private func setupDroneStatsTimer() {
        // Update stats at 30 FPS (every ~0.033 seconds)
        statsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateDroneStats()
            }
        }
    }

    private func updateDroneStats() {
        guard let drone = appModel.worldSceneController?.playerDrone else {
            droneSpeed = 0.0
            smoothedSpeed = 0.0
            droneAltitude = 0.0
            return
        }

        let currentPosition = drone.position

        // Get altitude from drone's Y position (always update this)
        droneAltitude = currentPosition.y

        // Initialize last position on first update
        guard let lastPos = lastDronePosition else {
            lastDronePosition = currentPosition
            droneSpeed = 0.0
            smoothedSpeed = 0.0
            return
        }

        // Calculate instantaneous speed from position change
        let deltaPosition = currentPosition - lastPos
        let distance = length(deltaPosition)
        let deltaTime: Float = 1.0 / 30.0  // Timer runs at 30 FPS
        let instantaneousSpeed = distance / deltaTime

        // Apply exponential smoothing to reduce flickering
        // smoothFactor of 0.3 means: 30% new value, 70% old value
        let smoothFactor: Float = 0.3
        smoothedSpeed = smoothedSpeed * (1.0 - smoothFactor) + instantaneousSpeed * smoothFactor

        // Update displayed speed with smoothed value
        droneSpeed = smoothedSpeed

        // Update last position for next frame
        lastDronePosition = currentPosition
    }

    // MARK: - Killstreak Listener

    private func setupKillstreakListener() {
        NotificationCenter.default.addObserver(
            forName: .playerKillstreak,
            object: nil,
            queue: .main
        ) { notification in
            gameLog("🎯 [VisionMainContentView] Killstreak notification received!")
            if let killstreak = notification.userInfo?["killstreak"] as? Int {
                gameLog("🎯 [VisionMainContentView] Killstreak value: \(killstreak)")
                self.showKillstreakImage(for: killstreak)
            } else {
                gameLog("❌ [VisionMainContentView] No killstreak value in notification userInfo")
            }
        }
    }

    // MARK: - Kill Notification Listener

    private func setupKillNotificationListener() {
        NotificationCenter.default.addObserver(
            forName: .playerKilledEnemy,
            object: nil,
            queue: .main
        ) { notification in
            gameLog("💀 [VisionMainContentView] Kill notification received!")
            if let killedPlayerName = notification.userInfo?["killedPlayerName"] as? String {
                gameLog("💀 [VisionMainContentView] Killed player: \(killedPlayerName)")
                self.showKillNotificationFunc(killedPlayerName: killedPlayerName)
            } else {
                gameLog("❌ [VisionMainContentView] No killedPlayerName in notification userInfo")
            }
        }
    }

    private func showKillNotificationFunc(killedPlayerName: String) {
        gameLog("💀 [VisionMainContentView] Showing kill notification for: \(killedPlayerName)")

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.killNotificationOpacity = 0.0
            }

            // Clean up after fade out animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showKillNotification = false
                self.killedPlayerName = ""
                gameLog("💀 [VisionMainContentView] Kill notification cleaned up")
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

        gameLog("🎯 [VisionMainContentView] showKillstreakImage called")
        gameLog("🎯 [VisionMainContentView] Killstreak: \(killstreak) -> Image: \(imageName)")
        gameLog("🎯 [VisionMainContentView] Current showKillstreakImage state: \(showKillstreakImage)")

        currentKillstreakImage = imageName
        killstreakImageOffset = -100 // Start above screen

        gameLog("🎯 [VisionMainContentView] Set currentKillstreakImage to: \(currentKillstreakImage ?? "nil")")

        // Slide down and fade in
        withAnimation(.easeOut(duration: 0.5)) {
            showKillstreakImage = true
            killstreakImageOffset = 0
        }

        gameLog("🎯 [VisionMainContentView] Animation started - showKillstreakImage: \(showKillstreakImage)")

        // Hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            gameLog("🎯 [VisionMainContentView] Hiding killstreak image after 2 seconds")
            withAnimation(.easeInOut(duration: 0.3)) {
                showKillstreakImage = false
                killstreakImageOffset = 100 // Slide down and out
            }

            // Clean up after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                gameLog("🎯 [VisionMainContentView] Cleaning up killstreak image")
                currentKillstreakImage = nil
                killstreakImageOffset = -100 // Reset for next time
            }
        }
    }
}

#endif
