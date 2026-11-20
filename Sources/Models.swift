import Foundation

// MARK: - Data model (mirrors the tia-mcp project-spec shape: project → device → tags / blocks)

enum LadElementKind: String, Codable, CaseIterable {
    case contactNO   // --| |--
    case contactNC   // --|/|--
    case coil        // --( )--
    case coilSet     // --(S)--
    case coilReset   // --(R)--
    case ton         // TON box
    case ctu         // CTU box
}

struct LadElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: LadElementKind = .contactNO
    var tag: String = ""          // contact/coil operand; for TON/CTU the Q output tag
    var instance: String = ""     // TON/CTU instance name, e.g. "TON_1"
    var preset: String = "T#3s"   // TON PT / CTU PV (as text, like TIA shows)
    var presetValue: Int = 5      // CTU: PV count
    var presetSeconds: Double = 3 // TON: PT in seconds
    var inputTag: String = ""     // CTU count input tag (CU)
}

struct LadNetwork: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = ""
    var comment: String = ""
    var series: [LadElement] = []     // main rung, left → right
    var parallel: [LadElement] = []   // one parallel branch of contacts under the first elements
    var output: LadElement = LadElement(kind: .coil)
}

struct PlcTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var dataType: String = "Bool"
    var address: String = ""      // %I0.0 / %Q0.0 / %M0.0 …
    var comment: String = ""
}

struct PlcBlock: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Main"
    var number: Int = 1
    var type: String = "OB"       // OB / FB / FC
    var language: String = "LAD"
    var networks: [LadNetwork] = []
}

struct PlcModule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var slot: Int = 1
    var iAddress: String = ""
    var qAddress: String = ""
    var article: String = ""
    var firmware: String = ""
}

struct PlcDevice: Identifiable, Codable {
    var id = UUID()
    var name: String = "PLC_1"
    var cpuName: String = "CPU 1214C DC/DC/DC"
    var article: String = "6ES7 214-1AG40-0XB0"
    var firmware: String = "V4.4"
    var modules: [PlcModule] = []
    var tags: [PlcTag] = []
    var blocks: [PlcBlock] = []
}

struct TiaProject: Identifiable, Codable {
    var id = UUID()
    var name: String = "Project1"
    var author: String = ""
    var comment: String = ""
    var created: Date = Date()
    var devices: [PlcDevice] = []

    static func newProject(name: String) -> TiaProject {
        var p = TiaProject(name: name)
        var d = PlcDevice()
        d.modules = [
            PlcModule(name: "PLC_1", slot: 1, iAddress: "0…1", qAddress: "0…1",
                      article: "6ES7 214-1AG40-0XB0", firmware: "V4.4"),
            PlcModule(name: "DI 14/DQ 10_1", slot: 11, iAddress: "0…1", qAddress: "0…1",
                      article: "", firmware: ""),
            PlcModule(name: "AI 2_1", slot: 12, iAddress: "64…67", qAddress: "",
                      article: "", firmware: ""),
            PlcModule(name: "CB 1241 (RS485)", slot: 101, iAddress: "", qAddress: "",
                      article: "", firmware: "")
        ]
        d.blocks = [PlcBlock(name: "Main", number: 1, type: "OB")]
        p.devices = [d]
        return p
    }

    /// The demo project students open first: the sorting-station exercise
    /// (same station as the Agent Factory / tia-mcp twin).
    static func demoProject() -> TiaProject {
        var p = newProject(name: "SortingStation")
        let tags: [(String, String)] = [
            ("SensEntry", "%I0.0"), ("SensSort", "%I0.1"), ("SensCount", "%I0.2"),
            ("SensCross", "%I0.3"), ("PusherFront", "%I0.4"), ("PusherBack", "%I0.5"),
            ("BtnStart", "%I0.6"), ("SelDivert", "%I0.7"),
            ("BeltA", "%Q0.0"), ("BeltB", "%Q0.1"), ("BeltC", "%Q0.2"),
            ("Pusher", "%Q0.3"), ("Blade", "%Q0.4"), ("LampRun", "%Q0.5"),
            ("StackGreen", "%Q0.6"), ("StackAmber", "%Q0.7"), ("StackRed", "%Q1.0"),
            ("BatchFull", "%M0.0")
        ]
        p.devices[0].tags = tags.map { PlcTag(name: $0.0, dataType: "Bool", address: $0.1) }
        func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }
        var ton = LadElement(kind: .ton, tag: "Blade", instance: "HoldTimer")
        ton.preset = "T#3.5s"; ton.presetSeconds = 3.5
        var ctu = LadElement(kind: .ctu, tag: "BatchFull", instance: "BatchCounter")
        ctu.inputTag = "SensCount"; ctu.preset = "5"; ctu.presetValue = 5
        p.devices[0].blocks[0].networks = [
            LadNetwork(title: "Belts and run lamp follow BtnStart",
                       series: [el(.contactNO, "BtnStart")],
                       output: el(.coil, "BeltA")),
            LadNetwork(title: "Second belt",
                       series: [el(.contactNO, "BtnStart")],
                       output: el(.coil, "BeltB")),
            LadNetwork(title: "Run lamp",
                       series: [el(.contactNO, "BtnStart")],
                       output: el(.coil, "LampRun")),
            LadNetwork(title: "Count boxes, batch of 5 holds the blade (TON)",
                       series: [ctu],
                       output: ton),
            LadNetwork(title: "Batch full lamp",
                       series: [el(.contactNO, "BatchFull")],
                       output: el(.coil, "StackAmber")),
            LadNetwork(title: "Blade active lamp",
                       series: [el(.contactNO, "Blade")],
                       output: el(.coil, "StackRed")),
            LadNetwork(title: "Running and no batch hold: green lamp",
                       series: [el(.contactNO, "LampRun"), el(.contactNC, "Blade")],
                       output: el(.coil, "StackGreen"))
        ]
        return p
    }
}

// MARK: - Compile diagnostics

struct Diagnostic: Identifiable {
    var id = UUID()
    var isError: Bool
    var path: String      // e.g. PLC_1 › Program blocks › Main (OB1)
    var text: String
    var time: String
}
