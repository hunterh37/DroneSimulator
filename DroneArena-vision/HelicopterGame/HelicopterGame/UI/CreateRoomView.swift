//
//  CreateRoomView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import SwiftUI

public struct CreateRoomView<Service: RoomService>: View {
    @ObservedObject var roomService: Service
    @Bindable var multiplayerManager: MultiplayerManager
    @Environment(\.dismiss) private var dismiss
    let onRoomCreated: (() -> Void)?

    @State private var roomName = ""
    @State private var selectedGameMode: MultiplayerGameMode = .freeFlight
    @State private var maxPlayers = 4
    @State private var isPrivate = false
    @State private var roomPassword = ""
    @State private var isCreating = false
    @State private var creationError: String?

    public init(roomService: Service, multiplayerManager: MultiplayerManager, onRoomCreated: (() -> Void)? = nil) {
        self.roomService = roomService
        self.multiplayerManager = multiplayerManager
        self.onRoomCreated = onRoomCreated
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: SteelLayout.xl) {
                    // Room Settings Form
                    VStack(spacing: SteelLayout.lg) {
                        // Room Name
                        SteelCard(hasHeaderStripe: true) {
                            VStack(alignment: .leading, spacing: SteelLayout.sm) {
                                Text("Room Name")
                                    .font(SteelTypography.headline)
                                    .foregroundColor(Color.textPrimary)

                                TextField("Enter room name", text: $roomName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(SteelTypography.body)
                                    .onAppear {
                                        if roomName.isEmpty {
                                            roomName = generateRandomRoomName()
                                        }
                                    }
                            }
                        }

                        // Game Mode Selection
                        SteelCard(hasHeaderStripe: true) {
                            VStack(alignment: .leading, spacing: SteelLayout.md) {
                                Text("Game Mode")
                                    .font(SteelTypography.headline)
                                    .foregroundColor(Color.textPrimary)

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: SteelLayout.md) {
                                    ForEach(MultiplayerGameMode.allCases, id: \.self) { mode in
                                        GameModeSelectionCard(
                                            gameMode: mode,
                                            isSelected: selectedGameMode == mode,
                                            onSelect: {
                                                selectedGameMode = mode
                                                maxPlayers = min(maxPlayers, mode.maxPlayers)
                                            }
                                        )
                                    }
                                }
                            }
                        }

                        // Player Limit
                        SteelCard {
                            VStack(alignment: .leading, spacing: SteelLayout.sm) {
                                HStack {
                                    Text("Max Players")
                                        .font(SteelTypography.headline)
                                        .foregroundColor(Color.textPrimary)

                                    Spacer()

                                    StatusChip("person.3.fill",
                                             label: "\(maxPlayers) players",
                                             isActive: true)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(maxPlayers) },
                                        set: { maxPlayers = Int($0) }
                                    ),
                                    in: 2...Double(selectedGameMode.maxPlayers),
                                    step: 1
                                )
                                .accentColor(Color.coreBlue)

                                HStack {
                                    Text("2")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                    Spacer()
                                    Text("\(selectedGameMode.maxPlayers)")
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.textSecondary)
                                }
                            }
                        }

                        // Privacy Settings
                        SteelCard {
                            VStack(alignment: .leading, spacing: SteelLayout.md) {
                                SteelToggle(isOn: $isPrivate, label: "Private Room")

                                if isPrivate {
                                    VStack(alignment: .leading, spacing: SteelLayout.sm) {
                                        Text("Room Code")
                                            .font(SteelTypography.body)
                                            .foregroundColor(Color.textSecondary)

                                        TextField("Optional room code", text: $roomPassword)
                                            .textFieldStyle(.roundedBorder)
                                            .font(SteelTypography.body)
                                    }
                                    .transition(.slide)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SteelLayout.xl)

                    // Error Display
                    if let error = creationError {
                        SteelCard(variant: .overlay) {
                            HStack(spacing: SteelLayout.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color.danger)
                                    .font(.system(size: 16))

                                Text(error)
                                    .font(SteelTypography.caption)
                                    .foregroundColor(Color.danger)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, SteelLayout.xl)
                    }

                    // Create Button
                    ChromeButton(isCreating ? "Creating Room..." : "Create Room",
                               icon: isCreating ? nil : "plus.circle.fill") {
                        createRoom()
                    }
                    .disabled(!canCreateRoom || isCreating)
                    .padding(.horizontal, SteelLayout.xl)

                    Spacer(minLength: SteelLayout.xl)
                }
            }
            .background(Color.night)
            .navigationTitle("Create Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.coreBlue)
                }
            }
        }
    }

    private var canCreateRoom: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createRoom() {
        guard canCreateRoom else { return }

        isCreating = true
        creationError = nil

        Task {
            do {
                let newRoom = GameRoom(
                    name: roomName.trimmingCharacters(in: .whitespacesAndNewlines),
                    hostPlayerID: multiplayerManager.localPlayerID,
                    hostPlayerName: multiplayerManager.localPlayerName,
                    currentPlayers: 1,
                    maxPlayers: maxPlayers,
                    gameMode: selectedGameMode.rawValue,
                    isPrivate: isPrivate,
                    roomCode: isPrivate && !roomPassword.isEmpty ? roomPassword : nil
                )

                let createdRoom = try await roomService.createRoom(newRoom)

                // Auto-join the created room via actual multiplayer connection
                try await multiplayerManager.joinRoom(
                    createdRoom.id,
                    roomName: createdRoom.name,
                    roomCode: createdRoom.roomCode
                )

                await MainActor.run {
                    isCreating = false
                    dismiss() // Dismiss this view
                    onRoomCreated?() // This will trigger lobby
                }
            } catch {
                await MainActor.run {
                    creationError = "Failed to create room: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }

    private func generateRandomRoomName() -> String {
        let adjectives = ["Epic", "Sky", "Cloud", "Storm", "Swift", "Lightning", "Thunder", "Nimble", "Stealth", "Turbo"]
        let nouns = ["Pilots", "Flyers", "Squadron", "Wings", "Hawks", "Eagles", "Drones", "Fleet", "Rangers", "Aces"]

        let adjective = adjectives.randomElement() ?? "Epic"
        let noun = nouns.randomElement() ?? "Pilots"
        let number = Int.random(in: 10...99)

        return "\(adjective) \(noun) \(number)"
    }
}

// MARK: - Game Mode Selection Card

public struct GameModeSelectionCard: View {
    let gameMode: MultiplayerGameMode
    let isSelected: Bool
    let onSelect: () -> Void

    public var body: some View {
        Button(action: onSelect) {
            VStack(spacing: SteelLayout.sm) {
                // Icon
                Image(systemName: gameModeIcon)
                    .font(.title)
                    .foregroundColor(isSelected ? Color.textPrimary : gameModeColor)

                // Title
                Text(gameMode.displayName)
                    .font(SteelTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? Color.textPrimary : Color.textPrimary)
                    .multilineTextAlignment(.center)

                // Description
                Text(gameMode.description)
                    .font(SteelTypography.caption)
                    .foregroundColor(isSelected ? Color.textSecondary : Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Max players
                Text("Max \(gameMode.maxPlayers)")
                    .font(SteelTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? Color.textSecondary : Color.textSecondary)
            }
            .padding(SteelLayout.md)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: SteelLayout.radiusMedium)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: SteelLayout.radiusMedium)
                                    .fill(gameModeColor.opacity(0.15))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SteelLayout.radiusMedium)
                            .stroke(isSelected ? gameModeColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var gameModeColor: Color {
        switch gameMode {
        case .freeFlight: return Color.coreBlue
        case .racing: return Color.warning
        case .delivery: return Color.success
        case .battle: return Color.danger
        }
    }

    private var gameModeIcon: String {
        switch gameMode {
        case .freeFlight: return "airplane.circle"
        case .racing: return "flag.checkered"
        case .delivery: return "shippingbox"
        case .battle: return "target"
        }
    }
}

#Preview {
    CreateRoomView(
        roomService: MockRoomService(),
        multiplayerManager: MultiplayerManager(),
        onRoomCreated: nil
    )
}
