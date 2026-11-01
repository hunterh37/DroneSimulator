//
//  HelicopterGame_iOSApp.swift
//  HelicopterGame-iOS
//
//  Created by Hunter Harris on 10/3/25.
//

import SwiftUI
#if DEBUG
import DicyaninStageDirector
#endif

@main
struct HelicopterGame_iOSApp: App {
    
    @State private var appModel = AppModel()
    @State private var gameUIModel = GameUIModel()
    
    var body: some Scene {
        WindowGroup {
            VisionContentView()
                .environment(appModel)
                .environment(gameUIModel)
            #if DEBUG
                .task {
                    let director = Director.shared
                    guard director.isDirecting else { return }
                    director.register { IOSDirectorRoutes.register($0, appModel: appModel, gameUIModel: gameUIModel) }
                    director.start()
                }
            #endif
        }
    }
}
