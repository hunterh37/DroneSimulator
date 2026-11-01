//
//  HandTutorialSystem.swift
//  HelicopterGame
//
//  ECS driver for the hand joystick tutorial. One HandTutorialComponent per
//  hand group. The system advances a single timeline per frame: fade in, demo
//  each stick direction (knob glides out, matching chevron + label light up),
//  fade out. No timers, no per-frame allocations.
//

#if os(visionOS)
import RealityKit
import simd

public struct HandTutorialComponent: Component {
    public enum Phase { case idle, running, finished }

    public var phase: Phase = .idle
    public var elapsed: Float = 0

    // Parts (class refs, set once at build time).
    public var knob: Entity?
    public var arrows: [Entity] = []   // order: up, right, down, left
    public var labels: [Entity] = []   // same order

    // Timeline (seconds).
    public var fadeIn: Float = 0.5
    public var stepDuration: Float = 1.3
    public var loops: Int = 2
    public var fadeOut: Float = 0.8
    public var knobTravel: Float = 0.022

    public var demoDuration: Float { stepDuration * Float(4 * loops) }
    public var totalDuration: Float { fadeIn + demoDuration + fadeOut }

    public init() {}
}

public struct HandTutorialSystem: System {
    private static let query = EntityQuery(where: .has(HandTutorialComponent.self))

    // up, right, down, left in diagram space (x right, y up).
    private static let directions: [SIMD2<Float>] = [[0, 1], [1, 0], [0, -1], [-1, 0]]

    private static let dimOpacity: Float = 0.3

    public init(scene: Scene) {}

    public func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var c = entity.components[HandTutorialComponent.self],
                  c.phase == .running else { continue }

            c.elapsed += dt
            let t = c.elapsed

            // Group opacity envelope.
            let fadeOutStart = c.fadeIn + c.demoDuration
            let groupOpacity: Float
            if t < c.fadeIn {
                groupOpacity = smooth(t / c.fadeIn)
            } else if t < fadeOutStart {
                groupOpacity = 1
            } else {
                groupOpacity = 1 - smooth((t - fadeOutStart) / c.fadeOut)
            }
            entity.components.set(OpacityComponent(opacity: groupOpacity))

            // Direction demo.
            let demoT = min(max(t - c.fadeIn, 0), c.demoDuration - 0.0001)
            let stepIndex = Int(demoT / c.stepDuration) % 4
            let local = (demoT.truncatingRemainder(dividingBy: c.stepDuration)) / c.stepDuration
            // Out (0-35%), hold (35-70%), back (70-100%).
            let push: Float
            if local < 0.35 { push = smooth(local / 0.35) }
            else if local < 0.7 { push = 1 }
            else { push = 1 - smooth((local - 0.7) / 0.3) }

            let dir = Self.directions[stepIndex]
            c.knob?.position = SIMD3<Float>(dir.x, dir.y, 0) * (c.knobTravel * push)

            for i in 0..<4 {
                let active = (i == stepIndex)
                let o = active ? Self.dimOpacity + (1 - Self.dimOpacity) * push : Self.dimOpacity
                let s: Float = active ? 1 + 0.25 * push : 1
                if i < c.arrows.count {
                    c.arrows[i].components.set(OpacityComponent(opacity: o))
                    c.arrows[i].scale = SIMD3<Float>(repeating: s)
                }
                if i < c.labels.count {
                    c.labels[i].components.set(OpacityComponent(opacity: active ? 0.45 + 0.55 * push : 0.45))
                }
            }

            if t >= c.totalDuration {
                c.phase = .finished
                entity.isEnabled = false
            }
            entity.components.set(c)
        }
    }

    @inline(__always)
    private func smooth(_ x: Float) -> Float {
        let v = min(max(x, 0), 1)
        return v * v * (3 - 2 * v)
    }
}
#endif
