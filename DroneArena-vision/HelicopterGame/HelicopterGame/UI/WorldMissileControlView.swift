//
//  WorldMissileControlView.swift
//  HelicopterGame
//
//  Created by Claude on 11/12/25.
//

import SwiftUI

/// Example view showing how to integrate the WorldMissileGridView with weapon selection
/// This is a complete UI for the world missile system with weapon slot selection
public struct WorldMissileControlView: View {
    @State private var selectedWeaponSlot: Int = 1
    @State private var gridSize: Int = 10
    @State private var lastFiredPosition: SIMD3<Float>?
    @State private var fireCount: Int = 0

    // Show/hide the grid
    @State private var isGridVisible: Bool = true

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            // Grid view
            if isGridVisible {
                gridView
                    .frame(maxWidth: 500, maxHeight: 500)
            }

            // Controls
            controlsView

            // Stats
            statsView
        }
        .padding()
        .background(Color.black.opacity(0.9))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("World Missile Targeting System")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Tap any grid cell to fire missiles from above")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        WorldMissileGridView(
            gridSize: gridSize,
            worldBounds: SIMD2<Float>(20, 20),
            weaponSlot: selectedWeaponSlot,
            highlightedCell: nil
        ) { position in
            handlePositionTapped(position)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 12) {
            // Weapon slot selector
            weaponSlotSelector

            // Grid size slider
            gridSizeSlider

            // Grid visibility toggle
            Toggle("Show Grid", isOn: $isGridVisible)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var weaponSlotSelector: some View {
        HStack(spacing: 16) {
            Text("Weapon Slot:")
                .font(.headline)
                .foregroundColor(.white)

            ForEach([1, 2], id: \.self) { slot in
                weaponSlotButton(slot: slot)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func weaponSlotButton(slot: Int) -> some View {
        Button(action: {
            selectedWeaponSlot = slot
        }) {
            VStack(spacing: 4) {
                Text("Slot \(slot)")
                    .font(.headline)

                if let weaponName = GameContext.shared.loadout.getCurrentWeaponStats(slot: slot) {
                    Text("\(weaponName.missileCount)x")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(minWidth: 100)
            .background(selectedWeaponSlot == slot ? Color.blue : Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }

    private var gridSizeSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Grid Size:")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(gridSize)x\(gridSize)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Slider(value: Binding(
                get: { Double(gridSize) },
                set: { gridSize = Int($0) }
            ), in: 5...20, step: 1)
            .accentColor(.blue)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Stats

    private var statsView: some View {
        VStack(spacing: 8) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                statItem(label: "Volleys Fired", value: "\(fireCount)")

                if let position = lastFiredPosition {
                    statItem(
                        label: "Last Target",
                        value: String(format: "X:%.1f Z:%.1f", position.x, position.z)
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    // MARK: - Actions

    private func handlePositionTapped(_ position: SIMD3<Float>) {
        lastFiredPosition = position
        fireCount += 1
        gameLog("🎯 [WorldMissileControlView] Fired at position: \(position)")
    }
}

// MARK: - Compact Version

/// A more compact version suitable for in-game overlay
public struct CompactWorldMissileGridView: View {
    @State private var selectedWeaponSlot: Int = 1

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            // Weapon slot toggle
            HStack(spacing: 8) {
                ForEach([1, 2], id: \.self) { slot in
                    Button("Slot \(slot)") {
                        selectedWeaponSlot = slot
                    }
                    .font(.caption)
                    .padding(8)
                    .background(selectedWeaponSlot == slot ? Color.blue : Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
            }

            // Compact grid
            WorldMissileGridView(
                gridSize: 8,
                worldBounds: SIMD2<Float>(20, 20),
                weaponSlot: selectedWeaponSlot
            )
            .frame(width: 200, height: 200)
        }
        .padding(12)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - Previews

#Preview("Full Control View") {
    WorldMissileControlView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}

#Preview("Compact View") {
    CompactWorldMissileGridView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
