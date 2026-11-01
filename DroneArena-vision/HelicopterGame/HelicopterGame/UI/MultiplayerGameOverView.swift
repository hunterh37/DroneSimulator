//
//  MultiplayerGameOverView.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import SwiftUI

struct MultiplayerGameOverView: View {
    let battleResult: BattleResult
    let onContinue: () -> Void
    let onReturnToMenu: () -> Void

    @State private var animateResults = false
    @State private var showConfetti = false
    @Environment(GameUIModel.self) var gameUIModel

    // Check if local player won
    private var isLocalPlayerWinner: Bool {
        let networking = MultiplayerNetworking()
        return battleResult.winnerPlayerID == networking.localPlayerID
    }

    var body: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                // Victory/Defeat Header
                victoryHeader

                // Winner Stats Card
                winnerStatsCard

                // Final Standings
                standingsCard

                // Action Buttons
                actionButtons

                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateResults = true
            }
            if isLocalPlayerWinner {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showConfetti = true
                }
            }
        }
    }

    // MARK: - Victory Header

    private var victoryHeader: some View {
        VStack(spacing: 12) {
            // Large Victory/Defeat Image
            Image(isLocalPlayerWinner ? "victory" : "defeat")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                .shadow(color: isLocalPlayerWinner ? .green.opacity(0.6) : .red.opacity(0.6), radius: 20)
                .opacity(animateResults ? 1.0 : 0.0)
                .scaleEffect(animateResults ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animateResults)

            // Winner announcement
            Text("\(battleResult.winnerName) wins!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .opacity(animateResults ? 1.0 : 0.0)
                .offset(y: animateResults ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateResults)
        }
    }

    // MARK: - Winner Stats Card

    private var winnerStatsCard: some View {
        VStack(spacing: 16) {
            Text("Match Statistics")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 32) {
                // Kills
                StatColumn(
                    icon: "target",
                    value: "\(battleResult.winnerKills)",
                    label: "Kills"
                )

                Divider()
                    .frame(height: 50)
                    .background(Color.white.opacity(0.3))

                // Deaths
                StatColumn(
                    icon: "xmark.circle",
                    value: "\(battleResult.winnerDeaths)",
                    label: "Deaths"
                )

                Divider()
                    .frame(height: 50)
                    .background(Color.white.opacity(0.3))

                // K/D Ratio
                StatColumn(
                    icon: "chart.bar.fill",
                    value: String(format: "%.2f", calculateKD(kills: battleResult.winnerKills, deaths: battleResult.winnerDeaths)),
                    label: "K/D"
                )

                Divider()
                    .frame(height: 50)
                    .background(Color.white.opacity(0.3))

                // Duration
                StatColumn(
                    icon: "clock.fill",
                    value: formatTime(battleResult.battleDuration),
                    label: "Duration"
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .stroke(isLocalPlayerWinner ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
        )
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: animateResults)
    }

    // MARK: - Standings Card

    private var standingsCard: some View {
        let cardBackground = RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.6))
            .stroke(Color.white.opacity(0.2), lineWidth: 1)

        return VStack(spacing: 12) {
            Text("Final Standings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(battleResult.finalStandings.enumerated()), id: \.element.playerID) { index, standing in
                standingRow(index: index, standing: standing)
            }
        }
        .padding(20)
        .background(cardBackground)
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 30)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5), value: animateResults)
    }

    private func standingRow(index: Int, standing: (playerID: String, kills: Int, deaths: Int)) -> some View {
        let isFirst = index == 0
        let rankColor: Color = isFirst ? .yellow : .white.opacity(0.7)
        let fillColor = isFirst ? Color.yellow.opacity(0.15) : Color.white.opacity(0.05)
        let strokeColor = isFirst ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1)

        let rowBackground = RoundedRectangle(cornerRadius: 8)
            .fill(fillColor)
            .stroke(strokeColor, lineWidth: 1)

        return HStack(spacing: 12) {
            // Rank
            Text("#\(index + 1)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 40, alignment: .leading)

            // Player name
            Text(getPlayerName(for: standing.playerID))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // K/D
            Text("\(standing.kills)/\(standing.deaths)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(rowBackground)
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(x: animateResults ? 0 : -50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4 + Double(index) * 0.1), value: animateResults)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Return to Menu
            Button(action: onReturnToMenu) {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Menu")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.3))
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                )
            }

            // Continue/Rematch - TEMPORARILY HIDDEN
            /*
            Button(action: onContinue) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Rematch")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.3))
                        .stroke(Color.green.opacity(0.6), lineWidth: 2)
                )
            }
            */
        }
        .opacity(animateResults ? 1.0 : 0.0)
        .offset(y: animateResults ? 0 : 20)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.7), value: animateResults)
    }

    // MARK: - Helper Views

    private struct StatColumn: View {
        let icon: String
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(minWidth: 70)
        }
    }

    // MARK: - Utility Functions

    private func calculateKD(kills: Int, deaths: Int) -> Double {
        guard deaths > 0 else { return Double(kills) }
        return Double(kills) / Double(deaths)
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func getPlayerName(for playerID: String) -> String {
        // Check if it's the local player
        let networking = MultiplayerNetworking()
        if playerID == networking.localPlayerID {
            return GameContext.shared.playerProfile.playerName
        }

        // Check room players for matching ID
        if let roomPlayer = gameUIModel.multiplayerManager.roomPlayers.first(where: { $0.id == playerID }) {
            return roomPlayer.name
        }

        // Check if it's a bot
        if playerID.hasPrefix("Bot_") {
            let botName = String(playerID.dropFirst(4))
            return botName.isEmpty ? "Enemy Drone" : botName
        }

        // Fallback
        return "Player"
    }
}

// MARK: - Preview

#Preview {
    MultiplayerGameOverView(
        battleResult: BattleResult(
            winnerPlayerID: "player1",
            winnerName: "TopGun",
            winnerKills: 10,
            winnerDeaths: 3,
            finalStandings: [
                (playerID: "player1", kills: 10, deaths: 3),
                (playerID: "player2", kills: 7, deaths: 8),
                (playerID: "player3", kills: 5, deaths: 10)
            ],
            battleDuration: 245.5
        ),
        onContinue: {},
        onReturnToMenu: {}
    )
}
