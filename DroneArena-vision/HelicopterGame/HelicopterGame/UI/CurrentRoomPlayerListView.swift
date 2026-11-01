//
//  CurrentRoomPlayerListView.swift
//  HelicopterGame
//
//  Created by Claude on 10/3/25.
//  Displays the current players in a multiplayer session
//

import SwiftUI

struct CurrentRoomPlayerListView: View {
    @Environment(GameUIModel.self) var gameUIModel
    @State private var animateElements = false
    @State private var healthManager = GameContext.shared.health
    @State private var rankManager = PlayerRankManager()

    // Track current players from the multiplayer session
    private var currentPlayers: [RoomPlayer] {
        // Get players from the multiplayer manager's room players list
        return gameUIModel.multiplayerManager.roomPlayers
    }

    // Add local player to the list
    private var allPlayers: [PlayerDisplayInfo] {
        var players: [PlayerDisplayInfo] = []
        let localPlayerID = gameUIModel.multiplayerManager.networking.localPlayerID

        // Add local player first
        let localPlayerStats = getPlayerStats(for: localPlayerID)
        let localPlayer = PlayerDisplayInfo(
            id: localPlayerID,
            name: "\(GameContext.shared.playerProfile.playerName) (You)",
            color: GameContext.shared.playerProfile.playerColorHex,
            isLocal: true,
            kills: localPlayerStats.kills,
            deaths: localPlayerStats.deaths,
            rank: rankManager.localPlayerRank
        )
        players.append(localPlayer)

        // Add remote players (exclude local player if it appears in roomPlayers)
        for roomPlayer in currentPlayers {
            // Skip if this room player is actually the local player
            if roomPlayer.id == localPlayerID {
                continue
            }

            let playerStats = getPlayerStats(for: roomPlayer.id)
            let player = PlayerDisplayInfo(
                id: roomPlayer.id,
                name: roomPlayer.name,
                color: roomPlayer.color,
                isLocal: false,
                kills: playerStats.kills,
                deaths: playerStats.deaths,
                rank: roomPlayer.rank
            )
            players.append(player)
        }

        return players
    }

    // Calculate kill/death stats from persistent counts
    private func getPlayerStats(for playerID: String) -> (kills: Int, deaths: Int) {
        let kills = healthManager.playerKillCounts[playerID] ?? 0
        let deaths = healthManager.playerDeathCounts[playerID] ?? 0
        return (kills: kills, deaths: deaths)
    }

    var body: some View {
        // Player list panel - always expanded
        VStack(spacing: 0) {
            // Header
            headerView

            // Player list content - always visible
            playerListContent
        }
        .background(
            RoundedRectangle(cornerRadius: DroneLayout.radiusLG)
                .fill(.black.opacity(0.85))
                .stroke(.white.opacity(0.2), lineWidth: 1)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .frame(width: 350)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                animateElements = true
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(spacing: DroneLayout.sm) {
            // Player count indicator
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.droneAccent)

                Text("\(allPlayers.count) Players")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.droneTextPrimary)
            }
            .opacity(animateElements ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.6).delay(0.7), value: animateElements)

            Spacer()
        }
        .padding(.horizontal, DroneLayout.sm)
        .padding(.vertical, DroneLayout.xs)
        .background(
            RoundedRectangle(cornerRadius: DroneLayout.radiusMD)
                .fill(Color.droneAccent.opacity(0.1))
        )
    }

    // MARK: - Player List Content
    private var playerListContent: some View {
        VStack(spacing: DroneLayout.xs) {
            // Title with game stats header
            VStack(spacing: 8) {
                HStack {
                    Text("ROOM PLAYERS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.droneAccent)
                        .kerning(0.5)

                    Spacer()

                    // Live connection status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(0.9)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                }

                // Professional stats header
                HStack {
                    Text("PLAYER")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.droneTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("KILLS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.droneTextSecondary)
                        .frame(width: 45)

                    Text("DEATHS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.droneTextSecondary)
                        .frame(width: 55)

                    Text("K/D")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.droneTextSecondary)
                        .frame(width: 40)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.05))
                )
            }
            .padding(.horizontal, DroneLayout.sm)
            .padding(.top, DroneLayout.sm)

            // Player list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: DroneLayout.xs) {
                    ForEach(Array(allPlayers.enumerated()), id: \.element.id) { index, player in
                        playerRow(player: player)
                            .opacity(animateElements ? 1.0 : 0.0)
                            .offset(x: animateElements ? 0 : 20)
                            .animation(
                                .easeOut(duration: 0.4).delay(Double(index) * 0.1 + 0.8),
                                value: animateElements
                            )
                    }
                }
                .padding(.horizontal, DroneLayout.sm)
            }
            .frame(maxHeight: 200) // Increased height for better readability

            Spacer(minLength: DroneLayout.xs)
        }
        .frame(width: 330) // Wider for better stats display
    }

    // MARK: - Player Row
    @ViewBuilder
    private func playerRow(player: PlayerDisplayInfo) -> some View {
        let kdRatio = player.deaths > 0 ? Double(player.kills) / Double(player.deaths) : Double(player.kills)

        HStack(spacing: 12) {
            // Player info section
            HStack(spacing: 8) {
                // Player color indicator - bigger
                Circle()
                    .fill(Color(player.color))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color(player.color).opacity(0.5), radius: 2)

                // Player name with rank and status
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        PlayerNameWithRankView(
                            playerName: player.name,
                            playerRank: player.rank,
                            textColor: player.isLocal ? .droneAccent : .droneTextPrimary,
                            fontSize: 14,
                            fontWeight: player.isLocal ? .bold : .semibold,
                            showLevel: false
                        )

                        // Status badge
                        if player.isLocal {
                            Text("YOU")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.droneAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.droneAccent.opacity(0.2))
                                        .stroke(Color.droneAccent.opacity(0.6), lineWidth: 1)
                                )
                        } else {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                        }

                        // Level indicator for all players
                        if let rank = player.rank {
                            Text("LV\(rank.level)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.droneAccent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.droneAccent.opacity(0.2))
                                        .stroke(Color.droneAccent.opacity(0.6), lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Stats section - aligned with header
            HStack(spacing: 0) {
                // Kills
                Text("\(player.kills)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 45)

                // Deaths
                Text("\(player.deaths)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 55)

                // K/D Ratio
                Text(String(format: "%.1f", kdRatio))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(kdRatio >= 1.0 ? .droneAccent : .droneTextSecondary)
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(player.isLocal ? 0.12 : 0.06))
                .stroke(.white.opacity(player.isLocal ? 0.25 : 0.12), lineWidth: 1)
        )
        .overlay(
            // Highlight border for good K/D ratios
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    kdRatio >= 2.0 ? Color.droneAccent.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

}

// MARK: - Supporting Types

struct PlayerDisplayInfo {
    let id: String
    let name: String
    let color: String
    let isLocal: Bool
    let kills: Int
    let deaths: Int
    let rank: PlayerRank?
}


#Preview {
    CurrentRoomPlayerListView()
        .environment(GameUIModel())
        .background(Color.black)
}
