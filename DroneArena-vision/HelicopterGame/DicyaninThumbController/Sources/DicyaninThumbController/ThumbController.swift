import Foundation
import simd
import Combine
#if os(visionOS)
import DicyaninARKitSession
import ARKit
import UIKit
#endif
import RealityKit

public enum HandSide {
    case left
    case right
}

public struct ThumbControllerHand {
    public let thumbTip: SIMD3<Float>?
    public let indexTip: SIMD3<Float>?
    public let indexKnuckle: SIMD3<Float>?
    public let indexMetacarpal: SIMD3<Float>?
    public let wrist: SIMD3<Float>?
    public let palmOrientation: simd_quatf?
    public let indexMetacarpalOrientation: simd_quatf?

    public init(thumbTip: SIMD3<Float>?, indexTip: SIMD3<Float>?, indexKnuckle: SIMD3<Float>?, indexMetacarpal: SIMD3<Float>?, wrist: SIMD3<Float>?, palmOrientation: simd_quatf?, indexMetacarpalOrientation: simd_quatf?) {
        self.thumbTip = thumbTip
        self.indexTip = indexTip
        self.indexKnuckle = indexKnuckle
        self.indexMetacarpal = indexMetacarpal
        self.wrist = wrist
        self.palmOrientation = palmOrientation
        self.indexMetacarpalOrientation = indexMetacarpalOrientation
    }
}

#if os(visionOS)
struct HandAnchorConverter {
    static func convert(_ anchor: HandAnchor) -> ThumbControllerHand {
        print("🔍 HandAnchorConverter.convert() called")
        guard let handSkeleton = anchor.handSkeleton else {
            print("⚠️ No hand skeleton available")
            return ThumbControllerHand(thumbTip: nil, indexTip: nil, indexKnuckle: nil, indexMetacarpal: nil, wrist: nil, palmOrientation: nil, indexMetacarpalOrientation: nil)
        }

        print("✅ Hand skeleton found, extracting joints...")
        let originTransform = anchor.originFromAnchorTransform

        let thumbTipJoint = handSkeleton.joint(.thumbTip)
        let indexTipJoint = handSkeleton.joint(.indexFingerTip)
        let indexKnuckleJoint = handSkeleton.joint(.indexFingerKnuckle)
        let indexMetacarpalJoint = handSkeleton.joint(.indexFingerMetacarpal)
        let wristJoint = handSkeleton.joint(.wrist)
        print("✅ All joints extracted")

        let thumbTipTransform = matrix_multiply(originTransform, thumbTipJoint.anchorFromJointTransform)
        let indexTipTransform = matrix_multiply(originTransform, indexTipJoint.anchorFromJointTransform)
        let indexKnuckleTransform = matrix_multiply(originTransform, indexKnuckleJoint.anchorFromJointTransform)
        let indexMetacarpalTransform = matrix_multiply(originTransform, indexMetacarpalJoint.anchorFromJointTransform)
        let wristTransform = matrix_multiply(originTransform, wristJoint.anchorFromJointTransform)

        let thumbTipPos = SIMD3<Float>(thumbTipTransform.columns.3.x,
                                      thumbTipTransform.columns.3.y,
                                      thumbTipTransform.columns.3.z)
        let indexTipPos = SIMD3<Float>(indexTipTransform.columns.3.x,
                                      indexTipTransform.columns.3.y,
                                      indexTipTransform.columns.3.z)
        let indexKnucklePos = SIMD3<Float>(indexKnuckleTransform.columns.3.x,
                                          indexKnuckleTransform.columns.3.y,
                                          indexKnuckleTransform.columns.3.z)
        let indexMetacarpalPos = SIMD3<Float>(indexMetacarpalTransform.columns.3.x,
                                             indexMetacarpalTransform.columns.3.y,
                                             indexMetacarpalTransform.columns.3.z)
        let wristPos = SIMD3<Float>(wristTransform.columns.3.x,
                                   wristTransform.columns.3.y,
                                   wristTransform.columns.3.z)

        print("✅ All positions calculated")

        // Extract palm orientation from the wrist transform
        let palmOrientation = simd_quatf(wristTransform)
        print("✅ Palm orientation extracted")

        // Extract index metacarpal orientation for rotation detection
        let indexMetacarpalOrientation = simd_quatf(indexMetacarpalTransform)
        print("✅ Metacarpal orientation extracted")

        print("✅ HandAnchorConverter.convert() complete, returning ThumbControllerHand")
        return ThumbControllerHand(thumbTip: thumbTipPos, indexTip: indexTipPos, indexKnuckle: indexKnucklePos, indexMetacarpal: indexMetacarpalPos, wrist: wristPos, palmOrientation: palmOrientation, indexMetacarpalOrientation: indexMetacarpalOrientation)
    }
}
#endif

@MainActor
public class ThumbController: ObservableObject {
    public static let shared = ThumbController(handSide: .right)

    @Published public private(set) var direction: SIMD3<Float> = .zero
    @Published public private(set) var magnitude: Float = 0.0
    @Published public private(set) var isActive: Bool = false
    @Published public var useVerticalThumbInput: Bool = true

    private let handSide: HandSide
    private var cancellables = Set<AnyCancellable>()

    private let settings = ThumbControllerSettings.shared

    public init(handSide: HandSide) {
        self.handSide = handSide

#if os(visionOS)
        setupHandTracking()
#endif

        ThumbControlledSystem.registerSystem()
        ThumbControlledComponent.registerComponent()
    }

#if os(visionOS)
    private func setupHandTracking() {
        ARKitSessionManager.shared.handTrackingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }

                // Only process the hand we're configured to track
                if self.handSide == .right {
                    if let rightHand = update.right {
                        let hand = HandAnchorConverter.convert(rightHand)
                        self.processHandPosition(hand)
                    }
                } else {
                    if let leftHand = update.left {
                        let hand = HandAnchorConverter.convert(leftHand)
                        self.processHandPosition(hand)
                    }
                }
            }
            .store(in: &cancellables)
    }
#endif

    private func processHandPosition(_ hand: ThumbControllerHand) {
        // Get the thumb tip position
        guard let thumbTip = hand.thumbTip else {
            return
        }

        // Get the index finger knuckle position as the base reference point
        guard let indexKnuckle = hand.indexKnuckle else {
            return
        }

        // Calculate the joystick reference point: knuckle position + 0.2 units closer to user (Z axis)
        let joystickReferencePoint = indexKnuckle + SIMD3<Float>(0, 0, 0.2)

        var finalVector: SIMD3<Float>
        var magnitude: Float
        var active: Bool = false

        if useVerticalThumbInput {
            // Vertical thumb input mode: use X/Z for horizontal movement AND Y for vertical movement
            let horizontalVector = thumbTip - joystickReferencePoint
            let horizontalDistance = length(SIMD2<Float>(horizontalVector.x, horizontalVector.z))
            let verticalDistance = abs(thumbTip.y - joystickReferencePoint.y)

            // Check if either horizontal or vertical movement is above deadzone
            let horizontalActive = horizontalDistance > settings.deadzone
            let verticalActive = verticalDistance > settings.verticalDeadzone

            if horizontalActive || verticalActive {
                var xMovement: Float = 0.0
                var yMovement: Float = 0.0
                var zMovement: Float = 0.0

                // Handle horizontal X/Z movement
                if horizontalActive {
                    let normalizedHorizontal = normalize(SIMD2<Float>(horizontalVector.x, horizontalVector.z))
                    let clampedHorizontalDistance = min(horizontalDistance, settings.maxDistance)
                    let scaledHorizontal = normalizedHorizontal * (clampedHorizontalDistance / settings.maxDistance)

                    xMovement = scaledHorizontal.x * settings.scaleFactor
                    zMovement = scaledHorizontal.y * settings.scaleFactor
                }

                // Handle vertical Y movement
                if verticalActive {
                    let yDirection = thumbTip.y > joystickReferencePoint.y ? 1.0 : -1.0
                    let clampedVerticalDistance = min(verticalDistance, settings.maxDistance)
                    let scaledVerticalMagnitude = clampedVerticalDistance / settings.maxDistance

                    yMovement = Float(yDirection) * scaledVerticalMagnitude * settings.scaleFactor
                }

                finalVector = SIMD3<Float>(xMovement, yMovement, zMovement)
                magnitude = max(horizontalDistance / settings.maxDistance, verticalDistance / settings.maxDistance)
                active = true
            } else {
                finalVector = .zero
                magnitude = 0.0
                active = false
            }
        } else {
            // Original joystick mode: use thumb tip relative to joystick reference point for X/Z movement
            let vector = thumbTip - joystickReferencePoint
            let distance = length(vector)

            // Check if we're within the deadzone
            if distance < settings.deadzone {
                finalVector = .zero
                magnitude = 0.0
                active = false
            } else {
                // Normalize the vector and apply max distance
                let normalizedVector = normalize(vector)
                let clampedDistance = min(distance, settings.maxDistance)
                let scaledVector = normalizedVector * clampedDistance

                // Apply significant scaling to make movement more pronounced
                // Zero out Y component for traditional joystick behavior
                finalVector = SIMD3<Float>(
                    scaledVector.x * settings.scaleFactor,
                    0.0,  // No vertical movement in joystick mode
                    scaledVector.z * settings.scaleFactor
                )

                magnitude = clampedDistance / settings.maxDistance
                active = true
            }
        }

        // Debug output if enabled
        if settings.enableDiagnostics {
            print("🎮 ThumbController Debug:")
      
            print("  ---")
        }

        // Update the state
        self.direction = finalVector
        self.magnitude = magnitude
        self.isActive = active
    }

    public func start() async throws {
        // Register the component and system
        ThumbControlledComponent.registerComponent()
        await ThumbControlledSystem.registerSystem()

#if os(visionOS)
        try await ARKitSessionManager.shared.start()
#endif
    }

    public func stop() {
#if os(visionOS)
        ARKitSessionManager.shared.stop()
#endif
    }
}

// MARK: - Dual Hand Controller

@MainActor
public class DualThumbController: ObservableObject {
    public static let shared = DualThumbController()

    // Left hand state
    @Published public private(set) var leftDirection: SIMD3<Float> = .zero
    @Published public private(set) var leftMagnitude: Float = 0.0
    @Published public private(set) var leftIsActive: Bool = false

    // Right hand state
    @Published public private(set) var rightDirection: SIMD3<Float> = .zero
    @Published public private(set) var rightMagnitude: Float = 0.0
    @Published public private(set) var rightIsActive: Bool = false

    @Published public var useVerticalThumbInput: Bool = true

    /// When false, the ARKit hand-tracking pipeline stops writing to the shared
    /// left/right channels. The world-anchored joystick rigs (3D gamepad / pillar
    /// stand) push their own input through `setVirtualJoystickInput` and must be
    /// the SOLE writer — otherwise raw hand poses (and the right hand's pitch in
    /// particular) overwrite the stick values every frame, so the blue stick stops
    /// behaving like a clean height+yaw control. The host flips this when the
    /// active control scheme is a world joystick rig.
    @Published public var isHandTrackingInputEnabled: Bool = true

    private var cancellables = Set<AnyCancellable>()
    private let settings = ThumbControllerSettings.shared

    public init() {

#if os(visionOS)
        setupDualHandTracking()
#endif

        ThumbControlledSystem.registerSystem()
        ThumbControlledComponent.registerComponent()
    }

#if os(visionOS)
    private func setupDualHandTracking() {
        ARKitSessionManager.shared.handTrackingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }

                // When a world joystick rig owns input, it is the sole writer of
                // the shared channels (via setVirtualJoystickInput). Skip raw hand
                // tracking so it can't overwrite the stick values each frame.
                guard self.isHandTrackingInputEnabled else { return }

                // Process both hands simultaneously
                if let leftHand = update.left {
                    let hand = HandAnchorConverter.convert(leftHand)
                    self.processHandPosition(hand, isLeftHand: true)
                }

                if let rightHand = update.right {
                    let hand = HandAnchorConverter.convert(rightHand)
                    self.processHandPosition(hand, isLeftHand: false)
                }
            }
            .store(in: &cancellables)
    }
#endif

    private func processHorizontalHandMode(_ hand: ThumbControllerHand, isLeftHand: Bool) {
        let handName = isLeftHand ? "LEFT" : "RIGHT"
        print("🎮 processHorizontalHandMode() called for \(handName) hand")

        guard let indexTip = hand.indexTip,
              let indexMetacarpal = hand.indexMetacarpal,
              let metacarpalOrientation = hand.indexMetacarpalOrientation else {
            print("⚠️ Missing required hand data for \(handName) hand")
            // Reset the hand state if we can't track it
            if isLeftHand {
                self.leftDirection = .zero
                self.leftMagnitude = 0.0
                self.leftIsActive = false
            } else {
                self.rightDirection = .zero
                self.rightMagnitude = 0.0
                self.rightIsActive = false
            }
            return
        }

        print("✅ All required hand data present for \(handName)")

        var finalVector: SIMD3<Float>
        var magnitude: Float
        var active: Bool = false

        // Calculate finger position: tip relative to metacarpal
        let fingerOffset = indexTip - indexMetacarpal
        let fingerVerticalPosition = fingerOffset.y
        print("📏 Finger vertical position: \(fingerVerticalPosition)")

        // Extract forward vector from metacarpal orientation for rotation detection
        let forwardVector = metacarpalOrientation.act(SIMD3<Float>(0, 0, -1))
        print("🧭 Forward vector: \(forwardVector)")

        // Calculate rotation angle in XZ plane (yaw)
        // atan2 gives us the angle of the forward vector projection on XZ plane
        let rotationAngle = atan2(forwardVector.x, -forwardVector.z)
        print("🔄 Rotation angle: \(rotationAngle)")

        if isLeftHand {
            print("👈 Processing LEFT hand")
            // LEFT HAND: Height (Y) and Yaw (rotation)

            // Height: Finger pointing up = fly up, finger pointing down = fly down
            let heightDeadzone: Float = 0.02 // 2cm vertical deadzone
            let heightActive = abs(fingerVerticalPosition) > heightDeadzone
            print("  Height active: \(heightActive)")

            // Yaw: Metacarpal rotation for turning
            let yawActive = abs(rotationAngle) > settings.horizontalTiltDeadzone
            print("  Yaw active: \(yawActive)")

            if heightActive || yawActive {
                print("  ✅ Left hand input ACTIVE")
                // Height movement (throttle up/down)
                // Normalize and scale the vertical finger position
                let heightInput = heightActive ? fingerVerticalPosition * settings.horizontalTiltSensitivity * settings.throttleSpeed : 0.0

                // Yaw rotation (turn left/right) - with proper deadzone
                // Only apply yaw if it exceeds the deadzone threshold
                var yawInput: Float = 0.0
                if yawActive {
                    yawInput = (rotationAngle / 3.0) * settings.horizontalTiltSensitivity * settings.yawSpeed
                }

                finalVector = SIMD3<Float>(yawInput, heightInput, 0)
                magnitude = max(abs(fingerVerticalPosition), abs(rotationAngle))
                active = true
            } else {
                finalVector = .zero
                magnitude = 0.0
                active = false
            }

        } else {
            print("👉 Processing RIGHT hand")
            // RIGHT HAND: Forward/Backward (same as left hand uses for height)

            // Forward/Backward: Use EXACT same logic as left hand height
            // Finger pointing down = forward, finger pointing up = backward
            let pitchDeadzone: Float = 0.02 // 2cm vertical deadzone
            let pitchActive = abs(fingerVerticalPosition) > pitchDeadzone

            if pitchActive {
                print("  ✅ Right hand input ACTIVE")
                // Pitch movement (forward/backward) - use same calculation as left hand height
                // Invert: finger down (negative Y) = forward (positive Z)
                let pitchInput = -fingerVerticalPosition * settings.horizontalTiltSensitivity * settings.pitchSpeed

                finalVector = SIMD3<Float>(0, 0, pitchInput)
                magnitude = abs(fingerVerticalPosition)
                active = true
            } else {
                finalVector = .zero
                magnitude = 0.0
                active = false
            }
        }

        // Debug output if enabled
        if settings.enableDiagnostics {
            let handName = isLeftHand ? "LEFT" : "RIGHT"
            print("🎮 HorizontalHandMode Debug [\(handName)]:")
            print("  IndexTip: \(indexTip)")
            print("  IndexMetacarpal: \(indexMetacarpal)")
            print("  Finger Vertical Position: \(fingerVerticalPosition)")
            print("  Rotation Angle: \(rotationAngle)")
            print("  Final direction: \(finalVector)")
            print("  Magnitude: \(magnitude)")
            print("  Active: \(active)")
            print("  ---")
        }

        // Update the appropriate hand state
        if isLeftHand {
            print("⬅️ Updating LEFT hand state: direction=\(finalVector), active=\(active)")
            self.leftDirection = finalVector
            self.leftMagnitude = magnitude
            self.leftIsActive = active
        } else {
            print("➡️ Updating RIGHT hand state: direction=\(finalVector), active=\(active)")
            self.rightDirection = finalVector
            self.rightMagnitude = magnitude
            self.rightIsActive = active
        }
        print("✅ processHorizontalHandMode() completed for \(handName)")
    }

    private func processHandPosition(_ hand: ThumbControllerHand, isLeftHand: Bool) {
        // Check if we're using horizontal hand input mode
        if settings.horizontalHandInputMode {
            processHorizontalHandMode(hand, isLeftHand: isLeftHand)
            return
        }

        // Otherwise use thumb joystick mode
        guard let thumbTip = hand.thumbTip,
              let indexKnuckle = hand.indexKnuckle else {
            // Reset the hand state if we can't track it
            if isLeftHand {
                self.leftDirection = .zero
                self.leftMagnitude = 0.0
                self.leftIsActive = false
            } else {
                self.rightDirection = .zero
                self.rightMagnitude = 0.0
                self.rightIsActive = false
            }
            return
        }

        // Calculate the joystick reference point: knuckle position + 0.2 units closer to user (Z axis)
        let joystickReferencePoint = indexKnuckle + SIMD3<Float>(0, 0, 0.2)

        var finalVector: SIMD3<Float>
        var magnitude: Float
        var active: Bool = false

        if useVerticalThumbInput {
            // Vertical thumb input mode: use X/Z for horizontal movement AND Y for vertical movement
            let horizontalVector = thumbTip - joystickReferencePoint
            let horizontalDistance = length(SIMD2<Float>(horizontalVector.x, horizontalVector.z))
            let verticalDistance = abs(thumbTip.y - joystickReferencePoint.y)

            // Check if either horizontal or vertical movement is above deadzone
            let horizontalActive = horizontalDistance > settings.deadzone
            let verticalActive = verticalDistance > settings.verticalDeadzone

            if horizontalActive || verticalActive {
                var xMovement: Float = 0.0
                var yMovement: Float = 0.0
                var zMovement: Float = 0.0

                // Handle horizontal X/Z movement
                if horizontalActive {
                    let normalizedHorizontal = normalize(SIMD2<Float>(horizontalVector.x, horizontalVector.z))
                    let clampedHorizontalDistance = min(horizontalDistance, settings.maxDistance)
                    let scaledHorizontal = normalizedHorizontal * (clampedHorizontalDistance / settings.maxDistance)

                    xMovement = scaledHorizontal.x * settings.scaleFactor
                    zMovement = scaledHorizontal.y * settings.scaleFactor
                }

                // Handle vertical Y movement
                if verticalActive {
                    let yDirection = thumbTip.y > joystickReferencePoint.y ? 1.0 : -1.0
                    let clampedVerticalDistance = min(verticalDistance, settings.maxDistance)
                    let scaledVerticalMagnitude = clampedVerticalDistance / settings.maxDistance

                    yMovement = Float(yDirection) * scaledVerticalMagnitude * settings.scaleFactor
                }

                finalVector = SIMD3<Float>(xMovement, yMovement, zMovement)
                magnitude = max(horizontalDistance / settings.maxDistance, verticalDistance / settings.maxDistance)
                active = true
            } else {
                finalVector = .zero
                magnitude = 0.0
                active = false
            }
        } else {
            // Original joystick mode: use thumb tip relative to joystick reference point for X/Z movement
            let vector = thumbTip - joystickReferencePoint
            let distance = length(vector)

            // Check if we're within the deadzone
            if distance < settings.deadzone {
                finalVector = .zero
                magnitude = 0.0
                active = false
            } else {
                // Normalize the vector and apply max distance
                let normalizedVector = normalize(vector)
                let clampedDistance = min(distance, settings.maxDistance)
                let scaledVector = normalizedVector * clampedDistance

                // Apply significant scaling to make movement more pronounced
                // Zero out Y component for traditional joystick behavior
                finalVector = SIMD3<Float>(
                    scaledVector.x * settings.scaleFactor,
                    0.0,  // No vertical movement in joystick mode
                    scaledVector.z * settings.scaleFactor
                )

                magnitude = clampedDistance / settings.maxDistance
                active = true
            }
        }

        // Debug output if enabled
        if settings.enableDiagnostics {
            let handName = isLeftHand ? "LEFT" : "RIGHT"
            print("🎮 DualThumbController Debug [\(handName)]:")
         
            print("  ---")
        }

        // Update the appropriate hand state
        if isLeftHand {
            self.leftDirection = finalVector
            self.leftMagnitude = magnitude
            self.leftIsActive = active
        } else {
            self.rightDirection = finalVector
            self.rightMagnitude = magnitude
            self.rightIsActive = active
        }
    }

    // Public method to manually set joystick values (for simulator virtual joystick input)
    public func setVirtualJoystickInput(
        leftDirection: SIMD3<Float>,
        leftMagnitude: Float,
        leftActive: Bool,
        rightDirection: SIMD3<Float>,
        rightMagnitude: Float,
        rightActive: Bool
    ) {
        self.leftDirection = leftDirection
        self.leftMagnitude = leftMagnitude
        self.leftIsActive = leftActive
        self.rightDirection = rightDirection
        self.rightMagnitude = rightMagnitude
        self.rightIsActive = rightActive
    }

    public func start() async throws {
        // Register the component and system
        ThumbControlledComponent.registerComponent()
        await ThumbControlledSystem.registerSystem()

#if os(visionOS)
        try await ARKitSessionManager.shared.start()
#endif
    }

    public func stop() {
#if os(visionOS)
        ARKitSessionManager.shared.stop()
#endif
    }
}

// MARK: - Thumb Controller Visualization

#if os(visionOS)
@MainActor
public class ThumbControllerVisualizer: ObservableObject {
    public static let shared = ThumbControllerVisualizer()

    // Right hand visualization (original)
    private var rightDeadzoneVisualizerEntity: Entity?
    private var rightJoystickVisualizerEntity: Entity?
    private var rightRedCylinder: ModelEntity?
    private var rightRedSphere: ModelEntity?
    private var rightGreenReferenceEntity: Entity?
    private var rightGreenSphere: ModelEntity?
    private var rightOffsetLineEntity: ModelEntity?

    // Left hand visualization (new)
    private var leftDeadzoneVisualizerEntity: Entity?
    private var leftJoystickVisualizerEntity: Entity?
    private var leftRedCylinder: ModelEntity?
    private var leftRedSphere: ModelEntity?
    private var leftGreenReferenceEntity: Entity?
    private var leftGreenSphere: ModelEntity?
    private var leftOffsetLineEntity: ModelEntity?

    private let settings = ThumbControllerSettings.shared

    public var isVisualizationEnabled: Bool {
        get { settings.isVisualizationEnabled }
        set {
            settings.isVisualizationEnabled = newValue
            updateVisualizationVisibility()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupVisualization()
        setupObservers()
    }

    private func setupVisualization() {
        setupHandVisualization(isLeftHand: false) // Right hand
        setupHandVisualization(isLeftHand: true)  // Left hand
    }

    private func setupHandVisualization(isLeftHand: Bool) {
        // Create the main container entities
        let deadzoneEntity = Entity()
        let joystickEntity = Entity()

        // Choose colors based on hand
        let joystickColor: UIColor = isLeftHand ? .orange : .red

        // Create colored cylinder for joystick stick
        let cylinderMesh = MeshResource.generateCylinder(height: settings.joystickCylinderHeight, radius: settings.joystickCylinderRadius)
        let joystickMaterial = SimpleMaterial(color: joystickColor, roughness: 0.2, isMetallic: false)
        let joystickMaterials: [any Material] = [joystickMaterial]
        let redCylinder = ModelEntity(mesh: cylinderMesh, materials: joystickMaterials)
        redCylinder.components.set(OpacityComponent(opacity: 0.8))

        // Position cylinder so it extends downward from the sphere (below the origin)
        redCylinder.position = SIMD3<Float>(0, -settings.joystickCylinderHeight / 2, 0)

        // Create colored sphere for joystick knob
        let redSphereMesh = MeshResource.generateSphere(radius: settings.joystickSphereRadius)
        let redSphere = ModelEntity(mesh: redSphereMesh, materials: joystickMaterials)
        redSphere.components.set(OpacityComponent(opacity: 0.9))

        // Position the sphere at the origin (at the thumb position)
        redSphere.position = SIMD3<Float>(0, 0, 0)

        // Create green transparent sphere for the joystick reference point (index finger tip)
        // This sphere shows the ACTUAL zone where thumb movements are calculated
        // Radius should match the maxDistance setting (0.15m = 15cm)
        let greenReferenceEntity = Entity()
        let greenSphereMesh = MeshResource.generateSphere(radius: settings.maxDistance)
        let greenMaterial = SimpleMaterial(color: .green, roughness: 0.3, isMetallic: false)
        let greenMaterials: [any Material] = [greenMaterial]
        let greenSphere = ModelEntity(mesh: greenSphereMesh, materials: greenMaterials)
        greenSphere.components.set(OpacityComponent(opacity: 0.3)) // Very transparent so it doesn't block vision
        greenReferenceEntity.addChild(greenSphere)

        // Create offset line entity (will be updated dynamically to show thumb offset vector)
        // Start with a minimal cylinder that will be resized and repositioned each frame
        let offsetLineMesh = MeshResource.generateBox(size: SIMD3<Float>(0.002, 0.002, 0.01))
        let lineColor: UIColor = isLeftHand ? .cyan : .yellow
        let lineMaterial = SimpleMaterial(color: lineColor, roughness: 0.2, isMetallic: false)
        let lineMaterials: [any Material] = [lineMaterial]
        let offsetLineEntity = ModelEntity(mesh: offsetLineMesh, materials: lineMaterials)
        offsetLineEntity.components.set(OpacityComponent(opacity: 0.8))

        // Assemble the visualization hierarchy
        joystickEntity.addChild(redCylinder)
        joystickEntity.addChild(redSphere)
        deadzoneEntity.addChild(joystickEntity)

        // Store references based on hand
        if isLeftHand {
            leftDeadzoneVisualizerEntity = deadzoneEntity
            leftJoystickVisualizerEntity = joystickEntity
            leftRedCylinder = redCylinder
            leftRedSphere = redSphere
            leftGreenReferenceEntity = greenReferenceEntity
            leftGreenSphere = greenSphere
            leftOffsetLineEntity = offsetLineEntity
        } else {
            rightDeadzoneVisualizerEntity = deadzoneEntity
            rightJoystickVisualizerEntity = joystickEntity
            rightRedCylinder = redCylinder
            rightRedSphere = redSphere
            rightGreenReferenceEntity = greenReferenceEntity
            rightGreenSphere = greenSphere
            rightOffsetLineEntity = offsetLineEntity
        }
    }

    private func setupObservers() {
        // Subscribe to hand tracking updates
        ARKitSessionManager.shared.handTrackingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self else { return }

                // Update right hand visualization
                if let rightHand = update.right {
                    let hand = HandAnchorConverter.convert(rightHand)
                    self.updateVisualizationPosition(with: hand, isLeftHand: false)
                }

                // Update left hand visualization
                if let leftHand = update.left {
                    let hand = HandAnchorConverter.convert(leftHand)
                    self.updateVisualizationPosition(with: hand, isLeftHand: true)
                }
            }
            .store(in: &cancellables)
    }

    private func updateVisualizationPosition(with hand: ThumbControllerHand, isLeftHand: Bool) {
        // Hide all thumb joystick visualization when in horizontal hand mode
        if settings.horizontalHandInputMode {
            let deadzoneEntity = isLeftHand ? leftDeadzoneVisualizerEntity : rightDeadzoneVisualizerEntity
            let greenReferenceEntity = isLeftHand ? leftGreenReferenceEntity : rightGreenReferenceEntity
            let offsetLineEntity = isLeftHand ? leftOffsetLineEntity : rightOffsetLineEntity

            deadzoneEntity?.isEnabled = false
            greenReferenceEntity?.isEnabled = false
            offsetLineEntity?.isEnabled = false
            return
        }

        guard let thumbTip = hand.thumbTip,
              let indexKnuckle = hand.indexKnuckle else { return }

        // Get the appropriate entities based on hand
        let deadzoneEntity = isLeftHand ? leftDeadzoneVisualizerEntity : rightDeadzoneVisualizerEntity
        let joystickEntity = isLeftHand ? leftJoystickVisualizerEntity : rightJoystickVisualizerEntity
        let greenReferenceEntity = isLeftHand ? leftGreenReferenceEntity : rightGreenReferenceEntity
        let offsetLineEntity = isLeftHand ? leftOffsetLineEntity : rightOffsetLineEntity

        guard let deadzoneEntity = deadzoneEntity,
              let joystickEntity = joystickEntity,
              let greenReferenceEntity = greenReferenceEntity,
              let offsetLineEntity = offsetLineEntity else { return }

        // Calculate the joystick reference point: knuckle position + 0.2 units closer to user (Z axis)
        let joystickReferencePoint = indexKnuckle + SIMD3<Float>(0, 0, 0.2)

        // ARKit hand positions are in world space - use them directly
        // Position the green reference sphere at the joystick reference point (knuckle + 0.2Z)
        greenReferenceEntity.setPosition(joystickReferencePoint, relativeTo: nil)

        // Position the joystick visualization at the thumb tip
        // The joystick (cylinder + sphere) should track the thumb position
        deadzoneEntity.setPosition(thumbTip, relativeTo: nil)

        // Calculate thumb movement relative to joystick reference point
        let thumbVector = thumbTip - joystickReferencePoint
        let distance = length(thumbVector)

        // Update the offset line to show the vector from reference point to thumb
        updateOffsetLine(offsetLineEntity, from: joystickReferencePoint, to: thumbTip)

        // Get the actual joystick output direction from DualThumbController
        let outputDirection = isLeftHand ? DualThumbController.shared.leftDirection : DualThumbController.shared.rightDirection
        let isActive = isLeftHand ? DualThumbController.shared.leftIsActive : DualThumbController.shared.rightIsActive

        if isActive && length(outputDirection) > 0.001 {
            // Show joystick visualization when there's actual output
            joystickEntity.isEnabled = true

            // Use the actual output direction to tilt the joystick
            // This shows the user exactly which direction they're sending input
            let outputMagnitude = length(outputDirection)
            let normalizedOutput = normalize(outputDirection)

            // Calculate tilt angle based on output magnitude (scaled down from the scaleFactor)
            let tiltAngle = min(outputMagnitude / 10.0, 1.0) * (Float.pi / 6) // Max 30-degree tilt

            // Create rotation to tilt joystick in the direction of actual output
            // Invert the rotations to match the actual movement direction
            let rotationX = simd_quatf(angle: normalizedOutput.z * tiltAngle, axis: SIMD3<Float>(1, 0, 0))
            let rotationZ = simd_quatf(angle: -normalizedOutput.x * tiltAngle, axis: SIMD3<Float>(0, 0, 1))

            // For Y movement (vertical), we can add a slight overall scale but keep X-Z tilt primary
            joystickEntity.orientation = simd_mul(rotationX, rotationZ)

        } else {
            // Hide joystick when not active or no output
            joystickEntity.isEnabled = false
        }
    }

    private func updateOffsetLine(_ lineEntity: ModelEntity, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        // Calculate the offset vector
        let offset = end - start
        let distance = length(offset)

        // Only show line if there's meaningful distance
        if distance < 0.001 {
            lineEntity.isEnabled = false
            return
        }

        lineEntity.isEnabled = true

        // Calculate midpoint for positioning
        let midpoint = (start + end) / 2.0

        // Create a box mesh scaled to represent the line
        let lineThickness: Float = 0.002
        let lineMesh = MeshResource.generateBox(size: SIMD3<Float>(lineThickness, lineThickness, distance))
        lineEntity.model?.mesh = lineMesh

        // Position at midpoint
        lineEntity.setPosition(midpoint, relativeTo: nil)

        // Calculate rotation to point from start to end
        let direction = normalize(offset)
        let defaultDirection = SIMD3<Float>(0, 0, 1) // Box's default orientation

        // Calculate rotation quaternion to align with the offset vector
        let rotationAxis = cross(defaultDirection, direction)
        let rotationAxisLength = length(rotationAxis)

        if rotationAxisLength > 0.001 {
            let angle = acos(dot(defaultDirection, direction))
            let normalizedAxis = rotationAxis / rotationAxisLength
            let rotation = simd_quatf(angle: angle, axis: normalizedAxis)
            lineEntity.setOrientation(rotation, relativeTo: nil)
        }
    }

    private func updateVisualizationVisibility() {
        rightDeadzoneVisualizerEntity?.isEnabled = isVisualizationEnabled
        rightJoystickVisualizerEntity?.isEnabled = isVisualizationEnabled
        rightGreenReferenceEntity?.isEnabled = isVisualizationEnabled
        rightOffsetLineEntity?.isEnabled = isVisualizationEnabled
        leftDeadzoneVisualizerEntity?.isEnabled = isVisualizationEnabled
        leftJoystickVisualizerEntity?.isEnabled = isVisualizationEnabled
        leftGreenReferenceEntity?.isEnabled = isVisualizationEnabled
        leftOffsetLineEntity?.isEnabled = isVisualizationEnabled
    }

    public func addToScene(_ scene: Entity) {
        if let rightDeadzoneEntity = rightDeadzoneVisualizerEntity {
            scene.addChild(rightDeadzoneEntity)
        }
        if let rightGreenEntity = rightGreenReferenceEntity {
            scene.addChild(rightGreenEntity)
        }
        if let rightLineEntity = rightOffsetLineEntity {
            scene.addChild(rightLineEntity)
        }
        if let leftDeadzoneEntity = leftDeadzoneVisualizerEntity {
            scene.addChild(leftDeadzoneEntity)
        }
        if let leftGreenEntity = leftGreenReferenceEntity {
            scene.addChild(leftGreenEntity)
        }
        if let leftLineEntity = leftOffsetLineEntity {
            scene.addChild(leftLineEntity)
        }
    }

    public func removeFromScene() {
        rightDeadzoneVisualizerEntity?.removeFromParent()
        rightGreenReferenceEntity?.removeFromParent()
        rightOffsetLineEntity?.removeFromParent()
        leftDeadzoneVisualizerEntity?.removeFromParent()
        leftGreenReferenceEntity?.removeFromParent()
        leftOffsetLineEntity?.removeFromParent()
    }

    public func startVisualization() {
        // Observers are already set up in init, just ensure visualization is enabled
        isVisualizationEnabled = true
    }

    public func stopVisualization() {
        cancellables.removeAll()
        removeFromScene()
    }
}
#endif
