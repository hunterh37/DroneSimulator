//
//  ControlSchemeSelector.swift
//  HelicopterGame
//
//  Shared UI for the two control schemes: an observable store that mirrors
//  ControlSchemeConfig, a two-card selector, and a compact HUD badge.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ControlSchemeStore {
    static let shared = ControlSchemeStore()

    private(set) var scheme: DroneControlScheme = ControlSchemeConfig.current
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: ControlSchemeConfig.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                ControlSchemeStore.shared.scheme = ControlSchemeConfig.current
            }
        }
    }

    func select(_ newScheme: DroneControlScheme) {
        guard newScheme != scheme else { return }
        scheme = newScheme
        ControlSchemeConfig.current = newScheme
    }

    func toggle() {
        select(scheme == .handJoystick ? .physicalJoystick : .handJoystick)
    }
}

/// Two slanted cards. The selected one fills VOLT.
struct ControlSchemeSelector: View {
    var compact: Bool = false
    @State private var store = ControlSchemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Controls").arenaLabel(12, color: Arena.textDim)
            HStack(spacing: 8) {
                ForEach(DroneControlScheme.allCases) { card($0) }
            }
        }
        .animation(Arena.snap, value: store.scheme)
    }

    private func card(_ scheme: DroneControlScheme) -> some View {
        let on = store.scheme == scheme
        return Button {
            SteelHaptics.lightTap()
            store.select(scheme)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: scheme.symbolName)
                    .font(.system(size: compact ? 18 : 24, weight: .black))
                    .symbolEffect(.bounce, value: on)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scheme.displayName).font(Arena.display(compact ? 15 : 18)).textCase(.uppercase)
                    if !compact {
                        Text(scheme.subtitle).font(Arena.body(11)).lineLimit(2)
                            .foregroundStyle(on ? Arena.ink.opacity(0.7) : Arena.textMute)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(on ? Arena.ink : Arena.textDim)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 48 : 68)
            .background(Slant(lean: 0.15).fill(on ? Arena.volt : Arena.carbon))
            .overlay(Slant(lean: 0.15).stroke(on ? Color.clear : Arena.line, lineWidth: 1))
            .contentShape(Slant(lean: 0.15))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(scheme.displayName)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// HUD chip showing the active scheme. Tap to switch.
struct ControlSchemeBadge: View {
    @State private var store = ControlSchemeStore.shared

    var body: some View {
        Button {
            SteelHaptics.lightTap()
            store.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.scheme.symbolName)
                    .font(.system(size: 13, weight: .black))
                    .contentTransition(.symbolEffect(.replace))
                Text(store.scheme.displayName).font(Arena.display(14)).textCase(.uppercase)
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .black)).foregroundStyle(Arena.textMute)
            }
            .foregroundStyle(Arena.text)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Slant().fill(Arena.carbon))
            .overlay(Slant().stroke(Arena.lineStrong, lineWidth: 1))
            .contentShape(Slant())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .animation(Arena.snap, value: store.scheme)
        .accessibilityLabel("Controls: \(store.scheme.displayName). Tap to switch.")
    }
}
