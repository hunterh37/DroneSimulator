#if os(visionOS)
import RealityKit
import SwiftUI
import UIKit

/// Debug overlay for the LiDAR scene reconstruction collision mesh.
/// When on, every mesh chunk renders as translucent white with wireframe lines.
@MainActor
enum SceneMeshDebug {
    static let key = "debugShowSceneMesh"

    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key); applyAll() }
    }

    static var material: RealityKit.Material {
        var m = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.18))
        m.blending = .transparent(opacity: .init(floatLiteral: 0.18))
        m.triangleFillMode = .lines
        return m
    }

    static func currentMaterial() -> RealityKit.Material {
        isOn ? material : SceneReconstructionManager.shared.wallMaterial
    }

    static func applyAll() {
        let mat = currentMaterial()
        for e in MeshAnchorTracker.models {
            guard var model = e.components[ModelComponent.self] else { continue }
            model.materials = [mat]
            e.components.set(model)
        }
    }
}

struct SceneMeshDebugToggle: View {
    @AppStorage(SceneMeshDebug.key) private var on = false

    var body: some View {
        Toggle("Show Scene Collision Mesh", isOn: $on)
            .onChange(of: on) { _, v in SceneMeshDebug.isOn = v }
    }
}
#endif
