//
//  KillfeedView.swift
//  HelicopterGame
//
//  Created by Claude on 10/5/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Killfeed View

public struct KillfeedView: View {
    @State private var healthManager = GameContext.shared.health
    @State private var playerNames: [String: String] = [:]
    @State private var currentKillstreak: Int = 0
    @State private var lastKillTime: Date?
    @State private var killstreakResetTimer: Timer?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(healthManager.killfeedEntries) { entry in
                KillfeedEntryView(
                    entry: entry,
                    killerName: getDisplayName(for: entry.killerPlayerID),
                    killedName: getDisplayName(for: entry.killedPlayerID)
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.easeInOut(duration: 0.3), value: healthManager.killfeedEntries)
            }
        }
        .frame(maxWidth: 400, alignment: .leading)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            // Remove expired entries
            healthManager.killfeedEntries.removeAll { $0.shouldExpire }
        }
        .onChange(of: healthManager.killfeedEntries.count) { oldCount, newCount in
            // Check if a new kill entry was added
            if newCount > oldCount {
                checkForPlayerKillstreak()
            }
        }
        .onAppear {
            loadPlayerNames()
        }
    }

    private func loadPlayerNames() {
        // Load player names from PlayerProfileManager or multiplayer data
        // This is a simplified version - in reality you'd get this from multiplayer session
        let profileManager = GameContext.shared.playerProfile

        // Add local player
        let networking = MultiplayerNetworking()
        let localPlayerID = networking.localPlayerID
        playerNames[localPlayerID] = profileManager.playerName

        // TODO: Add remote player names from multiplayer session
        // This would typically come from the room join success message or player joined messages
    }

    private func getDisplayName(for playerID: String) -> String {
        // Check if it's a boss
        if playerID.hasPrefix("Boss_") {
            return "Drone Boss"
        }

        // Check if it's a bot
        if playerID.hasPrefix("Bot_") {
            let botName = String(playerID.dropFirst(4)) // Remove "Bot_" prefix
            return botName.isEmpty ? "Enemy Drone" : botName
        }

        // Check for regular player names
        return playerNames[playerID] ?? "Player"
    }

    private func checkForPlayerKillstreak() {
        // Get the most recent kill entry (entries are inserted at index 0, so use .first)
        guard let latestEntry = healthManager.killfeedEntries.first else { return }

        // Check if this is our kill (local player is the killer)
        let networking = MultiplayerNetworking()
        let localPlayerID = networking.localPlayerID

        if latestEntry.killerPlayerID == localPlayerID {
            // This is our kill!
            let now = Date()

            // Reset killstreak timer
            killstreakResetTimer?.invalidate()

            // Check if this kill is within 3 seconds of the last one
            if let lastKill = lastKillTime, now.timeIntervalSince(lastKill) <= 3.0 {
                // Continue the killstreak
                currentKillstreak += 1
            } else {
                // Start a new killstreak
                currentKillstreak = 1
            }

            lastKillTime = now

            // Post killstreak notification
            NotificationCenter.default.post(
                name: .playerKillstreak,
                object: nil,
                userInfo: ["killstreak": currentKillstreak]
            )

            gameLog("🎯 Killstreak: \(currentKillstreak) kills!")

            // Start reset timer for 3 seconds
            startKillstreakResetTimer()
        }
    }

    private func startKillstreakResetTimer() {
        killstreakResetTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            // Reset killstreak after 3 seconds of no kills
            currentKillstreak = 0
            lastKillTime = nil
            gameLog("🎯 Killstreak reset after timeout")
        }
    }
}

// MARK: - Killfeed Entry View

private struct KillfeedEntryView: View {
    let entry: KillfeedEntry
    let killerName: String
    let killedName: String

    @State private var opacity: Double = 1.0

    private var isBotKill: Bool {
        entry.killedPlayerID.hasPrefix("Bot_")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Killer name
            Text(killerName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Kill icon - different for bot kills
            Image(systemName: isBotKill ? "target" : "scope")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isBotKill ? .orange : .red)

            // Killed name - different color for bots
            Text(killedName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isBotKill ? .orange : .gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.7))
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(opacity)
        .onAppear {
            // Start fade out animation after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 2.0)) {
                    opacity = 0.3
                }
            }
        }
    }
}

// MARK: - Health Bar View

public struct HealthBarView: View {
    @State private var healthManager = GameContext.shared.health

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Health text
            HStack {
                Text("HEALTH")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(healthManager.localPlayerHealth.currentHealth)/\(healthManager.localPlayerHealth.maxHealth)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Health bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black.opacity(0.5))
                        .stroke(.white.opacity(0.3), lineWidth: 1)

                    // Health fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(healthBarColor)
                        .frame(width: geometry.size.width * CGFloat(healthManager.localPlayerHealth.healthPercentage))
                        .animation(.easeInOut(duration: 0.3), value: healthManager.localPlayerHealth.healthPercentage)
                }
            }
            .frame(height: 20)
        }
        .frame(maxWidth: 200)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.7))
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(healthManager.localPlayerHealth.isAlive ? 1.0 : 0.5)
    }

    private var healthBarColor: Color {
        let healthPercent = healthManager.localPlayerHealth.healthPercentage

        if healthPercent > 0.6 {
            return .green
        } else if healthPercent > 0.3 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Respawn Overlay View

public struct RespawnOverlayView: View {
    @State private var healthManager = GameContext.shared.health
    @State private var respawnCountdown: Int = 0
    @Environment(GameUIModel.self) var gameUIModel

    public init() {}

    public var body: some View {
        // Only show in multiplayer mode when player is dead
        if gameUIModel.modeManager.currentMode == .playMultiplayer && !healthManager.localPlayerHealth.isAlive {
            ZStack {
                // Dark overlay
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Death message with Steel styling
                    VStack(spacing: 12) {
                        Text("YOU WERE ELIMINATED")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.5), radius: 8)

                        Text("Respawning in...")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    // Large countdown with modern styling
                    if respawnCountdown > 0 {
                        Text("\(respawnCountdown)")
                            .font(.system(size: 96, weight: .black))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .shadow(color: .neonBlue.opacity(0.6), radius: 20)
                            .scaleEffect(respawnCountdown <= 1 ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: respawnCountdown)
                    }
                }
            }
            .onAppear {
                startRespawnCountdown()
            }
            .onReceive(NotificationCenter.default.publisher(for: .localPlayerRespawned)) { _ in
                respawnCountdown = 0
            }
        }
    }

    private func startRespawnCountdown() {
        respawnCountdown = Int(healthManager.localPlayerHealth.respawnCooldown)

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            respawnCountdown -= 1

            if respawnCountdown <= 0 {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        KillfeedView()

        Spacer()

        VStack(alignment: .leading, spacing: 12) {
            HealthBarView()
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .onAppear {
        // Add some sample killfeed entries for preview
        let healthManager = GameContext.shared.health
        healthManager.killfeedEntries = [
            KillfeedEntry(killerPlayerID: "player1", killedPlayerID: "player2", timestamp: CACurrentMediaTime()),
            KillfeedEntry(killerPlayerID: "player3", killedPlayerID: "player1", timestamp: CACurrentMediaTime() - 2),
            KillfeedEntry(killerPlayerID: "player2", killedPlayerID: "player4", timestamp: CACurrentMediaTime() - 4)
        ]
    }
}
