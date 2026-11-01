import RealityKit
import simd

public struct ThumbControlledComponent: Component {
    public var movementSpeed: Float
    
    public init(movementSpeed: Float = 1.0) {
        self.movementSpeed = movementSpeed
    }
}

public class ThumbControlledSystem: System {
    // Define a query to return all entities with ThumbControlledComponent
    private static let query = EntityQuery(where: .has(ThumbControlledComponent.self))
    
    // Required initializer
    public required init(scene: Scene) { }
    
    // Update method
    public func update(context: SceneUpdateContext) {
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard let component = entity.components[ThumbControlledComponent.self] else { continue }
            
            // Apply movement if active
            if ThumbController.shared.isActive {
                let direction = ThumbController.shared.direction
                let magnitude = ThumbController.shared.magnitude
                
                // Calculate movement
                let baseMovement = direction * magnitude * component.movementSpeed * Float(context.deltaTime) * 2
                
                // Convert the direction into a joystick-like movement vector
                // Forward/backward movement (Z axis)
                let forwardMovement = baseMovement.z
                
                // Left/right movement (X axis)
                let horizontalMovement = baseMovement.x
                
                // Up/down movement (Y axis)
                // When moving backward, we want to naturally move down as well
                let verticalMovement = baseMovement.y - (forwardMovement * 0.5) // Add downward bias when moving backward
                
                // Create the final movement vector
                let movement = SIMD3<Float>(
                    horizontalMovement,  // Left/right
                    verticalMovement,    // Up/down
                    forwardMovement      // Forward/backward
                )
                
                // Apply movement to entity
                entity.position += movement
            }
        }
    }
}

// Extension to make it easier to add the component to entities
public extension Entity {
    func addThumbControl(movementSpeed: Float = 1.0) {
        ThumbControlledComponent.registerComponent()
        ThumbControlledSystem.registerSystem()
        self.components[ThumbControlledComponent.self] = ThumbControlledComponent(movementSpeed: movementSpeed)
    }
    
    func removeThumbControl() {
        self.components[ThumbControlledComponent.self] = nil
    }
}

// MARK: - Dual Thumb Control (Movement + Yaw)

public struct DualThumbControlledComponent: Component {
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

public class DualThumbControlledSystem: System {
    // Define a query to return all entities with DualThumbControlledComponent
    private static let query = EntityQuery(where: .has(DualThumbControlledComponent.self))

    // Required initializer
    public required init(scene: Scene) { }

    // Update method - Mode-2 Flight Controls
    public func update(context: SceneUpdateContext) {
        for entity in context.entities(
            matching: Self.query,
            updatingSystemWhen: .rendering
        ) {
            guard let component = entity.components[DualThumbControlledComponent.self] else { continue }

            let deltaTime = Float(context.deltaTime)
            var movement = SIMD3<Float>.zero
            var hasRotation = false
            var totalYawInput: Float = 0.0

            // LEFT STICK (Mode-2): Throttle (Y) + Yaw (X)
            if DualThumbController.shared.leftIsActive {
                let leftDirection = DualThumbController.shared.leftDirection
                let leftMagnitude = DualThumbController.shared.leftMagnitude

                // Y-axis: Throttle (up/down movement)
                let throttleInput = leftDirection.y * leftMagnitude * component.throttleSpeed * deltaTime
                movement.y += throttleInput

                // X-axis: Yaw rotation (turn left/right)
                let yawInput = leftDirection.x * leftMagnitude * component.yawSpeed * deltaTime
                totalYawInput += yawInput
                hasRotation = true

                print("🕹️ Left stick - Throttle: \(throttleInput), Yaw: \(yawInput)")
            }

            // RIGHT STICK (Mode-2): Pitch (Y) + Roll (X)
            if DualThumbController.shared.rightIsActive {
                let rightDirection = DualThumbController.shared.rightDirection
                let rightMagnitude = DualThumbController.shared.rightMagnitude

                // Y-axis: Pitch (forward/backward movement)
                let pitchInput = rightDirection.y * rightMagnitude * component.pitchSpeed * deltaTime
                movement.z += pitchInput

                // X-axis: Roll (strafe left/right movement)
                let rollInput = rightDirection.x * rightMagnitude * component.rollSpeed * deltaTime
                movement.x += rollInput

                print("🕹️ Right stick - Pitch: \(pitchInput), Roll: \(rollInput)")
            }

            // Apply movement relative to drone's orientation
            if length(movement) > 0 {
                // Transform movement from local space to world space based on drone's orientation
                let worldMovement = entity.orientation.act(movement)
                entity.position += worldMovement
                print("🕹️ Applied movement: \(movement) -> world: \(worldMovement) to entity at \(entity.position)")
            }

            // Apply yaw rotation if any input
            if hasRotation && abs(totalYawInput) > 0.001 {
                let yawRotation = simd_quatf(angle: totalYawInput, axis: SIMD3<Float>(0, 1, 0))
                entity.orientation = simd_mul(entity.orientation, yawRotation)
                print("🔄 Applied yaw rotation: \(totalYawInput) radians")
            }
        }
    }
}

// Extension to make it easier to add dual thumb control to entities
public extension Entity {
    func addDualThumbControl(
        throttleSpeed: Float = 2.0,
        yawSpeed: Float = 1.5,
        pitchSpeed: Float = 2.0,
        rollSpeed: Float = 2.0
    ) {
        DualThumbControlledComponent.registerComponent()
        DualThumbControlledSystem.registerSystem()
        self.components[DualThumbControlledComponent.self] = DualThumbControlledComponent(
            throttleSpeed: throttleSpeed,
            yawSpeed: yawSpeed,
            pitchSpeed: pitchSpeed,
            rollSpeed: rollSpeed
        )
    }

    func removeDualThumbControl() {
        self.components[DualThumbControlledComponent.self] = nil
    }
}
