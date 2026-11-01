//
//  SafariHUDView.swift
//  HelicopterGame
//
//  Safari HUD in BATTLE GRID style. GO green is the event color; the timer
//  is the hero number and turns red in the last 10 seconds.
//

import SwiftUI

struct SafariHUDView: View {
    @State private var safari = SafariManager.shared
    var onMainMenu: () -> Void

    var body: some View {
        ZStack {
            if safari.phase == .playing {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(safari.formattedTime)
                            .font(Arena.num(46)).foregroundStyle(Arena.ink)
                            .padding(.horizontal, 20).frame(height: 64)
                            .background(Slant().fill(Arena.go))
                        stat("Score", "\(safari.score)", Arena.text)
                        stat("Pops", "\(safari.popped)", Arena.text)
                        stat("Zones", "\(safari.discovered.count)/\(SafariArea.allCases.count)", Arena.text)
                        if safari.combo > 1 {
                            Text("x\(min(safari.combo, 5))")
                                .font(Arena.num(34)).foregroundStyle(Arena.ink)
                                .padding(.horizontal, 14).frame(height: 64)
                                .background(Slant().fill(Arena.heat))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 120)
                    if let area = safari.lastDiscovery {
                        HStack(spacing: 8) {
                            Text("Zone found").arenaLabel(11, color: Arena.ink.opacity(0.7))
                            Text(area.displayName).font(Arena.display(20)).foregroundStyle(Arena.ink).textCase(.uppercase)
                        }
                        .padding(.horizontal, 22).frame(height: 40)
                        .background(Slant().fill(Arena.go))
                        .id(area)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer()
                }
                .animation(Arena.punch, value: safari.combo)
                .animation(Arena.snap, value: safari.lastDiscovery)
            } else if safari.phase == .finished {
                finished
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).arenaLabel(9, color: Arena.textMute)
            Text(value).font(Arena.num(24)).foregroundStyle(tint).contentTransition(.numericText())
        }
        .padding(.horizontal, 14).frame(height: 64)
        .background(Slant(lean: 0.15).fill(Arena.ink.opacity(0.88)))
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 14) {
            CheckerStrip(cell: 7).frame(height: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text("Safari complete").arenaLabel(12, color: Arena.go)
                Text("\(safari.score)").font(Arena.num(84)).foregroundStyle(Arena.text)
                if safari.score >= safari.highScore && safari.score > 0 {
                    ArenaTag(text: "New high score", tint: Arena.go)
                } else {
                    Text("Best \(safari.highScore)").arenaLabel(11, color: Arena.textMute)
                }
            }
            HStack(spacing: 0) {
                ArenaReadout(label: "Critters", value: "\(safari.popped)")
                ArenaReadout(label: "Best combo", value: "x\(safari.bestCombo)", tint: Arena.heat)
                ArenaReadout(label: "Zones", value: "\(safari.discovered.count)/\(SafariArea.allCases.count)")
            }
            ArenaPrimaryButton(title: "Run It Back", icon: "arrow.clockwise", tint: Arena.go) { safari.restart() }
            HStack {
                Spacer()
                ArenaGhostButton(title: "Menu", icon: "house.fill", action: onMainMenu)
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .background(CutRect(cut: 22).fill(Arena.carbon.opacity(0.97)))
        .overlay(CutRect(cut: 22).stroke(Arena.go.opacity(0.4), lineWidth: 1.5))
        .padding(.horizontal, 16)
    }
}
