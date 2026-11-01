//
//  GamepadPillarEntity.swift
//  HelicopterGame
//
//  A world-anchored "table stand" controller: a floor-standing pillar topped
//  with a slightly tilted deck that carries the two physics joysticks plus a
//  red fire button that launches a missile.
//
//  The joysticks are built from Gamepad3DParts — the exact same socket/pivot/
//  shaft/head rig (and spring-joint physics) used by the flat Gamepad3DEntity —
//  so the movement that already feels good is reused verbatim here. The only new
//  piece is the fire button, whose press is routed to the existing missile-fire
//  path by ImmersiveView.
//

import RealityKit
import simd
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class GamepadPillarEntity: Entity {

    /// The visual skin applied to the column + foot + arcade lighting accents.
    public private(set) var skin: PillarSkin = .default

    // MARK: - Arcade readout (deck-top CRT)

    /// One retro readout: a caption that's drawn once plus a value mesh that gets
    /// regenerated whenever its number changes. `holder` sits at the readout's
    /// slot on the screen; the value node is recentered within it on each update.
    private struct Readout {
        let holder: Entity
        let valueNode: ModelEntity
        let color: UIColor
        var lastValue: String = ""
    }

    private var speedReadout: Readout?
    private var altReadout: Readout?
    private var missileReadout: Readout?

    /// The floating sci-fi minimap hologram that hovers above the deck. Hidden by
    /// default; toggled by the deck's hologram button.
    public private(set) var hologram: PillarHologramEntity?

    /// Glyphs are generated at a comfortable point size then scaled down to deck
    /// scale, so the curves stay crisp instead of faceting at tiny font sizes.
    private static let glyphFont = CGFloat(0.1)
    private static let captionScale: Float = 0.055
    private static let valueScale: Float = 0.12
    private static let legendScale: Float = 0.04

    /// `position` is where the deck (the top of the pillar) sits in world space.
    /// The column then drops from there down to the floor.
    public static func make(at position: SIMD3<Float> = SIMD3<Float>(0, 0.9, -0.5),
                            skin: PillarSkin = .default) -> GamepadPillarEntity {
        let pillar = GamepadPillarEntity()
        pillar.skin = skin
        // Set position FIRST — build() reads position.y to size the column down
        // to the floor.
        pillar.position = position
        pillar.build()
        return pillar
    }

    private func build() {
        name = "GamepadPillar"

        let deckThickness: Float = 0.03
        let deckTilt: Float = .pi / 6.0    // ~30°, tipped so the BACK edge rises
        let deckHeight = position.y        // distance from deck down to the floor

        // --- Pillar column (floor → deck) ---
        // Built straight down the world Y so it stays vertical regardless of the
        // deck tilt. Parented directly to self (origin = deck center).
        let columnRadius: Float = 0.035
        let columnHeight = max(deckHeight - deckThickness, 0.05)
        let column = ModelEntity(
            mesh: .generateCylinder(height: columnHeight, radius: columnRadius),
            materials: [skin.columnMaterial()]
        )
        column.name = "PillarColumn"
        column.position = SIMD3<Float>(0, -deckThickness / 2.0 - columnHeight / 2.0, 0)
        addChild(column)

        // Arcade lighting: neon strips + glow rings up the column (skin-driven).
        skin.addAccents(to: column, columnHeight: columnHeight, columnRadius: columnRadius)

        // Wide foot on the floor for a stable table-stand look.
        let foot = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: 0.12),
            materials: [skin.footMaterial()]
        )
        foot.name = "PillarFoot"
        foot.position = SIMD3<Float>(0, -deckHeight + 0.01, 0)

        // Glowing floor halo above the foot for arcade bloom.
        let halo = skin.makeBaseHalo(columnRadius: columnRadius)
        halo.position = SIMD3<Float>(0, -deckHeight + 0.022, 0)
        addChild(halo)
        // Only the base is grabbable: dragging it repositions the whole stand.
        foot.components.set(CollisionComponent(shapes: [.generateBox(width: 0.24, height: 0.05, depth: 0.24)]))
        foot.components.set(InputTargetComponent())
        #if !os(macOS)
        foot.components.set(HoverEffectComponent())  // hover highlight: visionOS/iOS only
        #endif
        foot.components.set(GamepadPillarBaseComponent(root: self))
        addChild(foot)

        // --- Tilted deck that holds the controls ---
        let deck = Entity()
        deck.name = "PillarDeck"
        // Tilt the opposite way from before (positive angle): the back edge lifts
        // up like an arcade-cabinet marquee facing the user.
        deck.orientation = simd_quatf(angle: deckTilt, axis: SIMD3<Float>(1, 0, 0))
        addChild(deck)

        let panel = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.26, deckThickness, 0.18), cornerRadius: 0.03),
            materials: [Gamepad3DParts.bodyMaterial()]
        )
        panel.name = "PillarDeckPanel"
        deck.addChild(panel)

        let topY = deckThickness / 2.0

        // Two joysticks toward the back of the deck (reused rig + physics).
        let xOffset: Float = 0.075
        Gamepad3DParts.addJoystick(to: deck, side: .left,  at: SIMD3<Float>(-xOffset, topY, -0.025))
        Gamepad3DParts.addJoystick(to: deck, side: .right, at: SIMD3<Float>( xOffset, topY, -0.025))

        // Two round missile buttons between the sticks, front-center.
        // Left = weapon slot 1 (red), right = weapon slot 2 (yellow).
        let button1 = Gamepad3DParts.makeFireButton(
            at: SIMD3<Float>(-0.025, topY, 0.045), slot: 1, tint: .systemRed
        )
        let button2 = Gamepad3DParts.makeFireButton(
            at: SIMD3<Float>( 0.025, topY, 0.045), slot: 2, tint: .systemYellow
        )
        deck.addChild(button1)
        deck.addChild(button2)

        // Hologram toggle button: a glowing cyan dome seated back-center between
        // the sticks. Tapping it shows/hides the floating minimap (handled in
        // ImmersiveView, which calls toggleHologram()).
        let holoButton = Gamepad3DParts.makeFireButton(
            at: SIMD3<Float>(0, topY, -0.062), slot: 0, tint: .cyan, radius: 0.015,
            action: .toggleHologram
        )
        holoButton.name = "HologramToggleButton"
        deck.addChild(holoButton)

        // Axis legends silk-screened in front of each stick: a subtle 4-way arrow
        // gate plus the channel it drives, like the control legend on an arcade
        // panel. Left stick = throttle + yaw; right stick = pitch + roll (this is
        // exactly how Gamepad3DSystem routes each side into the drone).
        buildJoystickLegend(on: deck, at: SIMD3<Float>(-xOffset, topY, 0.013),
                            caption: "THR \u{00B7} YAW", color: .systemBlue)
        buildJoystickLegend(on: deck, at: SIMD3<Float>( xOffset, topY, 0.013),
                            caption: "PITCH \u{00B7} ROLL", color: .systemOrange)

        // Retro arcade CRT strip set into the deck, in front of the fire buttons.
        buildArcadeScreen(on: deck, topY: topY)

        // The floating sci-fi hologram minimap, hovering above the deck center.
        let holo = PillarHologramEntity.make()
        holo.position = SIMD3<Float>(0.2, topY + 0.17, -0.12)
        deck.addChild(holo)
        hologram = holo
    }

    // MARK: - Hologram control

    /// Flip the hologram minimap on/off. Returns the new visibility.
    @discardableResult
    public func toggleHologram() -> Bool {
        guard let holo = hologram else { return false }
        holo.isEnabled.toggle()
        return holo.isEnabled
    }

    /// Forward live radar data to the hologram (no-op while it's hidden).
    public func updateHologram(playerWorld: SIMD3<Float>,
                               blips: [PillarHologramEntity.Blip],
                               modeLabel: String,
                               time: TimeInterval) {
        hologram?.updateHologram(playerWorld: playerWorld, blips: blips,
                                 modeLabel: modeLabel, time: time)
    }

    // MARK: - Joystick axis legends

    /// Builds the per-stick control legend: a small 4-way directional gate icon
    /// with an axis caption seated just ahead of it on the deck.
    private func buildJoystickLegend(on deck: Entity, at position: SIMD3<Float>,
                                     caption: String, color: UIColor) {
        let gate = makeAxisGate(color: color)
        gate.position = position + SIMD3<Float>(0, 0.0015, 0)
        deck.addChild(gate)

        let labelHolder = Entity()
        labelHolder.position = position + SIMD3<Float>(0, 0.0015, 0.019)
        deck.addChild(labelHolder)

        let node = ModelEntity()
        Self.applyText(caption, to: node, scale: Self.legendScale,
                       color: color.withAlphaComponent(0.8), baseZ: 0)
        labelHolder.addChild(node)
    }

    /// A subtle four-arrow gate (up/down/left/right) lying flat on the deck — the
    /// classic arcade directional indicator. Arrows point outward from center.
    private func makeAxisGate(color: UIColor) -> Entity {
        let group = Entity()
        let material = UnlitMaterial(color: color.withAlphaComponent(0.55))
        let arrowSize: Float = 0.006
        let reach: Float = 0.0075

        // (offset from center, yaw so the apex points outward along that axis)
        let arrows: [(pos: SIMD3<Float>, yaw: Float)] = [
            (SIMD3<Float>(0, 0,  reach), 0),         // toward user (+Z)
            (SIMD3<Float>(0, 0, -reach), .pi),       // toward screen (-Z)
            (SIMD3<Float>( reach, 0, 0),  .pi / 2),  // right (+X)
            (SIMD3<Float>(-reach, 0, 0), -.pi / 2)   // left  (-X)
        ]

        for a in arrows {
            let tri = ModelEntity(mesh: Self.arrowTriangle, materials: [material])
            tri.scale = SIMD3<Float>(repeating: arrowSize)
            tri.orientation = simd_quatf(angle: a.yaw, axis: SIMD3<Float>(0, 1, 0))
            tri.position = a.pos
            group.addChild(tri)
        }
        return group
    }

    /// A flat triangle lying in the deck plane (normal +Y), apex toward +Z, sized
    /// ~1 unit so callers scale it down. Reused for every gate arrow.
    private static let arrowTriangle: MeshResource = {
        var d = MeshDescriptor(name: "axisArrow")
        d.positions = MeshBuffers.Positions([
            SIMD3<Float>(0, 0, 0.5),
            SIMD3<Float>(0.4, 0, -0.3),
            SIMD3<Float>(-0.4, 0, -0.3)
        ])
        d.primitives = .triangles([0, 1, 2])
        return (try? MeshResource.generate(from: [d])) ?? .generateBox(size: 0.001)
    }()

    // MARK: - Arcade screen

    /// Lays a thin dark "CRT" panel across the front of the deck and seats three
    /// glowing readouts (SPD / ALT / MSL) on it, oldschool arcade-cabinet style.
    private func buildArcadeScreen(on deck: Entity, topY: Float) {
        let screenZ: Float = -0.078      // back edge, opposite the fire buttons
        let screenY = topY + 0.002

        // Recessed bezel + glassy black screen face.
        let bezel = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.232, 0.006, 0.05), cornerRadius: 0.006),
            materials: [Gamepad3DParts.socketMaterial()]
        )
        bezel.name = "ArcadeScreenBezel"
        bezel.position = SIMD3<Float>(0, screenY, screenZ)
        deck.addChild(bezel)

        let screen = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.214, 0.004, 0.04), cornerRadius: 0.003),
            materials: [Self.screenMaterial()]
        )
        screen.name = "ArcadeScreen"
        screen.position = SIMD3<Float>(0, screenY + 0.0025, screenZ)
        deck.addChild(screen)

        let glassTopY = screenY + 0.006   // text floats just above the glass

        // Three slots across the screen, each color-coded like a vintage segment
        // display: speed cyan, altitude amber, missiles red.
        speedReadout   = makeReadout(on: deck, caption: "SPD", color: .cyan,
                                     at: SIMD3<Float>(-0.072, glassTopY, screenZ))
        altReadout     = makeReadout(on: deck, caption: "ALT", color: .systemYellow,
                                     at: SIMD3<Float>(0.0, glassTopY, screenZ))
        missileReadout = makeReadout(on: deck, caption: "MSL", color: .systemRed,
                                     at: SIMD3<Float>(0.072, glassTopY, screenZ))

        // Seed initial values so the screen isn't blank before the first update.
        updateReadouts(speedMph: 0, altitudeFt: 0, missiles: 0)
    }

    /// Builds one labelled readout. The caption is rendered once toward the back
    /// of the slot; the value node is created empty and filled by `updateReadouts`.
    private func makeReadout(on deck: Entity, caption: String, color: UIColor,
                             at position: SIMD3<Float>) -> Readout {
        let holder = Entity()
        holder.name = "Readout_\(caption)"
        holder.position = position
        deck.addChild(holder)

        // Static caption (small, dim) seated toward the rear of the slot.
        let captionNode = ModelEntity()
        Self.applyText(caption, to: captionNode, scale: Self.captionScale,
                       color: color.withAlphaComponent(0.65), baseZ: -0.011)
        holder.addChild(captionNode)

        // Dynamic value (larger, bright) seated toward the front of the slot.
        let valueNode = ModelEntity()
        holder.addChild(valueNode)

        return Readout(holder: holder, valueNode: valueNode, color: color)
    }

    /// Pushes live flight/combat numbers onto the deck screen. Cheap to call every
    /// HUD tick: each readout only regenerates its glyph mesh when its value text
    /// actually changes.
    public func updateReadouts(speedMph: Int, altitudeFt: Int, missiles: Int) {
        refresh(&speedReadout, value: String(format: "%03d", max(0, speedMph)))
        refresh(&altReadout, value: String(format: "%03d", max(0, altitudeFt)))
        refresh(&missileReadout, value: String(format: "%02d", max(0, missiles)))
    }

    private func refresh(_ readout: inout Readout?, value: String) {
        guard var r = readout, r.lastValue != value else { return }
        Self.applyText(value, to: r.valueNode, scale: Self.valueScale, color: r.color, baseZ: 0.007)
        r.lastValue = value
        readout = r
    }

    // MARK: - Text + screen materials

    /// Generates a flat-lying, horizontally + depth centered text mesh facing up
    /// out of the deck, using an unlit emissive-style fill for that bright CRT pop.
    private static func applyText(_ string: String, to node: ModelEntity,
                                  scale: Float, color: UIColor, baseZ: Float) {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.001,
            font: .monospacedSystemFont(ofSize: glyphFont, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        node.model = ModelComponent(mesh: mesh, materials: [UnlitMaterial(color: color)])

        // Lay the text flat (face up) and recenter it on the holder origin. The
        // text is authored in its XY plane; rotating -90° about X maps text-up to
        // -Z (toward the deck back) so it reads from the user's side.
        node.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        node.scale = SIMD3<Float>(repeating: scale)

        // Recenter absolutely so repeated updates never drift: X centers the glyph
        // run; Z combines the slot's base offset with the text's vertical center
        // (text-up maps to -Z after the rotation above).
        let c = mesh.bounds.center
        node.position = SIMD3<Float>(-c.x * scale, 0, baseZ + c.y * scale)
    }

    private static func screenMaterial() -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(white: 0.02, alpha: 1.0))
        m.roughness = .init(floatLiteral: 0.15)   // glassy
        m.metallic = .init(floatLiteral: 0.0)
        m.emissiveColor = .init(color: UIColor(red: 0.0, green: 0.05, blue: 0.06, alpha: 1.0))
        m.emissiveIntensity = 0.5
        return m
    }
}
