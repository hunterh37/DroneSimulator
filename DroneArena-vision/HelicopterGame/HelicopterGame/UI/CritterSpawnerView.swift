//
//  CritterSpawnerView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct CritterSpawnerView: View {
    let sandboxManager: SandboxManager

    @State private var selectedCritterType: CritterType = .bunny
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title2)
                    .foregroundColor(.pink)

                Text("Critter Spawner")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }

            // Critter Type Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Critter Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(CritterType.allCases, id: \.self) { critterType in
                        CritterTypeButton(
                            critterType: critterType,
                            isSelected: selectedCritterType == critterType,
                            onSelect: { selectedCritterType = critterType }
                        )
                    }
                }
            }

            // Critter Info
            VStack(spacing: 10) {
                Text("\(selectedCritterType.displayName) Stats")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                VStack(spacing: 6) {
                    HStack {
                        Text("Speed:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f", selectedCritterType.movementSpeed))
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("Bounce:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(String(format: "%.1f", selectedCritterType.bounceHeight))
                            .foregroundColor(.white)
                    }
                }
                .font(.caption)
                .padding(.horizontal)
            }

            // Current Critters
            VStack(spacing: 10) {
                Text("Current Critters")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                VStack(spacing: 4) {
                    ForEach(CritterType.allCases, id: \.self) { type in
                        let count = sandboxManager.critterManager.activeCritters.filter { $0.critterType == type }.count
                        if count > 0 {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(count)")
                                    .foregroundColor(.white)
                            }
                            .font(.caption)
                        }
                    }

                    if sandboxManager.critterManager.activeCritters.isEmpty {
                        Text("No critters spawned")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Action Buttons
            VStack(spacing: 15) {
                Button(action: spawnSelectedCritter) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Spawn \(selectedCritterType.displayName)")
                    }
                }
                .buttonStyle(SpawnCritterButtonStyle())

                HStack(spacing: 12) {
                    Button("Spawn Random") {
                        spawnRandomCritter()
                    }
                    .buttonStyle(ActionCritterButtonStyle(color: .blue))

                    Button("Clear All") {
                        clearAllCritters()
                    }
                    .buttonStyle(ActionCritterButtonStyle(color: .red))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.pink.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Methods

    private func spawnSelectedCritter() {
        _ = sandboxManager.spawnCritter(type: selectedCritterType)
    }

    private func spawnRandomCritter() {
        let randomType = CritterType.allCases.randomElement() ?? .bunny
        _ = sandboxManager.spawnCritter(type: randomType)
    }

    private func clearAllCritters() {
        sandboxManager.critterManager.clearAllCritters()
    }
}

// MARK: - Supporting Views

struct CritterTypeButton: View {
    let critterType: CritterType
    let isSelected: Bool
    let onSelect: () -> Void

    var critterInfo: (icon: String, color: Color) {
        switch critterType {
        case .bunny:
            return ("🐰", .white)
        case .bird:
            return ("🐦", .blue)
        case .cat:
            return ("🐱", .orange)
        case .robot:
            return ("🤖", .gray)
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(critterInfo.icon)
                    .font(.title)

                Text(critterType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .black : .white)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? critterInfo.color : Color.clear)
                    .stroke(critterInfo.color.opacity(0.5), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// MARK: - Button Styles

struct SpawnCritterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pink.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
    }
}

struct ActionCritterButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
    }
}

#Preview {
    CritterSpawnerView(sandboxManager: SandboxManager())
        .frame(width: 300, height: 400)
}