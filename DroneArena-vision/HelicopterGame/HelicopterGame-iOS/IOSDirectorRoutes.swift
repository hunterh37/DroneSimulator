//
//  IOSDirectorRoutes.swift
//  HelicopterGame-iOS
//
//  DEBUG StageDirector routes for the iPhone app. Each route launches one mode
//  and optionally drives the virtual joysticks with -P.left / -P.right ("x,y").
//

#if DEBUG
import Foundation
import DicyaninStageDirector

@MainActor
enum IOSDirectorRoutes {
    private static let modes: [(String, GameMode, String)] = [
        ("practice", .playPractice, "Arena practice"),
        ("timetrial", .playTimeTrial, "Time trial"),
        ("safari", .playSafari, "Safari"),
        ("race", .playRaceLeague, "Race league"),
        ("crate", .playCrateDelivery, "Crate delivery"),
        ("sandbox", .playSandbox, "Sandbox"),
        ("delivery", .playDelivery, "Delivery"),
    ]

    static func register(_ b: RouteBook, appModel: AppModel, gameUIModel: GameUIModel) {
        b.route("menu/home", "Main menu", duration: 4) { take in
            await take.wait(2)
            await take.ready()
            take.done()
        }
        b.group("fly") { b in
            for (name, mode, summary) in modes {
                b.route(name, summary, duration: 12, tags: ["iphone"]) { take in
                    appModel.mobileLaunchRequest = mode
                    await take.wait(take.param("load", default: 6))
                    applySticks(take, appModel: appModel)
                    await take.ready()
                    await take.wait(take.param("hold", default: 2))
                    take.done()
                }
            }
        }
    }

    private static func applySticks(_ take: Take, appModel: AppModel) {
        func parse(_ key: String) -> CGPoint? {
            guard let v = take.param(key) else { return nil }
            let p = v.split(separator: ",").compactMap { Double($0) }
            return p.count == 2 ? CGPoint(x: p[0], y: p[1]) : nil
        }
        if let l = parse("left") { appModel.inputRouter.setLeftJoystick(position: l, active: true) }
        if let r = parse("right") { appModel.inputRouter.setRightJoystick(position: r, active: true) }
    }
}
#endif
