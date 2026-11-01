//
//  MainMenuView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct MainMenuView: View {
    let modeManager: ModeManager
    @Environment(EconomyModel.self) var economyModel

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Title
                VStack(spacing: 10) {
                    Text("Drone Game")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Choose Your Mode")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                // Player Stats
                PlayerStatsView(economyModel: economyModel)

                // Mode Selection
                VStack(spacing: 20) {
                    // Delivery Mode Button
                    GameModeButton(
                        title: "Delivery Mode",
                        subtitle: "Complete zone-based missions",
                        icon: "airplane",
                        color: .blue,
                        isEnabled: modeManager.canStartDeliveryMode()
                    ) {
                        modeManager.switchToMode(.playDelivery)
                    }

                    // Sandbox Mode Button
                    GameModeButton(
                        title: "Sandbox Mode",
                        subtitle: "Free play with unlimited crates",
                        icon: "cube.box",
                        color: .green,
                        isEnabled: true
                    ) {
                        modeManager.switchToMode(.playSandbox)
                    }

                    // Build Mode Button
                    GameModeButton(
                        title: "Build Mode",
                        subtitle: "Design your delivery zones",
                        icon: "hammer",
                        color: .orange,
                        isEnabled: true
                    ) {
                        modeManager.switchToMode(.build)
                    }
                }

                Spacer()

                // Settings and Info
                HStack {
                    Button("Settings") {
                        // TODO: Open settings
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Text("v1.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

struct GameModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .white : .gray)
                    .frame(width: 30)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isEnabled ? .white : .gray)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isEnabled ? .gray : .secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(isEnabled ? .gray : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .stroke(isEnabled ? color.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
    }
}

struct PlayerStatsView: View {
    let economyModel: EconomyModel

    var body: some View {
        HStack(spacing: 30) {
            StatItem(
                icon: "dollarsign.circle.fill",
                label: "Coins",
                value: "\(economyModel.playerProfile.coins)",
                color: .yellow
            )

            StatItem(
                icon: "medal.fill",
                label: "Medals",
                value: "\(economyModel.playerProfile.medals.count)",
                color: .orange
            )

            StatItem(
                icon: "airplane.departure",
                label: "Deliveries",
                value: "\(economyModel.playerProfile.totalDeliveries)",
                color: .blue
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.5))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    MainMenuView(modeManager: ModeManager(buildModeManager: BuildModeManager()))
        .environment(EconomyModel())
}