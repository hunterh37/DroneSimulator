//
//  DemoScript.swift
//  HelicopterGame
//
//  Op model for DemoDirector. Scripts are JSON arrays of ops, run in order.
//  Built-in scripts live in `DemoScript.builtIn`; any JSON file in
//  Documents/demo/scripts/<name>.json overrides them.
//
//  Ops (all fields optional unless noted):
//    {"op":"mode","value":"race|safari|crate|practice|timetrial|menu"}
//    {"op":"wait","dur":2}
//    {"op":"stick","thr":0,"yaw":0,"fwd":0.6,"strafe":0,"dur":2}   sticks in -1...1
//    {"op":"goto","pos":[x,y,z],"dur":6,"speed":0.8}               root-space metres
//    {"op":"seek","target":"gates|SafariCritter_|FoldCrate_|RelayGate_red","dur":10,
//         "speed":0.8,"alt":0.0}
//    {"op":"deliver","count":2}       Fold Freight: hook nearest crate, drop at its gate
//    {"op":"cam","preset":"chase|side|front|high|low","orbit":0.25,"dist":1.0,"ease":0.08}
//    {"op":"beginRace"} {"op":"crateShift"} {"op":"claw"} {"op":"reset"}
//    {"op":"mark","label":"race_start"}  timestamp written to state.json for editing
//    {"op":"loop"}                       restart the script from the top
//

import Foundation

struct DemoOp: Codable, Sendable {
    var op: String
    var value: String?
    var dur: Double?
    var thr: Float?
    var yaw: Float?
    var fwd: Float?
    var strafe: Float?
    var pos: [Float]?
    var speed: Float?
    var target: String?
    var alt: Float?
    var count: Int?
    var preset: String?
    var orbit: Float?
    var dist: Float?
    var ease: Float?
    var label: String?
}

enum DemoScript {
    static func load(_ name: String) -> [DemoOp] {
        if let url = DemoPaths.scripts?.appendingPathComponent("\(name).json"),
           let data = try? Data(contentsOf: url),
           let ops = try? JSONDecoder().decode([DemoOp].self, from: data) {
            return ops
        }
        if let data = builtIn[name]?.data(using: .utf8),
           let ops = try? JSONDecoder().decode([DemoOp].self, from: data) {
            return ops
        }
        NSLog("[Demo] unknown script \(name)")
        return []
    }

    static let builtIn: [String: String] = [
        "race": """
        [{"op":"mode","value":"race"},{"op":"cam","preset":"chase","dist":0.8},
         {"op":"wait","dur":3},{"op":"mark","label":"race_grid"},{"op":"beginRace"},
         {"op":"wait","dur":4.5},{"op":"mark","label":"race_go"},
         {"op":"seek","target":"gates","dur":14,"speed":0.9},
         {"op":"cam","preset":"side","orbit":0.15},{"op":"mark","label":"race_side"},
         {"op":"seek","target":"gates","dur":10,"speed":0.9},
         {"op":"cam","preset":"front"},{"op":"mark","label":"race_front"},
         {"op":"seek","target":"gates","dur":8,"speed":0.9},{"op":"mark","label":"race_end"}]
        """,
        "safari": """
        [{"op":"mode","value":"safari"},{"op":"cam","preset":"chase","dist":1.0},
         {"op":"wait","dur":3},{"op":"mark","label":"safari_start"},
         {"op":"seek","target":"SafariCritter_","dur":12,"speed":0.7,"alt":0.05},
         {"op":"cam","preset":"high","orbit":0.2},{"op":"mark","label":"safari_high"},
         {"op":"seek","target":"SafariCritter_","dur":12,"speed":0.7,"alt":0.05},
         {"op":"cam","preset":"low"},{"op":"mark","label":"safari_low"},
         {"op":"seek","target":"SafariCritter_","dur":8,"speed":0.7,"alt":0.05},
         {"op":"mark","label":"safari_end"}]
        """,
        "crate": """
        [{"op":"mode","value":"crate"},{"op":"cam","preset":"chase","dist":0.9},
         {"op":"wait","dur":3},{"op":"crateShift"},{"op":"wait","dur":2},
         {"op":"mark","label":"crate_start"},{"op":"deliver","count":2},
         {"op":"cam","preset":"side","orbit":0.2},{"op":"mark","label":"crate_side"},
         {"op":"deliver","count":2},{"op":"mark","label":"crate_end"}]
        """,
        "freeflight": """
        [{"op":"mode","value":"menu","dur":1},{"op":"cam","preset":"fixed"},{"op":"reset"},
         {"op":"mark","label":"room_start"},
         {"op":"goto","pos":[0,1.2,-1.4],"dur":3,"speed":0.5},
         {"op":"goto","pos":[1.2,1.4,-2.2],"dur":3.5,"speed":0.6},
         {"op":"goto","pos":[0.2,1.7,-3.2],"dur":3.5,"speed":0.6},
         {"op":"goto","pos":[-1.3,1.3,-2.3],"dur":3.5,"speed":0.6},
         {"op":"goto","pos":[-0.4,0.9,-1.2],"dur":3,"speed":0.5},
         {"op":"goto","pos":[0.25,1.4,-0.75],"dur":2.5,"speed":0.4},
         {"op":"stick","yaw":1,"dur":2},
         {"op":"goto","pos":[0,1.25,-1.0],"dur":2.5,"speed":0.4},
         {"op":"mark","label":"room_end"}]
        """,
        "all": """
        [{"op":"run","value":"freeflight"},{"op":"run","value":"race"},
         {"op":"run","value":"safari"},{"op":"run","value":"crate"},{"op":"mode","value":"menu"}]
        """,
    ]
}

enum DemoPaths {
    static var root: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("demo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    static var scripts: URL? { root?.appendingPathComponent("scripts", isDirectory: true) }
    /// Live channel: write a JSON op or op array here; it is consumed and deleted.
    static var command: URL? { root?.appendingPathComponent("cmd.json") }
    /// Status surface: mode, phase, drone pose, active op, marks.
    static var state: URL? { root?.appendingPathComponent("state.json") }
}
