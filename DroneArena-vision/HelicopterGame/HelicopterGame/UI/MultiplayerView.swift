//
//  MultiplayerView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/2/25.
//

import SwiftUI

public struct MultiplayerView: View {
    @Bindable var multiplayerManager: MultiplayerManager
    @State private var showingConnectionSheet = false
    @State private var serverHost = NetworkConfig.backendHost
    @State private var serverPort = String(NetworkConfig.defaultPort)
    @State private var roomID = ""
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var showPlayerProfileSetup = false
    @State private var profileManager = GameContext.shared.playerProfile
    @State private var lastConnectionType: ConnectionType?

    private enum ConnectionType {
        case quick
        case custom(host: String, port: UInt16)
    }

    public init(multiplayerManager: MultiplayerManager) {
        self.multiplayerManager = multiplayerManager
    }

    public var body: some View {
        VStack(spacing: SteelLayout.xl) {
            // Connection Status
            SteelCard(hasHeaderStripe: true) {
                VStack(spacing: SteelLayout.md) {
                    Text("Multiplayer Status")
                        .font(SteelTypography.headline)
                        .foregroundColor(Color.textPrimary)

                    HStack(spacing: SteelLayout.sm) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
                                    .scaleEffect(1.5)
                                    .opacity(multiplayerManager.isConnected ? 1 : 0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: multiplayerManager.isConnected)
                            )

                        Text(multiplayerManager.connectionStatus)
                            .font(SteelTypography.body)
                            .foregroundColor(Color.textSecondary)
                    }

                    if multiplayerManager.isConnected {
                        StatusChip("antenna.radiowaves.left.and.right",
                                 label: "\(multiplayerManager.remoteDrones.count) drones",
                                 isActive: true)
                    }
                }
            }

            // Connection Controls
            SteelCard {
                VStack(spacing: SteelLayout.lg) {
                    if !multiplayerManager.isConnected {
                        ChromeButton("Connect to Room", icon: "wifi") {
                            showingConnectionSheet = true
                        }
                        .disabled(isConnecting)

                        ChromeButton("Quick Connect", icon: "bolt.fill") {
                            Task {
                                await quickConnect()
                            }
                        }
                        .disabled(isConnecting)

                        GlassButton("SharePlay (Coming Soon)", icon: "shareplay") {
                            Task {
                                await connectSharePlay()
                            }
                        }
                        .disabled(true) // Disabled until SharePlay is implemented
                    } else {
                        ChromeButton("Disconnect", icon: "wifi.slash") {
                            Task {
                                await disconnect()
                            }
                        }
                    }

                    if isConnecting {
                        HStack(spacing: SteelLayout.sm) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.coreBlue))
                                .scaleEffect(0.8)
                            Text("Connecting...")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.top, SteelLayout.md)
                    }

                    if let error = connectionError {
                        SteelCard(variant: .overlay) {
                            VStack(spacing: SteelLayout.md) {
                                HStack(spacing: SteelLayout.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.danger)
                                        .font(.system(size: 16))

                                    Text(error)
                                        .font(SteelTypography.caption)
                                        .foregroundColor(Color.danger)
                                        .multilineTextAlignment(.leading)
                                }

                                // Show "Update Profile" button if error occurred
                                ChromeButton("Update Player Profile", icon: "person.circle") {
                                    showPlayerProfileSetup = true
                                }
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(SteelLayout.xl)
        .background(Color.night)
        .navigationTitle("Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingConnectionSheet) {
            connectionSheet
        }
        .sheet(isPresented: $showPlayerProfileSetup) {
            ZStack {
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)

                PlayerProfileSetupView {
                    // On profile completion, dismiss the sheet and retry connection
                    showPlayerProfileSetup = false

                    // Optionally retry the last connection attempt
                    Task {
                        await retryLastConnection()
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        if multiplayerManager.isConnected {
            return Color.success
        } else if isConnecting {
            return Color.warning
        } else {
            return Color.steel
        }
    }

    private var connectionSheet: some View {
        NavigationView {
            VStack(spacing: SteelLayout.xl) {
                Text("Connect to Multiplayer Room")
                    .steelDisplaySmall()
                    .foregroundColor(Color.textPrimary)

                SteelCard(hasHeaderStripe: true) {
                    VStack(alignment: .leading, spacing: SteelLayout.lg) {
                        Text("Server Settings")
                            .font(SteelTypography.headline)
                            .foregroundColor(Color.textPrimary)

                        VStack(alignment: .leading, spacing: SteelLayout.sm) {
                            Text("Host")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.textSecondary)
                            TextField(NetworkConfig.backendHost, text: $serverHost)
                                .textFieldStyle(.roundedBorder)
                                .font(SteelTypography.body)
                        }

                        VStack(alignment: .leading, spacing: SteelLayout.sm) {
                            Text("Port")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.textSecondary)
                            TextField("443", text: $serverPort)
                                .textFieldStyle(.roundedBorder)
                                .font(SteelTypography.body)
                                .keyboardType(.numberPad)
                        }

                        VStack(alignment: .leading, spacing: SteelLayout.sm) {
                            Text("Room ID (Optional)")
                                .font(SteelTypography.caption)
                                .foregroundColor(Color.textSecondary)
                            TextField("Enter room ID", text: $roomID)
                                .textFieldStyle(.roundedBorder)
                                .font(SteelTypography.body)
                        }
                    }
                }

                ChromeButton("Connect", icon: "wifi") {
                    Task {
                        await connectWithSettings()
                    }
                }
                .disabled(isConnecting || serverHost.isEmpty || serverPort.isEmpty)

                Spacer()
            }
            .padding(SteelLayout.xl)
            .background(Color.night)
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingConnectionSheet = false
                }
                .foregroundColor(Color.coreBlue)
            )
        }
    }

    // MARK: - Connection Actions

    private func quickConnect() async {
        isConnecting = true
        connectionError = nil
        lastConnectionType = .quick

        do {
            try await multiplayerManager.quickConnectToRoom()
            showingConnectionSheet = false
        } catch {
            connectionError = "Quick connect failed: \(error.localizedDescription)"
            // Check if profile is incomplete
            if !profileManager.isProfileComplete() {
                showPlayerProfileSetup = true
            }
        }

        isConnecting = false
    }

    private func connectWithSettings() async {
        guard let port = UInt16(serverPort) else {
            connectionError = "Invalid port number"
            return
        }

        isConnecting = true
        connectionError = nil
        lastConnectionType = .custom(host: serverHost, port: port)

        do {
            try await multiplayerManager.startWebSocketSession(host: serverHost, port: port)
            showingConnectionSheet = false
        } catch {
            connectionError = "Connection failed: \(error.localizedDescription)"
            // Check if profile is incomplete
            if !profileManager.isProfileComplete() {
                showPlayerProfileSetup = true
            }
        }

        isConnecting = false
    }

    private func connectSharePlay() async {
        isConnecting = true
        connectionError = nil

        do {
            try await multiplayerManager.startSharePlaySession()
        } catch {
            connectionError = "SharePlay not available: \(error.localizedDescription)"
        }

        isConnecting = false
    }

    private func disconnect() async {
        await multiplayerManager.endMultiplayerSession()
        connectionError = nil
    }

    private func retryLastConnection() async {
        guard let connectionType = lastConnectionType else {
            gameLog("⚠️ [MultiplayerView] No previous connection to retry")
            return
        }

        gameLog("🔄 [MultiplayerView] Retrying last connection with updated profile: '\(profileManager.playerName)' (\(profileManager.playerColorHex))")

        switch connectionType {
        case .quick:
            await quickConnect()
        case .custom(let host, let port):
            serverHost = host
            serverPort = String(port)
            await connectWithSettings()
        }
    }
}


// MARK: - Multiplayer Status Badge for Main Menu

public struct MultiplayerStatusBadge<Manager: MultiplayerManagerProtocol>: View {
    let multiplayerManager: Manager

    public init(multiplayerManager: Manager) {
        self.multiplayerManager = multiplayerManager
    }

    public var body: some View {
        HStack(spacing: SteelLayout.xs) {
            Circle()
                .fill(multiplayerManager.isConnected ? Color.success : Color.steel)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(multiplayerManager.isConnected ? Color.success.opacity(0.3) : .clear, lineWidth: 1)
                        .scaleEffect(1.5)
                        .opacity(multiplayerManager.isConnected ? 1 : 0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: multiplayerManager.isConnected)
                )

            if multiplayerManager.isConnected {
                Text("\(multiplayerManager.connectedPlayerCount) players")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
            } else {
                Text("Offline")
                    .font(SteelTypography.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(.horizontal, SteelLayout.sm)
        .padding(.vertical, SteelLayout.xs)
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

// MARK: - Backward Compatibility Extensions

extension MultiplayerStatusBadge where Manager == MultiplayerManager {
    /// Convenience initializer for the original MultiplayerManager
    public init(multiplayerManager: MultiplayerManager) {
        self.multiplayerManager = multiplayerManager
    }
}

#Preview {
    MultiplayerView(multiplayerManager: MultiplayerManager())
}