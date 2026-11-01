//
//  HelicopterGameApp.swift
//  HelicopterGame
//
//  Created by Hunter Harris on 10/1/25.
//

import SwiftUI

@main
struct HelicopterGameApp: App {

    @State private var appModel = AppModel()
    @State private var gameUIModel = GameUIModel()

    init() {
        // Register bundled cyber fonts (ShareTechMono / VT323) used by the splash.
        CyberTheme.registerFonts()

        // QA: relaunch with RESET_ONBOARDING=1 to replay the permissions gate +
        // flight tutorial from scratch.
        DroneOnboarding.resetIfRequested()
        ScreenshotDirector.prepareDefaults()
        #if os(visionOS)
        DemoDirector.prepareDefaults()
        #endif
    }

    var body: some SwiftUI.Scene {
        // DicyaninLabs studio splash + asset-loading flow. Declared first so it's the
        // window shown at launch; it opens "MainWindow" and dismisses itself when ready.
        WindowGroup(id: "DicyaninSplash") {
            DroneSplashView()
        }
        .windowStyle(.plain)
        .defaultSize(width: 1050, height: 1460)

        WindowGroup(id: "MainWindow") {
            VisionContentView()
                .frame(width: 600, height: 740).fixedSize()
                .environment(appModel)
                .environment(gameUIModel)
        }
        .defaultSize(width: 600, height: 740)
       
#if os(visionOS)
        WindowGroup(id: "live-drone-feed") {
            LiveDroneFeedView().environment(appModel)
        }
        .defaultSize(width: 1100, height: 800)
#endif

        WindowGroup(id: "joystick-help") {
            ThumbJoystickHelpView(isPresented: .constant(true))
                .frame(width: 600, height: 1200).fixedSize()
        }
        .defaultSize(width: 600, height: 1200)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(gameUIModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .immersiveEnvironmentBehavior(.coexist)

#if os(visionOS)
        ImmersiveSpace(id: LiveDroneMode.spaceID) {
            LiveDroneImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .immersiveEnvironmentBehavior(.coexist)
#endif
    }
}
