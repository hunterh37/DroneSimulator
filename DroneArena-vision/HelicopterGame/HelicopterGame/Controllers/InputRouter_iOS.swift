//
//  InputRouter_iOS.swift
//  HelicopterGame
//
//  Created by Claude on 10/3/25.
//  iOS-specific InputRouter implementation with virtual joysticks
//

import Foundation
import SwiftUI
import Combine
import simd

@MainActor
public class InputRouter: ObservableObject {
    @Published public private(set) var currentIntent: ControlIntent = .move(.zero, yaw: 0)
    @Published public private(set) var currentClawIntent: ClawIntent?
    @Published public var gazeInteractionEnabled: Bool = true

    // Simulator controls (for testing)
    public var simulatorControlIntent: ControlIntent?

    // iOS Virtual Joystick State
    @Published public var leftJoystickPosition: CGPoint = .zero
    @Published public var rightJoystickPosition: CGPoint = .zero
    @Published public var isLeftJoystickActive: Bool = false
    @Published public var isRightJoystickActive: Bool = false

    // Internal state tracking
    private var isInteracting: Bool = false
    private var lastMovementDirection: SIMD3<Float> = .zero
    private var cancellables = Set<AnyCancellable>()

    // Current joystick state
    private var leftDirection: SIMD3<Float> = .zero
    private var rightDirection: SIMD3<Float> = .zero
    private var leftMagnitude: Float = 0.0
    private var rightMagnitude: Float = 0.0
    private var leftHandActive: Bool = false
    private var rightHandActive: Bool = false

    public init() {
        setupVirtualJoysticks()
    }

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
        // Convert CGPoint to SIMD3<Float> for movement
        // Normalize position to -1.0 to 1.0 range and apply movement scaling
        let normalizedX = Float(max(-1.0, min(1.0, position.x)))
        let normalizedY = Float(max(-1.0, min(1.0, position.y)))

        // Joystick Y is already up-positive (VirtualJoystick inverts screen Y)
        leftDirection = SIMD3<Float>(normalizedX, normalizedY, 0)
        leftMagnitude = sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
        leftHandActive = leftMagnitude > 0.05 // Lower threshold for better responsiveness

        gameLog("🕹️ Left joystick: pos(\(position.x), \(position.y)) -> dir(\(leftDirection.x), \(leftDirection.y)) mag(\(leftMagnitude))")
    }

    private func updateRightJoystickInput(position: CGPoint) {
        // Right joystick controls yaw rotation (X component) and vertical movement (Y component)
        let normalizedX = Float(max(-1.0, min(1.0, position.x)))
        let normalizedY = Float(max(-1.0, min(1.0, position.y)))

        rightDirection = SIMD3<Float>(normalizedX, normalizedY, 0)
        rightMagnitude = sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
        rightHandActive = rightMagnitude > 0.05

        gameLog("🕹️ Right joystick: pos(\(position.x), \(position.y)) -> dir(\(rightDirection.x), \(rightDirection.y)) mag(\(rightMagnitude))")
    }

    // iOS-specific methods for updating joystick state
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

    public func startInputSystem() async throws {
        gameLog("🎮 iOS Virtual joysticks ready for input")
    }

    public func stopInputSystem() {
        // Reset joystick states
        leftJoystickPosition = .zero
        rightJoystickPosition = .zero
        isLeftJoystickActive = false
        isRightJoystickActive = false
        leftDirection = .zero
        rightDirection = .zero
        leftMagnitude = 0.0
        rightMagnitude = 0.0
        leftHandActive = false
        rightHandActive = false
    }

    public func processInput() {
        // Check for joystick input first (works everywhere - simulator or device)
        if let simulatorIntent = simulatorControlIntent {
            currentIntent = simulatorIntent

            // AGGRESSIVE DEBUG: Always log when we process joystick input
            gameLog("🎮 InputRouter processing joystick input: \(simulatorIntent.description)")
        } else {
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
                lastMovementDirection = movementVector
                gameLog("🎮 iOS virtual joystick input applied: movement=\(movementVector), yaw=\(yawInput)")
            } else {
                // No input from joysticks
                currentIntent = .move(.zero, yaw: 0)
            }
        }

        // Clear claw intent after processing
        currentClawIntent = nil
    }

    // Handle gaze-based interactions (future enhancement)
    public func handleGazeInteraction(at position: SIMD3<Float>) {
        guard gazeInteractionEnabled else { return }
        // iOS: Could implement tap-to-target functionality
    }

    // Handle pinch gestures for interaction (iOS: touch gestures)
    public func handlePinchGesture() {
        if !isInteracting {
            currentIntent = .interact
            isInteracting = true
        }
    }

    public func handlePinchEnd() {
        isInteracting = false
    }

    // Handle left-hand pinch for claw control (iOS: button press)
    public func handleLeftPinchDown() {
        setClawInput(grab: true)
    }

    public func handleLeftPinchUp() {
        setClawInput(grab: false)
    }

    // Handle boost input
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

    // iOS-specific convenience properties for UI feedback
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
        gameLog("📱 All iOS input reset")
    }
}
