//
//  BuildToolbarView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct BuildToolbarView: View {
    @Bindable var placementManager: PlacementManager
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onRotate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Zone type selector
            if !placementManager.isPlacing {
                VStack(spacing: 8) {
                    Text("Select Zone Type")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        ForEach(PlaceableType.allCases, id: \.self) { type in
                            Button(action: {
                                placementManager.startPlacement(type: type)
                            }) {
                                VStack {
                                    Image(systemName: iconForType(type))
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    Text(type.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colorForType(type))
                                        .opacity(0.8)
                                )
                            }
                        }
                    }
                }
            } else {
                // Placement controls
                VStack(spacing: 8) {
                    Text("Placing \(placementManager.selectedPlaceableType.rawValue.capitalized)")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 16) {
                        // Rotate button
                        Button(action: onRotate) {
                            Image(systemName: "rotate.3d")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.blue)
                                        .opacity(0.8)
                                )
                        }

                        // Confirm button
                        Button(action: onConfirm) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.green)
                                        .opacity(0.8)
                                )
                        }

                        // Cancel button
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .opacity(0.8)
                                )
                        }
                    }
                }
            }

            // Delete mode toggle
            if !placementManager.isPlacing {
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Zone")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .opacity(0.8)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .opacity(0.7)
        )
    }

    private func iconForType(_ type: PlaceableType) -> String {
        switch type {
        case .hub:
            return "house.fill"
        case .cargo:
            return "shippingbox.fill"
        case .delivery:
            return "target"
        }
    }

    private func colorForType(_ type: PlaceableType) -> Color {
        switch type {
        case .hub:
            return .blue
        case .cargo:
            return .green
        case .delivery:
            return .red
        }
    }
}

#Preview {
    BuildToolbarView(
        placementManager: PlacementManager(),
        onConfirm: {},
        onCancel: {},
        onRotate: {},
        onDelete: {}
    )
}