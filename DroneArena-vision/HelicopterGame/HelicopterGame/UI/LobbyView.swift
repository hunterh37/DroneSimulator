//
//  LobbyView.swift
//  HelicopterGame
//
//  Created by Claude on 10/10/25.
//

import SwiftUI

struct LobbyView: View {
    @Bindable var multiplayerManager: MultiplayerManager
    let onGameStart: () -> Void
    let onLeave: () -> Void

    @State private var isLocalPlayerReady = false
    @State private var showingLeaveAlert = false
    @State private var gameCountdown: Int? = nil
    @State private var countdownTimer: Timer?
    @State private var lastReceivedGameState: GameStatusMessage.GameState = .lobby
    @State private var lastGameStatusTimestamp: TimeInterval = 0
    @State private var hasStartedGame = false

    var body: some View {
        ZStack {
            // Background
            Color.night
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: SteelLayout.xl) {
                // Header
                lobbyHeaderView

                // Players list
                playersListView

                // Ready controls
                readyControlsView

                Spacer()
            }
            .padding(SteelLayout.lg)

            // Countdown overlay
            if let countdown = gameCountdown {
                countdownOverlay(countdown: countdown)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Leave") {
                    showingLeaveAlert = true
                }
                .foregroundColor(.danger)
            }
        }
        .alert("Leave Lobby?", isPresented: $showingLeaveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                onLeave()
            }
        } message: {
            Text("Are you sure you want to leave the lobby?")
        }
        .onReceive(multiplayerManager.networking.messagePublisher) { message in
            handleIncomingMessage(message)
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func triggerGameStart() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        guard !hasStartedGame else { return }
        hasStartedGame = true
        onGameStart()
    }

    // MARK: - Header View

    private var lobbyHeaderView: some View {
        SteelCard(hasHeaderStripe: true, variant: .overlay) {
            VStack(spacing: SteelLayout.md) {
                HStack {
                    VStack(alignment: .leading, spacing: SteelLayout.xs) {
                        Text(multiplayerManager.currentRoomName.isEmpty ? "Room Lobby" : multiplayerManager.currentRoomName)
                            .font(SteelTypography.headline)
                            .foregroundColor(.textPrimary)

                        if let roomCode = multiplayerManager.currentRoomCode, !roomCode.isEmpty {
                            Text("Room Code: \(roomCode)")
                                .font(SteelTypography.body)
                                .foregroundColor(.coreBlue)
                        } else {
                            Text("Waiting for players to get ready")
                                .font(SteelTypography.body)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: SteelLayout.xs) {
                        Text("\(multiplayerManager.roomPlayers.count)")
                            .font(SteelTypography.displaySmall)
                            .foregroundColor(.coreBlue)

                        Text("players")
                            .font(SteelTypography.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                // Connection status
                HStack {
                    Image(systemName: multiplayerManager.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(multiplayerManager.isConnected ? .success : .danger)

                    Text(multiplayerManager.isConnected ? "Connected" : "Connecting...")
                        .font(SteelTypography.caption)
                        .foregroundColor(.textSecondary)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Players List View

    private var playersListView: some View {
        SteelCard(variant: .overlay) {
            VStack(alignment: .leading, spacing: SteelLayout.lg) {
                HStack {
                    Text("Players")
                        .font(SteelTypography.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    StatusChip(
                        "person.3.fill",
                        label: "\(readyPlayersCount)/\(multiplayerManager.roomPlayers.count) ready",
                        isActive: allPlayersReady
                    )
                }

                ScrollView {
                    LazyVStack(spacing: SteelLayout.sm) {
                        ForEach(multiplayerManager.roomPlayers, id: \.id) { player in
                            LobbyPlayerRowView(
                                player: player,
                                isLocalPlayer: player.id == multiplayerManager.networking.localPlayerID
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: - Ready Controls View

    private var readyControlsView: some View {
        SteelCard(hasHeaderStripe: true, variant: .overlay) {
            VStack(spacing: SteelLayout.lg) {
                // Ready toggle
                HStack {
                    ChromeButton(
                        isLocalPlayerReady ? "Ready" : "Not Ready",
                        icon: isLocalPlayerReady ? "checkmark.circle.fill" : "circle",
                        size: .large
                    ) {
                        toggleReady()
                    }

                    // Start game button (only show for room creator)
                    if isRoomCreator {
                        ChromeButton(
                            "Start Game",
                            icon: "play.fill",
                            size: .large
                        ) {
                            startGame()
                        }
                        .disabled(!canStartGame)
                    }
                }

                if isRoomCreator && !canStartGame {
                    Text("All players must be ready to start")
                        .font(SteelTypography.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Countdown Overlay

    private func countdownOverlay(countdown: Int) -> some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: SteelLayout.xl) {
                Image("Prepare")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)

                if countdown > 0 {
                    Image("\(countdown)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 150)
                        .scaleEffect(1.2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: countdown)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isRoomCreator: Bool {
        // First player in the room is typically the creator
        guard let firstPlayer = multiplayerManager.roomPlayers.first else { return false }
        return firstPlayer.id == multiplayerManager.networking.localPlayerID
    }

    private var readyPlayersCount: Int {
        multiplayerManager.roomPlayers.filter { $0.isReady }.count
    }

    private var allPlayersReady: Bool {
        !multiplayerManager.roomPlayers.isEmpty &&
        multiplayerManager.roomPlayers.allSatisfy { $0.isReady }
    }

    private var canStartGame: Bool {
        isRoomCreator &&
        multiplayerManager.roomPlayers.count >= 2 &&
        allPlayersReady
    }

    // MARK: - Actions

    private func toggleReady() {
        isLocalPlayerReady.toggle()

        Task {
            await multiplayerManager.networking.sendPlayerReady(isReady: isLocalPlayerReady)
        }
    }

    private func startGame() {
        Task {
            await multiplayerManager.networking.sendGameStart()
            // Update our local game state to countdown
            await multiplayerManager.updateGameState(.countdown)
        }
    }

    private func handleIncomingMessage(_ message: MultiplayerMessage) {
        switch message {
        case .playerReady(let readyMessage):
            updatePlayerReadyStatus(playerID: readyMessage.playerID, isReady: readyMessage.isReady)

        case .gameStart(_):
            startCountdown()

        case .gameCountdown(let countdownMessage):
            gameCountdown = countdownMessage.countdown

            if countdownMessage.countdown <= 0 {
                // Game starts now
                triggerGameStart()
            }

        case .gameStatus(let statusMessage):
            handleGameStatusMessage(statusMessage)

        default:
            break
        }
    }

    private func handleGameStatusMessage(_ statusMessage: GameStatusMessage) {
        // Idempotency: Only process if this is newer than what we've seen
        // Use a small time window (0.5 seconds) to handle multiple messages from different players
        let timeSinceLastUpdate = statusMessage.timestamp - lastGameStatusTimestamp

        // Only update if:
        // 1. This is our first status message, OR
        // 2. The game state has changed, OR
        // 3. Enough time has passed since the last update (debounce)
        guard lastGameStatusTimestamp == 0 ||
              statusMessage.gameState != lastReceivedGameState ||
              timeSinceLastUpdate > 0.5 else {
            gameLog("🎮 [LobbyView] Ignoring duplicate game status from \(statusMessage.senderPlayerID)")
            return
        }

        gameLog("📊 [LobbyView] Processing game status: \(statusMessage.gameState) from \(statusMessage.senderPlayerID)")

        lastReceivedGameState = statusMessage.gameState
        lastGameStatusTimestamp = statusMessage.timestamp

        // Sync player list (safe to do multiple times)
        syncPlayerList(with: statusMessage.players)

        // Handle game state
        switch statusMessage.gameState {
        case .lobby:
            // We're in lobby - nothing special to do
            gameLog("🎮 [LobbyView] Game is in lobby state")

        case .countdown:
            // Game countdown has started
            if let countdown = statusMessage.countdownValue {
                gameLog("⏰ [LobbyView] Joining game in progress - countdown at \(countdown)")
                gameCountdown = countdown
            } else {
                // No countdown value, start our own countdown
                startCountdown()
            }

        case .active:
            // Game is already active - join immediately
            gameLog("🚀 [LobbyView] Game already active - joining now")
            triggerGameStart()

        case .ended:
            // Game has ended - stay in lobby
            gameLog("🏁 [LobbyView] Game has ended - remaining in lobby")
        }
    }

    private func syncPlayerList(with players: [RoomPlayer]) {
        // Merge the received player list with our current list
        // This ensures we have the most up-to-date player data
        for receivedPlayer in players {
            if let index = multiplayerManager.roomPlayers.firstIndex(where: { $0.id == receivedPlayer.id }) {
                // Update existing player
                multiplayerManager.roomPlayers[index] = receivedPlayer
            } else {
                // Add new player we didn't know about
                multiplayerManager.roomPlayers.append(receivedPlayer)
                gameLog("➕ [LobbyView] Added player from game status: \(receivedPlayer.name)")
            }
        }

        // Update local player ready status if we're in the list
        if let localPlayer = multiplayerManager.roomPlayers.first(where: { $0.id == multiplayerManager.networking.localPlayerID }) {
            isLocalPlayerReady = localPlayer.isReady
        }
    }

    private func updatePlayerReadyStatus(playerID: String, isReady: Bool) {
        // Update local player ready status
        if playerID == multiplayerManager.networking.localPlayerID {
            isLocalPlayerReady = isReady
        }

        // Update the player in the room players list
        if let index = multiplayerManager.roomPlayers.firstIndex(where: { $0.id == playerID }) {
            let updatedPlayer = multiplayerManager.roomPlayers[index]
            multiplayerManager.roomPlayers[index] = RoomPlayer(
                id: updatedPlayer.id,
                name: updatedPlayer.name,
                color: updatedPlayer.color,
                joinedAt: updatedPlayer.joinedAt,
                isReady: isReady,
                rank: updatedPlayer.rank,
                droneType: updatedPlayer.droneType
            )
        }
    }

    private func startCountdown() {
        guard countdownTimer == nil, !hasStartedGame else { return }
        var countdown = 3
        gameCountdown = countdown

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            gameCountdown = countdown

            if countdown <= 0 {
                timer.invalidate()
                triggerGameStart()
            }
        }
    }
}

// MARK: - Player Row View

struct LobbyPlayerRowView: View {
    let player: RoomPlayer
    let isLocalPlayer: Bool

    var body: some View {
        HStack(spacing: SteelLayout.md) {
            // Player rank icon
            if let rank = player.rank {
                Image(rank.rankIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                // Fallback for players without rank
                Image("Rank1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            }

            // Player info
            VStack(alignment: .leading, spacing: SteelLayout.xxs) {
                HStack(spacing: SteelLayout.xs) {
                    PlayerNameWithRankView(
                        roomPlayer: player,
                        textColor: .textPrimary,
                        fontSize: 16,
                        fontWeight: .semibold
                    )

                    if isLocalPlayer {
                        Text("(You)")
                            .font(SteelTypography.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Text("Joined recently")
                    .font(SteelTypography.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            // Ready status
            StatusChip(
                player.isReady ? "checkmark.circle.fill" : "circle",
                label: player.isReady ? "Ready" : "Not Ready",
                isActive: player.isReady
            )
        }
        .padding(.vertical, SteelLayout.xs)
        .padding(.horizontal, SteelLayout.sm)
        .background(
            isLocalPlayer ?
            RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                .fill(Color.coreBlue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SteelLayout.radiusLarge)
                        .stroke(Color.coreBlue.opacity(0.3), lineWidth: 1)
                ) : nil
        )
    }
}

// MARK: - Helper Functions

private func colorFromHex(_ hex: String) -> Color {
    let cleanHex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard cleanHex.count == 6 else { return .coreBlue }

    let scanner = Scanner(string: cleanHex)
    var hexNumber: UInt64 = 0

    if scanner.scanHexInt64(&hexNumber) {
        let r = Double((hexNumber & 0xff0000) >> 16) / 255
        let g = Double((hexNumber & 0x00ff00) >> 8) / 255
        let b = Double(hexNumber & 0x0000ff) / 255
        return Color(red: r, green: g, blue: b)
    }

    return .coreBlue
}

#Preview {
    LobbyView(
        multiplayerManager: MultiplayerManager(),
        onGameStart: {},
        onLeave: {}
    )
}
