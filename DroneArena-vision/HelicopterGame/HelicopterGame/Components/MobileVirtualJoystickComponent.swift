//
//  MobileVirtualJoystickComponent.swift
//  HelicopterGame
//
//  Created by Claude on 10/3/25.
//  iOS-specific ECS component and system for virtual joystick control
//

import RealityKit
import simd

// MARK: - Component

public struct MobileVirtualJoystickComponent: Component {
    public var throttleSpeed: Float    // Vertical movement speed (up/down)
    public var yawSpeed: Float         // Rotation speed (left/right turn)
    public var pitchSpeed: Float       // Forward/backward movement speed
    public var rollSpeed: Float        // Strafe left/right movement speed

    public init(throttleSpeed: Float = 2.0, yawSpeed: Float = 1.5, pitchSpeed: Float = 2.0, rollSpeed: Float = 2.0) {
        self.throttleSpeed = throttleSpeed
        self.yawSpeed = yawSpeed
        self.pitchSpeed = pitchSpeed
        self.rollSpeed = rollSpeed
    }
}

// MARK: - System

public class MobileVirtualJoystickSystem: System {
    // Define a query to return all entities with MobileVirtualJoystickComponent
    private static let query = EntityQuery(where: .has(MobileVirtualJoystickComponent.self))

    // Static reference to InputRouter for access from system
    @MainActor public static var inputRouter: InputRouter?

    // Required initializer
    public required init(scene: Scene) { }

    // Update method - Mode-2 Flight Controls for iOS Virtual Joysticks
    public func update(context: SceneUpdateContext) {
        guard let inputRouter = MobileVirtualJoystickSystem.inputRouter else {
            // gameLog("⚠️ MobileVirtualJoystickSystem: No InputRouter set")
            return
        }

        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard let component = entity.components[MobileVirtualJoystickComponent.self] else { continue }

            // Debug: Log which entity type is being controlled
            let entityType = type(of: entity)
            if entityType == PlayerDroneEntity.self {
                // This is expected - local player drone
            } else {
                gameLog("⚠️ [MobileVirtualJoystickSystem] Controlling unexpected entity type: \(entityType)")
                gameLog("⚠️ Entity: \(entity)")
                continue // Skip non-PlayerDroneEntity entities
            }

            // While crashed (Time Trial), the course system owns the drone; report
            // throttle for recovery-lift detection instead of moving it.
            if let drone = entity as? PlayerDroneEntity, drone.isCrashActive {
                if inputRouter.isRightJoystickActiveStatus {
                    CourseInput.directLift = max(0, inputRouter.currentVerticalDirection * inputRouter.rightJoystickMagnitude)
                }
                continue
            }

            let deltaTime = Float(context.deltaTime)
            var movement = SIMD3<Float>.zero
            var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

            // BLUE / LEFT STICK (leftDirection channel): Throttle (Y) + Yaw (X)
            // Yaw lives ONLY on this channel — this matches DualThumbControlledSystem's
            // Mode-2 mapping so the two systems never fight over rotation.
            if inputRouter.isLeftJoystickActiveStatus {
                let leftDirection = inputRouter.currentMovementDirection
                let leftMagnitude = inputRouter.leftJoystickMagnitude

                // Y-axis: Throttle (up/down movement)
                let throttleInput = leftDirection.y * leftMagnitude * component.throttleSpeed * deltaTime
                movement.y += throttleInput

                // X-axis: Yaw rotation (turn left/right)
                let yawInput = -leftDirection.x * leftMagnitude * component.yawSpeed * deltaTime
                rotation = simd_quatf(angle: yawInput, axis: SIMD3<Float>(0, 1, 0))

                // gameLog("🕹️ Blue stick - Throttle: \(throttleInput), Yaw: \(yawInput)")
            }

            // ORANGE / RIGHT STICK (rightDirection channel): Pitch (Y) + Roll (X)
            // The orange stick must NEVER drive yaw — it only moves the drone in the
            // pitch/roll (forward-back / strafe) plane.
            if inputRouter.isRightJoystickActiveStatus {
                let rightRoll = inputRouter.currentYawDirection        // rightDirection.x
                let rightPitch = inputRouter.currentVerticalDirection  // rightDirection.y
                let rightMagnitude = inputRouter.rightJoystickMagnitude

                // Y-axis: Forward/backward movement (pitch)
                let pitchInput = rightPitch * rightMagnitude * component.pitchSpeed * deltaTime
                movement.z += pitchInput

                // X-axis: Strafe left/right movement (roll)
                let rollInput = rightRoll * rightMagnitude * component.rollSpeed * deltaTime
                movement.x += rollInput

                // gameLog("🕹️ Orange stick - Pitch: \(pitchInput), Roll: \(rollInput)")
            }

            // Apply movement relative to drone's orientation
            if length(movement) > 0 {
                // Transform movement from local space to world space based on drone's orientation
                let worldMovement = entity.orientation.act(movement)
                entity.position += worldMovement
            }

            // Apply rotation if any yaw input
            if abs(rotation.angle) > 0.001 {
                entity.orientation = simd_mul(entity.orientation, rotation)
            }
        }
    }
}

// MARK: - Entity Extension

public extension Entity {
    func addMobileVirtualJoystickControl(
        throttleSpeed: Float = 2.0,
        yawSpeed: Float = 1.5,
        pitchSpeed: Float = 2.0,
        rollSpeed: Float = 2.0
    ) {
        // Only allow PlayerDroneEntity to have joystick control
        guard self is PlayerDroneEntity else {
            gameLog("⚠️ [MobileVirtualJoystickComponent] Attempted to add joystick control to non-PlayerDroneEntity: \(type(of: self))")
            return
        }

        MobileVirtualJoystickComponent.registerComponent()
        MobileVirtualJoystickSystem.registerSystem()
        self.components[MobileVirtualJoystickComponent.self] = MobileVirtualJoystickComponent(
            throttleSpeed: throttleSpeed,
            yawSpeed: yawSpeed,
            pitchSpeed: pitchSpeed,
            rollSpeed: rollSpeed
        )
        gameLog("📱 iOS: Added mobile virtual joystick control to PlayerDroneEntity")
    }

    func removeMobileVirtualJoystickControl() {
        self.components[MobileVirtualJoystickComponent.self] = nil
        gameLog("📱 iOS: Removed mobile virtual joystick control")
    }
}