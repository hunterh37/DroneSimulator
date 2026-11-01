#if os(visionOS)
import DicyaninThumbController
import SwiftUI

/// On-screen drag stick. Left: x yaw, up throttle. Right: x roll, up pitch.
/// Feeds DualThumbController only while dragging; release writes zero.
struct LiveTouchStick: View {
    enum Side { case left, right }
    let side: Side
    private let radius: CGFloat = 67
    private let knobSize: CGFloat = 39
    private let deadzone: CGFloat = 0.12
    @State private var offset: CGSize = .zero
    @State private var dragging = false
    @State private var value = SIMD2<Float>.zero

    private var past: Bool { dragging && hypot(offset.width, offset.height) / radius > deadzone }
    private var axisX: String { side == .left ? "YAW" : "ROLL" }
    private var axisY: String { side == .left ? "THR" : "PITCH" }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                LiveLabel(axisY, size: 11, color: LiveTheme.textDim)
                Spacer()
                LiveLabel(axisX, size: 11, color: LiveTheme.textDim)
            }
            .frame(width: radius * 2)
            pad
            VStack(spacing: 6) {
                bar(axisY, value.y)
                bar(axisX, value.x)
            }
            .frame(width: radius * 2)
        }
    }

    private var pad: some View {
        ZStack {
            Circle().fill(LiveTheme.surface)
            Circle().stroke(LiveTheme.hairlineHi, lineWidth: 1)
            Circle().stroke(LiveTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .frame(width: radius * 2 * deadzone * 2, height: radius * 2 * deadzone * 2)
            Rectangle().fill(LiveTheme.hairline).frame(width: 1, height: radius * 2)
            Rectangle().fill(LiveTheme.hairline).frame(width: radius * 2, height: 1)
            ForEach(0..<4, id: \.self) { i in
                Rectangle().fill(LiveTheme.textFaint).frame(width: 1.5, height: 8)
                    .offset(y: -(radius - 4)).rotationEffect(.degrees(Double(i) * 90))
            }
            Circle().fill(past ? LiveTheme.text : LiveTheme.textDim)
                .frame(width: knobSize, height: knobSize).offset(offset)
        }
        .frame(width: radius * 2, height: radius * 2)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { g in
                var v = CGSize(width: g.translation.width, height: g.translation.height)
                let len = hypot(v.width, v.height)
                if len > radius { v = CGSize(width: v.width / len * radius, height: v.height / len * radius) }
                offset = v
                dragging = true
                value = SIMD2(Float(v.width / radius), Float(-v.height / radius))
                send(value, held: true)
            }
            .onEnded { _ in
                offset = .zero
                dragging = false
                value = .zero
                send(.zero, held: false)
            })
        .animation(LiveTheme.spring, value: dragging)
    }

    private func bar(_ name: String, _ v: Float) -> some View {
        HStack(spacing: 8) {
            LiveLabel(name, size: 10, color: LiveTheme.textFaint).frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                let half = geo.size.width / 2
                ZStack(alignment: .leading) {
                    Rectangle().fill(LiveTheme.hairline).frame(height: 2)
                    Rectangle().fill(LiveTheme.hairlineHi).frame(width: 1, height: 8).offset(x: half)
                    Rectangle().fill(LiveTheme.text).frame(width: abs(CGFloat(v)) * half, height: 4)
                        .offset(x: v >= 0 ? half : half + CGFloat(v) * half)
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 8)
            Text(String(format: "%+.2f", v)).font(LiveTheme.mono(11)).foregroundStyle(LiveTheme.textDim)
                .frame(width: 46, alignment: .trailing)
        }
    }

    private func send(_ v: SIMD2<Float>, held: Bool) {
        let c = DualThumbController.shared
        let mag = simd_length(v)
        let dir: SIMD3<Float> = mag > 0 ? SIMD3(v.x / mag, v.y / mag, 0) : .zero
        if side == .left {
            c.setVirtualJoystickInput(leftDirection: dir, leftMagnitude: min(mag, 1), leftActive: held,
                                      rightDirection: c.rightDirection, rightMagnitude: c.rightMagnitude,
                                      rightActive: c.rightIsActive)
        } else {
            c.setVirtualJoystickInput(leftDirection: c.leftDirection, leftMagnitude: c.leftMagnitude,
                                      leftActive: c.leftIsActive,
                                      rightDirection: SIMD3(v.x, v.y, 0), rightMagnitude: min(mag, 1),
                                      rightActive: held)
        }
    }
}
#endif
