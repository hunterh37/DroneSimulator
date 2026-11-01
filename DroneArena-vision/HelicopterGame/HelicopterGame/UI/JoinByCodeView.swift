//
//  JoinByCodeView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import SwiftUI
import Combine

public struct JoinByCodeView<Service: RoomService>: View {
    @ObservedObject var roomService: Service
    @Bindable var multiplayerManager: MultiplayerManager
    @Environment(\.dismiss) private var dismiss
    let onRoomJoined: (() -> Void)?

    @State private var roomCode = ""
    @State private var isJoining = false
    @State private var joinError: String?

    public init(roomService: Service, multiplayerManager: MultiplayerManager, onRoomJoined: (() -> Void)? = nil) {
        self.roomService = roomService
        self.multiplayerManager = multiplayerManager
        self.onRoomJoined = onRoomJoined
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("Join by Room Code")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter the room code shared by the host to join their private game.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Room Code Input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Room Code")
                            .font(.headline)

                        TextField("Enter 6-digit code", text: $roomCode)
                            .textFieldStyle(RoomCodeTextFieldStyle())
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onReceive(roomCode.publisher.collect()) {
                                // Limit to 6 characters and numbers only
                                let filtered = String($0.prefix(6).filter { $0.isNumber })
                                if filtered != roomCode {
                                    roomCode = filtered
                                }
                            }
                    }

                    // Error Display
                    if let error = joinError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Join Button
                    Button(action: joinRoom) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            Text(isJoining ? "Joining..." : "Join Room")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canJoin ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canJoin || isJoining)
                }
                .padding(.horizontal)

                Spacer()

                // Instructions
                VStack(spacing: 8) {
                    Text("Need a room code?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Ask the room host to share their 6-digit room code with you.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Join by Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canJoin: Bool {
        roomCode.count == 6 && roomCode.allSatisfy { $0.isNumber }
    }

    private func joinRoom() {
        guard canJoin else { return }

        isJoining = true
        joinError = nil

        Task {
            do {
                // In a real implementation, this would find a room by code
                // For the mock, we'll simulate finding a room
                let matchingRoom = roomService.availableRooms.first { room in
                    room.roomCode == roomCode || room.id.hasSuffix(roomCode)
                }

                if let room = matchingRoom {
                    // Join via actual multiplayer connection
                    try await multiplayerManager.joinRoom(room.id)
                    await MainActor.run {
                        onRoomJoined?() // Trigger lobby view and handle dismiss
                    }
                } else {
                    await MainActor.run {
                        joinError = "Room not found. Please check the code and try again."
                        isJoining = false
                    }
                }
            } catch {
                await MainActor.run {
                    joinError = "Failed to join room: \(error.localizedDescription)"
                    isJoining = false
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style for Room Code

public struct RoomCodeTextFieldStyle: TextFieldStyle {
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.title)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    JoinByCodeView(
        roomService: MockRoomService(),
        multiplayerManager: MultiplayerManager()
    )
}