//
//  ContentView.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI
import RealityKit
#if os(visionOS)
import DicyaninThumbController
#endif

struct VisionContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(GameUIModel.self) var gameUIModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showingSettings = false
    @State private var animateElements = false
    @State private var showBetaDisclaimer = false
#if os(iOS)
    @State private var showMobileRealityView = false
#endif
#if os(visionOS)
    @State private var showThumbControllerSettings = false
    @State private var showThumbJoystickHelp = false
    /// Hand controls guide auto-opens the first time the player enters a game.
    @AppStorage("hasSeenHandControlsHelp") private var hasSeenHandControlsHelp = false
    @State private var isDroneLaunched = false
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    /// First-launch onboarding: drop the player straight into the permissions
    /// gate + flight tutorial on the very first run, without tapping Play.
    @State private var showFirstLaunchPermissions = false
#endif

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background with animated gradients
                backgroundView
                    .ignoresSafeArea()

                // Main content container
                VStack(spacing: 0) {

                    // Main content area
                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Bottom controls (joystick area)
                    if shouldShowJoystickControls {
                        switch gameUIModel.modeManager.currentMode {
                        case .menu:
                            EmptyView()
                        default:
                            bottomControlsView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                // Beta disclaimer overlay (highest priority)
                if showBetaDisclaimer {
                    BetaDisclaimerView(isPresented: $showBetaDisclaimer)
                        .zIndex(1000) // Ensure it appears above everything
                }
            }
        }
        .onAppear {
            // Tear down the DicyaninLabs splash window now that the main menu is up.
            #if os(visionOS)
            dismissWindow(id: "DicyaninSplash")
            #endif

            // Check if user has seen beta disclaimer
            #if DEBUG
            let hasSeenDisclaimer = UserDefaults.standard.bool(forKey: "HasSeenBetaDisclaimer")
                || ProcessInfo.processInfo.arguments.contains("-Route")
            #else
            let hasSeenDisclaimer = true
            #endif
            if !hasSeenDisclaimer {
                showBetaDisclaimer = true
            } else {
                // First launch: if there's no disclaimer to show first, kick off
                // the permissions gate right away. Otherwise it's chained after
                // the disclaimer is dismissed (see onChange below).
                #if os(visionOS)
                if DronePermissionsGate.needsPrompt {
                    showFirstLaunchPermissions = true
                }
                #endif
            }

            withAnimation(.easeInOut(duration: 1.0)) {
                animateElements = true
            }
            #if os(visionOS)
            if let shotMode = ScreenshotDirector.mode {
                Task {
                    appModel.immersiveSpaceState = .inTransition
                    if case .opened = await openImmersiveSpace(id: appModel.immersiveSpaceID) {} else {
                        appModel.immersiveSpaceState = .closed
                    }
                }
                gameUIModel.modeManager.switchToMode(shotMode)
            }
            if ScreenshotDirector.mode == nil && DemoDirector.isActive {
                Task {
                    appModel.immersiveSpaceState = .inTransition
                    if case .opened = await openImmersiveSpace(id: appModel.immersiveSpaceID) {} else {
                        appModel.immersiveSpaceState = .closed
                    }
                    if DemoDirector.hideUI {
                        try? await Task.sleep(for: .seconds(4))
                        dismissWindow(id: "MainWindow")
                    }
                }
            }
            #endif
        }
        #if os(visionOS)
        .onChange(of: appModel.immersiveSpaceState) { _, state in
            if state == .open && !hasSeenHandControlsHelp {
                hasSeenHandControlsHelp = true
                showThumbJoystickHelp = true
            }
        }
        .onChange(of: showBetaDisclaimer) { _, isShowing in
            // Once the beta disclaimer is dismissed on first launch, present the
            // ARKit permissions gate, which then flows into the flight tutorial.
            if !isShowing && DronePermissionsGate.needsPrompt {
                showFirstLaunchPermissions = true
            }
        }
        .fullScreenCover(isPresented: $showFirstLaunchPermissions) {
            DroneARKitPermissionsView(
                onContinue: { beginFirstLaunchOnboarding() }
            )
        }
        #endif
        .sheet(isPresented: $showingSettings) {
            DroneSettingsView()
        }
#if os(iOS)
        .fullScreenCover(isPresented: $showMobileRealityView) {
            MobileRealityView(isPresented: $showMobileRealityView)
                .environment(appModel)
                .environment(gameUIModel)
        }
        .onChange(of: appModel.mobileLaunchRequest) { _, mission in
            guard let mission else { return }
            appModel.mobileLaunchRequest = nil
            appModel.immersiveSpaceState = .open
            showMobileRealityView = true
            gameUIModel.modeManager.switchToMode(mission)
        }
        .onChange(of: showMobileRealityView) { oldValue, newValue in
            gameLog("📱 [iOS] showMobileRealityView changed from \(oldValue) to \(newValue)")
        }
#endif
#if os(visionOS)
        .sheet(isPresented: $showThumbControllerSettings) {
            ThumbControllerSettingsView()
        }
        .sheet(isPresented: $showThumbJoystickHelp) {
            ThumbJoystickHelpView(isPresented: $showThumbJoystickHelp)
        }
#endif
    }

#if os(visionOS)
    /// First-launch flow: record the gate as shown, then auto-open the immersive
    /// space in free-flight (sandbox) mode. ImmersiveView's `.task` starts the
    /// flight tutorial once the world is up.
    @MainActor
    private func beginFirstLaunchOnboarding() {
        DronePermissionsGate.markPrompted()
        showFirstLaunchPermissions = false

        Task {
            appModel.immersiveSpaceState = .inTransition
            let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
            switch result {
            case .opened:
                break
            default:
                appModel.immersiveSpaceState = .closed
            }
        }

        gameUIModel.modeManager.switchToMode(.playSandbox)
    }
#endif

    // MARK: - Background
    private var backgroundView: some View {
        ArenaBackdrop()
    }

    // MARK: - Top Status Bar
    private var topStatusBar: some View {
        HStack {
            // Game title with glow effect
//            VStack(alignment: .leading, spacing: 4) {
//                Text("DroneArena")
//                    .font(DroneTypography.heroTitle)
//                    .foregroundColor(.droneTextPrimary)
//                    .shadow(color: .droneAccent.opacity(0.5), radius: 8, x: 0, y: 0)
//            }

            Spacer()

            // Connection status
//            StatusIndicator(appModel.immersiveSpaceState == .open ? .online : .offline, label: "System")

            // Settings button
          /*  DroneButton(
                "",
                icon: "gearshape.fill",
                style: .ghost,
                size: .small
            ) {
                showingSettings = true
            }*/
        }
        .padding(.vertical, DroneLayout.sm)
    }

    // MARK: - Main Content
    private var mainContentView: some View {
        ZStack {
            switch gameUIModel.modeManager.currentMode {
            case .menu:
#if os(iOS)
                DroneMainMenuView(modeManager: gameUIModel.modeManager, multiplayerManager: gameUIModel.multiplayerManager, showMobileRealityView: $showMobileRealityView)
                    .environment(gameUIModel.economyModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
#else
                DroneMainMenuView(modeManager: gameUIModel.modeManager, multiplayerManager: gameUIModel.multiplayerManager)
                    .environment(gameUIModel.economyModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
#endif
                    

            case .results:
                if let results = gameUIModel.modeManager.currentSessionResults {
                    DroneResultsView(
                        results: results,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                gameUIModel.modeManager.returnToMenu()
                            }
                        },
                        onRestart: {
                            gameUIModel.modeManager.restartCurrentSession()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }

            case .build, .playSandbox, .playDelivery, .playMultiplayer, .playPractice, .playTimeTrial, .playSafari, .playRaceLeague, .playCrateDelivery, .play:
                #if os(visionOS)
                VisionMainContentView(
                    showThumbControllerSettings: $showThumbControllerSettings,
                    showThumbJoystickHelp: $showThumbJoystickHelp,
                    isDroneLaunched: $isDroneLaunched
                )
                .environment(gameUIModel)
                .transition(.move(edge: .top).combined(with: .opacity))
                #else
                EmptyView()
                #endif
            }
        }
        .animation(.easeInOut(duration: 0.5), value: gameUIModel.modeManager.currentMode)
//        .padding(.horizontal, DroneLayout.lg)
    }

    // MARK: - Bottom Controls
    private var bottomControlsView: some View {
        VStack(spacing: DroneLayout.md) {

            // Virtual joysticks (same as iOS)
            HStack {
                // Left joystick (throttle + yaw)
                VirtualJoystick(
                    position: appModel.inputRouter.rightJoystickPosition,
                    isActive: appModel.inputRouter.isRightJoystickActive,
                    onPositionChanged: { position, active in
                        appModel.inputRouter.setRightJoystick(position: position, active: active)
                    },
                    isLeftJoystick: false
                )
                .frame(width: 120, height: 120)

                Spacer()

                // Right joystick (pitch + roll)
                VirtualJoystick(
                    position: appModel.inputRouter.leftJoystickPosition,
                    isActive: appModel.inputRouter.isLeftJoystickActive,
                    onPositionChanged: { position, active in
                        appModel.inputRouter.setLeftJoystick(position: position, active: active)
                    },
                    isLeftJoystick: true
                )
                .frame(width: 120, height: 120)
            }
            .padding(.horizontal, DroneLayout.lg)
        }
        .padding(.bottom, DroneLayout.lg)
    }

    // MARK: - Computed Properties
    private var shouldShowJoystickControls: Bool {
        #if os(visionOS)
        return false

        #else
        // On other platforms (like iOS), use existing logic
        switch gameUIModel.modeManager.currentMode {
        case .playSandbox, .playDelivery, .playMultiplayer, .play:
            return appModel.immersiveSpaceState == .open
        default:
            return false
        }
        #endif
    }
}

// MARK: - Supporting Views

struct GridPatternView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 40
            let strokeWidth: CGFloat = 0.5

            // Vertical lines
            for x in stride(from: 0, through: size.width, by: spacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.white.opacity(0.1)),
                    lineWidth: strokeWidth
                )
            }

            // Horizontal lines
            for y in stride(from: 0, through: size.height, by: spacing) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.white.opacity(0.1)),
                    lineWidth: strokeWidth
                )
            }
        }
    }
}

struct DroneSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            DroneCard(variant: .primary) {
                VStack(spacing: DroneLayout.lg) {
                    Text("Settings")
                        .font(DroneTypography.title)
                        .foregroundColor(.droneTextPrimary)

                    Text("Settings panel coming soon...")
                        .font(DroneTypography.body)
                        .foregroundColor(.droneTextSecondary)

                    DroneButton("Close", style: .primary) {
                        dismiss()
                    }
                }
                .padding(DroneLayout.lg)
            }
            .padding(DroneLayout.lg)
            .background(Color.black)
        }
    }
}

#if os(visionOS)
#Preview(windowStyle: .automatic) {
    VisionContentView()
        .environment(AppModel())
        .environment(GameUIModel())
}
#else
#Preview {
    EmptyView()
}
#endif
