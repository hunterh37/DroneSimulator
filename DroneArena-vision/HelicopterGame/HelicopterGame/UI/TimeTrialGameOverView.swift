//
//  TimeTrialGameOverView.swift
//  HelicopterGame
//
//  Created by Claude on 10/6/25.
//

import SwiftUI

struct TimeTrialGameOverView: View {
    let timeTrialManager: TimeTrialManager
    let onRestart: () -> Void
    let onMainMenu: () -> Void

    @State private var showAnimation = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Prevent accidental dismiss
                }

            // Game Over panel
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("GAME OVER")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .scaleEffect(showAnimation ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showAnimation)

                    Text("Time Trial Complete")
                        .font(.title2)
                        .foregroundColor(.white)
                        .opacity(showAnimation ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.8).delay(0.3), value: showAnimation)
                }

                // Stats display
                if let gameOverData = timeTrialManager.getGameOverData() {
                    VStack(spacing: 16) {
                        // Level reached
                        TimeTrialStatRow(
                            icon: "flag.fill",
                            label: "Level Reached",
                            value: "\(gameOverData.levelReached)",
                            color: .orange
                        )

                        // Rings collected
                        TimeTrialStatRow(
                            icon: "circlebadge.fill",
                            label: "Rings Collected",
                            value: "\(gameOverData.totalRingsCollected)",
                            color: .yellow
                        )

                        // Total score
                        TimeTrialStatRow(
                            icon: "star.fill",
                            label: "Total Score",
                            value: "\(gameOverData.totalScore)",
                            color: .green
                        )

                        // Best time
                        TimeTrialStatRow(
                            icon: "stopwatch.fill",
                            label: "Best Level Time",
                            value: formatTime(gameOverData.bestTime),
                            color: .blue
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(showAnimation ? 1.0 : 0.0)
                    .offset(y: showAnimation ? 0 : 20)
                    .animation(.easeInOut(duration: 0.8).delay(0.5), value: showAnimation)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Restart button
                    Button(action: onRestart) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                            Text("Play Again")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }

                    // Main menu button
                    Button(action: onMainMenu) {
                        HStack {
                            Image(systemName: "house")
                                .font(.title3)
                            Text("Main Menu")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.gray.opacity(0.8))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showAnimation ? 1.0 : 0.0)
                .offset(y: showAnimation ? 0 : 30)
                .animation(.easeInOut(duration: 0.8).delay(0.7), value: showAnimation)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.9))
                    .stroke(.white.opacity(0.2), lineWidth: 2)
            )
            .scaleEffect(showAnimation ? 1.0 : 0.9)
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: showAnimation)
        }
        .onAppear {
            showAnimation = true
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

struct TimeTrialStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 30)

            Text(label)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
        )
    }
}

#Preview {
    TimeTrialGameOverView(
        timeTrialManager: TimeTrialManager(),
        onRestart: {},
        onMainMenu: {}
    )
}