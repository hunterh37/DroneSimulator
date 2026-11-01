//
//  DroneStatsHUDView.swift
//  HelicopterGame
//
//  A head-anchored sci-fi HUD that floats ~1m in front of the player and shows
//  the live drone combat / flight stats: AMMO, HEALTH and SPEED.
//
//  Wiring (mirrors the ZombieShooter "SciFiSurvivalHUDView" pattern):
//    • Rendered as a SwiftUI RealityView `Attachment` in `ImmersiveView`
//      (tag: `droneStatsHUDTag`).
//    • Parented to an `AnchorEntity(.head)` with a small -Z offset so it stays
//      locked in front of the player's view like a visor.
//    • Driven at runtime by `HUDViewModel.updateCombatStats(...)`.
//

import SwiftUI

struct DroneStatsHUDView: View {
    var hudViewModel: HUDViewModel

    // Sci-fi palette pulled from the drone design system.
    private let accent = Color.purpureus
    private let info = Color.silverLakeBlue
    private let good = Color.verdigris

    private var healthFraction: Double {
        guard hudViewModel.maxHealth > 0 else { return 0 }
        return Double(hudViewModel.health) / Double(hudViewModel.maxHealth)
    }

    private var healthColor: Color {
        if healthFraction <= 0.25 { return .red }
        if healthFraction <= 0.5 { return .orange }
        return good
    }

    // Speed in mph for a punchier readout.
    private var speedMph: Int { Int((hudViewModel.speed * 2.23694).rounded()) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 48) {
            missileBlock(slot: 1, name: hudViewModel.missile1Name, count: hudViewModel.missile1Count)
            missileBlock(slot: 2, name: hudViewModel.missile2Name, count: hudViewModel.missile2Count)
            divider
            healthBlock
            divider
            speedBlock
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: accent.opacity(0.4), radius: 24)
        )
        .frame(width: 1040, height: 260)
    }

    // MARK: - Blocks

    private func missileBlock(slot: Int, name: String, count: Int) -> some View {
        let isLow = count <= 1
        return VStack(alignment: .leading, spacing: 4) {
            label("MSL \(slot)", color: isLow ? .red : accent)
            Text("\(count)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(isLow ? .red : .white)
                .shadow(color: isLow ? .red.opacity(0.7) : .clear, radius: 12)
            Text(name.uppercased())
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(info.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .leading)
        }
    }

    private var healthBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("HEALTH", color: healthColor)
            Text("\(max(0, hudViewModel.health))")
                .font(.system(size: 55, weight: .black, design: .rounded))
                .foregroundStyle(healthColor)
                .shadow(color: healthColor.opacity(0.6), radius: 12)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12)).frame(width: 200, height: 12)
                Capsule()
                    .fill(healthColor)
                    .frame(width: 200 * CGFloat(max(0, min(1, healthFraction))), height: 12)
                    .animation(.easeOut(duration: 0.2), value: healthFraction)
            }
        }
    }

    private var speedBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            label("SPEED", color: info)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(speedMph)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("MPH")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(info.opacity(0.7))
            }
            Text(String(format: "ALT %.0f FT", hudViewModel.altitude * 3.28084))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(info.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .black, design: .monospaced))
            .tracking(6)
            .foregroundStyle(color.opacity(0.8))
    }

    private var divider: some View {
        Rectangle()
            .fill(accent.opacity(0.25))
            .frame(width: 1.5, height: 150)
    }
}
