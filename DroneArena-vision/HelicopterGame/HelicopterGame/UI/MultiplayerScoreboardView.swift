//
//  MultiplayerScoreboardView.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//  Minimal scoreboard showing leader kills and local player kills
//

import SwiftUI

struct MultiplayerScoreboardView: View {
    @Environment(GameUIModel.self) var gameUIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Leader kills
            if let leader = getLeader() {
                HStack(spacing: 8) {
                    // Trophy icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)

                    // Leader name and kills
                    Text("\(leader.name): \(leader.kills)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6))
                .cornerRadius(8)
            }

            // Local player kills
            HStack(spacing: 8) {
                // Scope icon
                Image(systemName: "scope")
                    .font(.system(size: 14))
                    .foregroundColor(.coreBlue)

                // Local player kills
                Text("You: \(getLocalPlayerKills())")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Functions

    private func getLeader() -> (name: String, kills: Int)? {
        guard !gameUIModel.multiplayerManager.roomPlayers.isEmpty else {
            return nil
        }

        // Find player with most kills by counting killfeed entries
        let sortedPlayers = gameUIModel.multiplayerManager.roomPlayers.sorted { (player1: RoomPlayer, player2: RoomPlayer) -> Bool in
            let kills1 = getKillCount(for: player1.id)
            let kills2 = getKillCount(for: player2.id)
            return kills1 > kills2
        }

        if let topPlayer = sortedPlayers.first {
            let kills = getKillCount(for: topPlayer.id)
            return (name: topPlayer.name, kills: kills)
        }

        return nil
    }

    private func getLocalPlayerKills() -> Int {
        let localPlayerID = gameUIModel.multiplayerManager.networking.localPlayerID
        return getKillCount(for: localPlayerID)
    }

    private func getKillCount(for playerID: String) -> Int {
        return GameContext.shared.health.playerKillCounts[playerID] ?? 0
    }
}

#Preview {
    MultiplayerScoreboardView()
        .environment(GameUIModel())
        .padding()
        .background(Color.gray)
}
