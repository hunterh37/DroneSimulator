//
//  EnhancedBuildToolbarView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

struct EnhancedBuildToolbarView: View {
    let buildModeManager: BuildModeManager
    let placementManager: PlacementManager
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onRotate: () -> Void
    let onDelete: () -> Void

    @State private var showPresets = false
    @State private var showZoneManager = false
    @State private var showLayoutSaver = false

    private var headerRow: some View {
        HStack(spacing: DroneLayout.sm) {
            Text("Zone Constructor")
                .font(DroneTypography.headline)
                .foregroundColor(.droneTextPrimary)

            Spacer()

            DroneButton("Presets", style: .ghost, size: .small) {
                showPresets.toggle()
            }

            DroneButton("Manage", style: .ghost, size: .small) {
                showZoneManager.toggle()
            }

            DroneButton("Save", style: .ghost, size: .small) {
                showLayoutSaver.toggle()
            }
        }
    }

    private var zoneToolbar: some View {
        HStack(spacing: 10) {
            ForEach(PlaceableType.allCases, id: \.self) { zoneType in
                ZoneButton(
                    zoneType: zoneType,
                    isActive: placementManager.selectedPlaceableType == zoneType,
                    onSelect: {
                        placementManager.startPlacement(type: zoneType)
                    }
                )
            }

            Spacer()

            if placementManager.isPlacing {
                DroneButton("Rotate", icon: "arrow.clockwise", style: .secondary, size: .small) {
                    onRotate()
                }

                DroneButton("Cancel", icon: "xmark", style: .ghost, size: .small) {
                    onCancel()
                }

                DroneButton("Place", icon: "checkmark", style: .primary, size: .small) {
                    onConfirm()
                }
            } else {
                DroneButton("Delete", icon: "trash", style: .danger, size: .small) {
                    onDelete()
                }
            }
        }
    }

    private var layoutStatus: some View {
        HStack {
            // Layout validation status using our StatusIndicator
            StatusIndicator(
                buildModeManager.isLayoutValid ? .online : .warning,
                label: buildModeManager.isLayoutValid ? "Layout Ready" : "Layout Incomplete"
            )

            Spacer()

            // Zone counts with our design system
            HStack(spacing: DroneLayout.sm) {
                let layout = buildModeManager.currentLevelLayout
                ZoneCountBadge(icon: "house.fill", count: layout.hub != nil ? 1 : 0, required: 1, color: .droneWarning)
                ZoneCountBadge(icon: "shippingbox.fill", count: layout.cargoZones.count, required: 1, color: .droneInfo)
                ZoneCountBadge(icon: "location.fill", count: layout.deliveryZones.count, required: 1, color: .droneSuccess)
            }
        }
    }

    var body: some View {
        VStack(spacing: DroneLayout.md) {
            headerRow
            zoneToolbar
            layoutStatus
        }
        .sheet(isPresented: $showPresets) {
            DroneCard(variant: .primary) {
                LayoutPresetsView(buildModeManager: buildModeManager)
            }
            .frame(width: 400, height: 500)
            .background(Color.black)
        }
        .sheet(isPresented: $showZoneManager) {
            DroneCard(variant: .primary) {
                ZoneManagerView(buildModeManager: buildModeManager)
            }
            .frame(width: 350, height: 400)
            .background(Color.black)
        }
        .sheet(isPresented: $showLayoutSaver) {
            DroneCard(variant: .primary) {
                LayoutSaverView(buildModeManager: buildModeManager)
            }
            .frame(width: 300, height: 250)
            .background(Color.black)
        }
    }
}

// MARK: - Zone Button

struct ZoneButton: View {
    let zoneType: PlaceableType
    let isActive: Bool
    let onSelect: () -> Void

    var zoneInfo: (icon: String, color: Color, name: String) {
        switch zoneType {
        case .hub:
            return ("house.fill", .droneWarning, "Hub")
        case .cargo:
            return ("shippingbox.fill", .droneInfo, "Cargo")
        case .delivery:
            return ("location.fill", .droneSuccess, "Delivery")
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DroneLayout.xxs) {
                Image(systemName: zoneInfo.icon)
                    .font(DroneTypography.caption)
                    .foregroundColor(isActive ? .droneTextPrimary : zoneInfo.color)

                Text(zoneInfo.name)
                    .font(DroneTypography.caption)
                    .foregroundColor(isActive ? .droneTextPrimary : .droneTextSecondary)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: DroneLayout.radiusSM)
                    .fill(isActive ? zoneInfo.color.opacity(0.2) : .droneSurfaceGlass)
                    .stroke(isActive ? zoneInfo.color : zoneInfo.color.opacity(0.3), lineWidth: isActive ? 2 : 1)
                    .background(
                        // Glow effect for active state
                        RoundedRectangle(cornerRadius: DroneLayout.radiusSM)
                            .fill(isActive ? zoneInfo.color.opacity(0.3) : Color.clear)
                            .blur(radius: isActive ? 4 : 0)
                    )
            )
        }
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Layout Status View

struct ZoneCountBadge: View {
    let icon: String
    let count: Int
    let required: Int
    let color: Color

    var isValid: Bool {
        return count >= required
    }

    var body: some View {
        HStack(spacing: DroneLayout.xxs) {
            Image(systemName: icon)
                .font(DroneTypography.caption)
                .foregroundColor(isValid ? color : .droneError)

            Text("\(count)")
                .font(DroneTypography.caption)
                .foregroundColor(isValid ? .droneTextPrimary : .droneError)
        }
        .padding(.horizontal, DroneLayout.xs)
        .padding(.vertical, DroneLayout.xxs)
        .background(
            RoundedRectangle(cornerRadius: DroneLayout.radiusXS)
                .fill(isValid ? color.opacity(0.2) : .droneError.opacity(0.1))
                .stroke(isValid ? color.opacity(0.4) : .droneError.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views

// MARK: - Layout Presets View

struct LayoutPresetsView: View {
    let buildModeManager: BuildModeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DroneLayout.lg) {
            // Header
            HStack {
                Text("Layout Presets")
                    .font(DroneTypography.title)
                    .foregroundColor(.droneTextPrimary)

                Spacer()

                DroneButton("Done", style: .primary, size: .small) {
                    dismiss()
                }
            }

            // Presets Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                    ForEach(PresetLayouts.allPresets) { preset in
                        PresetCard(
                            preset: preset,
                            onSelect: {
                                buildModeManager.currentLevelLayout = preset.layout
                                buildModeManager.saveLayout()
                                dismiss()
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PresetCard: View {
    let preset: LayoutPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(preset.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Text(preset.difficulty.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(preset.difficulty.color))
                        )
                }

                // Description
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)

                // Stats
                HStack {
                    Text("Time: \(preset.difficulty.estimatedTime)")
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Spacer()

                    // Zone counts
                    HStack(spacing: 4) {
                        Text("H:\(preset.layout.hub != nil ? 1 : 0)")
                        Text("C:\(preset.layout.cargoZones.count)")
                        Text("D:\(preset.layout.deliveryZones.count)")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Zone Manager View

struct ZoneManagerView: View {
    let buildModeManager: BuildModeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Zone Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }

            // Zone Lists
            ScrollView {
                VStack(spacing: 15) {
                    ZoneSection(title: "Hub Zone", zones: buildModeManager.currentLevelLayout.hub != nil ? [buildModeManager.currentLevelLayout.hub!] : [], color: .yellow)
                    ZoneSection(title: "Cargo Zones", zones: buildModeManager.currentLevelLayout.cargoZones, color: .blue)
                    ZoneSection(title: "Delivery Zones", zones: buildModeManager.currentLevelLayout.deliveryZones, color: .green)
                }
            }

            // Actions
            HStack {
                DroneButton("Clear All", style: .danger, size: .small) {
                    buildModeManager.clearLayout()
                }

                Spacer()

                DroneButton("Validate", style: .primary, size: .small) {
                    // Force validation
                }
                .disabled(buildModeManager.isLayoutValid)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ZoneSection: View {
    let title: String
    let zones: [EntityPlacement]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                Spacer()

                Text("\(zones.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.3))
                    )
            }

            if zones.isEmpty {
                Text("No zones placed")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(zones.indices, id: \.self) { index in
                    let zone = zones[index]
                    HStack {
                        Text(zone.zoneID)
                            .font(.caption)
                            .foregroundColor(.white)

                        Spacer()

                        Text(String(format: "(%.1f, %.1f, %.1f)", zone.position.x, zone.position.y, zone.position.z))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.5))
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Layout Saver View

struct LayoutSaverView: View {
    let buildModeManager: BuildModeManager
    @Environment(\.dismiss) private var dismiss
    @State private var layoutName = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Layout")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(spacing: 15) {
                TextField("Layout Name", text: $layoutName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("This will save your current layout for future use.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            HStack {
                DroneButton("Cancel", style: .ghost, size: .small) {
                    dismiss()
                }

                Spacer()

                DroneButton("Save", style: .primary, size: .small) {
                    // TODO: Implement custom layout saving
                    buildModeManager.saveLayout()
                    dismiss()
                }
                .disabled(layoutName.isEmpty)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    EnhancedBuildToolbarView(
        buildModeManager: BuildModeManager(),
        placementManager: PlacementManager(),
        onConfirm: {},
        onCancel: {},
        onRotate: {},
        onDelete: {}
    )
}