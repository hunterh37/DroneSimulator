//
//  DroneGameOverlayView.swift
//  HelicopterGame
//
//  Created by Claude on 10/2/25.
//

import SwiftUI

struct DroneGameOverlayView: View {
    let gameUIModel: GameUIModel
    @State private var showingModeSelector = false
    @State private var animateHUD = false

    var body: some View {
        VStack(spacing: 0) {
            // Top HUD
            topGameHUD
                .padding(.horizontal, DroneLayout.lg)

            Spacer()

            // Mode-specific overlays
            modeSpecificOverlay
                .padding(.horizontal, DroneLayout.lg)

            Spacer(minLength: 100) // Space for joystick controls
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animateHUD = true
            }
        }
    }

    // MARK: - Top Game HUD
    private var topGameHUD: some View {
        HStack {
            // Mode indicator
            modeIndicator

            Spacer()

            // Mission info
            if gameUIModel.modeManager.currentMode != .build {
                missionInfo
            }

            Spacer()

            // Quick actions
            quickActions
        }
        .opacity(animateHUD ? 1.0 : 0.0)
        .offset(y: animateHUD ? 0 : -20)
        .animation(.easeInOut(duration: 0.6), value: animateHUD)
    }

    // MARK: - Mode Indicator
    private var modeIndicator: some View {
        DroneCard(variant: .glass) {
            HStack(spacing: DroneLayout.sm) {
                Image(systemName: currentModeIcon)
                    .foregroundColor(currentModeColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentModeTitle)
                        .font(DroneTypography.button)
                        .foregroundColor(.droneTextPrimary)

                    if let subtitle = currentModeSubtitle {
                        Text(subtitle)
                            .font(DroneTypography.caption)
                            .foregroundColor(.droneTextSecondary)
                    }
                }
            }
        }
        .onTapGesture {
            showingModeSelector = true
        }
    }

    // MARK: - Mission Info
    private var missionInfo: some View {
        DroneCard(variant: .glass) {
            HStack(spacing: DroneLayout.md) {
                // Mission progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: DroneLayout.xs) {
                        Image(systemName: "target")
                            .foregroundColor(.droneAccent)
                            .font(.caption)

                        Text("Objective")
                            .font(DroneTypography.caption)
                            .foregroundColor(.droneTextSecondary)
                    }

                    Text(missionObjective)
                        .font(DroneTypography.button)
                        .foregroundColor(.droneTextPrimary)
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: DroneLayout.xs) {
                        Text("Score")
                            .font(DroneTypography.caption)
                            .foregroundColor(.droneTextSecondary)

                        Image(systemName: "star.fill")
                            .foregroundColor(.droneAccent)
                            .font(.caption)
                    }

                    Text("\(currentScore)")
                        .font(DroneTypography.button)
                        .foregroundColor(.droneTextPrimary)
                }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: DroneLayout.sm) {
            DroneButton(
                "",
                icon: "pause.circle.fill",
                style: .ghost,
                size: .small
            ) {
                // TODO: Pause game
            }

            DroneButton(
                "",
                icon: "house.circle.fill",
                style: .ghost,
                size: .small
            ) {
                gameUIModel.modeManager.returnToMenu()
            }
        }
    }

    // MARK: - Mode Specific Overlay
    @ViewBuilder
    private var modeSpecificOverlay: some View {
        switch gameUIModel.modeManager.currentMode {
        case .build:
            buildModeOverlay

        case .playSandbox:
            sandboxModeOverlay

        case .playDelivery:
            deliveryModeOverlay

        case .playMultiplayer:
            multiplayerModeOverlay

        default:
            EmptyView()
        }
    }

    // MARK: - Build Mode Overlay
    private var buildModeOverlay: some View {
        VStack(spacing: DroneLayout.md) {
            // Enhanced build toolbar with all functionality restored
            DroneCard(variant: .secondary) {
                EnhancedBuildToolbarView(
                    buildModeManager: gameUIModel.buildModeManager,
                    placementManager: gameUIModel.placementManager,
                    onConfirm: {
                        gameUIModel.placementManager.confirmPlacement()
                    },
                    onCancel: {
                        gameUIModel.placementManager.cancelPlacement()
                    },
                    onRotate: {
                        gameUIModel.placementManager.rotateGhost()
                    },
                    onDelete: {
                        gameUIModel.buildModeManager.clearLayout()
                    }
                )
            }
        }
        .opacity(animateHUD ? 1.0 : 0.0)
        .offset(y: animateHUD ? 0 : 20)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateHUD)
    }

    // MARK: - Sandbox Mode Overlay
    private var sandboxModeOverlay: some View {
        VStack(spacing: DroneLayout.md) {
            DroneCard(variant: .glass) {
                HStack {
                    VStack(alignment: .leading, spacing: DroneLayout.xs) {
                        Text("Free Flight")
                            .font(DroneTypography.headline)
                            .foregroundColor(.droneTextPrimary)

                        Text("Practice your piloting skills")
                            .font(DroneTypography.body)
                            .foregroundColor(.droneTextSecondary)
                    }

                    Spacer()

                    DroneButton(
                        "Spawn Crate",
                        icon: "cube.box.fill",
                        style: .secondary,
                        size: .small
                    ) {
                        // Spawn a crate using the sandbox manager
                        if let sandboxManager = gameUIModel.modeManager.sandboxManager {
                            let spec = PackageSpec.medium
                            let type = PackageType.generic
                            _ = sandboxManager.spawnCrate(spec: spec, type: type)
                        }
                    }
                }
            }
        }
        .opacity(animateHUD ? 1.0 : 0.0)
        .offset(y: animateHUD ? 0 : 20)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateHUD)
    }

    // MARK: - Delivery Mode Overlay
    private var deliveryModeOverlay: some View {
        VStack(spacing: DroneLayout.md) {
            DroneCard(variant: .primary) {
                VStack(spacing: DroneLayout.md) {
                    HStack {
                        Text("Active Mission")
                            .font(DroneTypography.headline)
                            .foregroundColor(.droneTextPrimary)

                        Spacer()

                        HStack(spacing: DroneLayout.xs) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.droneWarning)
                                .font(.caption)

                            Text("2:45")
                                .font(DroneTypography.button)
                                .foregroundColor(.droneWarning)
                        }
                    }

                    HStack(spacing: DroneLayout.lg) {
                        MissionStat(
                            icon: "shippingbox.fill",
                            value: "2/5",
                            label: "Delivered",
                            color: .droneSuccess
                        )

                        MissionStat(
                            icon: "target",
                            value: "1",
                            label: "Remaining",
                            color: .droneInfo
                        )

                        MissionStat(
                            icon: "battery.75percent",
                            value: "68%",
                            label: "Power",
                            color: .droneAccent
                        )
                    }
                }
            }
        }
        .opacity(animateHUD ? 1.0 : 0.0)
        .offset(y: animateHUD ? 0 : 20)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateHUD)
    }

    // MARK: - Multiplayer Mode Overlay
    private var multiplayerModeOverlay: some View {
        VStack(spacing: DroneLayout.md) {
            DroneCard(variant: .glass) {
                HStack {
                    VStack(alignment: .leading, spacing: DroneLayout.xs) {
                        Text("Connected Players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("0")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    Image(systemName: "person.2.fill")
                        .foregroundColor(.droneAccent)
                        .font(.title2)
                }
            }

            DroneCard(variant: .glass) {
                HStack {
                    VStack(alignment: .leading, spacing: DroneLayout.xs) {
                        Text("Network Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Online")
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    Image(systemName: "wifi")
                        .foregroundColor(.droneSuccess)
                        .font(.title2)
                }
            }
        }
        .opacity(animateHUD ? 1.0 : 0.0)
        .offset(y: animateHUD ? 0 : 20)
        .animation(.easeInOut(duration: 0.6).delay(0.2), value: animateHUD)
    }

    // MARK: - Computed Properties
    private var currentModeIcon: String {
        switch gameUIModel.modeManager.currentMode {
        case .build: return "hammer.circle.fill"
        case .playSandbox: return "cube.transparent"
        case .playDelivery: return "airplane.departure"
        case .playMultiplayer: return "person.2.wave.2"
        default: return "gamecontroller.fill"
        }
    }

    private var currentModeColor: Color {
        switch gameUIModel.modeManager.currentMode {
        case .build: return .droneWarning
        case .playSandbox: return .droneSuccess
        case .playDelivery: return .droneInfo
        case .playMultiplayer: return .purple
        default: return .droneAccent
        }
    }

    private var currentModeTitle: String {
        switch gameUIModel.modeManager.currentMode {
        case .build: return "Build Mode"
        case .playSandbox: return "Sandbox"
        case .playDelivery: return "Delivery"
        case .playMultiplayer: return "Multiplayer"
        case .playPractice: return "Practice"
        case .playTimeTrial: return "Time Trial"
        default: return "Game"
        }
    }

    private var currentModeSubtitle: String? {
        switch gameUIModel.modeManager.currentMode {
        case .build: return "Constructing"
        case .playSandbox: return "Free Flight"
        case .playDelivery: return "Mission Active"
        case .playMultiplayer: return "Online"
        case .playPractice: return "Combat Training"
        case .playTimeTrial: return "Racing"
        default: return nil
        }
    }

    private var missionObjective: String {
        switch gameUIModel.modeManager.currentMode {
        case .playDelivery: return "Deliver 5 packages"
        case .playSandbox: return "Practice flying"
        case .playMultiplayer: return "Team operations"
        default: return "Explore"
        }
    }

    private var currentScore: Int {
        // TODO: Get actual score from game state
        return 1250
    }
}

// MARK: - Supporting Components

struct MissionStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: DroneLayout.xs) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.callout)

            Text(value)
                .font(DroneTypography.button)
                .foregroundColor(.droneTextPrimary)

            Text(label)
                .font(DroneTypography.caption)
                .foregroundColor(.droneTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DroneGameOverlayView(gameUIModel: GameUIModel())
        .background(Color.black)
}