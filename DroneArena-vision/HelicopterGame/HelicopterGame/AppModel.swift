//
//  AppModel.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI
import RealityKit
import DicyaninVirtualJoystick
#if os(visionOS)
import DicyaninThumbController
#endif

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState: ImmersiveSpaceState = .closed
#if os(iOS)
    /// Set by DEBUG StageDirector routes; VisionContentView presents the flight view for it.
    var mobileLaunchRequest: GameMode?
#endif

    /// Connects the standalone DicyaninVirtualJoystick package to this app's
    /// control-scheme flag, hand tracking, and movement pipeline. The package has
    /// no knowledge of these app types; it only calls back through these hooks.
    private static func wireVirtualJoystickBridge() {
        // Active only while a world-anchored joystick rig is the selected scheme.
        VirtualJoystickBridge.isEnabled = { ControlSchemeConfig.useWorldJoystickRig }

        // When a world joystick rig is active, the rig is the SOLE writer of the
        // shared left/right channels. Suppress DualThumbController's raw ARKit
        // hand tracking so it can't overwrite the stick values every frame — that
        // contamination (especially the right hand's pitch) is what made the blue
        // stick do more than height + rotation.
        ControlSchemeConfig.syncHandTrackingGate()

        // Per-hand pinch positions for two-handed grabs (device only; nil in Sim).
        VirtualJoystickBridge.handPinchProvider = {
#if os(visionOS) && !targetEnvironment(simulator)
            let hg = GameContext.shared.handGesture
            return VirtualJoystickHandPinch(
                left: hg.isLeftPinching ? hg.leftPinchPosition : nil,
                right: hg.isRightPinching ? hg.rightPinchPosition : nil
            )
#else
            return nil
#endif
        }

        // Route the normalized stick output into the shared movement controller —
        // the same entry point the simulator joysticks feed.
        VirtualJoystickBridge.output = { input in
#if os(visionOS)
            if DemoDirector.ownsInput { return }
            DualThumbController.shared.setVirtualJoystickInput(
                leftDirection: input.leftDirection,
                leftMagnitude: input.leftMagnitude,
                leftActive: input.leftActive,
                rightDirection: input.rightDirection,
                rightMagnitude: input.rightMagnitude,
                rightActive: input.rightActive
            )
#endif
        }
    }

    init() {
        AppModel.wireVirtualJoystickBridge()

        GestureComponent.registerComponent()

        WorldMissileComponent.registerComponent()
        WorldMissileSystem.registerSystem()
        SandboxCrateComponent.registerComponent()
        GrabbableComponent.registerComponent()
        
        ClawInputComponent.registerComponent()
        ClawComponent.registerComponent()
        ClawSystem.registerSystem()

        DroneTrailParticleComponent.registerComponent()
        DroneTrailSystem.registerSystem()

        DroneHoverComponent.registerComponent()
        DroneHoverSystem.registerSystem()

        DroneMissileSystem.registerSystem()
        DroneMissileComponent.registerComponent()
        MissileComponent.registerComponent()
        
        RemoteDronePositionComponent.registerComponent()
        RemoteDronePositionSystem.registerSystem()

        RemoteDronePositionIndicatorComponent.registerComponent()
        RemoteDronePositionIndicatorSystem.registerSystem()

        PlayerHealthComponent.registerComponent()
        
        EnemyDroneAISystem.registerSystem()
        EnemyAIComponent.registerComponent()

        WallMeshComponent.registerComponent()
        
        TimeTrialComponent.registerComponent()
        RingComponent.registerComponent()
        CourseGateComponent.registerComponent()
        DroneCrashComponent.registerComponent()
        TimeTrialSystem.registerSystem()

        SafariManager.registerECS()
        RaceLeagueManager.registerECS()
        CrateDeliveryManager.registerECS()

        MobileVirtualJoystickComponent.registerComponent()
        MobileVirtualJoystickSystem.registerSystem()

        // Register the 3D gamepad joystick system (dev flag: ControlSchemeConfig)
        Gamepad3DJoystickComponent.registerComponent()
        Gamepad3DHeadComponent.registerComponent()
        Gamepad3DSystem.registerSystem()

        // Register the remote drone position system for smooth multiplayer interpolation
        RemoteDronePositionComponent.registerComponent()
        RemoteDronePositionSystem.registerSystem()

        // Register the drone missile system
        DroneMissileComponent.registerComponent()
        MissileComponent.registerComponent()
        DroneMissileSystem.registerSystem()

        // Register the enemy drone AI system
        EnemyAIComponent.registerComponent()

        // Register the time trial ECS system
        TimeTrialComponent.registerComponent()
        RingComponent.registerComponent()
        CourseGateComponent.registerComponent()
        DroneCrashComponent.registerComponent()
        TimeTrialSystem.registerSystem()

        // Register the boss AI system and projectile system
        EnemyAIBossComponent.registerComponent()
        EnemyAIBossSystem.registerSystem()
        AIBossProjectileComponent.registerComponent()
        AIBossProjectileSystem.registerSystem()

        // Register the drone position indicator system
        DronePositionIndicatorComponent.registerComponent()
        DronePositionIndicatorSystem.registerSystem()
        
        BossPositionIndicatorSystem.registerSystem()
        BossPositionIndicatorComponent.registerComponent()
        
        RemoteDronePositionComponent.registerComponent()
        RemoteDronePositionSystem.registerSystem()
        
        // Register the drone missile system
        DroneMissileComponent.registerComponent()
        MissileComponent.registerComponent()
        DroneMissileSystem.registerSystem()
        
        let _ = GameContext.shared.sound
    }

    // Communication between ContentView and ImmersiveView
    private var modeChangeCallback: ((GameMode) -> Void)?

    // Input router for simulator controls - initialize immediately for ContentView
    @ObservationIgnored private var _inputRouter: InputRouter?
    var inputRouter: InputRouter {
        if let router = _inputRouter {
            return router
        } else {
            let router = InputRouter()
            _inputRouter = router
            return router
        }
    }

    // World scene controller for direct joystick control
    var worldSceneController: WorldSceneController?

    // Flight controller for drone physics - shared across views
    @ObservationIgnored private var _flightController: FlightController?
    var flightController: FlightController {
        if let controller = _flightController {
            return controller
        } else {
            let controller = FlightController(playerSettings: GameContext.shared.gameSession.playerSettings)
            _flightController = controller
            return controller
        }
    }

    func setModeChangeCallback(_ callback: @escaping (GameMode) -> Void) {
        self.modeChangeCallback = callback
    }

    func notifyModeChange(_ mode: GameMode) {
        modeChangeCallback?(mode)
    }
}
