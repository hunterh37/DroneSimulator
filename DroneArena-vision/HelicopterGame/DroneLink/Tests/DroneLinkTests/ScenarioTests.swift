import Testing
@testable import DroneLink

struct ScenarioTests {
    @Test(arguments: ObstacleScenario.all.map(\.name))
    func scenario(_ name: String) {
        let sc = ObstacleScenario.all.first { $0.name == name }!
        let r = ScenarioRunner.run(sc)
        print(r.summary)
        #expect(r.passed, Comment(rawValue: r.summary))
    }
}
