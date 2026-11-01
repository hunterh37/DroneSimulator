import SwiftUI

public struct ThumbControllerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = ThumbControllerSettings.shared

    public init() {}

    private func formatVector(_ vector: SIMD3<Float>) -> String {
        return String(format: "X:%.2f Y:%.2f Z:%.2f", vector.x, vector.y, vector.z)
    }

    public var body: some View {
        NavigationView {
            Form {
                // Core Control Parameters Section
                Section(header: Text("Control Parameters")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deadzone: \(String(format: "%.3f", settings.deadzone))")
                            .font(.caption)
                        Slider(value: $settings.deadzone, in: 0.001...0.1, step: 0.001) {
                            Text("Deadzone")
                        }
                        Text("Minimum thumb movement to register input")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vertical Deadzone: \(String(format: "%.3f", settings.verticalDeadzone))")
                            .font(.caption)
                        Slider(value: $settings.verticalDeadzone, in: 0.001...0.05, step: 0.001) {
                            Text("Vertical Deadzone")
                        }
                        Text("Minimum vertical thumb movement")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Distance: \(String(format: "%.3f", settings.maxDistance))")
                            .font(.caption)
                        Slider(value: $settings.maxDistance, in: 0.05...0.5, step: 0.01) {
                            Text("Max Distance")
                        }
                        Text("Maximum thumb movement range")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scale Factor: \(String(format: "%.1f", settings.scaleFactor))")
                            .font(.caption)
                        Slider(value: $settings.scaleFactor, in: 1.0...50.0, step: 0.5) {
                            Text("Scale Factor")
                        }
                        Text("Movement sensitivity multiplier")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Dual Thumb Control Speeds Section
                Section(header: Text("Flight Control Speeds")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Throttle Speed: \(String(format: "%.1f", settings.throttleSpeed))")
                            .font(.caption)
                        Slider(value: $settings.throttleSpeed, in: 0.1...10.0, step: 0.1) {
                            Text("Throttle Speed")
                        }
                        Text("Vertical movement speed (up/down)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yaw Speed: \(String(format: "%.1f", settings.yawSpeed))")
                            .font(.caption)
                        Slider(value: $settings.yawSpeed, in: 0.1...10.0, step: 0.1) {
                            Text("Yaw Speed")
                        }
                        Text("Left/right rotation speed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pitch Speed: \(String(format: "%.1f", settings.pitchSpeed))")
                            .font(.caption)
                        Slider(value: $settings.pitchSpeed, in: 0.1...10.0, step: 0.1) {
                            Text("Pitch Speed")
                        }
                        Text("Forward/backward movement speed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Roll Speed: \(String(format: "%.1f", settings.rollSpeed))")
                            .font(.caption)
                        Slider(value: $settings.rollSpeed, in: 0.1...10.0, step: 0.1) {
                            Text("Roll Speed")
                        }
                        Text("Strafe left/right speed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Visualization Settings Section
                Section(header: Text("Visualization")) {
                    Toggle("Enable Visualization", isOn: $settings.isVisualizationEnabled)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Y Offset: \(String(format: "%.3f", settings.visualizationYOffset))")
                            .font(.caption)
                        Slider(value: $settings.visualizationYOffset, in: -0.2...0.2, step: 0.01) {
                            Text("Visualization Y Offset")
                        }
                        Text("Vertical position adjustment for visualizer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deadzone Sphere Radius: \(String(format: "%.4f", settings.deadzoneSphereRadius))")
                            .font(.caption)
                        Slider(value: $settings.deadzoneSphereRadius, in: 0.001...0.02, step: 0.001) {
                            Text("Deadzone Sphere Radius")
                        }
                        Text("Size of the deadzone visualization sphere")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Joystick Height: \(String(format: "%.4f", settings.joystickCylinderHeight))")
                            .font(.caption)
                        Slider(value: $settings.joystickCylinderHeight, in: 0.005...0.1, step: 0.005) {
                            Text("Joystick Cylinder Height")
                        }
                        Text("Height of the joystick visualization")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Debug Section
                Section(header: Text("Debug & Diagnostics")) {
                    Toggle("Show Debug Info", isOn: $settings.showDebugInfo)
                    Toggle("Enable Diagnostics", isOn: $settings.enableDiagnostics)

                    if settings.showDebugInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Real-time Controller Data")
                                .font(.headline)

                            Text("Coordinate System: +X=Right, +Y=Up, +Z=Forward")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("Left Stick: Y=Throttle(Up/Down), X=Yaw(Rotate)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("Right Stick: Y=Pitch(Forward/Back), X=Roll(Strafe)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            // Right hand controller data
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Right Hand:")
                                    .font(.subheadline)
                                    .bold()
                                Text("Direction: \(formatVector(DualThumbController.shared.rightDirection))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Magnitude: \(String(format: "%.3f", DualThumbController.shared.rightMagnitude))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Pitch (Y): \(String(format: "%.3f", DualThumbController.shared.rightDirection.y))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Roll (X): \(String(format: "%.3f", DualThumbController.shared.rightDirection.x))")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                Text("Active: \(DualThumbController.shared.rightIsActive ? "✅" : "❌")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                            // Left hand controller data
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Left Hand:")
                                    .font(.subheadline)
                                    .bold()
                                Text("Direction: \(formatVector(DualThumbController.shared.leftDirection))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Magnitude: \(String(format: "%.3f", DualThumbController.shared.leftMagnitude))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("Throttle (Y): \(String(format: "%.3f", DualThumbController.shared.leftDirection.y))")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("Yaw (X): \(String(format: "%.3f", DualThumbController.shared.leftDirection.x))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Active: \(DualThumbController.shared.leftIsActive ? "✅" : "❌")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }

                // Actions Section
                Section {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)

                    Button("Save Settings") {
                        settings.saveSettings()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Thumb Controller Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        settings.saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            settings.saveSettings()
        }
    }
}

#Preview {
    ThumbControllerSettingsView()
}