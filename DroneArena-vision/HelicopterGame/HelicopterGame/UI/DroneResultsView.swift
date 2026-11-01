//
//  DroneResultsView.swift
//  HelicopterGame
//
//  Created by Claude on 10/2/25.
//

import SwiftUI

struct DroneResultsView: View {
    let results: SessionResults
    let onContinue: () -> Void
    let onRestart: () -> Void
    @State private var animateResults = false

    var body: some View {
        VStack(spacing: DroneLayout.xl) {
            // Mission Complete Header
            missionCompleteHeader

            // Results Summary
            resultsSummary

            // Detailed Stats
            detailedStats

            // Action Buttons
            actionButtons

            Spacer()
        }
        .padding(DroneLayout.lg)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateResults = true
            }
        }
    }

    // MARK: - Mission Complete Header
    private var missionCompleteHeader: some View {
        DroneCard(variant: .glass, isGlowing: true) {
            VStack(spacing: DroneLayout.md) {
                // Success icon with animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.droneSuccess.opacity(0.3), .droneSuccess.opacity(0.1)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(animateResults ? 1.0 : 0.5)
                        .opacity(animateResults ? 1.0 : 0.0)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.droneSuccess)
                        .scaleEffect(animateResults ? 1.0 : 0.3)
                        .rotationEffect(.degrees(animateResults ? 0 : -180))
                }

                VStack(spacing: DroneLayout.xs) {
                    Text("Mission Complete")
                        .font(DroneTypography.title)
                        .foregroundColor(.droneTextPrimary)

                    Text(missionTypeLabel)
                        .font(DroneTypography.body)
                        .foregroundColor(.droneTextSecondary)
                }
                .opacity(animateResults ? 1.0 : 0.0)
                .offset(y: animateResults ? 0 : 20)
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateResults)
    }

    // MARK: - Results Summary
    private var resultsSummary: some View {
        DroneCard(variant: .primary) {
            VStack(spacing: DroneLayout.lg) {
                HStack {
                    Text("Performance Summary")
                        .font(DroneTypography.headline)
                        .foregroundColor(.droneTextPrimary)

                    Spacer()

                    medalView
                }

                HStack(spacing: DroneLayout.lg) {
                    MetricCard(
                        icon: "timer.circle.fill",
                        value: formattedTime,
                        label: "Duration",
                        color: .droneInfo
                    )

                    MetricCard(
                        icon: "shippingbox.fill",
                        value: "\(results.completedDeliveries.count)",
                        label: "Delivered",
                        color: .droneSuccess
                    )

                    MetricCard(
                        icon: "creditcard.circle.fill",
                        value: "\(results.coinsEarned)",
                        label: "Earned",
                        color: .droneAccent
                    )
                }
            }
        }
        .scaleEffect(animateResults ? 1.0 : 0.9)
        .opacity(animateResults ? 1.0 : 0.0)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateResults)
    }

    // MARK: - Detailed Stats
    private var detailedStats: some View {
        DroneCard(variant: .secondary) {
            VStack(alignment: .leading, spacing: DroneLayout.md) {
                Text("Mission Analytics")
                    .font(DroneTypography.headline)
                    .foregroundColor(.droneTextPrimary)

                VStack(spacing: DroneLayout.sm) {
                    DetailStatRow(
                        label: "Success Rate",
                        value: "\(Int((Float(results.completedDeliveries.count) / Float(results.totalJobs)) * 100))%",
                        color: efficiencyColor
                    )

                    DetailStatRow(
                        label: "Average Time",
                        value: String(format: "%.1f min", results.averageDeliveryTime / 60),
                        color: .droneInfo
                    )

                    DetailStatRow(
                        label: "Total Jobs",
                        value: "\(results.totalJobs)",
                        color: .droneAccent
                    )

                    if results.averageDeliveryTime < 30.0 {
                        DetailStatRow(
                            label: "Time Bonus",
                            value: "Achieved",
                            color: .droneSuccess
                        )
                    }
                }
            }
        }
        .scaleEffect(animateResults ? 1.0 : 0.9)
        .opacity(animateResults ? 1.0 : 0.0)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4), value: animateResults)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: DroneLayout.md) {
            DroneButton(
                "Continue to Menu",
                icon: "house.fill",
                style: .primary,
                size: .large
            ) {
                onContinue()
            }

            DroneButton(
                "Retry Mission",
                icon: "arrow.clockwise",
                style: .secondary,
                size: .medium
            ) {
                onRestart()
            }
        }
        .scaleEffect(animateResults ? 1.0 : 0.9)
        .opacity(animateResults ? 1.0 : 0.0)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6), value: animateResults)
    }

    // MARK: - Computed Properties
    private var missionTypeLabel: String {
        return "Delivery Operations"
    }

    private var medalView: some View {
        HStack(spacing: DroneLayout.xs) {
            Image(systemName: medalIcon)
                .foregroundColor(medalColor)
                .font(.title2)

            Text(medalLabel)
                .font(DroneTypography.caption)
                .foregroundColor(medalColor)
        }
        .padding(.horizontal, DroneLayout.sm)
        .padding(.vertical, DroneLayout.xs)
        .background(
            Capsule()
                .fill(medalColor.opacity(0.1))
                .stroke(medalColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var medalIcon: String {
        if let medal = results.medalAwarded {
            switch medal {
            case .bronze: return "medal.fill"
            case .silver: return "medal.fill"
            case .gold: return "crown.fill"
            }
        }
        return "minus.circle"
    }

    private var medalColor: Color {
        if let medal = results.medalAwarded {
            switch medal {
            case .bronze: return .droneWarning
            case .silver: return .droneInfo
            case .gold: return .droneAccent
            }
        }
        return .droneDisabled
    }

    private var medalLabel: String {
        if let medal = results.medalAwarded {
            switch medal {
            case .bronze: return "Bronze"
            case .silver: return "Silver"
            case .gold: return "Gold"
            }
        }
        return "No Medal"
    }

    private var formattedTime: String {
        let minutes = Int(results.sessionDuration) / 60
        let seconds = Int(results.sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var efficiencyColor: Color {
        let efficiency = Float(results.completedDeliveries.count) / Float(results.totalJobs)
        if efficiency > 0.8 { return .droneSuccess }
        if efficiency > 0.6 { return .droneWarning }
        return .droneError
    }

    private var batteryColor: Color {
        // Default to good since we don't have battery info in SessionResults
        return .droneSuccess
    }
}

// MARK: - Supporting Components

struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: DroneLayout.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(DroneTypography.headline)
                .foregroundColor(.droneTextPrimary)

            Text(label)
                .font(DroneTypography.caption)
                .foregroundColor(.droneTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DroneLayout.md)
        .background(
            RoundedRectangle(cornerRadius: DroneLayout.radiusSM)
                .fill(color.opacity(0.1))
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct DetailStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(DroneTypography.body)
                .foregroundColor(.droneTextSecondary)

            Spacer()

            Text(value)
                .font(DroneTypography.button)
                .foregroundColor(color)
        }
        .padding(.vertical, DroneLayout.xs)
    }
}

#Preview {
    DroneResultsView(
        results: SessionResults(
            levelID: "test_level",
            completedDeliveries: [
                CompletedDelivery(packageType: .generic, deliveryTime: 25.5),
                CompletedDelivery(packageType: .energyPod, deliveryTime: 18.2)
            ],
            totalJobs: 3,
            sessionDuration: 125.5
        ),
        onContinue: {},
        onRestart: {}
    )
    .background(Color.black)
}