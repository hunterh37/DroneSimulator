#if os(visionOS)
import DicyaninThumbController
import SwiftUI

/// On-screen drag stick. Left: x yaw, up throttle. Right: x roll, up pitch.
/// Feeds DualThumbController only while dragging; release writes zero.
struct LiveTouchStick: View {
    enum Side { case left, right }
    let side: Side
    private let radius: CGFloat = 48
    @State private var offset: CGSize = .zero
    @State private var dragging = false

    var body: some View {
        ZStack {
            Circle().stroke(LiveTheme.hairlineHi, lineWidth: 1)
            Circle().stroke(LiveTheme.hairline, lineWidth: 1).frame(width: 20, height: 20)
            Circle().fill(dragging ? LiveTheme.text : LiveTheme.textDim)
                .frame(width: 28, height: 28).offset(offset)
            LiveLabel(side == .left ? "Yaw / Alt" : "Roll / Pitch", size: 9, color: LiveTheme.textFaint)
                .offset(y: radius + 12)
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
                send(SIMD2(Float(v.width / radius), Float(-v.height / radius)), held: true)
            }
            .onEnded { _ in
                offset = .zero
                dragging = false
                send(.zero, held: false)
            })
        .animation(LiveTheme.spring, value: dragging)
        .padding(.bottom, 20)
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
