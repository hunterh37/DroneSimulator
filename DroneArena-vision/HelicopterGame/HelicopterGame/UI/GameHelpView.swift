//
//  GameHelpView.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import SwiftUI

struct GameHelpView: View {
    @Binding var isPresented: Bool
    @Binding var showJoystickTips: Bool
    @State private var showRankHelp = false
    let currentMode: GameMode

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissHelp()
                }

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Game Help")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismissHelp() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                ScrollView {
                    VStack(spacing: 24) {
                        // Current Mode Info
                        currentModeInfoCard

                        // Controls section
                        controlsInfoCard

                        // Mode-specific help
                        if currentMode == .playMultiplayer {
                            multiplayerHelpCard
                        } else if currentMode == .playTimeTrial {
                            timeTrialHelpCard
                        } else if currentMode == .playPractice {
                            practiceHelpCard
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .onAppear {
            // Show joystick tips when help opens
            showJoystickTips = true
        }
        .sheet(isPresented: $showRankHelp) {
            PlayerRankHelpView()
        }
    }

    private func dismissHelp() {
        // Hide joystick tips when help closes
        showJoystickTips = false
        isPresented = false
    }

    // MARK: - Current Mode Info Card

    private var currentModeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: modeIcon)
                    .font(.system(size: 24))
                    .foregroundColor(modeColor)

                Text(modeName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(modeDescription)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(modeColor.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Controls Info Card

    private var controlsInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controls")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                controlRow(icon: "gamecontroller", text: "Left Joystick: Throttle + Yaw (up/down, rotate)")
                controlRow(icon: "gamecontroller", text: "Right Joystick: Movement (forward/back, strafe)")
                controlRow(icon: "scope", text: "Missile Button: Fire weapon at enemies")
                controlRow(icon: "hand.point.up", text: "Claw Button: Grab packages (delivery mode)")
            }

            Text("Toggle joystick labels from settings ⚙️")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func controlRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - Multiplayer Help Card

    private var multiplayerHelpCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Multiplayer Combat")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                helpRow(icon: "scope", iconColor: .red, title: "Defeat Enemy Drones", description: "Shoot enemy drones 4 times to defeat them")
                helpRow(icon: "star.fill", iconColor: .yellow, title: "Earn XP", description: "+10 XP per kill, +50 XP for wins, +20 XP for losses")
                helpRow(icon: "arrow.up.circle.fill", iconColor: .green, title: "Level Up", description: "Gain XP to rank up from Level 1 to Level 10")
                helpRow(icon: "flame.fill", iconColor: .orange, title: "Killstreaks", description: "Chain kills quickly for bonus killstreak rewards")
            }

            // Player Rank Info Button
            Button(action: {
                showRankHelp = true
            }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))

                    Text("View All Player Ranks & XP System")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.blue)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Time Trial Help Card

    private var timeTrialHelpCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time Trial Mode")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                helpRow(icon: "target", iconColor: .cyan, title: "Fly Through Rings", description: "Navigate through checkpoint rings as fast as possible")
                helpRow(icon: "stopwatch.fill", iconColor: .orange, title: "Beat the Clock", description: "Complete waves before time runs out")
                helpRow(icon: "star.fill", iconColor: .yellow, title: "Score Points", description: "Earn points for each ring cleared")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Practice Help Card

    private var practiceHelpCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice Mode")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                helpRow(icon: "scope", iconColor: .red, title: "Combat Training", description: "Practice fighting against AI enemy drones")
                helpRow(icon: "flame.fill", iconColor: .orange, title: "Test Killstreaks", description: "Try out different weapons and strategies")
                helpRow(icon: "figure.walk", iconColor: .green, title: "Learn Controls", description: "Get comfortable with drone movement and combat")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
        )
    }

    private func helpRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Mode Info Helpers

    private var modeName: String {
        switch currentMode {
        case .playMultiplayer: return "Multiplayer Battle"
        case .playTimeTrial: return "Time Trial"
        case .playPractice: return "Practice Mode"
        case .playDelivery: return "Delivery Mode"
        case .play: return "Play Mode"
        case .playSandbox: return "Sandbox Mode"
        default: return "Game Mode"
        }
    }

    private var modeDescription: String {
        switch currentMode {
        case .playMultiplayer: return "Compete against other players in real-time combat. Defeat enemies to earn XP and level up your rank."
        case .playTimeTrial: return "Race against the clock flying through checkpoint rings. Complete waves to earn high scores."
        case .playPractice: return "Train your combat skills against AI enemy drones in a safe environment."
        case .playDelivery: return "Deliver packages to designated zones and collect coins."
        case .play: return "Free flight mode with full drone control."
        case .playSandbox: return "Explore and experiment with all game features."
        default: return "Explore the game world with your drone."
        }
    }

    private var modeIcon: String {
        switch currentMode {
        case .playMultiplayer: return "person.2.fill"
        case .playTimeTrial: return "stopwatch.fill"
        case .playPractice: return "target"
        case .playDelivery: return "shippingbox.fill"
        case .play: return "airplane"
        case .playSandbox: return "cube.fill"
        default: return "gamecontroller.fill"
        }
    }

    private var modeColor: Color {
        switch currentMode {
        case .playMultiplayer: return .red
        case .playTimeTrial: return .cyan
        case .playPractice: return .orange
        case .playDelivery: return .green
        case .play: return .blue
        case .playSandbox: return .purple
        default: return .white
        }
    }
}

#Preview {
    GameHelpView(
        isPresented: .constant(true),
        showJoystickTips: .constant(true),
        currentMode: .playMultiplayer
    )
}
