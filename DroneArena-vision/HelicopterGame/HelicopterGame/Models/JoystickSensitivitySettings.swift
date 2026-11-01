//
//  JoystickSensitivitySettings.swift
//  HelicopterGame
//
//  Created by Claude on 10/7/25.
//

import Foundation

@Observable
public class JoystickSensitivitySettings {
    // Sensitivity multipliers (0.1 to 3.0, default 1.0)
    public var leftJoystickSensitivity: Float = 1.0    // Movement joystick (pitch/roll)
    public var rightJoystickSensitivity: Float = 1.0   // Throttle/Yaw joystick

    // Individual axis sensitivities for fine-tuning
    public var pitchSensitivity: Float = 1.0      // Forward/backward movement
    public var rollSensitivity: Float = 1.0       // Left/right strafe movement
    public var throttleSensitivity: Float = 1.0   // Up/down movement
    public var yawSensitivity: Float = 1.0        // Left/right rotation

    // Deadzone settings (0.0 to 0.3, default 0.05)
    public var leftJoystickDeadzone: Float = 0.05
    public var rightJoystickDeadzone: Float = 0.05

    // Backing store for GameContext — fileprivate so this is the only file
    // that can reach `JoystickSensitivitySettings.shared` directly;
    // everyone else must go through GameContext.shared.joystickSensitivity.
    fileprivate static let shared = JoystickSensitivitySettings()

    private init() {
        loadSettings()
    }

    // MARK: - Persistence

    private let userDefaults = UserDefaults.standard

    private enum Keys {
        static let leftJoystickSensitivity = "joystick_left_sensitivity"
        static let rightJoystickSensitivity = "joystick_right_sensitivity"
        static let pitchSensitivity = "joystick_pitch_sensitivity"
        static let rollSensitivity = "joystick_roll_sensitivity"
        static let throttleSensitivity = "joystick_throttle_sensitivity"
        static let yawSensitivity = "joystick_yaw_sensitivity"
        static let leftJoystickDeadzone = "joystick_left_deadzone"
        static let rightJoystickDeadzone = "joystick_right_deadzone"
    }

    public func saveSettings() {
        userDefaults.set(leftJoystickSensitivity, forKey: Keys.leftJoystickSensitivity)
        userDefaults.set(rightJoystickSensitivity, forKey: Keys.rightJoystickSensitivity)
        userDefaults.set(pitchSensitivity, forKey: Keys.pitchSensitivity)
        userDefaults.set(rollSensitivity, forKey: Keys.rollSensitivity)
        userDefaults.set(throttleSensitivity, forKey: Keys.throttleSensitivity)
        userDefaults.set(yawSensitivity, forKey: Keys.yawSensitivity)
        userDefaults.set(leftJoystickDeadzone, forKey: Keys.leftJoystickDeadzone)
        userDefaults.set(rightJoystickDeadzone, forKey: Keys.rightJoystickDeadzone)

        gameLog("🎮 Joystick sensitivity settings saved")
    }

    private func loadSettings() {
        leftJoystickSensitivity = userDefaults.object(forKey: Keys.leftJoystickSensitivity) as? Float ?? 1.0
        rightJoystickSensitivity = userDefaults.object(forKey: Keys.rightJoystickSensitivity) as? Float ?? 1.0
        pitchSensitivity = userDefaults.object(forKey: Keys.pitchSensitivity) as? Float ?? 1.0
        rollSensitivity = userDefaults.object(forKey: Keys.rollSensitivity) as? Float ?? 1.0
        throttleSensitivity = userDefaults.object(forKey: Keys.throttleSensitivity) as? Float ?? 1.0
        yawSensitivity = userDefaults.object(forKey: Keys.yawSensitivity) as? Float ?? 1.0
        leftJoystickDeadzone = userDefaults.object(forKey: Keys.leftJoystickDeadzone) as? Float ?? 0.05
        rightJoystickDeadzone = userDefaults.object(forKey: Keys.rightJoystickDeadzone) as? Float ?? 0.05

        gameLog("🎮 Joystick sensitivity settings loaded")
        gameLog("   Left: \(leftJoystickSensitivity), Right: \(rightJoystickSensitivity)")
        gameLog("   Pitch: \(pitchSensitivity), Roll: \(rollSensitivity)")
        gameLog("   Throttle: \(throttleSensitivity), Yaw: \(yawSensitivity)")
        gameLog("   Deadzones - Left: \(leftJoystickDeadzone), Right: \(rightJoystickDeadzone)")
    }

    // MARK: - Utility Methods

    public func resetToDefaults() {
        leftJoystickSensitivity = 1.0
        rightJoystickSensitivity = 1.0
        pitchSensitivity = 1.0
        rollSensitivity = 1.0
        throttleSensitivity = 1.0
        yawSensitivity = 1.0
        leftJoystickDeadzone = 0.05
        rightJoystickDeadzone = 0.05
        saveSettings()
    }

    // Apply sensitivity and deadzone to joystick input
    public func applyLeftJoystickSensitivity(position: CGPoint) -> CGPoint {
        var adjustedX = position.x
        var adjustedY = position.y

        // Apply deadzone
        if abs(adjustedX) < CGFloat(leftJoystickDeadzone) {
            adjustedX = 0.0
        } else {
            // Remove deadzone and rescale to full range
            let deadzone = CGFloat(leftJoystickDeadzone)
            adjustedX = (adjustedX - (adjustedX > 0 ? deadzone : -deadzone)) / (1.0 - deadzone)
        }

        if abs(adjustedY) < CGFloat(leftJoystickDeadzone) {
            adjustedY = 0.0
        } else {
            let deadzone = CGFloat(leftJoystickDeadzone)
            adjustedY = (adjustedY - (adjustedY > 0 ? deadzone : -deadzone)) / (1.0 - deadzone)
        }

        // Apply sensitivity (X = Roll, Y = Pitch for left joystick)
        adjustedX *= CGFloat(rollSensitivity * leftJoystickSensitivity)
        adjustedY *= CGFloat(pitchSensitivity * leftJoystickSensitivity)

        // Clamp to [-1, 1] range
        adjustedX = max(-1.0, min(1.0, adjustedX))
        adjustedY = max(-1.0, min(1.0, adjustedY))

        return CGPoint(x: adjustedX, y: adjustedY)
    }

    public func applyRightJoystickSensitivity(position: CGPoint) -> CGPoint {
        var adjustedX = position.x
        var adjustedY = position.y

        // Apply deadzone
        if abs(adjustedX) < CGFloat(rightJoystickDeadzone) {
            adjustedX = 0.0
        } else {
            let deadzone = CGFloat(rightJoystickDeadzone)
            adjustedX = (adjustedX - (adjustedX > 0 ? deadzone : -deadzone)) / (1.0 - deadzone)
        }

        if abs(adjustedY) < CGFloat(rightJoystickDeadzone) {
            adjustedY = 0.0
        } else {
            let deadzone = CGFloat(rightJoystickDeadzone)
            adjustedY = (adjustedY - (adjustedY > 0 ? deadzone : -deadzone)) / (1.0 - deadzone)
        }

        // Apply sensitivity (X = Yaw, Y = Throttle for right joystick)
        adjustedX *= CGFloat(yawSensitivity * rightJoystickSensitivity)
        adjustedY *= CGFloat(throttleSensitivity * rightJoystickSensitivity)

        // Clamp to [-1, 1] range
        adjustedX = max(-1.0, min(1.0, adjustedX))
        adjustedY = max(-1.0, min(1.0, adjustedY))

        return CGPoint(x: adjustedX, y: adjustedY)
    }
}

extension GameContext {
    public var joystickSensitivity: JoystickSensitivitySettings { JoystickSensitivitySettings.shared }
}