//
//  WorldMissileGridView.swift
//  HelicopterGame
//
//  Created by Claude on 11/12/25.
//

import SwiftUI

/// SwiftUI view with a grid pattern for selecting world positions to fire missiles
/// Each grid cell represents a location in the game world
public struct WorldMissileGridView: View {
    // Grid configuration
    let gridSize: Int // Number of cells per row/column
    let worldBounds: SIMD2<Float> // Size of the game world (width, depth)
    let weaponSlot: Int // Which weapon slot to use (1 or 2)

    // Callback when a position is tapped
    var onPositionTapped: ((SIMD3<Float>) -> Void)?

    // Visual configuration
    let cellSpacing: CGFloat = 2
    let highlightedCell: GridCoordinate?

    @State private var lastTappedCell: GridCoordinate?

    public init(
        gridSize: Int = 10,
        worldBounds: SIMD2<Float> = SIMD2<Float>(20, 20),
        weaponSlot: Int = 1,
        highlightedCell: GridCoordinate? = nil,
        onPositionTapped: ((SIMD3<Float>) -> Void)? = nil
    ) {
        self.gridSize = gridSize
        self.worldBounds = worldBounds
        self.weaponSlot = weaponSlot
        self.highlightedCell = highlightedCell
        self.onPositionTapped = onPositionTapped
    }

    public var body: some View {
        GeometryReader { geometry in
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: gridSize),
                spacing: cellSpacing
            ) {
                ForEach(0..<(gridSize * gridSize), id: \.self) { index in
                    let row = index / gridSize
                    let col = index % gridSize
                    let coordinate = GridCoordinate(row: row, col: col)

                    GridCellView(
                        coordinate: coordinate,
                        isHighlighted: coordinate == highlightedCell,
                        isLastTapped: coordinate == lastTappedCell
                    )
                    .onTapGesture {
                        handleCellTap(coordinate: coordinate)
                    }
                }
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }

    private func handleCellTap(coordinate: GridCoordinate) {
        // Update last tapped cell for visual feedback
        lastTappedCell = coordinate

        // Convert grid coordinate to normalized 0-1 coordinates
        let normalizedX = Float(coordinate.col) / Float(gridSize - 1)
        let normalizedZ = Float(coordinate.row) / Float(gridSize - 1)

        // Convert to world position (centered at origin)
        let worldX = (normalizedX - 0.5) * worldBounds.x
        let worldZ = (normalizedZ - 0.5) * worldBounds.y
        let worldPosition = SIMD3<Float>(worldX, 0, worldZ)

        gameLog("🎯 [WorldMissileGridView] Tapped grid (\(coordinate.row), \(coordinate.col)) -> world position \(worldPosition)")

        // Fire missiles using WorldMissileShooter
        Task { @MainActor in
            GameContext.shared.worldMissileShooter.fireMissilesAt(targetPosition: worldPosition, slot: weaponSlot)
        }

        // Call the callback if provided
        onPositionTapped?(worldPosition)

        // Clear last tapped after a delay for visual feedback
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            await MainActor.run {
                if lastTappedCell == coordinate {
                    lastTappedCell = nil
                }
            }
        }
    }
}

// MARK: - Grid Cell View

private struct GridCellView: View {
    let coordinate: GridCoordinate
    let isHighlighted: Bool
    let isLastTapped: Bool

    var body: some View {
        Rectangle()
            .fill(cellColor)
            .overlay(
                Rectangle()
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .aspectRatio(1, contentMode: .fit)
            .animation(.easeInOut(duration: 0.2), value: isLastTapped)
    }

    private var cellColor: Color {
        if isLastTapped {
            return Color.red.opacity(0.6)
        } else if isHighlighted {
            return Color.yellow.opacity(0.4)
        } else {
            return Color.blue.opacity(0.2)
        }
    }

    private var borderColor: Color {
        if isLastTapped {
            return Color.red
        } else if isHighlighted {
            return Color.yellow
        } else {
            return Color.white.opacity(0.3)
        }
    }

    private var borderWidth: CGFloat {
        if isLastTapped || isHighlighted {
            return 2
        } else {
            return 0.5
        }
    }
}

// MARK: - Grid Coordinate

/// Represents a grid cell coordinate (row, col)
public struct GridCoordinate: Equatable, Hashable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

// MARK: - Preview

#Preview {
    WorldMissileGridView(
        gridSize: 10,
        worldBounds: SIMD2<Float>(20, 20),
        weaponSlot: 1,
        highlightedCell: GridCoordinate(row: 5, col: 5)
    ) { position in
        gameLog("Preview: Tapped position \(position)")
    }
    .frame(width: 400, height: 400)
    .padding()
}
