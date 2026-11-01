//
//  PlayerNameWithRankView.swift
//  HelicopterGame
//
//  Created by Claude on 10/11/25.
//  Reusable component for displaying player name with rank icon
//

import SwiftUI

struct PlayerNameWithRankView: View {
    let playerName: String
    let playerRank: PlayerRank?
    let textColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let showLevel: Bool

    init(
        playerName: String,
        playerRank: PlayerRank? = nil,
        textColor: Color = .droneTextPrimary,
        fontSize: CGFloat = 14,
        fontWeight: Font.Weight = .semibold,
        showLevel: Bool = true
    ) {
        self.playerName = playerName
        self.playerRank = playerRank
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.showLevel = showLevel
    }

    var body: some View {
        HStack(spacing: 6) {
            // Rank icon
            if let rank = playerRank {
                Image(rank.rankIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: fontSize + 2, height: fontSize + 2)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }

            // Player name
            Text(playerName)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(textColor)
                .lineLimit(1)

            // Level indicator
            if showLevel, let rank = playerRank {
                Text("LV\(rank.level)")
                    .font(.system(size: fontSize - 2, weight: .bold))
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

// MARK: - Convenience Initializers for Different Player Types

extension PlayerNameWithRankView {

    // For ConnectedPlayer
    init(connectedPlayer: ConnectedPlayer, textColor: Color = .droneTextPrimary, fontSize: CGFloat = 14, fontWeight: Font.Weight = .semibold, showLevel: Bool = true) {
        self.init(
            playerName: connectedPlayer.name,
            playerRank: connectedPlayer.rank,
            textColor: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            showLevel: showLevel
        )
    }

    // For RoomPlayer
    init(roomPlayer: RoomPlayer, textColor: Color = .droneTextPrimary, fontSize: CGFloat = 14, fontWeight: Font.Weight = .semibold, showLevel: Bool = true) {
        self.init(
            playerName: roomPlayer.name,
            playerRank: roomPlayer.rank,
            textColor: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            showLevel: showLevel
        )
    }

    // For APIPlayer
    init(apiPlayer: APIPlayer, textColor: Color = .droneTextPrimary, fontSize: CGFloat = 14, fontWeight: Font.Weight = .semibold, showLevel: Bool = true) {
        self.init(
            playerName: apiPlayer.name,
            playerRank: apiPlayer.rank,
            textColor: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            showLevel: showLevel
        )
    }

    // For local player with PlayerRankManager
    init(localPlayer: String, rankManager: PlayerRankManager, textColor: Color = .droneTextPrimary, fontSize: CGFloat = 14, fontWeight: Font.Weight = .semibold, showLevel: Bool = true) {
        self.init(
            playerName: localPlayer,
            playerRank: rankManager.localPlayerRank,
            textColor: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            showLevel: showLevel
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Player with rank
        PlayerNameWithRankView(
            playerName: "SkillfulPilot",
            playerRank: PlayerRank(level: 5, xp: 750, kills: 25, deaths: 8)
        )

        // Player without rank
        PlayerNameWithRankView(
            playerName: "NewPlayer",
            playerRank: nil
        )

        // Different styling
        PlayerNameWithRankView(
            playerName: "ProGamer",
            playerRank: PlayerRank(level: 10, xp: 2700, kills: 150, deaths: 30),
            textColor: .droneAccent,
            fontSize: 18,
            fontWeight: .bold
        )

        // Without level display
        PlayerNameWithRankView(
            playerName: "CompactView",
            playerRank: PlayerRank(level: 3, xp: 300),
            showLevel: false
        )
    }
    .padding()
    .background(Color.black)
}