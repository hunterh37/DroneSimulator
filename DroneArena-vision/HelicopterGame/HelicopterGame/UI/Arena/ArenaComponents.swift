//
//  ArenaComponents.swift
//  HelicopterGame
//
//  BATTLE GRID building blocks. Shared by menus and the in-game HUD.
//

import SwiftUI

// MARK: - Shapes

/// Forward-leaning parallelogram. The base shape of the system.
struct Slant: Shape {
    var lean: CGFloat = Arena.lean
    func path(in r: CGRect) -> Path {
        let d = r.height * lean
        var p = Path()
        p.move(to: .init(x: r.minX + d, y: r.minY))
        p.addLine(to: .init(x: r.maxX, y: r.minY))
        p.addLine(to: .init(x: r.maxX - d, y: r.maxY))
        p.addLine(to: .init(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Rectangle with top-left and bottom-right corners cut. For large panels,
/// where a full parallelogram would crop content.
struct CutRect: Shape {
    var cut: CGFloat = 16
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: r.minX + cut, y: r.minY))
        p.addLine(to: .init(x: r.maxX, y: r.minY))
        p.addLine(to: .init(x: r.maxX, y: r.maxY - cut))
        p.addLine(to: .init(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: .init(x: r.minX, y: r.maxY))
        p.addLine(to: .init(x: r.minX, y: r.minY + cut))
        p.closeSubpath()
        return p
    }
}

/// Two-row checker band. Marks start/finish moments.
struct CheckerStrip: View {
    var cell: CGFloat = 6
    var color: Color = Arena.text
    var body: some View {
        Canvas { ctx, size in
            let cols = Int(size.width / cell) + 1
            let rows = Int(size.height / cell) + 1
            for r in 0..<rows { for c in 0..<cols where (r + c) % 2 == 0 {
                ctx.fill(Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)), with: .color(color))
            } }
        }
    }
}

/// Run of forward chevrons.
struct Chevrons: View {
    var count: Int = 3
    var size: CGFloat = 12
    var color: Color = Arena.volt
    var body: some View {
        HStack(spacing: -size * 0.25) {
            ForEach(0..<count, id: \.self) { i in
                Image(systemName: "chevron.right")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(color.opacity(1 - Double(i) * 0.25))
            }
        }
    }
}

// MARK: - Panel

struct ArenaPanel<Content: View>: View {
    var accent: Color = Arena.volt
    var active: Bool = false
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CutRect().fill(active ? Arena.carbonHi : Arena.carbon))
            .overlay(CutRect().stroke(active ? accent : Arena.line, lineWidth: active ? 2 : 1))
            .overlay(alignment: .topLeading) {
                Slant().fill(accent).frame(width: 34, height: 4).offset(x: 20, y: -2).opacity(active ? 1 : 0.5)
            }
            .animation(Arena.snap, value: active)
    }
}

// MARK: - Buttons

struct ArenaPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Arena.volt
    var enabled: Bool = true
    var height: CGFloat = Arena.buttonHeight
    let action: () -> Void

    var body: some View {
        Button {
            SteelHaptics.lightTap()
            action()
        } label: {
            HStack(spacing: 12) {
                if let icon { Image(systemName: icon).font(.system(size: height * 0.28, weight: .black)) }
                Text(title).font(Arena.display(height * 0.42)).textCase(.uppercase)
                Spacer(minLength: 0)
                Chevrons(count: 3, size: height * 0.26, color: Arena.ink)
            }
            .foregroundStyle(Arena.ink)
            .padding(.horizontal, height * 0.5)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Slant().fill(enabled ? tint : Arena.textMute))
            .contentShape(Slant())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .disabled(!enabled)
    }
}

struct ArenaGhostButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Arena.text
    var height: CGFloat = 46
    let action: () -> Void

    var body: some View {
        Button {
            SteelHaptics.lightTap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .black)) }
                Text(title).font(Arena.display(17)).textCase(.uppercase)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 22)
            .frame(height: height)
            .frame(minWidth: 110)
            .background(Slant().fill(Arena.carbon))
            .overlay(Slant().stroke(tint.opacity(0.45), lineWidth: 1.5))
            .contentShape(Slant())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

struct ArenaIconButton: View {
    let icon: String
    var size: CGFloat = 46
    var tint: Color = Arena.text
    let action: () -> Void

    var body: some View {
        Button {
            SteelHaptics.lightTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .black))
                .foregroundStyle(tint)
                .frame(width: size * 1.25, height: size)
                .background(Slant().fill(Arena.carbon))
                .overlay(Slant().stroke(Arena.lineStrong, lineWidth: 1))
                .contentShape(Slant())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

// MARK: - Header

/// Screen header: back, oversized ghost step number, kicker + title,
/// slanted progress blocks.
struct ArenaStepHeader: View {
    let step: Int
    let total: Int
    let kicker: String
    let title: String
    var tint: Color = Arena.volt
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let onBack { ArenaIconButton(icon: "chevron.left", size: 40, action: onBack) }
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker).arenaLabel(12, color: tint)
                Text(title).font(Arena.display(40)).foregroundStyle(Arena.text).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%02d", step)).font(Arena.num(44)).foregroundStyle(tint)
                    + Text("/\(total)").font(Arena.num(18)).foregroundStyle(Arena.textMute)
                HStack(spacing: 3) {
                    ForEach(1...total, id: \.self) { i in
                        Slant().fill(i <= step ? tint : Arena.line).frame(width: 16, height: 5)
                    }
                }
            }
        }
        .animation(Arena.snap, value: step)
    }
}

// MARK: - Meter

/// Slanted ten-block meter. Discrete blocks compare at a glance.
struct ArenaMeter: View {
    let label: String
    let value: Int
    var tint: Color = Arena.volt

    private var lit: Int { Int((Double(value) / 10).rounded()) }

    var body: some View {
        HStack(spacing: 12) {
            Text(label).arenaLabel(12).lineLimit(1).minimumScaleFactor(0.6).frame(width: 78, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { i in
                    Slant(lean: 0.5).fill(i < lit ? tint : Color.white.opacity(0.07)).frame(height: 12)
                }
            }
            Text("\(value)").font(Arena.num(20)).foregroundStyle(Arena.text).frame(width: 36, alignment: .trailing)
        }
        .animation(Arena.snap, value: value)
    }
}

// MARK: - Small parts

struct ArenaTag: View {
    let text: String
    var tint: Color = Arena.volt
    var body: some View {
        Text(text)
            .font(Arena.display(12)).textCase(.uppercase)
            .foregroundStyle(Arena.ink)
            .padding(.horizontal, 12)
            .frame(height: 22)
            .background(Slant().fill(tint))
    }
}

struct ArenaReadout: View {
    let label: String
    let value: String
    var tint: Color = Arena.text
    var size: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).arenaLabel(10, color: Arena.textMute)
            Text(value).font(Arena.num(size)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ArenaPager: View {
    let count: Int
    let index: Int
    var tint: Color = Arena.volt
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Slant(lean: 0.8).fill(i == index ? tint : Arena.line).frame(width: i == index ? 22 : 8, height: 5)
            }
        }
        .animation(Arena.snap, value: index)
    }
}

/// Slanted segmented selector for small option sets.
struct ArenaSegmented<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    var tint: Color = Arena.volt
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { o in
                let on = o == selection
                Button {
                    SteelHaptics.lightTap()
                    withAnimation(Arena.snap) { selection = o }
                } label: {
                    Text(title(o))
                        .font(Arena.display(15)).textCase(.uppercase)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(on ? Arena.ink : Arena.textDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Slant().fill(on ? tint : Arena.carbonHi))
                        .contentShape(Slant())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
    }
}
