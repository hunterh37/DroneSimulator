//
//  GameModeOverlaysView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct GameModeOverlaysView: View {
    @Bindable var gameUIModel: GameUIModel

    var body: some View {
        VStack {
            // Top UI
            HStack {
                // Mode toggle and info (top left)
                VStack(alignment: .leading, spacing: 8) {
                    // Enhanced mode toggle for Step 3
                    EnhancedModeToggleView(
                        modeManager: gameUIModel.modeManager,
                        buildModeManager: gameUIModel.buildModeManager
                    )

                    // Show current mode info
                    CurrentModeInfoView(modeManager: gameUIModel.modeManager)
                }

                Spacer()

                // Top right UI based on mode
                topRightContent
            }
            .padding()

            Spacer()

            // Bottom UI
            bottomContent
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var topRightContent: some View {
        switch gameUIModel.modeManager.currentMode {
        case .playSandbox:
            SandboxControlsView(sandboxManager: gameUIModel.modeManager.sandboxManager)

        case .playDelivery, .play:
            DeliveryHUDView(deliveryDirector: gameUIModel.modeManager.deliveryDirector)

        case .playMultiplayer:
            EmptyView() // Multiplayer HUD handled separately

        case .playPractice, .playTimeTrial:
            EmptyView() // Practice and Time Trial HUD handled separately

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomContent: some View {
        switch gameUIModel.modeManager.currentMode {
        case .build:
            let actions = gameUIModel.handleBuildToolbarActions()
            BuildToolbarView(
                placementManager: gameUIModel.placementManager,
                onConfirm: actions.onConfirm,
                onCancel: actions.onCancel,
                onRotate: actions.onRotate,
                onDelete: actions.onDelete
            )
            .padding()

        case .playSandbox:
            SandboxToolbarView(modeManager: gameUIModel.modeManager)
                .padding()

        case .playDelivery, .play:
            DeliveryToolbarView(modeManager: gameUIModel.modeManager)
                .padding()

        case .playMultiplayer:
            EmptyView() // Multiplayer toolbar handled separately

        case .playPractice, .playTimeTrial:
            EmptyView() // Practice and Time Trial toolbar handled separately

        default:
            EmptyView()
        }
    }
}

struct EnhancedModeToggleView: View {
    let modeManager: ModeManager
    let buildModeManager: BuildModeManager

    var body: some View {
        VStack(spacing: 8) {
            Text("Current Mode")
                .font(.caption)
                .foregroundColor(.white)

            HStack(spacing: 8) {
                ForEach([GameMode.build, .playSandbox, .playDelivery], id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        currentMode: modeManager.currentMode,
                        isEnabled: mode == .build || mode == .playSandbox || buildModeManager.isLayoutValid
                    ) {
                        modeManager.switchToMode(mode)
                    }
                }

                // Menu button
                Button(action: {
                    modeManager.returnToMenu()
                }) {
                    Image(systemName: "house")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black)
                .opacity(0.7)
        )
    }
}

struct ModeButton: View {
    let mode: GameMode
    let currentMode: GameMode
    let isEnabled: Bool
    let action: () -> Void

    var modeInfo: (String, Color) {
        switch mode {
        case .build: return ("Build", .orange)
        case .playSandbox: return ("Sandbox", .green)
        case .playDelivery: return ("Delivery", .blue)
        case .playMultiplayer: return ("Multiplayer", .purple)
        case .playPractice: return ("Practice", .red)
        case .playTimeTrial: return ("Time Trial", .orange)
        default: return ("Play", .blue)
        }
    }

    var body: some View {
        Button(action: action) {
            Text(modeInfo.0)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(currentMode == mode ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentMode == mode ? modeInfo.1 : Color.clear)
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

struct CurrentModeInfoView: View {
    let modeManager: ModeManager

    var body: some View {
        switch modeManager.currentMode {
        case .build:
            Text(modeManager.buildModeManager.isLayoutValid ? "Layout Ready" : "Layout Incomplete")
                .font(.caption2)
                .foregroundColor(modeManager.buildModeManager.isLayoutValid ? .green : .orange)

        case .playSandbox:
            if let sandboxManager = modeManager.sandboxManager, sandboxManager.isActive {
                Text("Sandbox Active - \(formatTime(sandboxManager.sessionDuration))")
                    .font(.caption2)
                    .foregroundColor(.green)
            }

        case .playDelivery, .play:
            if let deliveryDirector = modeManager.deliveryDirector {
                Text("Active Jobs: \(deliveryDirector.activeJobCount)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }

        default:
            EmptyView()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Sandbox UI Components

struct SandboxControlsView: View {
    let sandboxManager: SandboxManager?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Sandbox Mode")
                .font(.caption)
                .foregroundColor(.green)

            if let manager = sandboxManager, manager.isActive {
                Text("Session: \(formatTime(manager.sessionDuration))")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.green.opacity(0.1))
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct SandboxToolbarView: View {
    let modeManager: ModeManager
    @State private var showCrateSpawner = false
    @State private var showCritterSpawner = false

    var body: some View {
        HStack(spacing: 15) {
            // Quick spawn buttons
            Button("Quick Spawn") {
                quickSpawnCrate()
            }
            .buttonStyle(SandboxButtonStyle())

            Button("Spawn Critter") {
                showCritterSpawner.toggle()
            }
            .buttonStyle(SandboxButtonStyle())

            Button("Advanced") {
                showCrateSpawner.toggle()
            }
            .buttonStyle(SandboxButtonStyle())

            Spacer()

            // Session stats
            if let sandboxManager = modeManager.sandboxManager {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Crates: \(sandboxManager.getSessionStats().activeCrates)")
                        .font(.caption2)
                        .foregroundColor(.white)

                    Text("Critters: \(sandboxManager.getSessionStats().activeCritters)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }

            Button("End Session") {
                if let sandboxManager = modeManager.sandboxManager {
                    modeManager.completeSandboxSession(timeSpent: sandboxManager.sessionDuration)
                }
            }
            .buttonStyle(EndSessionButtonStyle())
        }
        .sheet(isPresented: $showCrateSpawner) {
            if let sandboxManager = modeManager.sandboxManager {
                CrateSpawnerView(
                    sandboxManager: sandboxManager,
                    onSpawnCrate: { spec, type in
                        _ = sandboxManager.spawnCrate(spec: spec, type: type)
                    }
                )
                .frame(width: 350, height: 500)
            }
        }
        .sheet(isPresented: $showCritterSpawner) {
            if let sandboxManager = modeManager.sandboxManager {
                CritterSpawnerView(sandboxManager: sandboxManager)
                    .frame(width: 300, height: 400)
            }
        }
    }

    private func quickSpawnCrate() {
        guard let sandboxManager = modeManager.sandboxManager else { return }

        let randomType = PackageType.allCases.randomElement() ?? .generic
        let spec: PackageSpec

        switch randomType {
        case .generic, .toyCrate:
            spec = .medium
        case .energyPod:
            spec = .small
        case .priorityCargo:
            spec = .large
        }

        _ = sandboxManager.spawnCrate(spec: spec, type: randomType)
    }
}

// MARK: - Delivery UI Components

struct DeliveryHUDView: View {
    let deliveryDirector: DeliveryDirector?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("Delivery Mode")
                .font(.caption)
                .foregroundColor(.blue)

            if let director = deliveryDirector {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Jobs: \(director.activeJobCount)")
                        .font(.caption2)
                        .foregroundColor(.white)

                    // TODO: Show job timers and details
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DeliveryToolbarView: View {
    let modeManager: ModeManager

    var body: some View {
        HStack {
            Button("Pause") {
                // TODO: Implement pause functionality
            }
            .buttonStyle(SecondaryGameButtonStyle())

            Spacer()

            Button("End Mission") {
                // TODO: Collect results and end mission
                let sampleResults = SessionResults(
                    levelID: "current_level",
                    completedDeliveries: [],
                    totalJobs: 0,
                    sessionDuration: 0
                )
                modeManager.completeDeliverySession(with: sampleResults)
            }
            .buttonStyle(EndSessionButtonStyle())
        }
    }
}

// MARK: - Button Styles

struct SandboxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.4 : 0.2))
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
            )
    }
}

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(configuration.isPressed ? 0.4 : 0.2))
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
    }
}

struct EndSessionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.4 : 0.2))
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
    }
}

#Preview {
    GameModeOverlaysView(gameUIModel: GameUIModel())
}