//
//  DroneSceneView.swift
//  HelicopterGame
//
//  3D Drone background view with SceneKit
//

import SwiftUI
import SceneKit

struct DroneSceneView: UIViewRepresentable {
    let droneModelName: String
    let rotationSpeed: TimeInterval
    let cameraDistance: Float
    let lightingIntensity: CGFloat
    let primaryColor: String?
    let accentColor: String?
    let modelRotationX: Float // Rotation in radians for X axis

    init(
        droneModelName: String = "Drone",
        rotationSpeed: TimeInterval = 20.0,
        cameraDistance: Float = 5.0,
        lightingIntensity: CGFloat = 0.8,
        primaryColor: String? = nil,
        accentColor: String? = nil,
        modelRotationX: Float = 0.0 // Default: no rotation
    ) {
        self.droneModelName = droneModelName
        self.rotationSpeed = rotationSpeed
        self.cameraDistance = cameraDistance
        self.lightingIntensity = lightingIntensity
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.modelRotationX = modelRotationX
    }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()

        // Configure SceneView
        sceneView.backgroundColor = UIColor.clear
        sceneView.allowsCameraControl = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60

        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene

        // Setup camera
        setupCamera(scene: scene)

        // Setup lighting
        setupLighting(scene: scene)

        // Load and setup drone model
        loadDroneModel(scene: scene)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Check if the drone model needs to be reloaded
        guard let scene = uiView.scene else { return }

        // Remove old drone
        if let oldDrone = scene.rootNode.childNode(withName: "DroneContainer", recursively: false) ??
                          scene.rootNode.childNode(withName: "FallbackDrone", recursively: false) {
            oldDrone.removeFromParentNode()
        }

        // Load new drone model
        loadDroneModel(scene: scene)
    }

    private func setupCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60 // Wider field of view for more zoom effect
        cameraNode.position = SCNVector3(x: 0, y: 0, z: cameraDistance)

        // No rotation - view models as they are oriented in the files
        cameraNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0)

        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting(scene: SCNScene) {
        // Ambient light for overall illumination
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(Color.iceCyan.opacity(0.3))
        ambientLight.intensity = 200

        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Key light (main directional light)
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.color = UIColor(Color.coreBlue.opacity(lightingIntensity))
        keyLight.intensity = 1000
        keyLight.castsShadow = true
        keyLight.shadowRadius = 5

        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(x: 2, y: 3, z: 4)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)

        // Fill light (softer, opposite side)
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.color = UIColor(Color.neonBlue.opacity(0.4))
        fillLight.intensity = 500

        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(x: -2, y: 1, z: 2)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLightNode)

        // Rim light for chrome highlights
        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.color = UIColor(Color.chromeHi)
        rimLight.intensity = 800
        rimLight.spotInnerAngle = 20
        rimLight.spotOuterAngle = 45

        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(x: 0, y: -2, z: 3)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)
    }

    private func loadDroneModel(scene: SCNScene) {
        if let style = LowPolyDroneStyle.from(modelName: droneModelName) {
            let preset = DroneLivery.presets[LowPolyDroneStyle.allCases.firstIndex(of: style)! % DroneLivery.presets.count]
            let node = LowPolyDroneFactory.makeSceneKitNode(style, livery: preset)
            let container = SCNNode()
            container.name = "DroneContainer"
            container.addChildNode(node)
            container.scale = SCNVector3(4.2, 4.2, 4.2)
            container.eulerAngles = SCNVector3(0.35, 0, 0)
            scene.rootNode.addChildNode(container)
            startRotationAnimation(node: container)
            return
        }
        guard let url = Bundle.main.url(forResource: droneModelName, withExtension: "usdz") else {
            gameLog("❌ Could not find \(droneModelName).usdz in bundle")
            // Fallback: create a simple geometric drone representation
            createFallbackDrone(scene: scene)
            return
        }

        do {
            let droneScene = try SCNScene(url: url)

            // Create container node for the drone
            let droneContainer = SCNNode()
            droneContainer.name = "DroneContainer"

            // Add all nodes from the loaded scene
            for child in droneScene.rootNode.childNodes {
                droneContainer.addChildNode(child)
            }

            // Scale and position the drone
            droneContainer.scale = SCNVector3(0.8, 0.8, 0.8) // Larger size for closer view
            droneContainer.position = SCNVector3(0, 0, 0) // Centered - no offset

            // Apply optional X-axis rotation for model orientation correction
            droneContainer.eulerAngles = SCNVector3(modelRotationX, 0, 0)

            // Apply chrome/steel material properties with drone colors
            applyDroneMaterials(to: droneContainer)

            scene.rootNode.addChildNode(droneContainer)

            // Start rotation animation
            startRotationAnimation(node: droneContainer)

            gameLog("✅ Successfully loaded \(droneModelName).usdz")

        } catch {
            gameLog("❌ Error loading \(droneModelName).usdz: \(error)")
            createFallbackDrone(scene: scene)
        }
    }

    private func createFallbackDrone(scene: SCNScene) {
        // Create a simple geometric representation if USDZ fails to load
        let droneContainer = SCNNode()
        droneContainer.name = "FallbackDrone"

        // Main body (rounded box)
        let bodyGeometry = SCNBox(width: 1.0, height: 0.3, length: 1.5, chamferRadius: 0.1)
        let bodyNode = SCNNode(geometry: bodyGeometry)

        // Rotor arms
        let armGeometry = SCNBox(width: 0.1, height: 0.05, length: 0.8, chamferRadius: 0.02)

        let arm1 = SCNNode(geometry: armGeometry)
        arm1.position = SCNVector3(0, 0.1, 0)
        arm1.eulerAngles = SCNVector3(0, Float.pi/4, 0)

        let arm2 = SCNNode(geometry: armGeometry)
        arm2.position = SCNVector3(0, 0.1, 0)
        arm2.eulerAngles = SCNVector3(0, -Float.pi/4, 0)

        // Rotors
        let rotorGeometry = SCNCylinder(radius: 0.2, height: 0.02)
        let rotorPositions = [
            SCNVector3(0.4, 0.2, 0.4),
            SCNVector3(-0.4, 0.2, 0.4),
            SCNVector3(0.4, 0.2, -0.4),
            SCNVector3(-0.4, 0.2, -0.4)
        ]

        for position in rotorPositions {
            let rotor = SCNNode(geometry: rotorGeometry)
            rotor.position = position
            droneContainer.addChildNode(rotor)
        }

        droneContainer.addChildNode(bodyNode)
        droneContainer.addChildNode(arm1)
        droneContainer.addChildNode(arm2)

        // Apply materials
        applyDroneMaterials(to: droneContainer)

        scene.rootNode.addChildNode(droneContainer)
        startRotationAnimation(node: droneContainer)

        gameLog("✅ Created fallback geometric drone")
    }

    private func applyDroneMaterials(to node: SCNNode) {
        // Determine colors to use
        let baseColor: Color
        let highlightColor: Color
        let emissionColor: Color

        if let primaryHex = primaryColor {
            baseColor = Color(hex: primaryHex)
        } else {
            baseColor = Color.steel
        }

        if let accentHex = accentColor {
            highlightColor = Color(hex: accentHex)
            emissionColor = Color(hex: accentHex).opacity(0.15)
        } else {
            highlightColor = Color.chromeHi
            emissionColor = Color.coreBlue.opacity(0.1)
        }

        node.enumerateChildNodes { (child, _) in
            if let geometry = child.geometry {
                // Create chrome material with drone colors
                let droneMaterial = SCNMaterial()

                // Use drone's primary color as base
                droneMaterial.diffuse.contents = UIColor(baseColor)
                droneMaterial.specular.contents = UIColor(highlightColor)
                droneMaterial.metalness.contents = 0.85
                droneMaterial.roughness.contents = 0.15

                // Use accent color for emission glow
                droneMaterial.emission.contents = UIColor(emissionColor)

                // Apply to all material slots
                geometry.materials = [droneMaterial]
            }
        }
    }

    private func startRotationAnimation(node: SCNNode) {
        // Create smooth Y-axis rotation
        let rotationAction = SCNAction.rotateBy(x: 0, y: CGFloat(Float.pi * 2), z: 0, duration: CGFloat(rotationSpeed))
        let repeatAction = SCNAction.repeatForever(rotationAction)

        node.runAction(repeatAction, forKey: "rotation")

        // Add subtle floating animation
        let floatUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 3.0)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = floatUp.reversed()
        let floatSequence = SCNAction.sequence([floatUp, floatDown])
        let floatRepeat = SCNAction.repeatForever(floatSequence)

        node.runAction(floatRepeat, forKey: "floating")
    }
}

// MARK: - Preview Helper
struct DroneSceneView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.night
                .ignoresSafeArea()

            DroneSceneView()
                .frame(height: 300)
        }
    }
}
