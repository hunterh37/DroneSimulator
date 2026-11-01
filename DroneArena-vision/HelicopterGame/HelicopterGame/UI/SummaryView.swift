//
//  SummaryView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

public struct SummaryView: View {
    let runSession: RunSession
    let playerStats: PlayerStats
    @Binding var isPresented: Bool
    let onRestartRun: () -> Void

    public init(
        runSession: RunSession,
        playerStats: PlayerStats,
        isPresented: Binding<Bool>,
        onRestartRun: @escaping () -> Void
    ) {
        self.runSession = runSession
        self.playerStats = playerStats
        self._isPresented = isPresented
        self.onRestartRun = onRestartRun
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Mission Complete")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(runSession.levelID.uppercased())
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Performance Summary
            VStack(spacing: 16) {
                PerformanceCard(
                    title: "Time",
                    value: formatTime(runSession.elapsedTime),
                    icon: "clock",
                    color: .blue
                )

                PerformanceCard(
                    title: "Coins Earned",
                    value: "\(runSession.coinsEarned)",
                    icon: "bitcoinsign.circle.fill",
                    color: .yellow
                )

                if runSession.jobCompleted {
                    PerformanceCard(
                        title: "Delivery",
                        value: "SUCCESS",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                } else {
                    PerformanceCard(
                        title: "Delivery",
                        value: "INCOMPLETE",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                }

                // Medal placeholder
                if let medal = calculateMedal() {
                    MedalDisplay(medal: medal)
                }
            }

            // Total Progress
            VStack(spacing: 12) {
                Text("Total Progress")
                    .font(.headline)

                HStack(spacing: 32) {
                    StatDisplay(
                        title: "Total Coins",
                        value: "\(playerStats.coins + runSession.coinsEarned)"
                    )

                    StatDisplay(
                        title: "Deliveries",
                        value: "\(playerStats.deliveries + (runSession.jobCompleted ? 1 : 0))"
                    )

                    StatDisplay(
                        title: "Medals",
                        value: "\(playerStats.medals.count)"
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button("New Run") {
                    isPresented = false
                    onRestartRun()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Main Menu") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func calculateMedal() -> Medal? {
        guard runSession.jobCompleted else { return nil }

        let timeRatio = runSession.elapsedTime / 300.0 // 5 minutes baseline

        if timeRatio <= 0.5 {
            return .gold
        } else if timeRatio <= 0.8 {
            return .silver
        } else {
            return .bronze
        }
    }
}

struct PerformanceCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MedalDisplay: View {
    let medal: Medal

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: medalIcon)
                .font(.system(size: 40))
                .foregroundColor(medalColor)

            Text("\(medal.rawValue.capitalized) Medal")
                .font(.headline)
                .foregroundColor(medalColor)
        }
        .padding(20)
        .background(medalColor.opacity(0.1))
        .cornerRadius(15)
    }

    private var medalIcon: String {
        switch medal {
        case .bronze:
            return "medal.fill"
        case .silver:
            return "medal.fill"
        case .gold:
            return "medal.fill"
        }
    }

    private var medalColor: Color {
        switch medal {
        case .bronze:
            return .orange
        case .silver:
            return .gray
        case .gold:
            return .yellow
        }
    }
}

struct StatDisplay: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let runSession = RunSession(levelID: "level1")
    runSession.coinsEarned = 75
    runSession.jobCompleted = true

    return SummaryView(
        runSession: runSession,
        playerStats: PlayerStats(coins: 150, deliveries: 3),
        isPresented: .constant(true),
        onRestartRun: {}
    )
}