//
//  SimulatorJoystickView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI
import Foundation
import simd
import RealityKit

struct JoystickView: View {
    // Mode-2 Flight Controls
    @Binding var throttle: Float   // Left stick Y
    @Binding var yaw: Float        // Left stick X
    @Binding var pitch: Float      // Right stick Y
    @Binding var roll: Float       // Right stick X

    @State private var leftKnobOffset: CGSize = .zero
    @State private var rightKnobOffset: CGSize = .zero

    private let knobRadius: CGFloat = 25
    private let trackRadius: CGFloat = 60
    private let sensitivity: Float = 3.0

    var body: some View {
        HStack(spacing: DroneLayout.xl) {
            // Left joystick - Throttle (Y) and Yaw (X)
            VStack(spacing: DroneLayout.sm) {
                Text("Throttle/Yaw")
                    .font(DroneTypography.caption)
                    .foregroundColor(.droneTextSecondary)

                ZStack {
                    // Track with gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .droneSurfaceGlass,
                                    .droneSurfacePrimary
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: trackRadius
                            )
                        )
                        .frame(width: trackRadius * 2, height: trackRadius * 2)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.droneAccent.opacity(0.6), .droneSecondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    // Knob with glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .droneAccent,
                                    .droneSecondary
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: knobRadius
                            )
                        )
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.8), lineWidth: 1)
                        )
                        .background(
                            // Glow effect
                            Circle()
                                .fill(Color.droneAccent.opacity(0.4))
                                .frame(width: knobRadius * 2.5, height: knobRadius * 2.5)
                                .blur(radius: 6)
                        )
                        .offset(leftKnobOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)

                                    if distance <= trackRadius {
                                        leftKnobOffset = value.translation
                                    } else {
                                        let angle = atan2(value.translation.height, value.translation.width)
                                        leftKnobOffset = CGSize(
                                            width: cos(angle) * trackRadius,
                                            height: sin(angle) * trackRadius
                                        )
                                    }

                                    updateLeftStick()
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        leftKnobOffset = .zero
                                    }
                                    updateLeftStick()
                                }
                        )
                }
            }

            // Right joystick - Pitch (Y) and Roll (X)
            VStack(spacing: DroneLayout.sm) {
                Text("Pitch/Roll")
                    .font(DroneTypography.caption)
                    .foregroundColor(.droneTextSecondary)

                ZStack {
                    // Track with gradient
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .droneSurfaceGlass,
                                    .droneSurfacePrimary
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: trackRadius
                            )
                        )
                        .frame(width: trackRadius * 2, height: trackRadius * 2)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.droneInfo.opacity(0.6), .verdigris.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )

                    // Knob with glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .droneInfo,
                                    .verdigris
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: knobRadius
                            )
                        )
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.8), lineWidth: 1)
                        )
                        .background(
                            // Glow effect
                            Circle()
                                .fill(Color.droneInfo.opacity(0.4))
                                .frame(width: knobRadius * 2.5, height: knobRadius * 2.5)
                                .blur(radius: 6)
                        )
                        .offset(rightKnobOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let distance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)

                                    if distance <= trackRadius {
                                        rightKnobOffset = value.translation
                                    } else {
                                        let angle = atan2(value.translation.height, value.translation.width)
                                        rightKnobOffset = CGSize(
                                            width: cos(angle) * trackRadius,
                                            height: sin(angle) * trackRadius
                                        )
                                    }

                                    updateRightStick()
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        rightKnobOffset = .zero
                                    }
                                    updateRightStick()
                                }
                        )
                }
            }
        }
        .padding(DroneLayout.lg)
    }

    private func updateLeftStick() {
        // Left stick: Y = Throttle (up/down), X = Yaw (rotate left/right)
        let normalizedX = Float(leftKnobOffset.width / trackRadius) * sensitivity
        let normalizedY = Float(-leftKnobOffset.height / trackRadius) * sensitivity // Invert Y for up/down

        // Mode-2: Left stick controls throttle and yaw
        throttle = normalizedY  // Y-axis: up/down movement
        yaw = normalizedX       // X-axis: rotate left/right

        gameLog("🕹️ LEFT stick - Throttle: \(throttle), Yaw: \(yaw)")
    }

    private func updateRightStick() {
        // Right stick: Y = Pitch (forward/back), X = Roll (strafe left/right)
        let normalizedX = Float(rightKnobOffset.width / trackRadius) * sensitivity
        let normalizedY = Float(-rightKnobOffset.height / trackRadius) * sensitivity // Invert Y for forward/back

        // Mode-2: Right stick controls pitch and roll
        pitch = normalizedY     // Y-axis: forward/backward movement
        roll = normalizedX      // X-axis: strafe left/right movement

        gameLog("🕹️ RIGHT stick - Pitch: \(pitch), Roll: \(roll)")
    }
}

// Direct drone movement (working approach from ControllableSystem)
struct JoystickControlsView: View {
    let worldSceneController: WorldSceneController

    // Mode-2 Flight Controls
    @State private var throttle: Float = 0.0       // Left stick Y - up/down movement
    @State private var yaw: Float = 0.0            // Left stick X - rotation left/right
    @State private var pitch: Float = 0.0          // Right stick Y - forward/backward movement
    @State private var roll: Float = 0.0           // Right stick X - strafe left/right movement

    // Current velocities for smooth movement
    @State private var currentVelocity: SIMD3<Float> = .zero
    @State private var currentYawVelocity: Float = 0.0

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // Control buttons
                VStack(spacing: DroneLayout.md) {
                    // Grab button
//                    VStack(spacing: DroneLayout.sm) {
//                        DroneButton(
//                            "Grab",
//                            icon: "hand.raised.fill",
//                            style: .primary,
//                            size: .medium
//                        ) {
//                            handleGrabAction()
//                        }
//
//                        Text("Grab")
//                            .font(DroneTypography.caption)
//                            .foregroundColor(.droneTextSecondary)
//                    }
//
//                    // Reset position button
//                    VStack(spacing: DroneLayout.sm) {
//                        DroneButton(
//                            "Reset",
//                            icon: "arrow.counterclockwise",
//                            style: .secondary,
//                            size: .medium
//                        ) {
//                            handleResetPosition()
//                        }
//
//                        Text("Reset")
//                            .font(DroneTypography.caption)
//                            .foregroundColor(.droneTextSecondary)
//                    }
                }
                .padding(.trailing, DroneLayout.md)

                JoystickView(throttle: $throttle, yaw: $yaw, pitch: $pitch, roll: $roll)
                    .onChange(of: throttle) { _, newValue in
                        moveDroneDirectly()
                    }
                    .onChange(of: yaw) { _, newValue in
                        moveDroneDirectly()
                    }
                    .onChange(of: pitch) { _, newValue in
                        moveDroneDirectly()
                    }
                    .onChange(of: roll) { _, newValue in
                        moveDroneDirectly()
                    }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }

    private func moveDroneDirectly() {
        guard let drone = worldSceneController.playerDrone else {
            gameLog("🚨 No drone found!")
            return
        }

        // While crashed (Time Trial), the course system owns the drone. Don't move
        // it — instead report throttle so the course can detect the recovery lift.
        if drone.isCrashActive {
            CourseInput.directLift = max(0, throttle)
            return
        }

        // Realistic drone physics parameters
        let deltaTime: Float = 1.0 / 60.0
        let maxSpeed: Float = 4.0
        let acceleration: Float = 8.0  // How fast we reach max speed
        let deceleration: Float = 12.0 // How fast we stop (faster than acceleration)
        let maxYawSpeed: Float = 2.5
        let yawAcceleration: Float = 6.0

        var droneTransform = drone.transform

        // Mode-2 Flight Controls: Create movement vector from individual controls
        let movement3D = SIMD3<Float>(
            roll,      // X-axis: strafe left/right (right stick X)
            throttle,  // Y-axis: up/down movement (left stick Y)
            pitch      // Z-axis: forward/backward (right stick Y)
        )

        // Calculate target velocity from Mode-2 controls
        let targetVelocity = movement3D * maxSpeed
        let targetYawVelocity = self.yaw * maxYawSpeed

        // Apply acceleration/deceleration for movement
        let movementLength = length(movement3D)
        if movementLength > 0.001 {
            // Accelerating towards target velocity
            let velocityDiff = targetVelocity - currentVelocity
            let accelerationStep = normalize(velocityDiff) * acceleration * deltaTime

            // Don't overshoot the target
            if length(accelerationStep) > length(velocityDiff) {
                currentVelocity = targetVelocity
            } else {
                currentVelocity += accelerationStep
            }
        } else {
            // Decelerating to stop
            let currentSpeed = length(currentVelocity)
            if currentSpeed > 0.001 {
                let decelerationStep = min(deceleration * deltaTime, currentSpeed)
                currentVelocity = currentVelocity * ((currentSpeed - decelerationStep) / currentSpeed)
            } else {
                currentVelocity = .zero
            }
        }

        // Apply acceleration/deceleration for yaw
        if abs(self.yaw) > 0.001 {
            // Accelerating towards target yaw velocity
            let yawDiff = targetYawVelocity - currentYawVelocity
            let yawAccelStep = (yawDiff > 0 ? 1.0 : -1.0) * yawAcceleration * deltaTime

            if abs(yawAccelStep) > abs(yawDiff) {
                currentYawVelocity = targetYawVelocity
            } else {
                currentYawVelocity += yawAccelStep
            }
        } else {
            // Decelerating yaw to stop
            if abs(currentYawVelocity) > 0.001 {
                let yawDecelerationStep = min(yawAcceleration * deltaTime, abs(currentYawVelocity))
                currentYawVelocity = currentYawVelocity * ((abs(currentYawVelocity) - yawDecelerationStep) / abs(currentYawVelocity))
            } else {
                currentYawVelocity = 0.0
            }
        }

        // Apply movement using current velocity
        let movementDelta = currentVelocity * deltaTime
        droneTransform.translation += movementDelta

        // Apply rotation using current yaw velocity
        if abs(currentYawVelocity) > 0.001 {
            let rotationDelta = currentYawVelocity * deltaTime
            let yawRotation = simd_quatf(angle: rotationDelta, axis: SIMD3<Float>(0, 1, 0))
            droneTransform.rotation = droneTransform.rotation * yawRotation
        }

        // Move drone
        drone.move(to: droneTransform, relativeTo: nil)

        gameLog("🎮 REALISTIC Virtual joystick: throttle=\(self.throttle), yaw=\(self.yaw), pitch=\(self.pitch), roll=\(self.roll), current_velocity=\(currentVelocity), current_yaw_velocity=\(currentYawVelocity)")
    }

    private func handleGrabAction() {
        guard let drone = worldSceneController.playerDrone else {
            gameLog("🚨 No drone found for grab action!")
            return
        }

        gameLog("🤖 Grab button pressed - spawning claw...")
        spawnClawAndAttemptGrab(from: drone)
    }

    private func handleResetPosition() {
        guard let drone = worldSceneController.playerDrone else {
            gameLog("🚨 No drone found for reset action!")
            return
        }

        gameLog("🔄 Reset button pressed - resetting drone position to origin...")

        // Reset drone position to origin (0, 0, 0)
        var resetTransform = drone.transform
        resetTransform.translation = SIMD3<Float>(0, 0, 0)
        resetTransform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) // Reset rotation too

        // Reset velocities to prevent continued movement
        currentVelocity = .zero
        currentYawVelocity = 0.0

        // Apply the reset transform
        drone.move(to: resetTransform, relativeTo: nil)

        gameLog("✅ Drone position reset to origin (0, 0, 0)")
    }

    private func spawnClawAndAttemptGrab(from drone: PlayerDroneEntity) {
        // Create the claw entity
        let clawEntity = Entity()

        // Load the Claw.usdz model
        Task {
            do {
                if let clawURL = Bundle.main.url(forResource: "Claw", withExtension: "usdz") {
                    let clawModel = try await Entity(contentsOf: clawURL)
                    await MainActor.run {
                        clawModel.scale = .init(repeating: 0.1)
                        clawEntity.addChild(clawModel)
                        gameLog("📦 Loaded Claw.usdz model successfully")
                    }
                } else {
                    // Fallback to procedural claw if USDZ not found
                    await MainActor.run {
                        createFallbackClaw(clawEntity)
                        gameLog("⚠️ Claw.usdz not found, using fallback claw")
                    }
                }
            } catch {
                gameLog("❌ Failed to load Claw.usdz: \(error)")
                await MainActor.run {
                    createFallbackClaw(clawEntity)
                }
            }
        }

        // Position claw directly below drone
        let dronePosition = drone.transform.translation
        clawEntity.transform.translation = SIMD3<Float>(dronePosition.x, dronePosition.y + 0.7, dronePosition.z)

        // Add physics and collision to claw
        setupClawPhysics(clawEntity)

        // Add to world scene
        worldSceneController.rootEntity.addChild(clawEntity)

        // Animate claw drop and check for package collision
        animateClawDrop(clawEntity)
    }

    private func createFallbackClaw(_ clawEntity: Entity) {
        // Create a simple claw using basic shapes
        let clawMesh = MeshResource.generateBox(width: 0.1, height: 0.15, depth: 0.1)
        let clawMaterial = SimpleMaterial(color: .gray, roughness: 0.3, isMetallic: true)
        let clawModel = ModelEntity(mesh: clawMesh, materials: [clawMaterial])

        // Add some claw prongs
        let prongMesh = MeshResource.generateBox(width: 0.02, height: 0.05, depth: 0.02)
        let prongMaterial = SimpleMaterial(color: .orange, roughness: 0.1, isMetallic: false)

        let leftProng = ModelEntity(mesh: prongMesh, materials: [prongMaterial])
        leftProng.transform.translation = SIMD3<Float>(-0.04, -0.1, 0)

        let rightProng = ModelEntity(mesh: prongMesh, materials: [prongMaterial])
        rightProng.transform.translation = SIMD3<Float>(0.04, -0.1, 0)

        clawEntity.addChild(clawModel)
        clawEntity.addChild(leftProng)
        clawEntity.addChild(rightProng)
    }

    private func setupClawPhysics(_ clawEntity: Entity) {
        // Add kinematic physics body to claw
        let shape = ShapeResource.generateBox(width: 0.1, height: 0.15, depth: 0.1)
        let material = PhysicsMaterialResource.generate(friction: 0.3, restitution: 0.2)

        clawEntity.components.set(PhysicsBodyComponent(
            massProperties: .default,
            material: material,
            mode: .kinematic
        ))

        // Add collision detection
        clawEntity.components.set(CollisionComponent(shapes: [shape]))
    }

    private func animateClawDrop(_ clawEntity: Entity) {
        // Drop the claw down by 2 meters
        let startPosition = clawEntity.transform.translation
        let endPosition = SIMD3<Float>(startPosition.x, startPosition.y - 2.0, startPosition.z)

        // Simple animation using a timer (in a real app you'd use RealityKit animations)
        let animationDuration: Float = 1.0
        let steps = 60 // 60 FPS
        let stepDuration = animationDuration / Float(steps)
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: TimeInterval(stepDuration), repeats: true) { timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)

            let currentPosition = mix(startPosition, endPosition, t: progress)
            clawEntity.transform.translation = currentPosition

            // Check for package collision during drop
            self.checkForPackageCollision(clawEntity)

            if currentStep >= steps {
                timer.invalidate()
                gameLog("🎯 Claw drop animation completed")
                // Remove claw after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    clawEntity.removeFromParent()
                }
            }
        }
    }

    private func checkForPackageCollision(_ clawEntity: Entity) {
        // Find all PackageEntity objects in the scene
        let clawPosition = clawEntity.transform.translation

        worldSceneController.rootEntity.children.forEach { entity in
            if let packageEntity = entity as? PackageEntity {
                let packagePosition = packageEntity.transform.translation
                let distance = length(clawPosition - packagePosition)

                // Check if claw is close enough to grab the package
                if distance < 0.3 && !packageEntity.isPickedUp {
                    gameLog("📦 Claw collided with package! Attempting pickup...")
                    grabPackage(packageEntity, with: clawEntity)
                }
            }
        }
    }

    private func grabPackage(_ package: PackageEntity, with clawEntity: Entity) {
        // Parent the package to the claw
        package.removeFromParent()
        clawEntity.addChild(package)

        // Position package relative to claw
        package.transform.translation = SIMD3<Float>(0, -0.1, 0)

        // Mark package as picked up
        package.pickup()

        gameLog("✅ Package successfully grabbed by claw!")

        // Update package physics to kinematic since it's now attached
        if var physicsBody = package.components[PhysicsBodyComponent.self] {
            physicsBody.mode = .kinematic
            package.components.set(physicsBody)
        }
    }

    // Helper function for linear interpolation
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + t * (b - a)
    }
}


#Preview {
    ZStack {
        // Background similar to our app
        LinearGradient(
            colors: [
                Color.black,
                Color.purpureus.opacity(0.05),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        DroneCard(variant: .glass) {
            JoystickView(
                throttle: .constant(0),
                yaw: .constant(0),
                pitch: .constant(0),
                roll: .constant(0)
            )
        }
        .padding(DroneLayout.lg)
    }
    .ignoresSafeArea()
}
