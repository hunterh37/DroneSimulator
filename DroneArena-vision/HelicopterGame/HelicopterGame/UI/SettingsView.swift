//
//  SettingsView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var playerSettings: PlayerSettings
    @Binding var isPresented: Bool

    public init(playerSettings: PlayerSettings, isPresented: Binding<Bool>) {
        self.playerSettings = playerSettings
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    ControlSchemeSelector()
                        .listRowBackground(Color.clear)
                }

                Section("Flight Controls") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Control Sensitivity")
                        Slider(
                            value: $playerSettings.controlSensitivity,
                            in: 0.1...2.0,
                            step: 0.1
                        )
                        Text("Current: \(playerSettings.controlSensitivity, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Turning Sensitivity")
                        Slider(
                            value: $playerSettings.turningSensitivity,
                            in: 0.1...2.0,
                            step: 0.1
                        )
                        Text("Current: \(playerSettings.turningSensitivity, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Comfort Options") {
                    Toggle("Comfort Mode", isOn: $playerSettings.comfortMode)
                        .help("Reduces motion intensity for sensitive users")

                    Toggle("Snap Turning", isOn: $playerSettings.snapTurning)
                        .help("Turn in discrete increments instead of smooth rotation")

                    Toggle("Reduced Motion", isOn: $playerSettings.reducedMotion)
                        .help("Minimizes unnecessary animations and effects")
                }

                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $playerSettings.hapticFeedback)
                        .help("Vibration feedback for interactions")
                }

                #if os(visionOS)
                Section("Debug") {
                    SceneMeshDebugToggle()
                    PinchVisualsToggle()
                }
                #endif

                #if DEBUG
                Section("Debug Controls") {
                    Button("Spawn Enemy Drone") {
                        spawnTestEnemyDrone()
                    }
                    .foregroundColor(.red)
                    .help("Manually spawn an enemy drone for testing")
                }
                #endif

                Section("Performance Info") {
                    HStack {
                        Text("Motion Damping")
                        Spacer()
                        Text("\(playerSettings.motionDamping, specifier: "%.1f")")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Acceleration Limit")
                        Spacer()
                        Text("\(playerSettings.accelerationLimit, specifier: "%.1f")")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    #if DEBUG
    private func spawnTestEnemyDrone() {
        // Post notification to trigger enemy drone spawning
        NotificationCenter.default.post(
            name: .spawnTestEnemyDrone,
            object: nil,
            userInfo: nil
        )
        gameLog("🎯 [SettingsView] Requesting test enemy drone spawn")
    }
    #endif
}

// MARK: - Notification Names
extension Notification.Name {
    static let spawnTestEnemyDrone = Notification.Name("spawnTestEnemyDrone")
}

#Preview {
    SettingsView(
        playerSettings: PlayerSettings(),
        isPresented: .constant(true)
    )
}