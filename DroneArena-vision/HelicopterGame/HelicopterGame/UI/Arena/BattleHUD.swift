//
//  BattleHUD.swift
//  HelicopterGame
//
//  In-flight HUD parts. Same BATTLE GRID language as the menus, tuned for
//  glanceability: fewer words, bigger numbers, color only when state changes.
//

import SwiftUI

// MARK: - Armor gauge

/// Twenty slanted cells. VOLT when healthy, HEAT under 60%, red and pulsing
/// under 30%. The number is secondary; the shape of the bar is the read.
struct BattleHealthGauge: View {
    @State private var health = GameContext.shared.health
    @State private var pulse = false

    private var pct: Double { Double(health.localPlayerHealth.healthPercentage) }
    private var tint: Color { pct > 0.6 ? Arena.volt : (pct > 0.3 ? Arena.heat : Arena.hostile) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text("Armor").arenaLabel(11, color: tint)
                Spacer()
                Text("\(health.localPlayerHealth.currentHealth)").font(Arena.num(26)).foregroundStyle(Arena.text)
                    .contentTransition(.numericText())
                Text("/\(health.localPlayerHealth.maxHealth)").font(Arena.num(14)).foregroundStyle(Arena.textMute)
            }
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    Slant(lean: 0.6)
                        .fill(Double(i) / 20 < pct ? tint : Color.white.opacity(0.07))
                        .frame(height: 12)
                }
            }
            .opacity(pct <= 0.3 && pulse ? 0.45 : 1)
        }
        .frame(width: 240)
        .padding(12)
        .background(CutRect(cut: 12).fill(Arena.ink.opacity(0.85)))
        .overlay(CutRect(cut: 12).stroke(Arena.line, lineWidth: 1))
        .opacity(health.localPlayerHealth.isAlive ? 1 : 0.5)
        .animation(Arena.snap, value: pct)
        .onAppear { withAnimation(.easeInOut(duration: 0.45).repeatForever()) { pulse = true } }
    }
}

// MARK: - Hardpoint

/// Fire button for one missile slot. Tap fires, long-press swaps.
struct HardpointButton: View {
    let slot: Int
    let weapon: MissileWeapon?
    let armed: Bool
    let onFire: () -> Void
    let onSwap: () -> Void
    @State private var kick = false

    private var tint: Color { slot == 1 ? Arena.heat : Arena.volt }

    var body: some View {
        Button {
            SteelHaptics.lightTap()
            withAnimation(Arena.punch) { kick = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(Arena.snap) { kick = false } }
            onFire()
        } label: {
            HStack(spacing: 8) {
                Text(slot == 1 ? "A" : "B").font(Arena.num(30)).foregroundStyle(armed ? Arena.ink : tint)
                    .frame(width: 34, height: 70)
                    .background(Slant().fill(armed ? tint : Arena.carbonHi))
                VStack(spacing: 2) {
                    Group {
                        if let w = weapon, UIImage(named: w.imageName) != nil {
                            Image(w.imageName).resizable().scaledToFit()
                        } else {
                            Image(systemName: "scope").font(.system(size: 22, weight: .black)).foregroundStyle(tint)
                        }
                    }
                    .frame(width: 44, height: 40)
                    .rotationEffect(.degrees(35))
                    Text(weapon.map { "x\($0.missileCount)" } ?? "--").font(Arena.num(14)).foregroundStyle(Arena.textDim)
                }
                .frame(width: 52)
            }
            .padding(6)
            .background(CutRect(cut: 10).fill(Arena.ink.opacity(0.85)))
            .overlay(CutRect(cut: 10).stroke(armed ? tint : Arena.line, lineWidth: armed ? 2 : 1))
            .scaleEffect(kick ? 0.92 : 1)
            .contentShape(CutRect(cut: 10))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in onSwap() })
        .accessibilityLabel("Fire hardpoint \(slot == 1 ? "A" : "B"). Long press to swap.")
    }
}

// MARK: - Launch

/// Pre-flight start grid: event name over a checker band, control choice,
/// and one LAUNCH button.
struct LaunchGridOverlay: View {
    let eventName: String
    let tint: Color
    let onLaunch: () -> Void
    let onHelp: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            ArenaBackdrop(tint: tint).opacity(0.97)
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                CheckerStrip(cell: 8).frame(height: 16).opacity(0.9)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Grid ready").arenaLabel(13, color: tint)
                    Text(eventName).font(Arena.display(58)).foregroundStyle(Arena.text).textCase(.uppercase)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                .offset(x: shown ? 0 : -40)
                .opacity(shown ? 1 : 0)
                ControlSchemeSelector()
                ArenaPrimaryButton(title: "Launch", icon: "bolt.fill", tint: tint, height: 72) {
                    ArenaSound.shared.play(.launch, volume: 0.8)
                    onLaunch()
                }
                Button(action: onHelp) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark").font(.system(size: 11, weight: .black))
                        Text("How to fly").arenaLabel(12, color: Arena.textDim)
                    }
                    .foregroundStyle(Arena.textDim)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, Arena.gutter + 6)
        }
        .onAppear { withAnimation(Arena.snap.delay(0.1)) { shown = true } }
    }
}

// MARK: - Exit confirm

struct ExitConfirmPanel: View {
    let onStay: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Arena.ink.opacity(0.88).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("Retire from event?").arenaLabel(12, color: Arena.hostile)
                Text("Leave the arena").font(Arena.display(40)).foregroundStyle(Arena.text).textCase(.uppercase)
                Text("Current run progress is lost.").font(Arena.body(14)).foregroundStyle(Arena.textDim)
                HStack(spacing: 10) {
                    ArenaGhostButton(title: "Stay", action: onStay)
                    ArenaPrimaryButton(title: "Retire", icon: "flag.slash.fill", tint: Arena.hostile, height: 46, action: onExit)
                }
            }
            .padding(24)
            .background(CutRect(cut: 18).fill(Arena.carbon))
            .overlay(CutRect(cut: 18).stroke(Arena.hostile.opacity(0.5), lineWidth: 1.5))
            .padding(.horizontal, Arena.gutter)
        }
    }
}
