//
//  DroneSelectionView.swift
//  HelicopterGame
//
//  Step 02, the garage. Drone on a lit platform with its livery color
//  bleeding into the floor; oversized name and rating read like a driver
//  intro card. Three slanted meters compare frames while paging.
//

import SwiftUI

struct DroneSelectionView: View {
    @Environment(EconomyModel.self) var economyModel
    @State private var droneRegistry = DroneRegistry()
    @State private var selectionManager = DroneSelectionManager()
    @State private var index = 0
    @State private var direction: CGFloat = 1

    let onDroneSelected: (Drone) -> Void
    let onCancel: () -> Void

    private var drones: [Drone] { droneRegistry.availableDrones(for: economyModel.playerProfile) }
    private var current: Drone? { drones.indices.contains(index) ? drones[index] : nil }
    private var livery: Color { current.map { Color(hex: $0.primaryColor) } ?? Arena.volt }

    var body: some View {
        ZStack {
            ArenaBackdrop(tint: livery)
            VStack(alignment: .leading, spacing: 16) {
                ArenaStepHeader(step: 2, total: 3, kicker: "Pick your frame", title: "Garage", onBack: onCancel)
                platform
                if let d = current {
                    intro(d).id(d.id).transition(.opacity.combined(with: .offset(x: 20 * direction)))
                    VStack(spacing: 9) {
                        ArenaMeter(label: "Speed", value: d.speed, tint: Arena.volt)
                        ArenaMeter(label: "Firepower", value: d.damage, tint: Arena.heat)
                        ArenaMeter(label: "Armor", value: d.health, tint: Arena.ice)
                    }
                }
                Spacer(minLength: 0)
                ArenaPrimaryButton(title: "Lock Frame", tint: Arena.volt, enabled: current != nil) { confirm() }
            }
            .padding(.horizontal, Arena.gutter)
            .padding(.top, 26)
            .padding(.bottom, 22)
        }
        .onAppear(perform: restore)
    }

    // MARK: Platform

    private var platform: some View {
        ZStack {
            // Floor disc in livery color.
            Ellipse()
                .fill(RadialGradient(colors: [livery.opacity(0.55), livery.opacity(0.0)], center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 360, height: 70)
                .offset(y: 100)
            Ellipse().stroke(livery.opacity(0.6), lineWidth: 1.5).frame(width: 250, height: 42).offset(y: 100)
            if let d = current {
                DroneSceneView(
                    droneModelName: d.modelName,
                    rotationSpeed: 20.0,
                    cameraDistance: 1.3,
                    lightingIntensity: 0.85,
                    primaryColor: d.primaryColor,
                    accentColor: d.accentColor,
                    modelRotationX: d.modelRotationX
                )
                .id(d.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 60 * direction)),
                    removal: .opacity.combined(with: .offset(x: -60 * direction))
                ))
            }
            HStack {
                ArenaIconButton(icon: "chevron.left", size: 50) { page(-1) }
                Spacer()
                ArenaIconButton(icon: "chevron.right", size: 50) { page(1) }
            }
            .opacity(drones.count > 1 ? 1 : 0)
            VStack {
                Spacer()
                ArenaPager(count: drones.count, index: index, tint: livery)
            }
        }
        .frame(height: 270)
        .clipped()
    }

    // MARK: Intro card

    private func intro(_ d: Drone) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ArenaTag(text: d.droneClass.displayName, tint: livery)
                    Text(String(format: "#%02d", index + 1)).arenaLabel(11, color: Arena.textMute)
                }
                Text(d.displayName).font(Arena.display(32)).foregroundStyle(Arena.text).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(d.description).font(Arena.body(13)).foregroundStyle(Arena.textDim).lineLimit(2, reservesSpace: true)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("RTG").arenaLabel(10, color: Arena.textMute)
                Text("\(d.combatRating)").font(Arena.num(52)).foregroundStyle(livery)
            }
        }
    }

    // MARK: Actions

    private func restore() {
        if let d = selectionManager.selectedDrone(from: droneRegistry),
           let i = drones.firstIndex(where: { $0.id == d.id }) { index = i }
    }

    private func page(_ step: Int) {
        guard drones.count > 1 else { return }
        SteelHaptics.lightTap()
        ArenaSound.shared.tick()
        direction = CGFloat(step)
        withAnimation(Arena.snap) { index = (index + step + drones.count) % drones.count }
    }

    private func confirm() {
        guard let d = current else { return }
        SteelHaptics.successFeedback()
        ArenaSound.shared.play(.confirm, volume: 0.6)
        selectionManager.selectDrone(d.id)
        onDroneSelected(d)
    }
}
