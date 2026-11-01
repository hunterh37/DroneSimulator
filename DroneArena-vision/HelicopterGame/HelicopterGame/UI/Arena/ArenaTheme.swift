//
//  ArenaTheme.swift
//  HelicopterGame
//
//  BATTLE GRID design language for Drone Arena.
//  The brief: armed drone racing. Everything should feel like a start grid
//  and a broadcast graphics package, not a settings app.
//
//  Rules
//  - Forward lean. Every surface is a 12 degree parallelogram; type is heavy
//    condensed italic. Nothing sits upright and still.
//  - Two hot colors with fixed jobs. VOLT (acid yellow) = go / you / race.
//    HEAT (red-orange) = weapons / damage. White is info. Nothing else glows.
//  - Asphalt, not glass. Opaque carbon panels on near-black, speed-line
//    backdrop. No blur materials, no rounded pills.
//  - Numbers are the hero. Position, speed, lap, ammo get the largest type.
//  - Checker and chevron are the only ornaments, used to mark starts,
//    finishes and forward motion.
//

import SwiftUI
import AVFoundation

enum Arena {
    // MARK: Color
    static let ink = Color(hex: "08080A")
    static let carbon = Color(hex: "131317")
    static let carbonHi = Color(hex: "1D1D23")
    static let line = Color.white.opacity(0.08)
    static let lineStrong = Color.white.opacity(0.2)
    static let text = Color.white
    static let textDim = Color(hex: "A0A0AB")
    static let textMute = Color(hex: "585862")
    static let volt = Color(hex: "E4FF1A")
    static let heat = Color(hex: "FF4A1C")
    static let hostile = Color(hex: "FF2D55")
    static let go = Color(hex: "2BFF8E")
    static let ice = Color(hex: "38D9FF")

    // MARK: Type
    /// Names, titles, calls ("RACE LEAGUE", "VICTORY").
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed).italic()
    }
    /// Numbers: speed, position, timers. Compressed so big values stay narrow.
    static func num(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.compressed).italic().monospacedDigit()
    }
    /// Small tracked labels and button text.
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.condensed)
    }
    /// Body copy. Kept upright for readability.
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    // MARK: Metrics
    static let gutter: CGFloat = 26
    static let lean: CGFloat = 0.21          // tan(12 deg): skew per point of height
    static let buttonHeight: CGFloat = 60

    // MARK: Motion
    static let snap = Animation.spring(response: 0.3, dampingFraction: 0.82)
    static let punch = Animation.spring(response: 0.22, dampingFraction: 0.6)
}

extension View {
    /// Tracked uppercase label.
    func arenaLabel(_ size: CGFloat = 11, color: Color = Arena.textDim) -> some View {
        self.font(Arena.label(size)).tracking(size * 0.16).textCase(.uppercase).foregroundStyle(color)
    }
}

// MARK: - Backdrop

/// Asphalt floor with forward-leaning speed lines and a colored heat bloom
/// from the lower right, the direction of travel.
struct ArenaBackdrop: View {
    var tint: Color = Arena.volt

    var body: some View {
        ZStack {
            Arena.ink
            Canvas { ctx, size in
                let spacing: CGFloat = 22
                let rise = size.height * 0.45
                var x: CGFloat = -rise
                var i = 0
                while x < size.width + rise {
                    var p = Path()
                    p.move(to: .init(x: x, y: size.height))
                    p.addLine(to: .init(x: x + rise, y: 0))
                    let a = i % 5 == 0 ? 0.05 : 0.018
                    ctx.stroke(p, with: .color(.white.opacity(a)), lineWidth: i % 5 == 0 ? 1.2 : 0.6)
                    x += spacing
                    i += 1
                }
            }
            RadialGradient(colors: [tint.opacity(0.22), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 560)
            RadialGradient(colors: [Arena.heat.opacity(0.08), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: tint)
    }
}

// MARK: - Sound

@MainActor
final class ArenaSound {
    static let shared = ArenaSound()
    private var player: AVAudioPlayer?
    private var flip = false

    enum Cue: String {
        case confirm = "GlitchTone1"
        case select = "GlitchTone2"
        case launch = "GlitchTone3"
        case tickA = "Glitch1"
        case tickB = "Glitch2"
    }

    func play(_ cue: Cue, volume: Float = 0.6) {
        guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = volume
        player?.play()
    }

    func tick() {
        flip.toggle()
        play(flip ? .tickA : .tickB, volume: 0.45)
    }
}
