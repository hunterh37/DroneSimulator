//
//  OnlinePlayerCountView.swift
//  HelicopterGame
//
//  Created by Claude on 10/18/25.
//

import SwiftUI

public struct OnlinePlayerCountView: View {
    let multiplayerManager: MultiplayerManager

    public init(multiplayerManager: MultiplayerManager) {
        self.multiplayerManager = multiplayerManager
    }

    public var body: some View {
        HStack(spacing: SteelLayout.sm) {
            Image(systemName: "person.2.fill")
                .font(SteelTypography.caption)
                .foregroundColor(.textSecondary.opacity(0.6))

            Text("\(multiplayerManager.connectedPlayerCount) players online")
                .font(SteelTypography.caption)
                .foregroundColor(.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, SteelLayout.md)
        .padding(.vertical, SteelLayout.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
