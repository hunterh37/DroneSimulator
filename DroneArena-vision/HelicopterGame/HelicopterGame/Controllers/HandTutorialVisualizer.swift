//
//  HandTutorialVisualizer.swift
//  HelicopterGame
//
//  Onboarding overlay shown the first time hand tracking starts in game mode.
//  Each hand gets a face-on thumbstick diagram (base ring, gliding knob,
//  four chevrons, pill labels) that demos every direction, driven by
//  HandTutorialSystem.
//
//  Mode-2 mapping (see DualThumbControlledSystem):
//    LEFT  hand: Up/Down = altitude (throttle), Left/Right = turn (yaw)
//    RIGHT hand: Up/Down = forward/back (pitch), Left/Right = strafe (roll)
//

#if os(visionOS)
import Foundation
import RealityKit
import ARKit
import UIKit
import Combine
import simd
import DicyaninARKitSession

@MainActor
public final class HandTutorialVisualizer {
    fileprivate static let shared = HandTutorialVisualizer()
    private static var registered = false

    // MARK: - Style
    private let leftAccent = UIColor(red: 0.30, green: 0.85, blue: 1.00, alpha: 1)
    private let rightAccent = UIColor(red: 1.00, green: 0.62, blue: 0.25, alpha: 1)
    private let panelColor = UIColor(white: 0.05, alpha: 0.55)

    // MARK: - Layout (meters)
    private let groupLift: Float = 0.07
    private let ringRadius: Float = 0.032
    private let arrowRadius: Float = 0.046
    private let labelRadius: Float = 0.078

    // MARK: - State
    private var groups: [Entity] = []
    private var hasShown = false
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Public API

    public func start(in root: Entity) {
        guard !hasShown else { return }
        buildIfNeeded(in: root)
        ARKitSessionManager.shared.handTrackingUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self, !self.hasShown else { return }
                if update.left != nil || update.right != nil { self.playSequence() }
            }
            .store(in: &cancellables)
    }

    public func replay(in root: Entity) {
        hasShown = false
        buildIfNeeded(in: root)
        playSequence()
    }

    // MARK: - Build

    private func buildIfNeeded(in root: Entity) {
        guard groups.isEmpty else { return }
        if !Self.registered {
            HandTutorialComponent.registerComponent()
            HandTutorialSystem.registerSystem()
            Self.registered = true
        }
        for isLeft in [true, false] {
            let anchor = AnchorEntity(.hand(isLeft ? .left : .right, location: .aboveHand))
            let group = makeHandGroup(isLeft: isLeft)
            anchor.addChild(group)
            root.addChild(anchor)
            groups.append(group)
        }
    }

    private func makeHandGroup(isLeft: Bool) -> Entity {
        let accent = isLeft ? leftAccent : rightAccent

        // Outer entity is billboarded; the whole diagram faces the user as one
        // flat card so directions read consistently.
        let group = Entity()
        group.name = isLeft ? "HandTutorial.Left" : "HandTutorial.Right"
        group.position = [0, groupLift, 0]
        group.components.set(BillboardComponent())
        group.components.set(OpacityComponent(opacity: 0))
        group.isEnabled = false

        // Backing disc.
        group.addChild(plane(width: 0.19, height: 0.19, corner: 0.095,
                             color: panelColor, z: -0.002))

        // Base ring (thin torus approximated by two discs).
        group.addChild(disc(radius: ringRadius + 0.0025, color: accent.withAlphaComponent(0.9), z: -0.001))
        group.addChild(disc(radius: ringRadius, color: UIColor(white: 0.08, alpha: 0.9), z: -0.0005))

        // Knob.
        let knob = Entity()
        knob.addChild(disc(radius: 0.0135, color: .white, z: 0.001))
        knob.addChild(disc(radius: 0.009, color: accent, z: 0.0015))
        group.addChild(knob)

        // Chevrons + labels in order up, right, down, left.
        let names = labels(forLeftHand: isLeft)
        let angles: [Float] = [0, -.pi / 2, .pi, .pi / 2]
        let dirs: [SIMD3<Float>] = [[0, 1, 0], [1, 0, 0], [0, -1, 0], [-1, 0, 0]]
        var arrows: [Entity] = []
        var labelEntities: [Entity] = []
        for i in 0..<4 {
            let chevron = makeChevron(color: accent)
            chevron.position = dirs[i] * arrowRadius
            chevron.orientation = simd_quatf(angle: angles[i], axis: [0, 0, 1])
            group.addChild(chevron)
            arrows.append(chevron)

            let label = makePill(names[i])
            label.position = dirs[i] * labelRadius
            group.addChild(label)
            labelEntities.append(label)
        }

        // Title.
        let title = makeText(isLeft ? "LEFT THUMB" : "RIGHT THUMB",
                             color: accent, fontSize: 0.014, weight: .heavy)
        title.position = [0, labelRadius + 0.03, 0.001]
        group.addChild(title)

        var c = HandTutorialComponent()
        c.knob = knob
        c.arrows = arrows
        c.labels = labelEntities
        group.components.set(c)
        return group
    }

    private func labels(forLeftHand isLeft: Bool) -> [String] {
        isLeft ? ["CLIMB", "TURN R", "DESCEND", "TURN L"]
               : ["FORWARD", "STRAFE R", "BACK", "STRAFE L"]
    }

    // MARK: - Primitives

    private func plane(width: Float, height: Float, corner: Float,
                       color: UIColor, z: Float) -> ModelEntity {
        var m = UnlitMaterial(color: color)
        m.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        let e = ModelEntity(mesh: .generatePlane(width: width, height: height, cornerRadius: corner),
                            materials: [m])
        e.position.z = z
        return e
    }

    private func disc(radius: Float, color: UIColor, z: Float) -> ModelEntity {
        plane(width: radius * 2, height: radius * 2, corner: radius, color: color, z: z)
    }

    /// Chevron pointing +Y, built from two rounded bars.
    private func makeChevron(color: UIColor) -> Entity {
        let root = Entity()
        let len: Float = 0.011, thick: Float = 0.0032
        let d = len * 0.5 * 0.7071
        for sign: Float in [-1, 1] {
            // Left bar rises toward the tip at the origin; right bar mirrors it.
            let bar = plane(width: len, height: thick, corner: thick / 2, color: color, z: 0.001)
            bar.orientation = simd_quatf(angle: -sign * .pi / 4, axis: [0, 0, 1])
            bar.position = [sign * d, -d, 0]
            root.addChild(bar)
        }
        root.components.set(OpacityComponent(opacity: 0.3))
        return root
    }

    private func makePill(_ string: String) -> Entity {
        let root = Entity()
        let text = makeText(string, color: .white, fontSize: 0.0105, weight: .semibold)
        text.position.z = 0.001
        let width = max(0.03, textWidth(of: text) + 0.012)
        root.addChild(plane(width: width, height: 0.018, corner: 0.009,
                            color: UIColor(white: 0.12, alpha: 0.85), z: 0))
        root.addChild(text)
        root.components.set(OpacityComponent(opacity: 0.45))
        return root
    }

    private func textWidth(of container: Entity) -> Float {
        container.visualBounds(relativeTo: container).extents.x
    }

    /// Centered unlit text; origin at glyph center. No billboard (parent handles it).
    private func makeText(_ string: String, color: UIColor, fontSize: Float,
                          weight: UIFont.Weight) -> Entity {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.0002,
            font: .systemFont(ofSize: CGFloat(fontSize), weight: weight),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let e = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
        let b = mesh.bounds
        e.position = [-b.center.x, -b.center.y, 0]
        let container = Entity()
        container.addChild(e)
        return container
    }

    // MARK: - Sequence

    private func playSequence() {
        guard !hasShown else { return }
        hasShown = true
        cancellables.removeAll()
        for group in groups {
            guard var c = group.components[HandTutorialComponent.self] else { continue }
            c.phase = .running
            c.elapsed = 0
            group.components.set(c)
            group.components.set(OpacityComponent(opacity: 0))
            group.isEnabled = true
        }
    }
}

extension GameContext {
    public var handTutorial: HandTutorialVisualizer { HandTutorialVisualizer.shared }
}
#endif
