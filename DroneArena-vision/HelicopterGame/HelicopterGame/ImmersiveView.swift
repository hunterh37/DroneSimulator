//
//  ImmersiveView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI
import RealityKit
import DicyaninThumbController
import DicyaninVirtualJoystick
import Combine
import QuartzCore

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(GameUIModel.self) var gameUIModel
    @State private var worldScene = WorldSceneController()
    private var inputRouter: InputRouter { appModel.inputRouter }
    private var flightController: FlightController { appModel.flightController }
    @State private var interactionController: InteractionController?
    @State private var hudViewModel = HUDViewModel()
    @State private var runViewModel = RunViewModel()
    @State private var multiplayerPositionTimer: Timer?
    @State private var controlHintEntity: Entity?
    @State private var controlHintTimer: Timer?
    @State private var droneStatsHUDEntity: Entity?
    /// Pillar position (in its parent's space) captured when a base-drag starts.
    @State private var pillarDragStart: SIMD3<Float>?
    @State private var pillarRotationStart: simd_quatf?

    /// Drone world position from the previous frame, used to measure actual
    /// flight speed. The drone is moved directly by DualThumbControlledSystem
    /// (entity.position += …), so FlightController.currentSpeed never updates and
    /// reads a permanent 0 — we derive speed from real motion instead.
    @State private var lastDroneWorldPos: SIMD3<Float>?
    /// Low-pass-filtered speed (m/s) so the readout doesn't jitter frame-to-frame.
    @State private var smoothedDroneSpeed: Float = 0

    /// Attachment id for the head-anchored drone stats HUD (ammo / health / speed).
    private let droneStatsHUDTag = "droneStatsHUD"

#if os(visionOS)
    private let handGestureManager = GameContext.shared.handGesture
    @State private var gestureCancellable: AnyCancellable?
#endif

    @State private var clawController = ClawController()
    @State private var packageSpawner = PackageSpawner()
    @State private var deliveryDirector = DeliveryDirector()
    @State private var coinSpawner = CoinSpawner()
    @State private var enemyDroneSpawner = EnemyDroneSpawner()
    
    var sceneReconstructionManager = SceneReconstructionManager.shared
    
    var body: some View {
        RealityView { content, attachments in
            configureDefaultContent(content)
            presentControlHint(using: attachments)
            presentDroneStatsHUD(using: attachments)
        } update: { content, attachments in
            updateGameSystems()
        } attachments: {
//            Attachment(id: "controlHint") {
//                ControlHintView(onDismiss: dismissControlHint)
//            }
//            Attachment(id: droneStatsHUDTag) {
//                DroneStatsHUDView(hudViewModel: hudViewModel)
//            }
        }
        .task {
            do {
                sceneReconstructionManager.generate()
                try await handGestureManager.start()

                setupGestureSubscriptions()
                appModel.setModeChangeCallback(handleModeChange)
                if [.playSafari, .playRaceLeague, .playCrateDelivery].contains(gameUIModel.modeManager.currentMode) {
                    handleModeChange(gameUIModel.modeManager.currentMode)
                }
                appModel.worldSceneController = worldScene
                worldScene.createHandAnchoredHUD(with: hudViewModel)

                if gameUIModel.buildModeManager.currentMode == .play && gameUIModel.buildModeManager.isLayoutValid {
                    worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                    packageSpawner.startSpawning()
                    deliveryDirector.startNextJob()
                }

                runViewModel.startRun(levelID: "tutorial")

                GameContext.shared.health.setMultiplayerNetworking(gameUIModel.multiplayerManager.networking)
                GameContext.shared.health.setMultiplayerManager(gameUIModel.multiplayerManager)

                if gameUIModel.multiplayerManager.isMultiplayerEnabled {
                    startMultiplayerPositionTimer()
                }

                // First-launch flight tutorial. Runs once (gated by UserDefaults),
                // immediately after the ARKit permissions gate, throwing the player
                // straight into a guided "raise height → fly forward" flight.
                GameContext.shared.droneTutorial.startIfNeeded(in: worldScene)
                ScreenshotDirector.stage(root: worldScene.rootEntity, drone: worldScene.playerDrone)
                let modeManager = gameUIModel.modeManager
                DemoDirector.stage(root: worldScene.rootEntity, drone: worldScene.playerDrone,
                                   mode: { modeManager.currentMode },
                                   switchMode: { modeManager.switchToMode($0) })
            } catch {
                gameLog("Failed to start input system: \(error)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ControlSchemeConfig.didChangeNotification)) { _ in
            worldScene.applyControlScheme()
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
            gestureCancellable?.cancel()
            handGestureManager.stop()
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            runViewModel.endRun()
            stopMultiplayerPositionTimer()
            GameContext.shared.droneTutorial.stop()
            dismissControlHint()
            droneStatsHUDEntity?.parent?.removeFromParent()
            droneStatsHUDEntity = nil
            
            Task {
                await gameUIModel.multiplayerManager.endMultiplayerSession()
            }
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { _ in
                    if gameUIModel.buildModeManager.currentMode == .build {
                        handleBuildModeInteraction()
                    } else {
                        interactionController?.handleInteraction()
                    }
                }
        )
        .simultaneousGesture(dragGesture)
        // Simulator: touch/drag a joystick head with the SwiftUI DragGesture (one
        // pointer, one stick — all a mouse can do anyway).
        // Device: hand tracking in Gamepad3DSystem drives the grabs so BOTH sticks
        // can be grabbed at once. The two paths are gated so they never double-drive.
        .installGamepad3DGesture()
        .simultaneousGesture(gamepadFireButtonGesture)
        .simultaneousGesture(gamepadPillarMoveGesture)
        .simultaneousGesture(gamepadPillarRotateGesture)
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
    }
    
    private func configureDefaultContent(_ content: RealityViewContent) {
        appModel.worldSceneController = worldScene
        content.add(worldScene.rootEntity)
        setupStep2Systems(content: content)
        interactionController = InteractionController(
            worldScene: worldScene,
            flightController: flightController)
        
        TimeTrialSystem.timeTrialManager = gameUIModel.modeManager.timeTrialManager
        
        GameContext.shared.worldMissileShooter.setRootEntity(worldScene.rootEntity)
        
        if let drone = worldScene.playerDrone {
            drone.addDroneMissileCapability(
                missileSpeed: 5.0,
                missileLifetime: 3.0,
                fireRate: 0.5
            )
            drone.components.set(PlayerHealthComponent())
        }

        setupVisionOSSimulatorJoysticks()
    }
    
    private func updateGameSystems() {
        let deltaTime: Float = 1.0 / 60.0
        inputRouter.processInput()
        interactionController?.updateInteractions()

        if let clawIntent = inputRouter.currentClawIntent {
            clawController.processClawIntent(clawIntent)
        }

        flightController.updateBattery(deltaTime: Double(deltaTime))
        gameUIModel.multiplayerManager.update(deltaTime: deltaTime)

        if gameUIModel.modeManager.currentMode == .playPractice {
            enemyDroneSpawner.update(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)
        }

        if gameUIModel.modeManager.currentMode == .playTimeTrial {
            gameUIModel.modeManager.timeTrialManager?.syncStateFromECS()
        }

        updateHUDReactive()
    }
    
    private func updateHUDReactive() {
        hudViewModel.updateBattery(
            percentage: flightController.batteryPercentage,
            isRecharging: flightController.batteryModel.isRecharging
        )

        if let drone = worldScene.playerDrone {
            hudViewModel.updateDroneState(
                drone.droneState,
                carryingParcel: drone.attachedParcel != nil
            )
        }

        hudViewModel.updateClawStatus(clawController.statusText)

        // Feed the head-anchored drone stats HUD (missiles / health / speed).
        let health = GameContext.shared.health.localPlayerHealth
        let loadout = GameContext.shared.loadout
        let stats1 = loadout.getCurrentWeaponStats(slot: 1)
        let stats2 = loadout.getCurrentWeaponStats(slot: 2)
        // Measure real flight speed from the drone's world-space motion this frame.
        // (FlightController.currentSpeed is bypassed by DualThumbControlledSystem.)
        let droneWorldPos = worldScene.playerDrone?.position(relativeTo: nil) ?? .zero
        let altitude = droneWorldPos.y
        if let last = lastDroneWorldPos {
            let deltaTime: Float = 1.0 / 60.0
            let measuredSpeed = simd_length(droneWorldPos - last) / max(deltaTime, 0.0001)
            // Exponential smoothing (~0.2 blend) to tame per-frame jitter.
            smoothedDroneSpeed += (measuredSpeed - smoothedDroneSpeed) * 0.2
        }
        lastDroneWorldPos = droneWorldPos
        let speed = smoothedDroneSpeed

        hudViewModel.updateCombatStats(
            speed: speed,
            altitude: altitude,
            health: health.currentHealth,
            maxHealth: health.maxHealth,
            missile1Count: stats1?.missileCount ?? 0,
            missile1Name: loadout.selectedWeapon?.displayName ?? "NONE",
            missile2Count: stats2?.missileCount ?? 0,
            missile2Name: loadout.selectedWeapon2?.displayName ?? "NONE"
        )

        // Mirror the live stats onto the pillar stand's deck-top arcade readout.
        worldScene.gamepadPillar?.updateReadouts(
            speedMph: Int((speed * 2.23694).rounded()),
            altitudeFt: Int((altitude * 3.28084).rounded()),
            missiles: (stats1?.missileCount ?? 0) + (stats2?.missileCount ?? 0)
        )

        if gameUIModel.multiplayerManager.isMultiplayerEnabled, let drone = worldScene.playerDrone {
            gameUIModel.multiplayerManager.updateLocalDronePosition(drone)
        }

        // Feed the pillar's floating sci-fi hologram minimap. Our drone is the
        // blue center; enemies plot as red blips at their position relative to us.
        if let pillar = worldScene.gamepadPillar, pillar.hologram?.isEnabled == true {
            let playerWorld = worldScene.playerDrone?.position(relativeTo: nil) ?? .zero
            var blips: [PillarHologramEntity.Blip] = []
            collectHologramBlips(in: worldScene.rootEntity, into: &blips)
            pillar.updateHologram(
                playerWorld: playerWorld,
                blips: blips,
                modeLabel: "TACTICAL",
                time: CACurrentMediaTime()
            )
        }
    }

    /// Walks the scene graph collecting enemy contacts as red hologram blips.
    private func collectHologramBlips(in entity: Entity, into blips: inout [PillarHologramEntity.Blip]) {
        if entity is EnemyDroneEntity || entity is EnemyDroneBossEntity {
            blips.append(.init(worldPosition: entity.position(relativeTo: nil), color: .systemRed))
        }
        for child in entity.children {
            collectHologramBlips(in: child, into: &blips)
        }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .useGestureComponent()
    }
    
    private func setupVisionOSSimulatorJoysticks() {
        // Intentionally a no-op.
        //
        // The player drone is driven by a SINGLE movement controller on both the
        // simulator and a real device: DualThumbControlledComponent (added in
        // WorldSceneController) consumed by DualThumbControlledSystem.
        //
        // On visionOS the on-screen simulator joysticks and the 3D gamepad pillar
        // both feed their input into DualThumbController (see InputRouter.processInput
        // and Gamepad3DSystem), so DualThumbControlledSystem already handles every
        // input source. Attaching MobileVirtualJoystickComponent here as well would
        // double-drive the drone and re-introduce the conflicting control mapping
        // (notably the orange stick driving yaw). MobileVirtualJoystickSystem is
        // reserved for the standalone iOS app (see MobileRealityView).
    }
    
    private func updateHUD() {
        hudViewModel.updateBattery(
            percentage: flightController.batteryPercentage,
            isRecharging: flightController.batteryModel.isRecharging
        )

        if let drone = worldScene.playerDrone {
            hudViewModel.updateDroneState(
                drone.droneState,
                carryingParcel: drone.attachedParcel != nil
            )
        }

        if let interactionController = interactionController {
            hudViewModel.updateInteractionPrompt(interactionController.interactionPrompt)
        }

        hudViewModel.updateClawStatus(clawController.statusText)

        if let activeJob = deliveryDirector.activeJob {
            hudViewModel.updateJobTimer(
                remaining: activeJob.remainingTime,
                total: activeJob.timeLimit
            )
        }
    }
    
    private func setupStep2Systems(content: RealityViewContent) {
        gameUIModel.placementManager.setup(contentEntity: worldScene.rootEntity, buildModeManager: gameUIModel.buildModeManager)

        if let drone = worldScene.playerDrone {
            clawController.setup(drone: drone, worldScene: worldScene)
        }

        packageSpawner.setup(worldScene: worldScene)
        deliveryDirector.setup(worldScene: worldScene, packageSpawner: packageSpawner)
        coinSpawner.setup(worldScene: worldScene)
        gameUIModel.modeManager.setupDependencies(worldScene: worldScene.rootEntity, packageSpawner: packageSpawner)
        gameUIModel.multiplayerManager.setupWorldAnchor(worldScene.rootEntity)
    }
    
    private func handleModeChange(_ mode: GameMode) {
        switch mode {
        case .build:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()

        case .play:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                packageSpawner.startSpawning()
                deliveryDirector.startNextJob()
            }

        case .playDelivery:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
                packageSpawner.startSpawning()
                deliveryDirector.startNextJob()
                coinSpawner.startSpawning()
            }

        case .playSandbox:
            gameUIModel.placementManager.stopPlacement()
            enemyDroneSpawner.stopSpawning()
            if gameUIModel.buildModeManager.isLayoutValid {
                worldScene.loadZones(from: gameUIModel.buildModeManager.currentLevelLayout)
            }

        case .playPractice:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            worldScene.clearZones()
            enemyDroneSpawner.setup(maxEnemies: 3, spawnRadius: 15.0, spawnCooldown: 3.0)
            enemyDroneSpawner.startSpawning(in: worldScene.rootEntity, playerDrone: worldScene.playerDrone)

        case .playSafari:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
            CrateDeliveryManager.shared.stop()
            SafariManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .playRaceLeague:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
            SafariManager.shared.stop()
            CrateDeliveryManager.shared.stop()
            RaceLeagueManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .playTimeTrial:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
            if let timeTrialManager = gameUIModel.modeManager.timeTrialManager,
               let playerDrone = worldScene.playerDrone {
                timeTrialManager.setup(worldScene: worldScene.rootEntity, playerDrone: playerDrone)
                timeTrialManager.startNewSession()
            }

        case .playMultiplayer:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
            if gameUIModel.multiplayerManager.isMultiplayerEnabled {
                startMultiplayerPositionTimer()
            }

        case .playCrateDelivery:
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
            SafariManager.shared.stop()
            RaceLeagueManager.shared.stop()
            CrateDeliveryManager.shared.start(in: worldScene.rootEntity, drone: worldScene.playerDrone)

        case .menu, .results:
            SafariManager.shared.stop()
            CrateDeliveryManager.shared.stop()
            RaceLeagueManager.shared.stop()
            packageSpawner.stopSpawning()
            coinSpawner.stopSpawning()
            enemyDroneSpawner.stopSpawning()
            worldScene.clearZones()
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

    /// Anchors the thumb-joystick control hint as a billboarded HUD card ~1.5m
    /// in front of the player whenever an immersive game mode starts.
    private func presentControlHint(using attachments: RealityViewAttachments) {
        guard let hint = attachments.entity(for: "controlHint") else { return }
        hint.position = SIMD3<Float>(0, 1.3, -1.5)
        hint.components.set(BillboardComponent())
        worldScene.rootEntity.addChild(hint)
        controlHintEntity = hint

        controlHintTimer?.invalidate()
        controlHintTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            dismissControlHint()
        }
    }

    /// Anchors the drone stats HUD to the device (head) anchor with a small -Z
    /// offset so it floats ~1.1m in front of the player like a visor readout.
    /// Mirrors ZombieShooter's `SciFiSurvivalHUDView` head-anchoring pattern.
    private func presentDroneStatsHUD(using attachments: RealityViewAttachments) {
        guard droneStatsHUDEntity == nil,
              let hud = attachments.entity(for: droneStatsHUDTag) else { return }
        hud.name = "droneStatsHUDEntity"
        // RealityView attachments are auto-converted from points to meters
        // (~1360 pt/m), so the 1040×260 pt panel is already ~0.76 m wide at
        // scale 1.0. A small extra shrink keeps it visor-sized without
        // collapsing it to nothing (0.0015 made it ~1 mm = invisible).
        hud.scale = SIMD3<Float>(repeating: 0.6)
        // In front of and slightly below the line of sight.
        hud.position = SIMD3<Float>(0, -0.25, -1.1)

        // Head anchors must be added directly to the scene root so RealityKit
        // activates device tracking for them.
        let headAnchor = AnchorEntity(.head)
        headAnchor.anchoring.trackingMode = .continuous
        headAnchor.addChild(hud)
        worldScene.rootEntity.addChild(headAnchor)
        droneStatsHUDEntity = hud
    }

    private func dismissControlHint() {
        controlHintTimer?.invalidate()
        controlHintTimer = nil
        controlHintEntity?.removeFromParent()
        controlHintEntity = nil
    }
    
#if os(visionOS)
    private func setupGestureSubscriptions() {
        gestureCancellable = handGestureManager.gestureEvents
            .sink { [self] event in
                handleGestureEvent(event)
            }
    }

    private func handleGestureEvent(_ event: GestureEvent) {
        switch event.type {
        case .indexFingerTouch:
            fireMissileFromGesture()
        case .pinch, .doublePinch, .palmFacing:
            break
        }
    }
    
    /// Tap on the pillar stand's red button → fire a missile through the exact
    /// same path the index-finger gesture uses. Also gives the cap a quick
    /// press-down/spring-back animation for feedback.
    private var gamepadFireButtonGesture: some Gesture {
        SpatialTapGesture()
            .targetedToEntity(where: .has(Gamepad3DButtonComponent.self))
            .onEnded { value in
                let cap = value.entity
                guard let button = cap.components[Gamepad3DButtonComponent.self] else { return }

                // Press feedback: pop the cap down, then spring it back.
                var down = cap.transform
                down.translation.y = button.restY - button.pressDepth
                cap.move(to: down, relativeTo: cap.parent, duration: 0.05)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [weak cap] in
                    guard let cap else { return }
                    var up = cap.transform
                    up.translation.y = button.restY
                    cap.move(to: up, relativeTo: cap.parent, duration: 0.12)
                }

                switch button.action {
                case .fireMissile:
                    if gameUIModel.modeManager.currentMode == .playCrateDelivery {
                        CrateDeliveryManager.shared.clawButton()
                    } else {
                        fireMissileFromGesture(slot: button.slot)
                    }
                case .toggleHologram:
                    worldScene.gamepadPillar?.toggleHologram()
                }
            }
    }

    /// Drag the pillar stand's floor base to reposition the whole controller.
    /// Only the foot carries `GamepadPillarBaseComponent`, so this never fires
    /// when grabbing a joystick or a button. The deck height (Y) is preserved;
    /// only the X/Z floor position follows the hand.
    private var gamepadPillarMoveGesture: some Gesture {
        DragGesture()
            .targetedToEntity(where: .has(GamepadPillarBaseComponent.self))
            .onChanged { value in
                guard let root = value.entity.components[GamepadPillarBaseComponent.self]?.root else { return }
                let parent = root.parent

                let start = pillarDragStart ?? root.position
                if pillarDragStart == nil { pillarDragStart = start }

                // Hand displacement since the drag began, expressed in the
                // pillar parent's local space.
                let nowScene = value.convert(value.location3D, from: .local, to: .scene)
                let startScene = value.convert(value.startLocation3D, from: .local, to: .scene)
                let nowLocal = parent?.convert(position: nowScene, from: nil) ?? nowScene
                let startLocal = parent?.convert(position: startScene, from: nil) ?? startScene
                let delta = nowLocal - startLocal

                // Move along the floor only; keep the deck at its original height.
                root.position = SIMD3<Float>(start.x + delta.x, start.y, start.z + delta.z)
            }
            .onEnded { _ in
                pillarDragStart = nil
            }
    }

    /// Twist the pillar stand's floor base to rotate the whole controller about
    /// its vertical (Y) axis. Like the move gesture, this is targeted only to the
    /// foot's `GamepadPillarBaseComponent`, so grabbing a joystick or button never
    /// triggers a rotation. The deck position is preserved; only its yaw changes.
    private var gamepadPillarRotateGesture: some Gesture {
        RotateGesture3D(constrainedToAxis: .y)
            .targetedToEntity(where: .has(GamepadPillarBaseComponent.self))
            .onChanged { value in
                guard let root = value.entity.components[GamepadPillarBaseComponent.self]?.root else { return }

                let start = pillarRotationStart ?? root.orientation
                if pillarRotationStart == nil { pillarRotationStart = start }

                // Yaw angle (radians) about the Y axis since the twist began.
                let angle = Float(value.rotation.angle.radians) * Float(value.rotation.axis.y < 0 ? -1 : 1)
                let yaw = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
                root.orientation = yaw * start
            }
            .onEnded { _ in
                pillarRotationStart = nil
            }
    }

    private func fireMissileFromGesture(slot: Int = 1) {
        if gameUIModel.modeManager.currentMode == .playCrateDelivery {
            CrateDeliveryManager.shared.clawButton()
            return
        }
        guard let drone = worldScene.playerDrone else { return }

        let weaponStats = GameContext.shared.loadout.getCurrentWeaponStats(slot: slot)

        DroneMissileSystem.fireMissile(from: drone, addingTo: worldScene.rootEntity, slot: slot)

        if gameUIModel.multiplayerManager.isMultiplayerEnabled {
            Task {
                let spawnOffset = SIMD3<Float>(0, 0, -0.03)
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
#endif
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
