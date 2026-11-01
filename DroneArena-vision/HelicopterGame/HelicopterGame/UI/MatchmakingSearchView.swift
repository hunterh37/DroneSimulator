//
//  MatchmakingSearchView.swift
//  HelicopterGame
//
//  Created by Claude on 10/12/25.
//

import SwiftUI

public struct MatchmakingSearchView: View {
    @Bindable var multiplayerManager: MultiplayerManager
    @StateObject private var roomService = RealRoomService()
    @State private var profileManager = GameContext.shared.playerProfile

    let onRoomJoined: () -> Void
    let onCancel: () -> Void

    @State private var searchTimer: Timer?
    @State private var attemptCount: Int = 0
    @State private var statusMessage: String = "Searching for available rooms..."
    @State private var isSearching: Bool = true
    @State private var animateSearchIcon: Bool = false

    public init(multiplayerManager: MultiplayerManager, onRoomJoined: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.multiplayerManager = multiplayerManager
        self.onRoomJoined = onRoomJoined
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Animated search icon
                searchIconView

                // Status card
                statusCardView

                // Cancel button
                cancelButtonView

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startMatchmaking()
            startSearchAnimation()
        }
        .onDisappear {
            stopMatchmaking()
        }
    }

    // MARK: - Search Icon View

    private var searchIconView: some View {
        ZStack {
            // Pulsing rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.coreBlue.opacity(0.3), lineWidth: 2)
                    .frame(width: 100 + CGFloat(index * 40), height: 100 + CGFloat(index * 40))
                    .scaleEffect(animateSearchIcon ? 1.5 : 1.0)
                    .opacity(animateSearchIcon ? 0.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.4),
                        value: animateSearchIcon
                    )
            }

            // Center icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.coreBlue.opacity(0.4), Color.coreBlue.opacity(0.1)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(animateSearchIcon ? 10 : -10))
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: animateSearchIcon
                    )
            }
        }
    }

    // MARK: - Status Card View

    private var statusCardView: some View {
        VStack(spacing: 24) {
            // Status message
            Text(statusMessage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Progress indicator
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.coreBlue)
                    .scaleEffect(1.2)

                Text("Attempt \(attemptCount)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .monospacedDigit()
            }

            // Available rooms count (if any)
            if !roomService.availableRooms.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)

                    Text("\(roomService.availableRooms.count) room\(roomService.availableRooms.count == 1 ? "" : "s") found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.15))
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "clock.fill", text: "Checking every 3 seconds")
                tipRow(icon: "person.2.fill", text: "Looking for available players")
                tipRow(icon: "bolt.fill", text: "Will join first available room")
            }
            .padding(.top, 12)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
                .stroke(Color.coreBlue.opacity(0.3), lineWidth: 2)
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.coreBlue.opacity(0.8))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Cancel Button View

    private var cancelButtonView: some View {
        Button(action: {
            stopMatchmaking()
            onCancel()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))

                Text("Cancel Search")
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
    }

    // MARK: - Matchmaking Logic

    private func startMatchmaking() {
        gameLog("🔍 [MatchmakingSearch] Starting matchmaking search...")

        // Initial search
        attemptSearch()

        // Set up timer to search every 3 seconds
        searchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            attemptSearch()
        }
    }

    private func stopMatchmaking() {
        gameLog("🔍 [MatchmakingSearch] Stopping matchmaking search")
        searchTimer?.invalidate()
        searchTimer = nil
        isSearching = false
    }

    private func attemptSearch() {
        guard isSearching else { return }

        attemptCount += 1
        gameLog("🔍 [MatchmakingSearch] Search attempt #\(attemptCount)")

        Task {
            do {
                // Refresh rooms from server
                try await roomService.refreshRooms()

                await MainActor.run {
                    statusMessage = "Found \(roomService.availableRooms.count) room(s)..."
                }

                // Try to find an available room (not full)
                if let room = roomService.availableRooms.first(where: { !$0.isFull }) {
                    gameLog("🔍 [MatchmakingSearch] Found available room: \(room.name)")

                    await MainActor.run {
                        statusMessage = "Joining \(room.name)..."
                    }

                    // Join the room via WebSocket
                    try await multiplayerManager.joinRoom(
                        room.id,
                        roomName: room.name,
                        roomCode: room.roomCode
                    )

                    // Success! Stop searching and show lobby
                    await MainActor.run {
                        gameLog("✅ [MatchmakingSearch] Successfully joined room!")
                        stopMatchmaking()
                        onRoomJoined()
                    }
                } else {
                    gameLog("🔍 [MatchmakingSearch] No available rooms found, will retry in 3s...")
                    await MainActor.run {
                        statusMessage = "No available rooms yet, searching..."
                    }
                }
            } catch {
                gameLog("❌ [MatchmakingSearch] Search failed: \(error)")
                await MainActor.run {
                    statusMessage = "Search error, retrying..."
                }
            }
        }
    }

    private func startSearchAnimation() {
        withAnimation {
            animateSearchIcon = true
        }
    }
}

// MARK: - Preview

#Preview {
    MatchmakingSearchView(
        multiplayerManager: MultiplayerManager(),
        onRoomJoined: {
            gameLog("Room joined!")
        },
        onCancel: {
            gameLog("Search cancelled")
        }
    )
}
