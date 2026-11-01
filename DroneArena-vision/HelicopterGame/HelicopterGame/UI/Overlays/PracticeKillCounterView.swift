//
//  PracticeKillCounterView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI

/// Wave number and defeat count in the BATTLE GRID language: VOLT for the wave,
/// HEAT for the boss wave and kills.
struct PracticeKillCounterView: View {
    let enemiesDefeated: Int
    @State private var waveManager = GameContext.shared.waves

    private var waveTint: Color { waveManager.isBossWaveActive ? Arena.heat : Arena.volt }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(waveManager.isBossWaveActive ? "Boss wave" : "Wave").arenaLabel(10, color: waveTint)
                Text("\(waveManager.currentWave)").font(Arena.num(34)).foregroundStyle(Arena.text)
                    .contentTransition(.numericText())
            }
            Rectangle().fill(Arena.line).frame(width: 1, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text("Defeated").arenaLabel(10, color: Arena.textMute)
                Text("\(enemiesDefeated)").font(Arena.num(34)).foregroundStyle(Arena.heat)
                    .contentTransition(.numericText())
            }
            if waveManager.isWaveActive {
                Text(waveManager.waveProgressText).font(Arena.num(13)).foregroundStyle(Arena.textDim)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(CutRect(cut: 10).fill(Arena.ink.opacity(0.85)))
        .overlay(CutRect(cut: 10).stroke(waveManager.isBossWaveActive ? Arena.heat : Arena.line, lineWidth: 1))
        .animation(Arena.snap, value: enemiesDefeated)
    }
}
