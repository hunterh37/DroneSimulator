import Foundation
import simd

@Observable
public class ThumbControllerSettings: @unchecked Sendable {
    @MainActor public static let shared = ThumbControllerSettings()

    // Core control parameters
    public var deadzone: Float = 0.02
    public var verticalDeadzone: Float = 0.005
    public var maxDistance: Float = 0.15
    public var scaleFactor: Float = 10.0

    // Visualization parameters
    public var visualizationYOffset: Float = -0.06
    public var deadzoneSphereRadius: Float = 0.0065
    public var joystickCylinderHeight: Float = 0.026
    public var joystickCylinderRadius: Float = 0.0013
    public var joystickSphereRadius: Float = 0.0039
    public var isVisualizationEnabled: Bool = true

    // Dual thumb control speeds
    public var throttleSpeed: Float = 2.0
    public var yawSpeed: Float = 1.5
    public var pitchSpeed: Float = 2.0
    public var rollSpeed: Float = 2.0

    // Input mode selection
    public var horizontalHandInputMode: Bool = false

    // Horizontal hand mode sensitivity
    public var horizontalTiltSensitivity: Float = 2.0
    public var horizontalTiltDeadzone: Float = 0.1 // Radians (~5.7 degrees)

    // Debug and calibration
    public var showDebugInfo: Bool = false
    public var enableDiagnostics: Bool = false

    private init() {
        loadSettings()
    }

    // MARK: - Persistence

    private let userDefaults = UserDefaults.standard

    private func loadSettings() {
        deadzone = userDefaults.object(forKey: "ThumbController.deadzone") as? Float ?? 0.02
        verticalDeadzone = userDefaults.object(forKey: "ThumbController.verticalDeadzone") as? Float ?? 0.005
        maxDistance = userDefaults.object(forKey: "ThumbController.maxDistance") as? Float ?? 0.15
        scaleFactor = userDefaults.object(forKey: "ThumbController.scaleFactor") as? Float ?? 10.0

        visualizationYOffset = userDefaults.object(forKey: "ThumbController.visualizationYOffset") as? Float ?? -0.06
        deadzoneSphereRadius = userDefaults.object(forKey: "ThumbController.deadzoneSphereRadius") as? Float ?? 0.0065
        joystickCylinderHeight = userDefaults.object(forKey: "ThumbController.joystickCylinderHeight") as? Float ?? 0.026
        joystickCylinderRadius = userDefaults.object(forKey: "ThumbController.joystickCylinderRadius") as? Float ?? 0.0013
        joystickSphereRadius = userDefaults.object(forKey: "ThumbController.joystickSphereRadius") as? Float ?? 0.0039
        isVisualizationEnabled = userDefaults.object(forKey: "ThumbController.isVisualizationEnabled") as? Bool ?? true

        throttleSpeed = userDefaults.object(forKey: "ThumbController.throttleSpeed") as? Float ?? 2.0
        yawSpeed = userDefaults.object(forKey: "ThumbController.yawSpeed") as? Float ?? 1.5
        pitchSpeed = userDefaults.object(forKey: "ThumbController.pitchSpeed") as? Float ?? 2.0
        rollSpeed = userDefaults.object(forKey: "ThumbController.rollSpeed") as? Float ?? 2.0

        horizontalHandInputMode = userDefaults.object(forKey: "ThumbController.horizontalHandInputMode") as? Bool ?? false
        horizontalTiltSensitivity = userDefaults.object(forKey: "ThumbController.horizontalTiltSensitivity") as? Float ?? 2.0
        horizontalTiltDeadzone = userDefaults.object(forKey: "ThumbController.horizontalTiltDeadzone") as? Float ?? 0.1

        showDebugInfo = userDefaults.object(forKey: "ThumbController.showDebugInfo") as? Bool ?? false
        enableDiagnostics = userDefaults.object(forKey: "ThumbController.enableDiagnostics") as? Bool ?? false
    }

    public func saveSettings() {
        userDefaults.set(deadzone, forKey: "ThumbController.deadzone")
        userDefaults.set(verticalDeadzone, forKey: "ThumbController.verticalDeadzone")
        userDefaults.set(maxDistance, forKey: "ThumbController.maxDistance")
        userDefaults.set(scaleFactor, forKey: "ThumbController.scaleFactor")

        userDefaults.set(visualizationYOffset, forKey: "ThumbController.visualizationYOffset")
        userDefaults.set(deadzoneSphereRadius, forKey: "ThumbController.deadzoneSphereRadius")
        userDefaults.set(joystickCylinderHeight, forKey: "ThumbController.joystickCylinderHeight")
        userDefaults.set(joystickCylinderRadius, forKey: "ThumbController.joystickCylinderRadius")
        userDefaults.set(joystickSphereRadius, forKey: "ThumbController.joystickSphereRadius")
        userDefaults.set(isVisualizationEnabled, forKey: "ThumbController.isVisualizationEnabled")

        userDefaults.set(throttleSpeed, forKey: "ThumbController.throttleSpeed")
        userDefaults.set(yawSpeed, forKey: "ThumbController.yawSpeed")
        userDefaults.set(pitchSpeed, forKey: "ThumbController.pitchSpeed")
        userDefaults.set(rollSpeed, forKey: "ThumbController.rollSpeed")

        userDefaults.set(horizontalHandInputMode, forKey: "ThumbController.horizontalHandInputMode")
        userDefaults.set(horizontalTiltSensitivity, forKey: "ThumbController.horizontalTiltSensitivity")
        userDefaults.set(horizontalTiltDeadzone, forKey: "ThumbController.horizontalTiltDeadzone")

        userDefaults.set(showDebugInfo, forKey: "ThumbController.showDebugInfo")
        userDefaults.set(enableDiagnostics, forKey: "ThumbController.enableDiagnostics")
    }

    public func resetToDefaults() {
        deadzone = 0.02
        verticalDeadzone = 0.005
        maxDistance = 0.15
        scaleFactor = 10.0

        visualizationYOffset = -0.06
        deadzoneSphereRadius = 0.0065
        joystickCylinderHeight = 0.026
        joystickCylinderRadius = 0.0013
        joystickSphereRadius = 0.0039
        isVisualizationEnabled = true

        throttleSpeed = 2.0
        yawSpeed = 1.5
        pitchSpeed = 2.0
        rollSpeed = 2.0

        horizontalHandInputMode = false
        horizontalTiltSensitivity = 2.0
        horizontalTiltDeadzone = 0.1

        showDebugInfo = false
        enableDiagnostics = false

        saveSettings()
    }
}
