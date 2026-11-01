//
//  CrateSpawnerView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct CrateSpawnerView: View {
    let sandboxManager: SandboxManager
    let onSpawnCrate: (PackageSpec, PackageType) -> Void

    @State private var selectedCrateType: PackageType = .generic
    @State private var spawnCount: Int = 1
    @State private var autoSpawn: Bool = false
    @State private var spawnTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cube.box.fill")
                        .font(.title2)
                        .foregroundColor(.green)

                    Text("Crate Spawner")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: toggleAutoSpawn) {
                        Image(systemName: autoSpawn ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(autoSpawn ? .red : .green)
                    }
                }

                if sandboxManager.isActive {
                    Text("Session: \(formatTime(sandboxManager.sessionDuration))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Crate Type Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Crate Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(PackageType.allCases, id: \.self) { crateType in
                        CrateTypeButton(
                            crateType: crateType,
                            isSelected: selectedCrateType == crateType,
                            onSelect: { selectedCrateType = crateType }
                        )
                    }
                }
            }

            // Spawn Controls
            VStack(spacing: 15) {
                // Spawn Count
                HStack {
                    Text("Spawn Count:")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 12) {
                        Button("-") {
                            spawnCount = max(1, spawnCount - 1)
                        }
                        .buttonStyle(CounterButtonStyle())
                        .disabled(spawnCount <= 1)

                        Text("\(spawnCount)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(minWidth: 30)

                        Button("+") {
                            spawnCount = min(10, spawnCount + 1)
                        }
                        .buttonStyle(CounterButtonStyle())
                        .disabled(spawnCount >= 10)
                    }
                }

                // Auto Spawn Toggle
                HStack {
                    Text("Auto Spawn:")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Spacer()

                    Toggle("", isOn: $autoSpawn)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: autoSpawn) { _, newValue in
                            if newValue {
                                startAutoSpawn()
                            } else {
                                stopAutoSpawn()
                            }
                        }
                }

                // Manual Spawn Button
                Button(action: spawnCrates) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Spawn \(spawnCount) \(selectedCrateType.displayName)\(spawnCount > 1 ? "s" : "")")
                    }
                }
                .buttonStyle(SpawnButtonStyle())
                .disabled(autoSpawn)
            }

            // Quick Actions
            VStack(spacing: 10) {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Button("Clear All") {
                        // TODO: Clear all spawned crates
                    }
                    .buttonStyle(ActionButtonStyle(color: .red))

                    Button("Random Mix") {
                        spawnRandomMix()
                    }
                    .buttonStyle(ActionButtonStyle(color: .blue))

                    Button("Challenge") {
                        spawnChallenge()
                    }
                    .buttonStyle(ActionButtonStyle(color: .orange))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.8))
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .onDisappear {
            stopAutoSpawn()
        }
    }

    // MARK: - Helper Methods

    private func spawnCrates() {
        let spec = getPackageSpec(for: selectedCrateType)

        for _ in 0..<spawnCount {
            onSpawnCrate(spec, selectedCrateType)
        }
    }

    private func spawnRandomMix() {
        let types = PackageType.allCases
        for _ in 0..<5 {
            let randomType = types.randomElement() ?? .generic
            let spec = getPackageSpec(for: randomType)
            onSpawnCrate(spec, randomType)
        }
    }

    private func spawnChallenge() {
        // Spawn a challenging mix with priority cargo
        let challengeTypes: [PackageType] = [.priorityCargo, .energyPod, .toyCrate, .generic]
        for type in challengeTypes {
            let spec = getPackageSpec(for: type)
            onSpawnCrate(spec, type)
        }
    }

    private func getPackageSpec(for type: PackageType) -> PackageSpec {
        switch type {
        case .generic, .toyCrate:
            return .medium
        case .energyPod:
            return .small
        case .priorityCargo:
            return .large
        }
    }

    private func toggleAutoSpawn() {
        autoSpawn.toggle()
    }

    private func startAutoSpawn() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            spawnCrates()
        }
    }

    private func stopAutoSpawn() {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Supporting Views

struct CrateTypeButton: View {
    let crateType: PackageType
    let isSelected: Bool
    let onSelect: () -> Void

    var crateInfo: (icon: String, color: Color) {
        switch crateType {
        case .generic:
            return ("cube", .gray)
        case .energyPod:
            return ("battery.100", .yellow)
        case .toyCrate:
            return ("gift", .pink)
        case .priorityCargo:
            return ("exclamationmark.triangle.fill", .red)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: crateInfo.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .black : crateInfo.color)

                Text(crateType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? crateInfo.color : Color.clear)
                    .stroke(crateInfo.color.opacity(0.5), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// MARK: - Button Styles

struct CounterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(Color.gray.opacity(configuration.isPressed ? 0.6 : 0.4))
            )
    }
}

struct SpawnButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
    }
}

#Preview {
    CrateSpawnerView(
        sandboxManager: SandboxManager(),
        onSpawnCrate: { _, _ in }
    )
    .frame(width: 300)
}