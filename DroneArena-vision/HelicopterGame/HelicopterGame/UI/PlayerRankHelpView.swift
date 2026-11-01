//
//  PlayerRankHelpView.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import SwiftUI

struct PlayerRankHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("Player Ranks")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                ScrollView {
                    VStack(spacing: 32) {
                        // How to Earn XP Section
                        howToEarnXPSection

                        // All Ranks Display
                        allRanksSection
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }

    // MARK: - How to Earn XP

    private var howToEarnXPSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Earn XP")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                xpMethodRow(
                    icon: "scope",
                    iconColor: .red,
                    title: "Kill Enemy",
                    xp: PlayerRank.xpForKill()
                )

                xpMethodRow(
                    icon: "trophy.fill",
                    iconColor: .green,
                    title: "Win Match",
                    xp: PlayerRank.xpForWin()
                )

                xpMethodRow(
                    icon: "flag.fill",
                    iconColor: .orange,
                    title: "Lose Match",
                    xp: PlayerRank.xpForLoss()
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func xpMethodRow(icon: String, iconColor: Color, title: String, xp: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32)

            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Text("+\(xp)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.yellow)

                Text("XP")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow.opacity(0.8))
            }
        }
    }

    // MARK: - All Ranks Section

    private var allRanksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Ranks")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(1...10, id: \.self) { level in
                    rankCard(level: level)
                }
            }
        }
    }

    private func rankCard(level: Int) -> some View {
        let xpRequired = PlayerRank.xpRequiredForLevel(level)
        let nextLevelXP = level < 10 ? PlayerRank.xpRequiredForLevel(level + 1) : xpRequired

        return VStack(spacing: 12) {
            // Rank icon with fallback
            ZStack {
                Image("Rank\(level)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }

            // Level number
            Text("Level \(level)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // XP requirement
            if level == 1 {
                Text("Starting Rank")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else if level == 10 {
                Text("Max Rank")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
            } else {
                VStack(spacing: 4) {
                    Text("\(xpRequired) XP")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.yellow)

                    Text("(\(nextLevelXP - xpRequired) to next)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            level == 10 ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: level == 10 ? 2 : 1
                        )
                )
        )
    }
}

#Preview {
    PlayerRankHelpView()
}
