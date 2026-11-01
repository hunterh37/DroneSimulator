//
//  ResultsView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct ResultsView: View {
    let results: SessionResults
    let onContinue: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Medal Display
                if let medal = results.medalAwarded {
                    MedalDisplayView(medal: medal)
                }

                // Session Summary
                VStack(spacing: 20) {
                    Text("Mission Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    ResultsSessionStatsView(results: results)
                }

                // Coins Earned
                CoinRewardView(coinsEarned: results.coinsEarned)

                Spacer()

                // Action Buttons
                VStack(spacing: 15) {
                    Button("Continue") {
                        onContinue()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Restart Mission") {
                        onRestart()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct MedalDisplayView: View {
    let medal: Medal

    var medalColor: Color {
        switch medal {
        case .bronze: return .orange
        case .silver: return .gray
        case .gold: return .yellow
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "medal.fill")
                .font(.system(size: 60))
                .foregroundColor(medalColor)

            Text("\(medal.rawValue.capitalized) Medal!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct ResultsSessionStatsView: View {
    let results: SessionResults

    var body: some View {
        VStack(spacing: 15) {
            StatRow(
                label: "Deliveries Completed",
                value: "\(results.completedDeliveries.count)/\(results.totalJobs)"
            )

            StatRow(
                label: "Average Delivery Time",
                value: String(format: "%.1fs", results.averageDeliveryTime)
            )

            StatRow(
                label: "Session Duration",
                value: formatTime(results.sessionDuration)
            )

            if !results.completedDeliveries.isEmpty {
                StatRow(
                    label: "Fastest Delivery",
                    value: String(format: "%.1fs", results.completedDeliveries.map(\.deliveryTime).min() ?? 0)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct CoinRewardView: View {
    let coinsEarned: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title)
                .foregroundColor(.yellow)

            Text("+\(coinsEarned)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.yellow)

            Text("coins earned")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.1))
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

#Preview {
    let sampleResults = SessionResults(
        levelID: "level_1",
        completedDeliveries: [
            CompletedDelivery(packageType: .generic, deliveryTime: 25.5),
            CompletedDelivery(packageType: .priorityCargo, deliveryTime: 18.2, wasPriority: true)
        ],
        totalJobs: 3,
        sessionDuration: 180.0
    )

    ResultsView(
        results: sampleResults,
        onContinue: {},
        onRestart: {}
    )
}