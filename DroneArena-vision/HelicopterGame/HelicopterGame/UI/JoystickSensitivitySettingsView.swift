//
//  JoystickSensitivitySettingsView.swift
//  HelicopterGame
//
//  Created by Claude on 10/7/25.
//

import SwiftUI

struct JoystickSensitivitySettingsView: View {
    @Binding var isPresented: Bool
    @State private var settings = GameContext.shared.joystickSensitivity

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SteelLayout.xl) {
                    // Overall Sensitivity Section
                    SteelCard(hasHeaderStripe: true) {
                        VStack(spacing: SteelLayout.lg) {
                            Text("Overall Sensitivity")
                                .font(SteelTypography.headline)
                                .foregroundColor(Color.textPrimary)

                            // Left Joystick (Movement)
                            VStack(alignment: .leading, spacing: SteelLayout.sm) {
                                HStack {
                                    Text("Movement Joystick")
                                        .font(SteelTypography.body)
                                        .foregroundColor(Color.textPrimary)

                                    Spacer()

                                    StatusChip("gamecontroller.fill",
                                             label: String(format: "%.1fx", settings.leftJoystickSensitivity),
                                             isActive: true)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settings.leftJoystickSensitivity) },
                                        set: { settings.leftJoystickSensitivity = Float($0) }
                                    ),
                                    in: 0.1...3.0,
                                    step: 0.1
                                )
                                .accentColor(Color.coreBlue)

                                HStack {
                                    Text("0.1x")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                    Spacer()
                                    Text("3.0x")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                }
                            }

                            Divider()
                                .background(Color.gunmetal)

                            // Right Joystick (Throttle & Yaw)
                            VStack(alignment: .leading, spacing: SteelLayout.sm) {
                                HStack {
                                    Text("Throttle & Yaw Joystick")
                                        .font(SteelTypography.body)
                                        .foregroundColor(Color.textPrimary)

                                    Spacer()

                                    StatusChip("gamecontroller.fill",
                                             label: String(format: "%.1fx", settings.rightJoystickSensitivity),
                                             isActive: true)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settings.rightJoystickSensitivity) },
                                        set: { settings.rightJoystickSensitivity = Float($0) }
                                    ),
                                    in: 0.1...3.0,
                                    step: 0.1
                                )
                                .accentColor(Color.coreBlue)

                                HStack {
                                    Text("0.1x")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                    Spacer()
                                    Text("3.0x")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                }
                            }
                        }
                    }

                    // Individual Axis Settings
                    SteelCard(hasHeaderStripe: true) {
                        VStack(spacing: SteelLayout.lg) {
                            Text("Individual Axis Settings")
                                .font(SteelTypography.headline)
                                .foregroundColor(Color.textPrimary)

                            // Movement Axes
                            VStack(spacing: SteelLayout.md) {
                                // Pitch (Forward/Backward)
                                axisSensitivitySlider(
                                    title: "Forward/Backward",
                                    icon: "arrow.up.and.down",
                                    value: Binding(
                                        get: { Double(settings.pitchSensitivity) },
                                        set: { settings.pitchSensitivity = Float($0) }
                                    )
                                )

                                // Roll (Left/Right Strafe)
                                axisSensitivitySlider(
                                    title: "Left/Right Strafe",
                                    icon: "arrow.left.and.right",
                                    value: Binding(
                                        get: { Double(settings.rollSensitivity) },
                                        set: { settings.rollSensitivity = Float($0) }
                                    )
                                )

                                // Throttle (Up/Down)
                                axisSensitivitySlider(
                                    title: "Up/Down",
                                    icon: "arrow.up.and.down.circle",
                                    value: Binding(
                                        get: { Double(settings.throttleSensitivity) },
                                        set: { settings.throttleSensitivity = Float($0) }
                                    )
                                )

                                // Yaw (Left/Right Turn)
                                axisSensitivitySlider(
                                    title: "Turn Left/Right",
                                    icon: "arrow.clockwise",
                                    value: Binding(
                                        get: { Double(settings.yawSensitivity) },
                                        set: { settings.yawSensitivity = Float($0) }
                                    )
                                )
                            }
                        }
                    }

                    // Deadzone Settings
                   /* SteelCard(hasHeaderStripe: true) {
                        VStack(spacing: SteelLayout.lg) {
                            Text("Deadzone Settings")
                                .font(SteelTypography.headline)
                                .foregroundColor(Color.textPrimary)

                            Text("Deadzone prevents small unintended movements when the joystick isn't perfectly centered.")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.center)

                            VStack(spacing: SteelLayout.md) {
                                // Left Joystick Deadzone
                                deadzoneSlider(
                                    title: "Movement Joystick",
                                    icon: "gamecontroller.fill",
                                    value: Binding(
                                        get: { Double(settings.leftJoystickDeadzone) },
                                        set: { settings.leftJoystickDeadzone = Float($0) }
                                    )
                                )

                                // Right Joystick Deadzone
                                deadzoneSlider(
                                    title: "Throttle & Yaw",
                                    icon: "gamecontroller.fill",
                                    value: Binding(
                                        get: { Double(settings.rightJoystickDeadzone) },
                                        set: { settings.rightJoystickDeadzone = Float($0) }
                                    )
                                )
                            }
                        }
                    }*/

                    // Action Buttons
                    VStack(spacing: SteelLayout.md) {
                        ChromeButton("Reset to Defaults", icon: "arrow.counterclockwise") {
                            withAnimation(.easeInOut) {
                                settings.resetToDefaults()
                            }
                        }

                        GlassButton("Save & Close", icon: "checkmark") {
                            settings.saveSettings()
                            isPresented = false
                        }
                    }

                    Spacer(minLength: SteelLayout.xl)
                }
            }
            .padding(SteelLayout.xl)
            .background(Color.night)
            .navigationTitle("Joystick Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Don't save changes, just close
                        isPresented = false
                    }
                    .foregroundColor(Color.coreBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        settings.saveSettings()
                        isPresented = false
                    }
                    .foregroundColor(Color.coreBlue)
                }
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func axisSensitivitySlider(title: String, icon: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: SteelLayout.xs) {
            HStack {
                Image(systemName: icon)
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(SteelTypography.body)
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Text(String(format: "%.1fx", value.wrappedValue))
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.coreBlue)
                    .fontWeight(.semibold)
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(value: value, in: 0.1...3.0, step: 0.1)
                .accentColor(Color.coreBlue)

            HStack {
                Text("0.1x")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
                Spacer()
                Text("3.0x")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(.vertical, SteelLayout.xs)
    }

    @ViewBuilder
    private func deadzoneSlider(title: String, icon: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: SteelLayout.xs) {
            HStack {
                Image(systemName: icon)
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(SteelTypography.body)
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Text(String(format: "%.2f", value.wrappedValue))
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.warning)
                    .fontWeight(.semibold)
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(value: value, in: 0.0...0.3, step: 0.01)
                .accentColor(Color.warning)

            HStack {
                Text("0.0")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
                Spacer()
                Text("0.3")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(.vertical, SteelLayout.xs)
    }
}

#Preview {
    JoystickSensitivitySettingsView(isPresented: .constant(true))
}
