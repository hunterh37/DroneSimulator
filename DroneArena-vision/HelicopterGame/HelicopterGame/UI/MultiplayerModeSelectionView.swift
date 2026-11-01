//
//  MultiplayerModeSelectionView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import SwiftUI

public struct MultiplayerModeSelectionView: View {
    @Bindable var multiplayerManager: MultiplayerManager
    @StateObject private var roomService = RealRoomService()
    @State private var profileManager = GameContext.shared.playerProfile
    @State private var selectedTab: MultiplayerTab = .browse
    @State private var showingCreateRoom = false
    @State private var showingJoinByCode = false
    @State private var showingProfileSetup = false
    @State private var isQuickConnecting = false
    @State private var showingMatchmaking = false

    let onRoomJoined: () -> Void

    public init(multiplayerManager: MultiplayerManager, onRoomJoined: @escaping () -> Void = {}) {
        self.multiplayerManager = multiplayerManager
        self.onRoomJoined = onRoomJoined
    }

    public var body: some View {
        ZStack {
            // Main multiplayer content
            VStack(spacing: 0) {
                // Title section with dropdown menu
                titleSectionView

                // Header with quick actions
                headerView

                RoomBrowserView(
                    roomService: roomService,
                    multiplayerManager: multiplayerManager,
                    onRoomJoined: handleRoomJoined
                )
            }
            .blur(radius: showingProfileSetup ? 8 : 0)

            // Profile setup overlay
            if showingProfileSetup {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't allow dismissing if profile is incomplete
                        if profileManager.isProfileComplete() {
                            showingProfileSetup = false
                        }
                    }

                PlayerProfileSetupView {
                    showingProfileSetup = false
                }
            }
        }
        .sheet(isPresented: $showingCreateRoom) {
            CreateRoomView(
                roomService: roomService,
                multiplayerManager: multiplayerManager,
                onRoomCreated: {
                    onRoomJoined() // Direct lobby trigger
                }
            )
        }
        .sheet(isPresented: $showingJoinByCode) {
            JoinByCodeView(
                roomService: roomService,
                multiplayerManager: multiplayerManager,
                onRoomJoined: {
                    showingJoinByCode = false
                    onRoomJoined() // Direct lobby trigger
                }
            )
        }
        .fullScreenCover(isPresented: $showingMatchmaking) {
            MatchmakingSearchView(
                multiplayerManager: multiplayerManager,
                onRoomJoined: {
                    showingMatchmaking = false
                    onRoomJoined() // Direct lobby trigger
                },
                onCancel: {
                    showingMatchmaking = false
                }
            )
        }
        .task {
            await roomService.refreshRooms()
        }
    }

    private var titleSectionView: some View {
        HStack {
            // Player profile button
            Button(action: {
                showingProfileSetup = true
            }) {
                HStack(spacing: SteelLayout.xs) {
                    Circle()
                        .fill(profileManager.playerColor)
                        .frame(width: 16, height: 16)
                    Text(profileManager.isProfileComplete() ? profileManager.playerName : "Set Profile")
                        .font(SteelTypography.caption)
                        .foregroundColor(Color.textPrimary)
                }
                .padding(.horizontal, SteelLayout.xs)
                .padding(.vertical, SteelLayout.xxs)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }

            Spacer()

            // Actions menu
            Menu {
                Button("Edit Profile", systemImage: "person.circle") {
                    showingProfileSetup = true
                }

                Divider()

                Button("Create Room", systemImage: "plus.circle") {
                    showingCreateRoom = true
                }

                Button("Join by Code", systemImage: "number.circle") {
                    showingJoinByCode = true
                }

                Divider()

                Button("Refresh Rooms", systemImage: "arrow.clockwise") {
                    Task {
                        await roomService.refreshRooms()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(Color.textPrimary)
            }
        }
        .padding(.horizontal, SteelLayout.md)
        .padding(.top, SteelLayout.xs)
        .padding(.bottom, SteelLayout.sm)
        .background(Color.night)
    }

    private var headerView: some View {
        SteelCard(hasHeaderStripe: true) {
            VStack(spacing: SteelLayout.md) {
                // Connection status
                MultiplayerStatusBadge(multiplayerManager: multiplayerManager)

                // Quick Join button (full width, first row)
//                ChromeButton("Quick Join", icon: "bolt.fill", size: .large) {
//                    Task {
//                        isQuickConnecting = true
//                        do {
//                            // Find available room and join it
//                            try await roomService.refreshRooms()
//                            if let room = roomService.availableRooms.first(where: { !$0.isFull }) {
//                                // Join via WebSocket
//                                try await multiplayerManager.joinRoom(
//                                    room.id,
//                                    roomName: room.name,
//                                    roomCode: room.roomCode
//                                )
//
//                                // Launch immersive space
//                                await MainActor.run {
//                                    onRoomJoined()
//                                }
//                            } else {
//                                gameLog("No available rooms for quick connect")
//                            }
//                        } catch {
//                            gameLog("Quick connect failed: \(error)")
//                        }
//                        isQuickConnecting = false
//                    }
//                }
//                .disabled(isQuickConnecting)

                // Second row: Matchmaking and Create Room
                HStack(spacing: SteelLayout.sm) {
                    ChromeButton("Create", icon: "plus.circle.fill") {
                        showingCreateRoom = true
                    }
                    
                    ChromeButton("Quick Join", icon: "antenna.radiowaves.left.and.right") {
                        showingMatchmaking = true
                    }
                    .disabled(isQuickConnecting)
                }
            }
        }
        .padding(.horizontal, SteelLayout.md)
        .padding(.vertical, SteelLayout.sm)
    }

    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            ForEach(MultiplayerTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, SteelLayout.md)
        .background(Color.gunmetal.opacity(0.8))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gunmetal),
            alignment: .bottom
        )
        .onAppear {
            // Check if player profile is complete
            if !profileManager.isProfileComplete() {
                showingProfileSetup = true
            }
        }
    }

    private func tabButton(for tab: MultiplayerTab) -> some View {
        let isSelected = selectedTab == tab
        let textColor = isSelected ? Color.coreBlue : Color.textSecondary

        return Button(action: {
            selectedTab = tab
        }) {
            HStack(spacing: SteelLayout.xs) {
                Image(systemName: tab.icon)
                    .font(SteelTypography.caption)
                Text(tab.title)
                    .font(SteelTypography.caption)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SteelLayout.sm)
            .background(
                Group {
                    if isSelected {
                        selectedTabBackground
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var selectedTabBackground: some View {
        Rectangle()
            .fill(Color.coreBlue.opacity(0.1))
            .overlay(
                Rectangle()
                    .frame(height: 2)
//                    .fill(Color.coreBlue)
//                alignment: .bottom
            )
    }

    private func handleRoomJoined() {
        // Ensure profile is complete before joining
        if !profileManager.isProfileComplete() {
            showingProfileSetup = true
            return
        }
        onRoomJoined()
    }
}

// MARK: - Tab Enum

public enum MultiplayerTab: CaseIterable {
    case browse
    case quickConnect

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .quickConnect: return "Quick Join"
        }
    }

    var icon: String {
        switch self {
        case .browse: return "list.bullet"
        case .quickConnect: return "bolt"
        }
    }
}

// MARK: - Room Browser View

public struct RoomBrowserView<Service: RoomService>: View {
    @ObservedObject var roomService: Service
    @Bindable var multiplayerManager: MultiplayerManager
    @State private var searchText = ""
    let onRoomJoined: () -> Void

    public var body: some View {
        VStack(spacing: SteelLayout.lg) {
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal, SteelLayout.md)

            if roomService.isLoading {
                SteelCard {
                    VStack(spacing: SteelLayout.md) {
                        ProgressView()
                            .tint(Color.coreBlue)
                        Text("Loading rooms...")
                            .font(SteelTypography.body)
                            .foregroundColor(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SteelLayout.xl)
                }
                .padding(.horizontal, SteelLayout.md)
            } else if filteredRooms.isEmpty {
                emptyStateView
            } else {
                roomListView
            }
        }
       // .background(Color.night)
        .refreshable {
            await roomService.refreshRooms()
        }
    }

    private var filteredRooms: [GameRoom] {
        if searchText.isEmpty {
            return roomService.availableRooms
        } else {
            return roomService.availableRooms.filter { room in
                room.name.localizedCaseInsensitiveContains(searchText) ||
                room.hostPlayerName.localizedCaseInsensitiveContains(searchText) ||
                room.gameMode.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var emptyStateView: some View {
        SteelCard {
            VStack(spacing: SteelLayout.lg) {
                Image("DroneMultiplayer")
                    .resizable()
                    .frame(width: 90, height: 72)
                    .foregroundColor(Color.textSecondary)

                Text("No Rooms Available")
                    .font(SteelTypography.title)
                    .foregroundColor(Color.textPrimary)

                ChromeButton("Refresh", icon: "arrow.clockwise") {
                    Task {
                        await roomService.refreshRooms()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SteelLayout.xl)
        }
        .padding(.horizontal, SteelLayout.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var roomListView: some View {
        ScrollView {
            LazyVStack(spacing: SteelLayout.md) {
                ForEach(filteredRooms) { room in
                    RoomRowView(
                        room: room,
                        onJoin: {
                            Task {
                                do {
                                    // Join the room via actual multiplayer connection
                                    try await multiplayerManager.joinRoom(
                                        room.id,
                                        roomName: room.name,
                                        roomCode: room.roomCode
                                    )

                                    // Show the lobby
                                    await MainActor.run {
                                        onRoomJoined()
                                    }
                                } catch {
                                    gameLog("❌ Failed to join room: \(error)")
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, SteelLayout.md)
        }
    }
}

// MARK: - Quick Connect View

public struct QuickConnectView<Service: RoomService>: View {
    @ObservedObject var roomService: Service
    @Bindable var multiplayerManager: MultiplayerManager
    @Binding var isConnecting: Bool
    let onRoomJoined: () -> Void

    public var body: some View {
        VStack(spacing: SteelLayout.xl) {
            // Quick connect illustration
            SteelCard(hasHeaderStripe: true) {
                VStack(spacing: SteelLayout.lg) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Quick Connect")
                        .steelDisplayMedium()
                        .foregroundColor(Color.textPrimary)

                    Text("Find and join an available room instantly, or create a new one if none are available.")
                        .font(SteelTypography.body)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Quick connect button
            ChromeButton(isConnecting ? "Connecting..." : "Quick Connect", icon: isConnecting ? nil : "bolt.fill") {
                Task {
                    isConnecting = true
                    do {
                        // Find available room and join it
                        try await roomService.refreshRooms()
                        if let room = roomService.availableRooms.first(where: { !$0.isFull }) {
                            // Join via WebSocket
                            try await multiplayerManager.joinRoom(
                                room.id,
                                roomName: room.name,
                                roomCode: room.roomCode
                            )

                            // Launch immersive space
                            await MainActor.run {
                                onRoomJoined()
                            }
                        } else {
                            gameLog("No available rooms for quick connect")
                        }
                    } catch {
                        gameLog("Quick connect failed: \(error)")
                    }
                    isConnecting = false
                }
            }
            .disabled(isConnecting)

            // Available rooms count
            if !roomService.availableRooms.isEmpty {
                StatusChip("wifi",
                         label: "\(roomService.availableRooms.count) rooms available",
                         isActive: true)
            }

            Spacer()
        }
        .padding(SteelLayout.xl)
        .background(Color.night)
    }
}

// MARK: - Room Row View

public struct RoomRowView: View {
    let room: GameRoom
    let onJoin: () -> Void

    public var body: some View {
        SteelCard {
            HStack(spacing: SteelLayout.sm) {
                VStack(alignment: .leading, spacing: SteelLayout.xs) {
                    HStack(spacing: SteelLayout.xs) {
                        Text(room.name)
                            .font(SteelTypography.headline)
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)

                        if room.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.warning)
                        }
                    }

                    Text(room.playerCountText)
                        .font(SteelTypography.caption)
                        .foregroundColor(Color.textSecondary)

                    HStack {
                        GameModeTag(gameMode: MultiplayerGameMode(rawValue: room.gameMode) ?? .freeFlight)
                        Spacer()
                    }
                }

                Spacer()

                GlassButton(room.isFull ? "Full" : "Join") {
                    onJoin()
                }
                .disabled(room.isFull)
            }
        }
    }
}

// MARK: - Game Mode Tag

public struct GameModeTag: View {
    let gameMode: MultiplayerGameMode

    public var body: some View {
        Text(gameMode.displayName)
            .font(SteelTypography.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color.textPrimary)
            .padding(.horizontal, SteelLayout.xs)
            .padding(.vertical, SteelLayout.xxs)
            .background(
                Capsule()
                    .fill(gameModeColor)
                    .overlay(
                        Capsule()
                            .stroke(gameModeColor.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var gameModeColor: Color {
        switch gameMode {
        case .freeFlight: return Color.coreBlue
        case .racing: return Color.warning
        case .delivery: return Color.success
        case .battle: return Color.danger
        }
    }
}

// MARK: - Search Bar

public struct SearchBar: View {
    @Binding var text: String

    public var body: some View {
        HStack(spacing: SteelLayout.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textSecondary)
                .font(SteelTypography.body)

            TextField("Search rooms...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(SteelTypography.body)
                .foregroundColor(Color.textPrimary)

            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(SteelTypography.caption)
                .foregroundColor(Color.coreBlue)
            }
        }
        .padding(.horizontal, SteelLayout.md)
        .padding(.vertical, SteelLayout.sm)
        .background(
            RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: SteelLayout.radiusButton)
                        .stroke(Color.gunmetal.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    MultiplayerModeSelectionView(multiplayerManager: MultiplayerManager())
}
