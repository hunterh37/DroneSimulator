//
//  MobileRealityView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI
import RealityKit
import ARKit

struct MobileRealityView: View {
    @Binding var isPresented: Bool
    @Environment(AppModel.self) var appModel
    @Environment(GameUIModel.self) var gameUIModel
    @State private var worldScene = WorldSceneController()
    private var inputRouter: InputRouter { appModel.inputRouter }
    private var flightController: FlightController { appModel.flightController }
    @State private var interactionController: InteractionController?
    @State private var hudViewModel = HUDViewModel()
    @State private var runViewModel = RunViewModel()
    @State private var multiplayerPositionTimer: Timer?
    @State var collisionSubscription: EventSubscription?
    @State private var frameSubscription: EventSubscription?
    private let session = ARSession()
    @State private var notificationCoordinator = GameNotificationCoordinator()
    @State private var clawController = ClawController()
    @State private var packageSpawner = PackageSpawner()
    @State private var deliveryDirector = DeliveryDirector()
    @State private var coinSpawner = CoinSpawner()
    @State private var enemyDroneSpawner = EnemyDroneSpawner()
    @State private var bossDroneSpawner = EnemyDroneBossSpawner()
    @State private var showMobileSettings = false
    @State private var showJoystickTips = true
    @State private var showPlayerListSheet = false
    @State private var showPlayerListOverlay = false
    @State private var showGameHelp = false
    @State private var showExitConfirmation = false
    @State private var showWeaponSelection1 = false
    @State private var showWeaponSelection2 = false
    @State private var currentWeaponSlot: Int = 1
    @State private var isLoading = true
    @State private var showUI = false
    @State private var showBattleAnnouncement = false
    @State private var battleAnnouncementScale: CGFloat = 100.0
    @State private var battleAnnouncementOpacity: Double = 0.0
    @State private var testKillstreakCount: Int = 0
    @State private var showSinglePlayerGameOver = false
    @State private var singlePlayerOldRank: PlayerRank?
    @State private var singlePlayerNewRank: PlayerRank?
    @State private var singlePlayerXPEarned: Int = 0
    @State private var droneSpeed: Float = 0.0
    @State private var droneAltitude: Float = 0.0
    @State private var lastDronePosition: SIMD3<Float>?
    @State private var smoothedSpeed: Float = 0.0  // Smoothed speed for display

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .spatialTracking
                appModel.worldSceneController = worldScene
                content.add(worldScene.rootEntity)
                setupStep2Systems()
                interactionController = InteractionController(
                    worldScene: worldScene,
                    flightController: flightController
                )
                collisionSubscription = content.subscribe(to: CollisionEvents.Began.self) { event in
                    GameContext.shared.collision.handleCollisionBegan(event: event)
                }
                frameSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    updateGameSystems(deltaTime: Float(event.deltaTime))
                }
            }
            .task {
                do {
                    try await inputRouter.startInputSystem()
                    appModel.setModeChangeCallback(handleModeChange)
                    if [.playSafari, .playRaceLeague, .playCrateDelivery].contains(gameUIModel.modeManager.currentMode) {
                        handleModeChange(gameUIModel.modeManager.currentMode)
                    }
                    appModel.worldSceneController = worldScene
                    if gameUIModel.modeManager.currentMode == .playTimeTrial {
                        setupTimeTrialMode()
                    }
                    worldScene.createHandAnchoredHUD(with: hudViewModel)
                    if gameUIModel.buildModeManager.currentMode == .play && gameUIModel.buildModeManager.isLayoutValid {
                        worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                        packageSpawner.startSpawning()
                        deliveryDirector.startNextJob()
                    }
                    if gameUIModel.modeManager.currentMode == .playDelivery || gameUIModel.modeManager.currentMode == .play {
                        runViewModel.startRun(levelID: "tutorial")
                    }
                    if gameUIModel.multiplayerManager.isMultiplayerEnabled {
                        startMultiplayerPositionTimer()
                    }
                    GameContext.shared.health.setMultiplayerNetworking(gameUIModel.multiplayerManager.networking)
                    notificationCoordinator.setupAllListeners()
                    notificationCoordinator.onPlayerDeath = {
                        if self.gameUIModel.modeManager.currentMode == .playPractice {
                            self.handlePlayerDeath()
                        }
                    }
                } catch {
                    gameLog("Failed to start input system: \(error)")
                }
            }
            .onChange(of: gameUIModel.modeManager.currentMode) { _, newMode in
                if [.playSafari, .playRaceLeague, .playCrateDelivery, .menu, .results].contains(newMode) { handleModeChange(newMode) }
            }
            .onChange(of: gameUIModel.multiplayerManager.isMultiplayerEnabled) { oldValue, newValue in
                if newValue {
                    startMultiplayerPositionTimer()
                } else {
                    stopMultiplayerPositionTimer()
                }
            }
            .onDisappear {
                inputRouter.stopInputSystem()
                packageSpawner.stopSpawning()
                coinSpawner.stopSpawning()
                enemyDroneSpawner.stopSpawning()
                bossDroneSpawner.stopSpawning()
                runViewModel.endRun()
                stopMultiplayerPositionTimer()
                Task {
                    await gameUIModel.multiplayerManager.endMultiplayerSession()
                }
                notificationCoordinator.removeAllListeners()
                MobileVirtualJoystickSystem.inputRouter = nil
                appModel.immersiveSpaceState = .closed
            }
            .onTapGesture { location in
                if gameUIModel.buildModeManager.currentMode == .build {
                    handleBuildModeInteraction()
                } else {
                    interactionController?.handleInteraction()
                }
            }

            DamageFlashOverlay(opacity: notificationCoordinator.damageFlashOpacity)
            if isLoading {
                SteelLoadingIndicator()
                    .transition(.opacity)
            }
            if notificationCoordinator.showKillstreakImage, let imageName = notificationCoordinator.currentKillstreakImage {
                VStack {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 234)
                        .offset(y: notificationCoordinator.killstreakImageOffset)
                        .opacity(notificationCoordinator.showKillstreakImage ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: notificationCoordinator.showKillstreakImage)
                        .animation(.easeOut(duration: 0.5), value: notificationCoordinator.killstreakImageOffset)
                        .padding(.top, 160)
                    Spacer()
                }
            }
            if showBattleAnnouncement {
                BattleAnnouncementView(
                    scale: battleAnnouncementScale,
                    opacity: battleAnnouncementOpacity
                )
            }
            if notificationCoordinator.showKillNotification {
                KillNotificationView(
                    killedPlayerName: notificationCoordinator.killedPlayerName,
                    opacity: notificationCoordinator.killNotificationOpacity
                )
            }
            if showPlayerListOverlay {
                PlayerListOverlay(
                    isPresented: $showPlayerListOverlay
                )
                .environment(gameUIModel)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            if showUI {
                DronePositionIndicatorView()
                BossPositionIndicatorView()
                RemoteDronePositionIndicatorView()
            }
            if showUI {
                mobileControlsView
            }
            RespawnOverlayView()
            if gameUIModel.modeManager.currentMode == .playRaceLeague {
                RaceLeagueHUDView(onMainMenu: {
                    gameUIModel.modeManager.switchToMode(.menu)
                    isPresented = false
                })
            }
            if gameUIModel.modeManager.currentMode == .playCrateDelivery {
                CrateDeliveryHUDView(onMainMenu: {
                    gameUIModel.modeManager.switchToMode(.menu)
                    isPresented = false
                })
            }
            if gameUIModel.modeManager.currentMode == .playSafari {
                SafariHUDView(onMainMenu: {
                    gameUIModel.modeManager.switchToMode(.menu)
                    isPresented = false
                })
            }
            if let timeTrialManager = gameUIModel.modeManager.timeTrialManager,
               timeTrialManager.currentState == .gameOver {
                TimeTrialGameOverView(
                    timeTrialManager: timeTrialManager,
                    onRestart: {
                        timeTrialManager.startNewSession()
                    },
                    onMainMenu: {
                        gameUIModel.modeManager.switchToMode(.menu)
                        isPresented = false
                    }
                )
            }
            if GameContext.shared.battle.showXPRewards,
               let oldRank = GameContext.shared.battle.oldRank,
               let newRank = GameContext.shared.battle.newRank {
                MultiplayerXPRewardsView(
                    xpEarned: GameContext.shared.battle.xpEarned,
                    oldRank: oldRank,
                    newRank: newRank,
                    onContinue: {
                        GameContext.shared.battle.dismissXPRewards()
                    }
                )
            }
            if GameContext.shared.battle.showGameOver,
               let battleResult = GameContext.shared.battle.battleResult {
                MultiplayerGameOverView(
                    battleResult: battleResult,
                    onContinue: {
                        GameContext.shared.battle.resetBattle()
                        gameUIModel.modeManager.switchToMode(.menu)
                        isPresented = false
                    },
                    onReturnToMenu: {
                        GameContext.shared.battle.resetBattle()
                        Task {
                            await gameUIModel.multiplayerManager.endMultiplayerSession()
                        }
                        gameUIModel.modeManager.switchToMode(.menu)
                        isPresented = false
                    }
                )
            }
            if showSinglePlayerGameOver,
               let oldRank = singlePlayerOldRank,
               let newRank = singlePlayerNewRank {
                SinglePlayerGameOverView(
                    enemiesDefeated: notificationCoordinator.enemiesDefeated,
                    xpEarned: singlePlayerXPEarned,
                    oldRank: oldRank,
                    newRank: newRank,
                    onContinue: {
                        showSinglePlayerGameOver = false
                        notificationCoordinator.resetPracticeMode()
                        worldScene.playerDrone?.resetHealth()
                        GameContext.shared.waves.stopWaveSystem()
                        gameUIModel.modeManager.switchToMode(.menu)
                        isPresented = false
                    },
                    onPlayAgain: {
                        showSinglePlayerGameOver = false
                        notificationCoordinator.resetPracticeMode()
                        worldScene.playerDrone?.resetHealth()
                        GameContext.shared.health.localPlayerHealth.respawn()
                        enemyDroneSpawner.stopSpawning()
                        bossDroneSpawner.stopSpawning()
                        clearPracticeEnemies()
                        GameContext.shared.waves.reset()
                        GameContext.shared.waves.startWaveSystem()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            enemyDroneSpawner.setup(
                                maxEnemies: GameContext.shared.waves.getMaxConcurrentEnemies(),
                                spawnRadius: GameContext.shared.waves.getSpawnRadius(),
                                spawnCooldown: GameContext.shared.waves.getSpawnCooldown()
                            )
                            enemyDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
                            bossDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
                        }
                    }
                )
            }
            if showExitConfirmation {
                ExitConfirmationOverlay(
                    isPresented: $showExitConfirmation,
                    onConfirm: {
                        Task {
                            await gameUIModel.multiplayerManager.endMultiplayerSession()
                        }
                        gameUIModel.modeManager.switchToMode(.menu)
                        isPresented = false
                    },
                    onCancel: {
                        showExitConfirmation = false
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            startLoadingSequence()
            if gameUIModel.multiplayerManager.isMultiplayerEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showBattleAnnouncementFunc()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showJoystickTips = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            handleAppDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleAppWillEnterForeground()
        }
        .sheet(isPresented: $runViewModel.showSummary) {
            if let runSession = runViewModel.currentRunSession {
                SummaryView(
                    runSession: runSession,
                    playerStats: runViewModel.playerStats,
                    isPresented: $runViewModel.showSummary,
                    onRestartRun: {
                        runViewModel.startRun(levelID: "tutorial")
                    }
                )
            }
        }
        .sheet(isPresented: $runViewModel.showSettings) {
            SettingsView(
                playerSettings: runViewModel.playerSettings,
                isPresented: $runViewModel.showSettings
            )
        }
        .sheet(isPresented: $showPlayerListSheet) {
            CurrentRoomPlayerListView()
                .environment(gameUIModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGameHelp) {
            GameHelpView(
                isPresented: $showGameHelp,
                showJoystickTips: $showJoystickTips,
                currentMode: gameUIModel.modeManager.currentMode
            )
        }
        .sheet(isPresented: $showWeaponSelection1) {
            WeaponSelectionView(
                slot: 1,
                onWeaponSelected: { weapon, slot in
                    GameContext.shared.loadout.selectWeapon(weapon)
                    showWeaponSelection1 = false
                },
                onCancel: {
                    showWeaponSelection1 = false
                }
            )
        }
        .sheet(isPresented: $showWeaponSelection2) {
            WeaponSelectionView(
                slot: 2,
                onWeaponSelected: { weapon, slot in
                    GameContext.shared.loadout.selectWeapon2(weapon)
                    showWeaponSelection2 = false
                },
                onCancel: {
                    showWeaponSelection2 = false
                }
            )
        }
    }

    var mobileControlsView: some View {
        VStack(spacing: 0) {
            mobileTopBar
            if gameUIModel.modeManager.currentMode == .playTimeTrial {
                timeTrialHUD.padding(.top, 10)
            }
            Spacer(minLength: 0)
            mobileBottomCluster
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 28)
    }

    private var mobileTopBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                BattleHealthGauge()
                if gameUIModel.modeManager.currentMode == .playPractice {
                    PracticeKillCounterView(enemiesDefeated: notificationCoordinator.enemiesDefeated)
                }
                if gameUIModel.modeManager.currentMode == .playMultiplayer {
                    Button(action: {
                        SteelHaptics.lightTap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showPlayerListOverlay.toggle()
                        }
                    }) {
                        MultiplayerScoreboardView()
                            .environment(gameUIModel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                if gameUIModel.modeManager.currentMode == .playMultiplayer || gameUIModel.modeManager.currentMode == .playPractice {
                    KillfeedView()
                }
            }
            Spacer(minLength: 8)
            controlButtonsView
        }
    }

    private var mobileBottomCluster: some View {
        VStack(spacing: 10) {
            CurrentDroneStatsView(speed: droneSpeed, altitude: droneAltitude)
            HStack(alignment: .bottom) {
                VirtualJoystick(
                    position: inputRouter.leftJoystickPosition,
                    isActive: inputRouter.isLeftJoystickActive,
                    onPositionChanged: { position, active in
                        inputRouter.setLeftJoystick(position: position, active: active)
                    },
                    isLeftJoystick: true,
                    tint: Arena.volt
                )
                Spacer(minLength: 8)
                VStack(spacing: 8) {
                    HardpointButton(
                        slot: 1, weapon: GameContext.shared.loadout.selectedWeapon, armed: currentWeaponSlot == 1,
                        onFire: { currentWeaponSlot = 1; fireMissile(slot: 1) },
                        onSwap: { showWeaponSelection1 = true }
                    )
                    HardpointButton(
                        slot: 2, weapon: GameContext.shared.loadout.selectedWeapon2, armed: currentWeaponSlot == 2,
                        onFire: { currentWeaponSlot = 2; fireMissile(slot: 2) },
                        onSwap: { showWeaponSelection2 = true }
                    )
                }
                Spacer(minLength: 8)
                VirtualJoystick(
                    position: inputRouter.rightJoystickPosition,
                    isActive: inputRouter.isRightJoystickActive,
                    onPositionChanged: { position, active in
                        inputRouter.setRightJoystick(position: position, active: active)
                    },
                    isLeftJoystick: false,
                    tint: Arena.heat
                )
            }
        }
        .overlay(alignment: .bottom) {
            if showJoystickTips && showUI { JoystickTipsOverlay().allowsHitTesting(false).transition(.opacity) }
        }
    }

    var controlButtonsView: some View {
        HStack(spacing: 6) {
            ArenaIconButton(icon: "questionmark", size: 38, tint: Arena.textDim) { showGameHelp = true }
            ArenaIconButton(icon: "gearshape.fill", size: 38, tint: Arena.textDim) { showMobileSettings = true }
            ArenaIconButton(icon: "xmark", size: 38, tint: Arena.hostile) {
                if gameUIModel.modeManager.currentMode == .playMultiplayer {
                    showExitConfirmation = true
                } else {
                    Task {
                        await gameUIModel.multiplayerManager.endMultiplayerSession()
                    }
                    gameUIModel.modeManager.switchToMode(.menu)
                    isPresented = false
                }
            }
        }
    }

    private var timeTrialHUD: some View {
        Group {
            if let timeTrialManager = gameUIModel.modeManager.timeTrialManager {
                HStack(alignment: .lastTextBaseline, spacing: 16) {
                    Text(timeTrialManager.formattedTimeRemaining).font(Arena.num(44)).foregroundStyle(Arena.volt)
                    ArenaReadout(label: "Rings", value: "\(timeTrialManager.currentRingsRemaining)", size: 26)
                    ArenaReadout(label: "Score", value: "\(timeTrialManager.currentScore)", tint: Arena.heat, size: 26)
                }
                .fixedSize()
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(CutRect(cut: 10).fill(Arena.ink.opacity(0.85)))
                .overlay(CutRect(cut: 10).stroke(Arena.line, lineWidth: 1))
            }
        }
    }

    private var multiplayerStatusIndicator: some View {
        HStack(spacing: SteelLayout.xs) {
            StatusChip(
                gameUIModel.multiplayerManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill",
                label: gameUIModel.multiplayerManager.isConnected ? "Connected" : "Disconnected",
                isActive: gameUIModel.multiplayerManager.isConnected
            )
            if !gameUIModel.multiplayerManager.roomPlayers.isEmpty {
                StatusChip(
                    "person.2.fill",
                    label: "\(gameUIModel.multiplayerManager.roomPlayers.count) players"
                )
            }
        }
    }

    private func updateGameSystems(deltaTime: Float) {
        inputRouter.processInput()
        flightController.updateBattery(deltaTime: Double(deltaTime))
        gameUIModel.multiplayerManager.update(deltaTime: deltaTime)
        if gameUIModel.modeManager.currentMode == .playPractice {
            enemyDroneSpawner.update(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
            bossDroneSpawner.update(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
        }
        updateEnemyAI(deltaTime: deltaTime)
        updateHUDReactive(deltaTime: deltaTime)
    }

    private func updateHUDReactive(deltaTime: Float) {
        hudViewModel.updateBattery(
            percentage: flightController.batteryPercentage,
            isRecharging: flightController.batteryModel.isRecharging
        )

        if let drone = worldScene.playerDrone {
            hudViewModel.updateDroneState(
                drone.droneState,
                carryingParcel: drone.attachedParcel != nil
            )

            // Update drone stats (speed and altitude)
            updateDroneStats(drone: drone, deltaTime: deltaTime)
        }
        hudViewModel.updateClawStatus(clawController.statusText)
        if gameUIModel.multiplayerManager.isMultiplayerEnabled, let drone = worldScene.playerDrone {
            gameUIModel.multiplayerManager.updateLocalDronePosition(drone)
        }
    }

    private func updateDroneStats(drone: PlayerDroneEntity, deltaTime: Float) {
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

        // Calculate instantaneous speed from position change (mobile uses MobileVirtualJoystickSystem, not FlightController)
        let deltaPosition = currentPosition - lastPos
        let distance = length(deltaPosition)
        let instantaneousSpeed = deltaTime > 0 ? distance / deltaTime : 0

        // Apply exponential smoothing to reduce flickering
        // smoothFactor of 0.3 means: 30% new value, 70% old value
        let smoothFactor: Float = 0.3
        smoothedSpeed = smoothedSpeed * (1.0 - smoothFactor) + instantaneousSpeed * smoothFactor

        // Update displayed speed with smoothed value
        droneSpeed = smoothedSpeed

        // Update last position for next frame
        lastDronePosition = currentPosition
    }

    private func setupStep2Systems() {
        gameUIModel.placementManager.setup(contentEntity: worldScene.rootEntity, buildModeManager: gameUIModel.buildModeManager)
        if let drone = worldScene.playerDrone {
            clawController.setup(drone: drone, worldScene: worldScene)
        }
        gameUIModel.modeManager.setupDependencies(worldScene: worldScene.rootEntity, packageSpawner: packageSpawner)
        gameUIModel.multiplayerManager.setupWorldAnchor(worldScene.rootEntity)
        setupMobileJoystickSystem()
    }

    private func setupMobileJoystickSystem() {
        MobileVirtualJoystickSystem.inputRouter = inputRouter
        if let drone = worldScene.playerDrone {
            drone.addMobileVirtualJoystickControl(
                throttleSpeed: 2.0,
                yawSpeed: 8.0,
                pitchSpeed: 2.0,
                rollSpeed: 2.0
            )
            drone.addDroneMissileCapability(
                missileSpeed: 5.0,
                missileLifetime: 3.0,
                fireRate: 0.5)
            drone.components.set(PlayerHealthComponent())
        }
    }

    private func fireMissile(slot: Int = 1) {
        if gameUIModel.modeManager.currentMode == .playCrateDelivery {
            CrateDeliveryManager.shared.clawButton()
            return
        }
        guard let drone = worldScene.playerDrone else {
            gameLog("⚠️ Cannot fire missile: no drone available")
            return
        }
        let weaponStats = GameContext.shared.loadout.getCurrentWeaponStats(slot: slot)
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

    private func handleGrabAction() {
        guard let drone = worldScene.playerDrone else {
            gameLog("🚨 No drone found for grab action!")
            return
        }
        spawnClawAndAttemptGrab(from: drone)
    }

    private func spawnClawAndAttemptGrab(from drone: PlayerDroneEntity) {
        let clawEntity = Entity()
        Task {
            do {
                if let clawURL = Bundle.main.url(forResource: "Claw", withExtension: "usdz") {
                    let clawModel = try await Entity(contentsOf: clawURL)
                    await MainActor.run {
                        clawModel.scale = .init(repeating: 0.1)
                        clawEntity.addChild(clawModel)
                    }
                } else {
                    await MainActor.run {
                        createFallbackClaw(clawEntity)
                    }
                }
            } catch {
                gameLog("❌ Failed to load Claw.usdz: \(error)")
                await MainActor.run {
                    createFallbackClaw(clawEntity)
                }
            }
        }
        let dronePosition = drone.transform.translation
        clawEntity.transform.translation = SIMD3<Float>(dronePosition.x, dronePosition.y + 0.7, dronePosition.z)
        setupClawPhysics(clawEntity)
        worldScene.rootEntity.addChild(clawEntity)
        animateClawDrop(clawEntity)
    }

    private func createFallbackClaw(_ clawEntity: Entity) {
        let clawMesh = MeshResource.generateBox(width: 0.1, height: 0.15, depth: 0.1)
        let clawMaterial = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: true)
        let clawModel = ModelEntity(mesh: clawMesh, materials: [clawMaterial])
        let prongMesh = MeshResource.generateBox(width: 0.02, height: 0.05, depth: 0.02)
        let prongMaterial = SimpleMaterial(color: .orange, roughness: 0.1, isMetallic: false)
        let leftProng = ModelEntity(mesh: prongMesh, materials: [prongMaterial])
        leftProng.transform.translation = SIMD3<Float>(-0.04, -0.1, 0)
        let rightProng = ModelEntity(mesh: prongMesh, materials: [prongMaterial])
        rightProng.transform.translation = SIMD3<Float>(0.04, -0.1, 0)
        clawEntity.addChild(clawModel)
        clawEntity.addChild(leftProng)
        clawEntity.addChild(rightProng)
    }

    private func setupClawPhysics(_ clawEntity: Entity) {
        let shape = ShapeResource.generateBox(width: 0.1, height: 0.15, depth: 0.1)
        let material = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.2)
        clawEntity.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: material,
            mode: .kinematic
        ))
        clawEntity.components.set(CollisionComponent(shapes: [shape]))
    }

    private func animateClawDrop(_ clawEntity: Entity) {
        let startPosition = clawEntity.transform.translation
        let endPosition = SIMD3<Float>(startPosition.x, startPosition.y - 2.0, startPosition.z)
        let animationDuration: Float = 1.0
        let steps = 60
        let stepDuration = animationDuration / Float(steps)
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: TimeInterval(stepDuration), repeats: true) { timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            let currentPosition = mix(startPosition, endPosition, t: progress)
            clawEntity.transform.translation = currentPosition
            self.checkForPackageCollision(clawEntity)
            if currentStep >= steps {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    clawEntity.removeFromParent()
                }
            }
        }
    }

    private func checkForPackageCollision(_ clawEntity: Entity) {
        let clawPosition = clawEntity.transform.translation
        worldScene.rootEntity.children.forEach { entity in
            if let packageEntity = entity as? PackageEntity {
                let packagePosition = packageEntity.transform.translation
                let distance = length(clawPosition - packagePosition)
                if distance < 0.3 && !packageEntity.isPickedUp {
                    grabPackage(packageEntity, with: clawEntity)
                }
            }
        }
    }

    private func grabPackage(_ package: PackageEntity, with clawEntity: Entity) {
        package.removeFromParent()
        clawEntity.addChild(package)
        package.transform.translation = SIMD3<Float>(0, -0.1, 0)
        package.pickup()
        if var physicsBody = package.components[PhysicsBodyComponent.self] {
            physicsBody.mode = .kinematic
            package.components.set(physicsBody)
        }
    }

    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + t * (b - a)
    }

    private func createFloorEntity(in rootEntity: Entity) {
        let floorEntity = Entity()
        floorEntity.name = "InvisibleFloor"
        let floorMesh = MeshResource.generatePlane(width: 10.0, depth: 10.0)
        var floorMaterial = UnlitMaterial()
        floorMaterial.color = .init(tint: .white.withAlphaComponent(0.0000001))
        let floorModel = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
        floorModel.model = nil
        floorEntity.addChild(floorModel)
        floorEntity.position = SIMD3<Float>(0, 0, 0)
        let collisionShape = ShapeResource.generateBox(width: 10.0, height: 0.1, depth: 10.0)
        let collisionComponent = CollisionComponent(shapes: [collisionShape])
        floorEntity.components.set(collisionComponent)
        let floorMaterial_physics = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.3)
        let physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: floorMaterial_physics,
            mode: .static
        )
        floorEntity.components.set(physicsBody)
        rootEntity.addChild(floorEntity)
    }

    private func createMultiplayerArena(in rootEntity: Entity) {
        let arenaSize: Float = 8.0
        let wallHeight: Float = 5.0
        let wallThickness: Float = 0.2
        let floorY: Float = -2.0
        var wallMaterial = SimpleMaterial()
        wallMaterial.color = .init(tint: .gray)
        wallMaterial.roughness = 0.8
        wallMaterial.metallic = 0.2
        let physicsMaterial = PhysicsMaterialResource.generate(friction: 0.5, restitution: 0.3)
        let arenaFloor = Entity()
        arenaFloor.name = "ArenaFloor"
        let floorSize: Float = arenaSize * 2.0
        let floorCollision = ShapeResource.generateBox(width: floorSize, height: 0.1, depth: floorSize)
        arenaFloor.components.set(CollisionComponent(shapes: [floorCollision]))
        arenaFloor.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: physicsMaterial,
            mode: .static
        ))
        arenaFloor.components[ModelComponent.self] = nil
        arenaFloor.position = SIMD3<Float>(0, floorY, 0)
        rootEntity.addChild(arenaFloor)
        createWall(
            at: SIMD3<Float>(0, floorY + wallHeight/2, arenaSize),
            size: SIMD3<Float>(arenaSize * 2.0, wallHeight, wallThickness),
            material: wallMaterial,
            physicsMaterial: physicsMaterial,
            name: "NorthWall",
            in: rootEntity
        )
        createWall(
            at: SIMD3<Float>(0, floorY + wallHeight/2, -arenaSize),
            size: SIMD3<Float>(arenaSize * 2.0, wallHeight, wallThickness),
            material: wallMaterial,
            physicsMaterial: physicsMaterial,
            name: "SouthWall",
            in: rootEntity
        )
        createWall(
            at: SIMD3<Float>(arenaSize, floorY + wallHeight/2, 0),
            size: SIMD3<Float>(wallThickness, wallHeight, arenaSize * 2.0),
            material: wallMaterial,
            physicsMaterial: physicsMaterial,
            name: "EastWall",
            in: rootEntity
        )
        createWall(
            at: SIMD3<Float>(-arenaSize, floorY + wallHeight/2, 0),
            size: SIMD3<Float>(wallThickness, wallHeight, arenaSize * 2.0),
            material: wallMaterial,
            physicsMaterial: physicsMaterial,
            name: "WestWall",
            in: rootEntity
        )
    }

    private func createWall(
        at position: SIMD3<Float>,
        size: SIMD3<Float>,
        material: SimpleMaterial,
        physicsMaterial: PhysicsMaterialResource,
        name: String,
        in rootEntity: Entity
    ) {
        let wallEntity = Entity()
        wallEntity.name = name
        wallEntity.position = position
        let wallMesh = MeshResource.generateBox(width: size.x, height: size.y, depth: size.z)
        let wallModel = ModelEntity(mesh: wallMesh, materials: [material])
        wallModel.components[ModelComponent.self] = nil
        wallEntity.addChild(wallModel)
        let collisionShape = ShapeResource.generateBox(width: size.x, height: size.y, depth: size.z)
        wallEntity.components.set(CollisionComponent(shapes: [collisionShape]))
        wallEntity.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: physicsMaterial,
            mode: .static
        ))
        rootEntity.addChild(wallEntity)
    }

    private func handleModeChange(_ mode: GameMode) {
        switch mode {
        case .build:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
        case .play:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                packageSpawner.startSpawning()
                deliveryDirector.startNextJob()
            }
        case .playDelivery:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                packageSpawner.startSpawning()
                deliveryDirector.startNextJob()
                coinSpawner.startSpawning()
            }
        case .playSandbox:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
            }
        case .playPractice:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            worldScene.clearZones()
            notificationCoordinator.resetPracticeMode()
            GameContext.shared.waves.startWaveSystem()
            enemyDroneSpawner.setup(
                maxEnemies: GameContext.shared.waves.getMaxConcurrentEnemies(),
                spawnRadius: GameContext.shared.waves.getSpawnRadius(),
                spawnCooldown: GameContext.shared.waves.getSpawnCooldown()
            )
            enemyDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
            bossDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
        case .playMultiplayer:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            createMultiplayerArena(in: worldScene.rootEntity)
            showBattleAnnouncementFunc()
            GameContext.shared.battle.startBattle()
            if gameUIModel.multiplayerManager.isMultiplayerEnabled {
                startMultiplayerPositionTimer()
            }
        case .playSafari:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            SafariManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .playRaceLeague:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            SafariManager.shared.stop()
            RaceLeagueManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .playTimeTrial:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            if let timeTrialManager = gameUIModel.modeManager.timeTrialManager,
               let playerDrone = worldScene.playerDrone {
                timeTrialManager.setup(worldScene: worldScene.rootEntity, playerDrone: playerDrone)
                timeTrialManager.startNewSession()
            }
        case .playCrateDelivery:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            SafariManager.shared.stop()
            RaceLeagueManager.shared.stop()
            CrateDeliveryManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .menu, .results:
            SafariManager.shared.stop()
            RaceLeagueManager.shared.stop()
            CrateDeliveryManager.shared.stop()
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            bossDroneSpawner.stopSpawning()
            worldScene.clearZones()
            GameContext.shared.waves.stopWaveSystem()
            stopMultiplayerPositionTimer()
        }
    }

    private func handleBuildModeInteraction() {
        if gameUIModel.placementManager.isPlacing {
            let placementPosition = SIMD3<Float>(0, 0, -2)
            gameUIModel.placementManager.setPlacementPosition(placementPosition)
        }
    }

    private func startMultiplayerPositionTimer() {
        stopMultiplayerPositionTimer()
        multiplayerPositionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 3.0, repeats: true) { _ in
            if let drone = worldScene.playerDrone {
                gameUIModel.multiplayerManager.updateLocalDronePosition(drone)
            }
        }
    }

    private func stopMultiplayerPositionTimer() {
        multiplayerPositionTimer?.invalidate()
        multiplayerPositionTimer = nil
    }

    private func spawnTestEnemyDrone() {
        guard let playerDrone = worldScene.playerDrone else { return }
        let playerPosition = playerDrone.position
        let angle = Float.random(in: 0...(2 * Float.pi))
        let distance: Float = 1.5
        let height: Float = playerPosition.y + 0.5
        let spawnPosition = SIMD3<Float>(
            playerPosition.x + cos(angle) * distance,
            height,
            playerPosition.z + sin(angle) * distance
        )
        let enemyID = "TestEnemy_\(UUID().uuidString.prefix(8))"
        let enemyDrone = EnemyDroneEntity(enemyID: enemyID, spawnPosition: spawnPosition)
        worldScene.rootEntity.addChild(enemyDrone)
    }

    private func updateEnemyAI(deltaTime: Float) {
        var enemyCount = 0
        updateEnemyAIRecursive(entity: worldScene.rootEntity, deltaTime: deltaTime, playerDrone: worldScene.playerDrone, enemyCount: &enemyCount)
    }

    private func updateEnemyAIRecursive(entity: Entity, deltaTime: Float, playerDrone: Entity?, enemyCount: inout Int) {
        if let enemyDrone = entity as? EnemyDroneEntity {
            enemyCount += 1
            enemyDrone.updateAI(deltaTime: deltaTime, playerDrone: playerDrone)
        }
        for child in entity.children {
            updateEnemyAIRecursive(entity: child, deltaTime: deltaTime, playerDrone: playerDrone, enemyCount: &enemyCount)
        }
    }

    private func handleAppDidEnterBackground() {
        gameUIModel.multiplayerManager.networking.handleAppDidEnterBackground()
        stopMultiplayerPositionTimer()
        enemyDroneSpawner.stopSpawning()
        bossDroneSpawner.stopSpawning()
        packageSpawner.stopSpawning()
        coinSpawner.stopSpawning()
    }

    private func handleAppWillEnterForeground() {
        gameUIModel.multiplayerManager.networking.handleAppWillEnterForeground()
        if gameUIModel.multiplayerManager.isMultiplayerEnabled {
            startMultiplayerPositionTimer()
        }
        switch gameUIModel.modeManager.currentMode {
        case .playPractice:
            enemyDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
            bossDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
        case .play, .playDelivery:
            packageSpawner.startSpawning()
            if gameUIModel.modeManager.currentMode == .playDelivery {
                coinSpawner.startSpawning()
            }
        default:
            break
        }
    }

    private func startLoadingSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                isLoading = false
                showUI = true
            }
        }
    }

    private func setupTimeTrialMode() {
        packageSpawner.stopSpawning()
        coinSpawner.stopSpawning()
        enemyDroneSpawner.stopSpawning()
        worldScene.clearZones()
        if let timeTrialManager = gameUIModel.modeManager.timeTrialManager,
           let playerDrone = worldScene.playerDrone {
            timeTrialManager.setup(worldScene: worldScene.rootEntity, playerDrone: playerDrone)
            timeTrialManager.startNewSession()
        }
    }

    private func showBattleAnnouncementFunc() {
        battleAnnouncementScale = 100.0
        battleAnnouncementOpacity = 0.0
        showBattleAnnouncement = true
        withAnimation(.easeOut(duration: 0.8)) {
            battleAnnouncementScale = 1.0
            battleAnnouncementOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                battleAnnouncementOpacity = 0.0
                battleAnnouncementScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showBattleAnnouncement = false
                battleAnnouncementScale = 100.0
            }
        }
    }

    private func handlePlayerDeath() {
        singlePlayerXPEarned = notificationCoordinator.enemiesDefeated * 10
        let rankManager = PlayerRankManager()
        singlePlayerOldRank = rankManager.localPlayerRank
        singlePlayerNewRank = rankManager.localPlayerRank
        showSinglePlayerGameOver = true
    }

    private func updatePracticeSpawnerSettings() {
        enemyDroneSpawner.setup(
            maxEnemies: GameContext.shared.waves.getMaxConcurrentEnemies(),
            spawnRadius: GameContext.shared.waves.getSpawnRadius(),
            spawnCooldown: GameContext.shared.waves.getSpawnCooldown()
        )
    }

    private func clearPracticeEnemies() {
        var removedCount = 0
        clearEnemiesRecursive(entity: worldScene.rootEntity, removedCount: &removedCount)
    }

    private func clearEnemiesRecursive(entity: Entity, removedCount: inout Int) {
        if entity is EnemyDroneEntity || entity is EnemyDroneBossEntity {
            entity.removeFromParent()
            removedCount += 1
            return
        }
        for child in entity.children.reversed() {
            clearEnemiesRecursive(entity: child, removedCount: &removedCount)
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    return MobileRealityView(isPresented: .constant(true))
        .environment(AppModel())
        .environment(GameUIModel())
}
