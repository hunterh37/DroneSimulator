//
//  CurrentDroneStatsView.swift
//  HelicopterGame
//
//  Telemetry cluster: speed is the hero number (racing speedo), altitude
//  rides beside it. Altitude turns HEAT near the floor.
//

import SwiftUI

struct CurrentDroneStatsView: View {
    let speed: Float      // m/s
    let altitude: Float   // m

    private var mph: Int { Int(speed * 2.23694) }
    private var feet: Int { Int(altitude * 3.28084) }
    /// 0...1 against a 12 mph top end, for the rev bar.
    private var rev: CGFloat { CGFloat(min(1, max(0, speed * 2.23694 / 12))) }
    private var altTint: Color { altitude < 0.5 ? Arena.hostile : (altitude < 1 ? Arena.heat : Arena.text) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(mph)").font(Arena.num(54)).foregroundStyle(Arena.text)
                        .contentTransition(.numericText()).frame(minWidth: 56, alignment: .trailing)
                    Text("MPH").arenaLabel(11, color: Arena.volt)
                }
                HStack(spacing: 2) {
                    ForEach(0..<12, id: \.self) { i in
                        Slant(lean: 0.8)
                            .fill(CGFloat(i) / 12 < rev ? (i >= 9 ? Arena.heat : Arena.volt) : Color.white.opacity(0.08))
                            .frame(width: 9, height: 6)
                    }
                }
            }
            Rectangle().fill(Arena.line).frame(width: 1, height: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("ALT").arenaLabel(10, color: Arena.textMute)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(feet)").font(Arena.num(30)).foregroundStyle(altTint).contentTransition(.numericText())
                    Text("FT").arenaLabel(10, color: Arena.textMute)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(CutRect(cut: 12).fill(Arena.ink.opacity(0.85)))
        .overlay(CutRect(cut: 12).stroke(Arena.line, lineWidth: 1))
        .animation(.linear(duration: 0.1), value: mph)
    }
}

#Preview {
    VStack(spacing: 20) {
        CurrentDroneStatsView(speed: 2.5, altitude: 1.8)
        CurrentDroneStatsView(speed: 4.8, altitude: 0.3)
    }
    .padding()
    .background(Arena.ink)
}
