//
//  InputRouter.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import Foundation
import SwiftUI
import Combine
import simd
#if os(visionOS)
import DicyaninThumbController
#endif

@MainActor
public class InputRouter: ObservableObject {
    @Published public private(set) var currentIntent: ControlIntent = .move(.zero, yaw: 0)
    @Published public private(set) var currentClawIntent: ClawIntent?
    @Published public var gazeInteractionEnabled: Bool = true

    // Simulator controls
    public var simulatorControlIntent: ControlIntent?

#if os(visionOS)
    private let dualThumbController = DualThumbController.shared
#endif
    private var isInteracting: Bool = false
    private var lastThumbDirection: SIMD3<Float> = .zero
    private var leftPinchPressed: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var handTrackingStarted = false

    // Current thumb controller state (visionOS) / virtual joystick state (iOS)
    private var leftHandActive: Bool = false
    private var rightHandActive: Bool = false
    private var leftDirection: SIMD3<Float> = .zero
    private var rightDirection: SIMD3<Float> = .zero
    private var leftMagnitude: Float = 0.0
    private var rightMagnitude: Float = 0.0

    // Virtual joystick properties (iOS and visionOS simulator)
    @Published public var leftJoystickPosition: CGPoint = .zero
    @Published public var rightJoystickPosition: CGPoint = .zero
    @Published public var isLeftJoystickActive: Bool = false
    @Published public var isRightJoystickActive: Bool = false

    public init() {
#if os(visionOS)
        setupThumbController()
        setupThumbControllerObservers()
#endif
        // Setup virtual joysticks for both iOS and visionOS (for simulator support)
        setupVirtualJoysticks()
    }

#if os(visionOS)
    private func setupThumbController() {
        // Enable vertical thumb input for full 3D movement
        dualThumbController.useVerticalThumbInput = true
    }

    private func setupThumbControllerObservers() {
        // Observe left hand input
        dualThumbController.$leftDirection
            .sink { [weak self] direction in
                self?.leftDirection = direction
                gameLog("🤚 Left direction: \(direction)")
            }
            .store(in: &cancellables)

        dualThumbController.$leftMagnitude
            .sink { [weak self] magnitude in
                self?.leftMagnitude = magnitude
                gameLog("🤚 Left magnitude: \(magnitude)")
            }
            .store(in: &cancellables)

        dualThumbController.$leftIsActive
            .sink { [weak self] isActive in
                self?.leftHandActive = isActive
                gameLog("🤚 Left hand active: \(isActive)")
            }
            .store(in: &cancellables)

        // Observe right hand input
        dualThumbController.$rightDirection
            .sink { [weak self] direction in
                self?.rightDirection = direction
                gameLog("🤚 Right direction: \(direction)")
            }
            .store(in: &cancellables)

        dualThumbController.$rightMagnitude
            .sink { [weak self] magnitude in
                self?.rightMagnitude = magnitude
                gameLog("🤚 Right magnitude: \(magnitude)")
            }
            .store(in: &cancellables)

        dualThumbController.$rightIsActive
            .sink { [weak self] isActive in
                self?.rightHandActive = isActive
                gameLog("🤚 Right hand active: \(isActive)")
            }
            .store(in: &cancellables)
    }
#endif

    // Virtual joystick setup (iOS and visionOS simulator)
    private func setupVirtualJoysticks() {
        // Set up observers for virtual joystick positions
        $leftJoystickPosition
            .sink { [weak self] position in
                self?.updateLeftJoystickInput(position: position)
            }
            .store(in: &cancellables)

        $rightJoystickPosition
            .sink { [weak self] position in
                self?.updateRightJoystickInput(position: position)
            }
            .store(in: &cancellables)
    }

    private func updateLeftJoystickInput(position: CGPoint) {
        // Only update if joystick is actually active (not just from observer firing)
        if !isLeftJoystickActive {
            leftDirection = .zero
            leftMagnitude = 0.0
            leftHandActive = false
            return
        }

        // Convert CGPoint to SIMD3<Float> for movement
        // Normalize position to -1.0 to 1.0 range and apply movement scaling
        let normalizedX = Float(max(-1.0, min(1.0, position.x)))
        let normalizedY = Float(max(-1.0, min(1.0, position.y)))

        // X: left/right, Y: forward/back (inverted), Z: up/down (will be controlled separately)
        leftDirection = SIMD3<Float>(normalizedX, -normalizedY, 0)
        leftMagnitude = sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
        leftHandActive = leftMagnitude > 0.05 // Lower threshold for better responsiveness

        gameLog("🕹️ Left joystick: pos(\(position.x), \(position.y)) -> dir(\(leftDirection.x), \(leftDirection.y)) mag(\(leftMagnitude))")
    }

    private func updateRightJoystickInput(position: CGPoint) {
        // Only update if joystick is actually active (not just from observer firing)
        if !isRightJoystickActive {
            rightDirection = .zero
            rightMagnitude = 0.0
            rightHandActive = false
            return
        }

        // Right joystick controls yaw rotation (X component) and vertical movement (Y component)
        let normalizedX = Float(max(-1.0, min(1.0, position.x)))
        let normalizedY = Float(max(-1.0, min(1.0, position.y)))

        rightDirection = SIMD3<Float>(normalizedX, normalizedY, 0)
        rightMagnitude = sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
        rightHandActive = rightMagnitude > 0.05

        gameLog("🕹️ Right joystick: pos(\(position.x), \(position.y)) -> dir(\(rightDirection.x), \(rightDirection.y)) mag(\(rightMagnitude))")
    }

    // Virtual joystick methods (iOS and visionOS simulator)
    public func setLeftJoystick(position: CGPoint, active: Bool) {
        leftJoystickPosition = position
        isLeftJoystickActive = active
        if !active {
            // Reset when not active
            leftDirection = SIMD3<Float>.zero
            leftMagnitude = 0.0
            leftHandActive = false
        }
    }

    public func setRightJoystick(position: CGPoint, active: Bool) {
        rightJoystickPosition = position
        isRightJoystickActive = active
        if !active {
            // Reset when not active
            rightDirection = SIMD3<Float>.zero
            rightMagnitude = 0.0
            rightHandActive = false
        }
    }

#if os(iOS)
    // iOS-specific method to update vertical movement (for altitude control)
    public func setVerticalInput(_ value: Float) {
        // Update the Z component of left direction for vertical movement
        leftDirection.z = max(-1.0, min(1.0, value))
        gameLog("📱 Vertical input: \(value)")
    }

    // iOS-specific method for claw/grabber control
    public func setClawInput(grab: Bool) {
        if grab {
            currentClawIntent = .extendOrGrab
        } else {
            currentClawIntent = .release
        }
        gameLog("🦾 Claw input: \(grab ? "grab" : "release")")
    }

    // iOS-specific method for boost control
    public func setBoostInput(active: Bool) {
        if active {
            currentIntent = .boost
        }
        gameLog("🚀 Boost input: \(active)")
    }
#endif

    public func startInputSystem() async throws {
#if os(visionOS)
        // Always registered so schemes can switch live. The hand-tracking gate
        // (ControlSchemeConfig.syncHandTrackingGate) decides who writes input.
        ControlSchemeConfig.syncHandTrackingGate()
        // ARKitSessionManager cannot rerun a stopped session; start once, keep it alive across game exits.
        if !handTrackingStarted {
            handTrackingStarted = true
            do { try await dualThumbController.start() } catch { handTrackingStarted = false; throw error }
        }
        gameLog("🎮 DualThumbController started - observers should be active")
#elseif os(iOS)
        gameLog("🎮 Virtual joysticks ready for iOS input")
#endif
    }

    public func stopInputSystem() {
        // Hand tracking session intentionally left running (see startInputSystem).
        resetAllInput()
        // Reset joystick states (both iOS and visionOS simulator)
        leftJoystickPosition = .zero
        rightJoystickPosition = .zero
        isLeftJoystickActive = false
        isRightJoystickActive = false
    }

    public func processInput() {

#if os(visionOS)
        // On visionOS, sync virtual joystick values to DualThumbController (for simulator support)
        // This allows virtual joysticks to work by feeding data to DualThumbController
        // which is what DualThumbControlledSystem reads from
        // IMPORTANT: Always sync, even when inactive, to ensure zero values are sent when released
        // EXCEPTION: the joystick stand owns DualThumbController; don't clobber it.
        if !ControlSchemeConfig.useWorldJoystickRig && !DemoDirector.ownsInput {
        dualThumbController.setVirtualJoystickInput(
            leftDirection: leftDirection,
            leftMagnitude: leftMagnitude,
            leftActive: leftHandActive,
            rightDirection: rightDirection,
            rightMagnitude: rightMagnitude,
            rightActive: rightHandActive
        )
        }
#endif

        // Check for joystick input first (works everywhere - simulator or device)
        if let simulatorIntent = simulatorControlIntent {
            currentIntent = simulatorIntent

        } else {
            // Platform-specific input handling
#if os(visionOS)
            // Use dual hand tracking: left hand for movement, right hand for yaw
            // Use observed values from the Combine observers
            let leftHandActiveWithThreshold = leftHandActive && leftMagnitude > 0.01
            let rightHandActiveWithThreshold = rightHandActive && rightMagnitude > 0.01

            var movementVector: SIMD3<Float> = .zero
            var yawInput: Float = 0.0

            // Left hand controls yaw rotation and height
            // In horizontal hand mode: X = yaw, Y = height, Z = unused
            if leftHandActiveWithThreshold {
                yawInput = leftDirection.x * 0.05 // Use X component for yaw rotation
                movementVector.y = leftDirection.y * 0.1 // Use Y component for height/throttle
                gameLog("🎮 Processing left hand - yaw: \(leftDirection.x), height: \(leftDirection.y)")
            }

            // Right hand controls strafe and forward/backward movement
            // In horizontal hand mode: X = strafe, Y = unused, Z = forward/backward
            if rightHandActiveWithThreshold {
                movementVector.x = rightDirection.x * 0.1 // Use X component for strafe (left/right)
                movementVector.z = rightDirection.z * 0.1 // Use Z component for forward/backward
                gameLog("🎮 Processing right hand - strafe: \(rightDirection.x), forward/back: \(rightDirection.z)")
            }

            // Create movement intent with combined hand input
            if leftHandActiveWithThreshold || rightHandActiveWithThreshold {
                currentIntent = .move(movementVector, yaw: yawInput)
                lastThumbDirection = movementVector
                gameLog("🎮 visionOS input applied: movement=\(movementVector), yaw=\(yawInput)")
            } else {
                // No input from either hand
                currentIntent = .move(.zero, yaw: 0)
            }
#elseif os(iOS)
            // iOS virtual joystick handling
            let leftJoystickActiveWithThreshold = leftHandActive && leftMagnitude > 0.05
            let rightJoystickActiveWithThreshold = rightHandActive && rightMagnitude > 0.05

            var movementVector: SIMD3<Float> = .zero
            var yawInput: Float = 0.0

            // Left joystick controls movement (X, Y, Z)
            if leftJoystickActiveWithThreshold {
                // Apply more aggressive scaling for iOS virtual joysticks
                movementVector = leftDirection * 0.15 // Slightly higher scale for virtual joysticks
                gameLog("🎮 Processing left joystick movement: \(leftDirection)")
            }

            // Right joystick controls yaw rotation and vertical movement
            if rightJoystickActiveWithThreshold {
                yawInput = rightDirection.x * 0.08 // Yaw from X component
                // Add vertical movement from right joystick Y component to movementVector Z
                movementVector.z = rightDirection.y * 0.15
                gameLog("🎮 Processing right joystick yaw: \(rightDirection.x), vertical: \(rightDirection.y)")
            }

            // Create movement intent with virtual joystick input
            if leftJoystickActiveWithThreshold || rightJoystickActiveWithThreshold {
                currentIntent = .move(movementVector, yaw: yawInput)
                lastThumbDirection = movementVector
                gameLog("🎮 iOS virtual joystick input applied: movement=\(movementVector), yaw=\(yawInput)")
            } else {
                // No input from joysticks
                currentIntent = .move(.zero, yaw: 0)
            }
#endif
        }

        // Clear claw intent after processing
        currentClawIntent = nil
    }

    // Handle gaze-based interactions (future enhancement)
    public func handleGazeInteraction(at position: SIMD3<Float>) {
        guard gazeInteractionEnabled else { return }
        // Implement gaze interaction logic
    }

    // Handle pinch gestures for interaction
    public func handlePinchGesture() {
        if !isInteracting {
            currentIntent = .interact
            isInteracting = true
        }
    }

    public func handlePinchEnd() {
        isInteracting = false
    }

    // Handle left-hand pinch for claw control
    public func handleLeftPinchDown() {
        if !leftPinchPressed {
            leftPinchPressed = true
            currentClawIntent = .extendOrGrab
        }
    }

    public func handleLeftPinchUp() {
        if leftPinchPressed {
            leftPinchPressed = false
            currentClawIntent = .release
        }
    }

    // Handle boost input (could be mapped to a gesture or button)
    public func handleBoostInput() {
        currentIntent = .boost
    }

    // Handle map toggle
    public func handleMapToggle() {
        currentIntent = .toggleMap
    }

    // Get current movement vector for display purposes
    public var currentMovementVector: SIMD3<Float> {
        if case .move(let movement, _) = currentIntent {
            return movement
        }
        return .zero
    }

    // Get current yaw input
    public var currentYawInput: Float {
        if case .move(_, let yaw) = currentIntent {
            return yaw
        }
        return 0
    }

    // Check if player is actively providing input
    public var isActivelyControlling: Bool {
        return leftHandActive || rightHandActive
    }

    // Convenience properties for virtual joystick feedback (iOS and visionOS simulator)
    public var leftJoystickMagnitude: Float {
        return leftMagnitude
    }

    public var rightJoystickMagnitude: Float {
        return rightMagnitude
    }

    public var isLeftJoystickActiveStatus: Bool {
        return leftHandActive
    }

    public var isRightJoystickActiveStatus: Bool {
        return rightHandActive
    }

    // Get the current movement direction for UI display
    public var currentMovementDirection: SIMD3<Float> {
        return leftDirection
    }

    // Get the current yaw direction for UI display
    public var currentYawDirection: Float {
        return rightDirection.x
    }

    // Get the current vertical direction for UI display
    public var currentVerticalDirection: Float {
        return rightDirection.y
    }

    // Reset all virtual joystick input
    public func resetAllInput() {
        setLeftJoystick(position: .zero, active: false)
        setRightJoystick(position: .zero, active: false)
        currentClawIntent = nil
        simulatorControlIntent = nil
        gameLog("📱 All input reset")
    }
}