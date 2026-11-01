//
//  MultiJobHUD.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct MultiJobHUD: View {
    let deliveryDirector: DeliveryDirector
    let economyModel: EconomyModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Active Jobs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                // Job count badge
                Text("\(deliveryDirector.activeJobCount)/3")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.3))
                    )
            }

            // Active Jobs List
            if deliveryDirector.activeJobCount > 0 {
                VStack(spacing: 8) {
                    ForEach(Array(deliveryDirector.activeJobs.enumerated()), id: \.element.id) { index, job in
                        JobCard(
                            job: job,
                            index: index,
                            isPriority: job.timeLimit < 45.0 // Simplified priority detection
                        )
                    }
                }
            } else {
                NoJobsView()
            }

            // Session Stats
            SessionStatsView(
                deliveryDirector: deliveryDirector,
                economyModel: economyModel
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: Job
    let index: Int
    let isPriority: Bool

    var progressPercentage: Float {
        let elapsed = max(0, job.timeLimit - job.remainingTime)
        return Float(elapsed / job.timeLimit) * 100
    }

    var timeColor: Color {
        let remaining = job.remainingTime
        if remaining < 10.0 {
            return .red
        } else if remaining < 20.0 {
            return .orange
        } else {
            return .white
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Job header
            HStack {
                // Priority indicator
                if isPriority {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Text("Job \(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                // Status indicator
                JobStatusIndicator(job: job)
            }

            // Job details
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pickup: \(job.pickupZoneID)")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Text("Delivery: \(job.deliveryZoneID)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Timer
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(job.remainingTime))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(timeColor)

                    // Progress bar
                    ProgressView(value: progressPercentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: timeColor))
                        .frame(width: 60, height: 4)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPriority ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                .stroke(isPriority ? Color.red.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Job Status Indicator

struct JobStatusIndicator: View {
    let job: Job

    var statusInfo: (icon: String, color: Color) {
        if job.isCompleted {
            return ("checkmark.circle.fill", .green)
        } else if job.isExpired {
            return ("xmark.circle.fill", .red)
        } else if job.isPickedUp {
            return ("shippingbox.fill", .blue)
        } else {
            return ("clock.fill", .orange)
        }
    }

    var body: some View {
        Image(systemName: statusInfo.icon)
            .font(.caption)
            .foregroundColor(statusInfo.color)
    }
}

// MARK: - No Jobs View

struct NoJobsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "briefcase")
                .font(.title3)
                .foregroundColor(.gray)

            Text("No active jobs")
                .font(.caption)
                .foregroundColor(.gray)

            Text("New jobs will appear automatically")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Session Stats View

struct SessionStatsView: View {
    let deliveryDirector: DeliveryDirector
    let economyModel: EconomyModel

    var body: some View {
        VStack(spacing: 6) {
            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("Session Stats")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()
            }

            HStack {
                SessionStatItem(
                    label: "Completed",
                    value: "\(deliveryDirector.completedJobs.count)",
                    color: .green
                )

                Spacer()

                SessionStatItem(
                    label: "Failed",
                    value: "\(deliveryDirector.failedJobs.count)",
                    color: .red
                )

                Spacer()

                SessionStatItem(
                    label: "Coins",
                    value: "\(economyModel.playerProfile.coins)",
                    color: .yellow
                )

                Spacer()

                SessionStatItem(
                    label: "Time",
                    value: formatSessionTime(deliveryDirector.sessionDuration),
                    color: .blue
                )
            }
        }
    }

    private func formatSessionTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct SessionStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Enhanced HUD View

struct EnhancedHUDView: View {
    let deliveryDirector: DeliveryDirector?
    let sandboxManager: SandboxManager?
    let economyModel: EconomyModel
    let currentMode: GameMode

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Mode-specific HUD
            switch currentMode {
            case .playDelivery, .play:
                if let director = deliveryDirector {
                    MultiJobHUD(deliveryDirector: director, economyModel: economyModel)
                }

            case .playSandbox:
                if let sandbox = sandboxManager {
                    SandboxHUD(sandboxManager: sandbox)
                }

            case .playMultiplayer:
                EmptyView() // Multiplayer HUD handled elsewhere

            case .playPractice, .playTimeTrial:
                EmptyView() // Practice and Time Trial HUD handled elsewhere

            default:
                EmptyView()
            }

            Spacer()

            // Common elements
            PlayerStatusHUD(economyModel: economyModel)
        }
    }
}

// MARK: - Sandbox HUD

struct SandboxHUD: View {
    let sandboxManager: SandboxManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text("Sandbox Mode")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
            }

            let stats = sandboxManager.getSessionStats()

            VStack(spacing: 6) {
                HStack {
                    Text("Session: \(formatTime(stats.duration))")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                }

                HStack {
                    Text("Active Crates: \(stats.activeCrates)")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    Text("Critters: \(stats.activeCritters)")
                        .font(.caption)
                        .foregroundColor(.pink)
                }

                HStack {
                    Text("Spawned: \(stats.cratesSpawned)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Efficiency: \(String(format: "%.0f%%", stats.efficiency * 100))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Player Status HUD

struct PlayerStatusHUD: View {
    let economyModel: EconomyModel

    var body: some View {
        HStack(spacing: 15) {
            // Coins
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)

                Text("\(economyModel.playerProfile.coins)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Total deliveries
            HStack(spacing: 4) {
                Image(systemName: "airplane.departure")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("\(economyModel.playerProfile.totalDeliveries)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Medal count
            HStack(spacing: 4) {
                Image(systemName: "medal.fill")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text("\(economyModel.playerProfile.medals.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    let deliveryDirector = DeliveryDirector()
    let economyModel = EconomyModel()

    MultiJobHUD(deliveryDirector: deliveryDirector, economyModel: economyModel)
        .frame(width: 250)
}