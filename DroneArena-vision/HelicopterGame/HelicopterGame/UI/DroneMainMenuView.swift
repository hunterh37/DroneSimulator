//
//  DroneMainMenuView.swift
//  HelicopterGame
//
//  Menu flow controller: 01 Event, 02 Garage, 03 Armory, then launch.
//  Steps render inline and slide forward/back so the flow reads like a
//  pre-race sequence.
//

import SwiftUI
#if os(visionOS)
import DicyaninThumbController
#endif

struct DroneMainMenuView: View {
    let modeManager: ModeManager
    let multiplayerManager: MultiplayerManager
    @Environment(EconomyModel.self) var economyModel
    @Environment(AppModel.self) var appModel
    @Environment(GameUIModel.self) var gameUIModel
#if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var showPermissionsGate = false
    @State private var pendingMission: GameMode? = nil
#endif

    enum Stage: Int { case home, garage, armory }

    /// StageDirector `-P.stage garage|armory` starts the menu on that step (DEBUG only).
    private static var debugStage: Stage {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-P.stage"), i + 1 < args.count {
            switch args[i + 1] {
            case "garage": return .garage
            case "armory": return .armory
            default: break
            }
        }
        #endif
        return .home
    }

    @State private var stage: Stage = DroneMainMenuView.debugStage
    @State private var forward = true
    @State private var event: ArenaEvent = .race
    @State private var showRankHelp = false
#if os(iOS)
    @Binding var showMobileRealityView: Bool
#endif

#if os(iOS)
    init(modeManager: ModeManager, multiplayerManager: MultiplayerManager, showMobileRealityView: Binding<Bool>) {
        self.modeManager = modeManager
        self.multiplayerManager = multiplayerManager
        self._showMobileRealityView = showMobileRealityView
        UIApplication.shared.isIdleTimerDisabled = true
    }
#else
    init(modeManager: ModeManager, multiplayerManager: MultiplayerManager) {
        self.modeManager = modeManager
        self.multiplayerManager = multiplayerManager
    }
#endif

    var body: some View {
        ZStack {
            ArenaBackdrop(tint: stage == .home ? Arena.volt : event.tint)
            Group {
                switch stage {
                case .home:
                    ArenaHomeView(
                        multiplayerManager: multiplayerManager,
                        onPick: { e in event = e; go(.garage) },
                        onRankHelp: { showRankHelp = true }
                    )
                case .garage:
                    DroneSelectionView(
                        onDroneSelected: { d in
                            GameContext.shared.loadout.selectDrone(d)
                            go(.armory)
                        },
                        onCancel: { go(.home) }
                    )
                case .armory:
                    ArmoryView(event: event, onBack: { go(.garage) }, onLaunch: {
                        RaceLeagueManager.shared.isPractice = event.isPractice
                        launchMission(event.mode)
                    })
                }
            }
            .id(stage)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: forward ? 50 : -50)),
                removal: .opacity.combined(with: .offset(x: forward ? -50 : 50))
            ))
        }
        .preferredColorScheme(.dark)
#if os(visionOS)
        .fullScreenCover(isPresented: $showPermissionsGate) {
            DroneARKitPermissionsView(
                onContinue: { resumeAfterPermissionsGate() }
            )
        }
#endif
        .sheet(isPresented: $showRankHelp) { PlayerRankHelpView() }
    }

    private func go(_ next: Stage) {
        forward = next.rawValue > stage.rawValue
        withAnimation(Arena.snap) { stage = next }
    }

    // MARK: - Launch

    @MainActor
    private func launchMission(_ mission: GameMode) {
        guard mission != .playMultiplayer else {
            gameLog("📱 [iOS] Skipping multiplayer mission")
            return
        }

#if os(visionOS)
        // First launch only: show the ARKit permissions gate before the immersive
        // space opens, so tracking is authorized before the flight tutorial runs.
        // Defer the mission until the player clears (or skips) the gate.
        if DronePermissionsGate.needsPrompt {
            pendingMission = mission
            showPermissionsGate = true
            return
        }

        openImmersiveSpace(for: mission)
#else
        if appModel.immersiveSpaceState == .closed {
            appModel.immersiveSpaceState = .inTransition
            showMobileRealityView = true
            appModel.immersiveSpaceState = .open
            modeManager.switchToMode(mission)
        }
#endif
    }

#if os(visionOS)
    /// Actually opens the immersive space for a mission. Split out from
    /// `launchMission` so the permissions gate can resume here after the player
    /// grants (or skips) access.
    @MainActor
    private func openImmersiveSpace(for mission: GameMode) {
        Task {
            appModel.immersiveSpaceState = .inTransition
            let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)

            switch result {
            case .opened:
                break
            case .userCancelled, .error:
                appModel.immersiveSpaceState = .closed
            @unknown default:
                appModel.immersiveSpaceState = .closed
            }
        }

        modeManager.switchToMode(mission)
    }

    /// Called when the permissions gate is dismissed (granted or skipped):
    /// records that we've prompted and resumes the deferred mission.
    @MainActor
    private func resumeAfterPermissionsGate() {
        DronePermissionsGate.markPrompted()
        showPermissionsGate = false
        if let mission = pendingMission {
            pendingMission = nil
            openImmersiveSpace(for: mission)
        }
    }
#endif

}
