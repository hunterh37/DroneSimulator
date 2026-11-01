//
//  HUDView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

public struct HUDView: View {
    var hudViewModel: HUDViewModel
    @State private var isVisible: Bool = true

    public init(hudViewModel: HUDViewModel) {
        self.hudViewModel = hudViewModel
    }

    public var body: some View {
        VStack {
            // Top status bar
            HStack {
                BatteryIndicator(
                    percentage: hudViewModel.batteryPercentage,
                    isRecharging: hudViewModel.isRecharging
                )

                Spacer()

                TimerDisplay(
                    elapsedTime: hudViewModel.elapsedTime,
                    isRunActive: hudViewModel.isRunActive
                )

                Spacer()

                CoinsDisplay(coins: hudViewModel.coinsEarned)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            // Center interaction prompt
            if !hudViewModel.interactionPrompt.isEmpty {
                InteractionPrompt(text: hudViewModel.interactionPrompt)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Bottom status
            HStack {
                // Left: Claw status
                ClawStatusIndicator(
                    clawStatus: hudViewModel.clawStatus,
                    isCarrying: hudViewModel.isCarryingParcel
                )

                Spacer()

                // Center: Job timer (when active)
                if hudViewModel.hasActiveJob {
                    JobTimerDisplay(
                        remainingTime: hudViewModel.jobRemainingTime,
                        totalTime: hudViewModel.jobTotalTime
                    )
                }

                Spacer()

                // Right: Waypoint indicator
                if hudViewModel.isRunActive {
                    WaypointIndicator(
                        hasJob: hudViewModel.hasActiveJob,
                        jobStage: hudViewModel.jobStage
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .opacity(isVisible ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.spring(), value: hudViewModel.interactionPrompt)
    }
}

struct BatteryIndicator: View {
    let percentage: Double
    let isRecharging: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isRecharging ? "battery.100.bolt" : "battery.100")
                .foregroundColor(batteryColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("BATTERY")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\(Int(percentage))%")
                    .font(.headline)
                    .foregroundColor(batteryColor)
            }

            // Battery bar
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 12)
                .overlay(
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(batteryColor)
                            .frame(width: 60 * (percentage / 100))
                        Spacer(minLength: 0)
                    }
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private var batteryColor: Color {
        if isRecharging {
            return .green
        } else if percentage > 50 {
            return .green
        } else if percentage > 20 {
            return .orange
        } else {
            return .red
        }
    }
}

struct TimerDisplay: View {
    let elapsedTime: TimeInterval
    let isRunActive: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("TIME")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(timeString)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(isRunActive ? .white : .yellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private var timeString: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CoinsDisplay: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(.yellow)
                .font(.title2)

            VStack(alignment: .trailing, spacing: 2) {
                Text("COINS")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("\(coins)")
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
}

struct InteractionPrompt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(15)
            .shadow(radius: 5)
    }
}

struct DroneStatusIndicator: View {
    let state: DroneState
    let isCarryingParcel: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("STATUS")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private var statusIcon: String {
        switch state {
        case .idle:
            return "pause.circle"
        case .flying:
            return isCarryingParcel ? "shippingbox" : "airplane"
        case .carryingParcel:
            return "shippingbox.fill"
        case .recharging:
            return "bolt.circle"
        case .emergency:
            return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:
            return .gray
        case .flying, .carryingParcel:
            return .green
        case .recharging:
            return .blue
        case .emergency:
            return .red
        }
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "IDLE"
        case .flying:
            return isCarryingParcel ? "CARRYING" : "FLYING"
        case .carryingParcel:
            return "CARRYING"
        case .recharging:
            return "RECHARGING"
        case .emergency:
            return "EMERGENCY"
        }
    }
}

struct WaypointIndicator: View {
    let hasJob: Bool
    let jobStage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.circle")
                .foregroundColor(.cyan)
                .font(.title2)

            VStack(alignment: .trailing, spacing: 2) {
                Text("OBJECTIVE")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(jobStage)
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .opacity(hasJob ? 1.0 : 0.0)
    }
}

struct ClawStatusIndicator: View {
    let clawStatus: String
    let isCarrying: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: clawIcon)
                .foregroundColor(clawColor)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("CLAW")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(clawStatus)
                    .font(.caption)
                    .foregroundColor(clawColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private var clawIcon: String {
        switch clawStatus.lowercased() {
        case "stowed":
            return "arrow.up.circle"
        case "grabbing":
            return "arrow.down.circle"
        case "carrying":
            return "shippingbox.fill"
        case "releasing":
            return "arrow.down.circle.fill"
        case "retracting":
            return "arrow.up.circle.fill"
        default:
            return "questionmark.circle"
        }
    }

    private var clawColor: Color {
        switch clawStatus.lowercased() {
        case "stowed":
            return .gray
        case "grabbing", "retracting":
            return .yellow
        case "carrying":
            return .green
        case "releasing":
            return .orange
        default:
            return .white
        }
    }
}

struct JobTimerDisplay: View {
    let remainingTime: TimeInterval
    let totalTime: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            Text("JOB TIMER")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(timeString)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(timerColor)

            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: timerColor))
                .frame(width: 100)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return remainingTime / totalTime
    }

    private var timerColor: Color {
        if progress > 0.5 {
            return .green
        } else if progress > 0.25 {
            return .orange
        } else {
            return .red
        }
    }
}