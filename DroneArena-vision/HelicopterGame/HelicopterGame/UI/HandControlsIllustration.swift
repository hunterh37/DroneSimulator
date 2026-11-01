//
//  HandControlsIllustration.swift
//  HelicopterGame
//
//  Vector illustration of the two-hand thumb joystick controls.
//  Left thumb: up/down = altitude, left/right = turn (yaw).
//  Right thumb: push away/pull back = forward/backward, left/right = strafe.
//

import SwiftUI

struct HandControlsIllustration: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            HandControlPanel(side: .left)
            HandControlPanel(side: .right)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Raise both hands with thumbs up. Left thumb: move up or down to change altitude, left or right to turn. Right thumb: push away or pull back to fly forward or backward, left or right to strafe."
        )
    }
}

private enum HandSideArt {
    case left, right

    var title: String { self == .left ? "LEFT HAND" : "RIGHT HAND" }
    var subtitle: String { self == .left ? "Altitude + Turn" : "Fly + Strafe" }
    var light: Color { self == .left ? Color(red: 0.50, green: 0.83, blue: 1.0) : Color(red: 0.62, green: 1.0, blue: 0.66) }
    var dark: Color { self == .left ? Color(red: 0.12, green: 0.44, blue: 0.72) : Color(red: 0.13, green: 0.59, blue: 0.29) }
    var ink: Color { self == .left ? Color(red: 0.05, green: 0.23, blue: 0.39) : Color(red: 0.04, green: 0.30, blue: 0.13) }
}

private struct HandControlPanel: View {
    let side: HandSideArt

    var body: some View {
        VStack(spacing: 10) {
            Text(side.title)
                .font(.system(size: 15, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(side.light)
            Text(side.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            HandDiagram(side: side)
                .aspectRatio(300.0 / 340.0, contentMode: .fit)
                .frame(maxWidth: 300)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(side.dark.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(side.light.opacity(0.35), lineWidth: 1.5)
                )
        )
    }
}

/// Drawn in a 300 x 340 design space, scaled to fit.
private struct HandDiagram: View {
    let side: HandSideArt

    private static let designSize = CGSize(width: 300, height: 340)
    /// Thumb tip in design space (left-hand layout, before mirroring).
    private static let tip = CGPoint(x: 150, y: 120)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.designSize.width, size.height / Self.designSize.height)
            let offsetX = (size.width - Self.designSize.width * scale) / 2
            var ctx = context
            ctx.translateBy(x: offsetX, y: 0)
            ctx.scaleBy(x: scale, y: scale)

            if side == .right {
                drawDepthPlane(in: ctx)
            }
            drawHand(in: ctx)
            if side == .left {
                drawAltitudeAndYaw(in: ctx)
            } else {
                drawForwardAndStrafe(in: ctx)
            }
        }
    }

    // MARK: Hand

    /// Fist with thumb up. Knuckles face the center of the illustration.
    private func handParts() -> [Path] {
        let raw: [Path] = [
            Path { p in
                p.move(to: CGPoint(x: 102, y: 262))
                p.addLine(to: CGPoint(x: 160, y: 262))
                p.addLine(to: CGPoint(x: 172, y: 340))
                p.addLine(to: CGPoint(x: 86, y: 340))
                p.closeSubpath()
            },
            Path(roundedRect: CGRect(x: 84, y: 150, width: 110, height: 128), cornerRadius: 34),
            Path(roundedRect: CGRect(x: 148, y: 156, width: 70, height: 30), cornerRadius: 15),
            Path(roundedRect: CGRect(x: 152, y: 186, width: 68, height: 30), cornerRadius: 15),
            Path(roundedRect: CGRect(x: 150, y: 216, width: 64, height: 30), cornerRadius: 15),
            Path(roundedRect: CGRect(x: 144, y: 246, width: 56, height: 28), cornerRadius: 14),
            Path(roundedRect: CGRect(x: 129, y: 100, width: 42, height: 120), cornerRadius: 21),
        ]
        return raw.map(mirrored)
    }

    private func drawHand(in ctx: GraphicsContext) {
        let parts = handParts()
        for part in parts {
            ctx.stroke(part, with: .color(side.light.opacity(0.35)), lineWidth: 10)
        }
        let fill = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [side.light, side.dark]),
            startPoint: CGPoint(x: 0, y: 100),
            endPoint: CGPoint(x: 0, y: 340)
        )
        for part in parts {
            ctx.fill(part, with: fill)
        }

        var creases = Path()
        creases.move(to: CGPoint(x: 164, y: 186)); creases.addLine(to: CGPoint(x: 214, y: 186))
        creases.move(to: CGPoint(x: 164, y: 216)); creases.addLine(to: CGPoint(x: 212, y: 216))
        creases.move(to: CGPoint(x: 160, y: 246)); creases.addLine(to: CGPoint(x: 196, y: 246))
        ctx.stroke(mirrored(creases), with: .color(side.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        let nail = Path(roundedRect: CGRect(x: 137, y: 108, width: 26, height: 20), cornerRadius: 8)
        ctx.stroke(mirrored(nail), with: .color(.white.opacity(0.7)), lineWidth: 2.5)
    }

    // MARK: Left hand overlays

    private func drawAltitudeAndYaw(in ctx: GraphicsContext) {
        let tip = Self.tip
        let accent = Color.white

        // Altitude: double-headed vertical arrow beside the thumb.
        let altX: CGFloat = 44
        drawArrow(in: ctx, from: CGPoint(x: altX, y: 120), to: CGPoint(x: altX, y: 52), color: accent)
        drawArrow(in: ctx, from: CGPoint(x: altX, y: 120), to: CGPoint(x: altX, y: 188), color: accent)
        drawLabel(in: ctx, "UP", at: CGPoint(x: altX, y: 34))
        drawLabel(in: ctx, "DOWN", at: CGPoint(x: altX, y: 206))

        // Turn left / right: curved arrows around the thumb tip.
        let radius: CGFloat = 62
        var leftArc = Path()
        leftArc.addArc(center: tip, radius: radius, startAngle: .degrees(-115), endAngle: .degrees(-170), clockwise: true)
        var rightArc = Path()
        rightArc.addArc(center: tip, radius: radius, startAngle: .degrees(-65), endAngle: .degrees(-10), clockwise: false)
        ctx.stroke(leftArc, with: .color(side.light), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        ctx.stroke(rightArc, with: .color(side.light), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        drawHead(in: ctx, at: point(on: tip, radius: radius, degrees: -170), direction: .degrees(-170 - 90), color: side.light)
        drawHead(in: ctx, at: point(on: tip, radius: radius, degrees: -10), direction: .degrees(-10 + 90), color: side.light)
        drawLabel(in: ctx, "TURN L", at: CGPoint(x: 98, y: 136))
        drawLabel(in: ctx, "TURN R", at: CGPoint(x: 230, y: 136))
    }

    // MARK: Right hand overlays

    private var rightTip: CGPoint { CGPoint(x: Self.designSize.width - Self.tip.x, y: Self.tip.y) }

    /// Ground plane ellipse around the thumb tip, drawn behind the hand.
    private func drawDepthPlane(in ctx: GraphicsContext) {
        let tip = rightTip
        let plane = Path(ellipseIn: CGRect(x: tip.x - 92, y: tip.y - 34, width: 184, height: 68))
        ctx.stroke(plane, with: .color(side.light.opacity(0.6)), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
    }

    private func drawForwardAndStrafe(in ctx: GraphicsContext) {
        let tip = rightTip

        let accent = Color.white
        // Forward (push away): up-right into the scene. Back (pull toward you): down-left.
        drawArrow(in: ctx, from: CGPoint(x: tip.x + 14, y: tip.y - 30), to: CGPoint(x: tip.x + 52, y: tip.y - 78), color: accent)
        drawLabel(in: ctx, "FORWARD", at: CGPoint(x: tip.x + 60, y: tip.y - 112))
        drawLabel(in: ctx, "push away", at: CGPoint(x: tip.x + 60, y: tip.y - 96), small: true)

        drawArrow(in: ctx, from: CGPoint(x: tip.x - 104, y: tip.y + 28), to: CGPoint(x: tip.x - 118, y: tip.y + 70), color: accent)
        drawLabel(in: ctx, "BACK", at: CGPoint(x: tip.x - 116, y: tip.y + 88))
        drawLabel(in: ctx, "pull in", at: CGPoint(x: tip.x - 116, y: tip.y + 104), small: true)

        // Strafe left / right along the plane.
        drawArrow(in: ctx, from: CGPoint(x: tip.x - 60, y: tip.y), to: CGPoint(x: tip.x - 104, y: tip.y), color: side.light)
        drawArrow(in: ctx, from: CGPoint(x: tip.x + 60, y: tip.y), to: CGPoint(x: tip.x + 104, y: tip.y), color: side.light)
        drawLabel(in: ctx, "STRAFE", at: CGPoint(x: tip.x - 108, y: tip.y - 22))
        drawLabel(in: ctx, "STRAFE", at: CGPoint(x: tip.x + 108, y: tip.y + 24))
    }

    // MARK: Primitives

    private func mirrored(_ path: Path) -> Path {
        guard side == .right else { return path }
        let t = CGAffineTransform(translationX: Self.designSize.width, y: 0).scaledBy(x: -1, y: 1)
        return path.applying(t)
    }

    private func point(on center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(r), y: center.y + radius * sin(r))
    }

    private func drawArrow(in ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var shaft = Path()
        shaft.move(to: from)
        shaft.addLine(to: to)
        ctx.stroke(shaft, with: .color(color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        let angle = atan2(to.y - from.y, to.x - from.x)
        drawHead(in: ctx, at: to, direction: .radians(angle), color: color)
    }

    private func drawHead(in ctx: GraphicsContext, at tip: CGPoint, direction: Angle, color: Color) {
        let a = direction.radians
        let len: CGFloat = 16
        let spread: CGFloat = 0.5
        var head = Path()
        head.move(to: CGPoint(x: tip.x + 4 * cos(a), y: tip.y + 4 * sin(a)))
        head.addLine(to: CGPoint(x: tip.x - len * cos(a - spread), y: tip.y - len * sin(a - spread)))
        head.addLine(to: CGPoint(x: tip.x - len * cos(a + spread), y: tip.y - len * sin(a + spread)))
        head.closeSubpath()
        ctx.fill(head, with: .color(color))
    }

    private func drawLabel(in ctx: GraphicsContext, _ text: String, at point: CGPoint, small: Bool = false) {
        let label = Text(text)
            .font(.system(size: small ? 11 : 13, weight: small ? .medium : .heavy))
            .foregroundColor(small ? .white.opacity(0.7) : .white)
        ctx.draw(label, at: point, anchor: .center)
    }
}

#Preview {
    HandControlsIllustration()
        .padding()
        .background(Color.black)
}
