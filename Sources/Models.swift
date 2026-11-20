import Foundation

// MARK: - Data model (mirrors the tia-mcp project-spec shape: project → device → tags / blocks)
// New fields added in v2 are Optional so v1 project files still open.

enum LadElementKind: String, Codable, CaseIterable {
    case contactNO   // --| |--
    case contactNC   // --|/|--
    case coil        // --( )--
    case coilSet     // --(S)--
    case coilReset   // --(R)--
    case ton         // TON box (on-delay)
    case tof         // TOF box (off-delay)
    case tp          // TP box (pulse)
    case ctu         // CTU box (count up)
    case ctd         // CTD box (count down)
    case pTrig       // --|P|-- edge contact
    case nTrig       // --|N|-- edge contact
    case notOp       // NOT (invert rung power)
}

struct LadElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: LadElementKind = .contactNO
    var tag: String = ""          // contact/coil operand; for timer/counter boxes the Q output tag
    var instance: String = ""     // timer/counter instance name, e.g. "TON_1"
    var preset: String = "T#3s"   // PT / PV as text, like TIA shows
    var presetValue: Int = 5      // counter PV
    var presetSeconds: Double = 3 // timer PT in seconds
    var inputTag: String = ""     // counter count-input tag (CU / CD)
}

struct LadNetwork: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = ""
    var comment: String = ""
    var series: [LadElement] = []
    var parallel: [LadElement] = []
    var output: LadElement = LadElement(kind: .coil)
}

struct PlcTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var dataType: String = "Bool"
    var address: String = ""      // %I0.0 / %Q0.0 / %M0.0 …
    var comment: String = ""
}

struct InterfaceVar: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var section: String = "Temp"  // Input / Output / InOut / Static / Temp / Constant / Return
    var dataType: String = "Bool"
    var comment: String = ""
}

struct PlcBlock: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Main"
    var number: Int = 1
    var type: String = "OB"       // OB / FB / FC
    var language: String = "LAD"
    var networks: [LadNetwork] = []
    var interfaceRows: [InterfaceVar]? = nil   // v2 (optional: v1 files)
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

// MARK: - HMI (v2)

enum HmiElementKind: String, Codable, CaseIterable {
    case button, lamp, ioField, textLabel, bar
    case gauge, slider, toggleSwitch, symbol   // Studio additions (v3.3)
}

struct HmiElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: HmiElementKind = .button
    var text: String = ""
    var tag: String = ""          // PLC tag binding (button/lamp) or counter instance (ioField/bar)
    var x: Double = 20            // position on the 800x480 KTP700 canvas
    var y: Double = 20
    var w: Double = 96
    var h: Double = 40
    var colorOn: String = "green" // lamp on-colour name
    // Studio additions (v3.3) — decoded with decodeIfPresent so screens
    // saved by older versions still open.
    var symbol: String = ""       // symbol name (kind .symbol) or target screen (button action "navigate")
    var action: String = "momentary" // button: momentary / toggle / set / reset / navigate
    var fontSize: Double = 15
}

extension HmiElement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(HmiElementKind.self, forKey: .kind) ?? .button
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 20
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 20
        w = try c.decodeIfPresent(Double.self, forKey: .w) ?? 96
        h = try c.decodeIfPresent(Double.self, forKey: .h) ?? 40
        colorOn = try c.decodeIfPresent(String.self, forKey: .colorOn) ?? "green"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        action = try c.decodeIfPresent(String.self, forKey: .action) ?? "momentary"
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 15
    }
}

struct HmiScreen: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Screen_1"
    var elements: [HmiElement] = []
}

struct HmiDevice: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "HMI_1"
    var panel: String = "KTP700 Basic PN"
    var screens: [HmiScreen] = [HmiScreen()]
    var startScreen: Int = 0      // Studio addition (v3.3)
}

extension HmiDevice {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "HMI_1"
        panel = try c.decodeIfPresent(String.self, forKey: .panel) ?? "KTP700 Basic PN"
        screens = try c.decodeIfPresent([HmiScreen].self, forKey: .screens) ?? [HmiScreen()]
        startScreen = try c.decodeIfPresent(Int.self, forKey: .startScreen) ?? 0
    }
}

// MARK: - Project

struct TiaProject: Identifiable, Codable {
    var id = UUID()
    var name: String = "Project1"
    var author: String = ""
    var comment: String = ""
    var created: Date = Date()
    var devices: [PlcDevice] = []
    var hmi: HmiDevice? = nil          // v2 (optional: v1 files)
    var watchTags: [String]? = nil     // v2 (optional: v1 files)

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
        var main = PlcBlock(name: "Main", number: 1, type: "OB")
        main.interfaceRows = [
            InterfaceVar(name: "Initial_Call", section: "Temp", dataType: "Bool", comment: "Initial call of this OB"),
            InterfaceVar(name: "Remanence", section: "Temp", dataType: "Bool", comment: "Scan cycle start info"),
            InterfaceVar(name: "Temp_1", section: "Temp", dataType: "Bool", comment: "")
        ]
        d.blocks = [main]
        p.devices = [d]
        p.hmi = HmiDevice()
        return p
    }

    /// The demo project students open first: the sorting station,
    /// with its HMI screen and watch table ready.
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
        p.watchTags = ["BtnStart", "SensCount", "BeltA", "Blade", "BatchFull", "StackGreen"]
        var screen = HmiScreen(name: "Screen_1")
        screen.elements = [
            HmiElement(kind: .textLabel, text: "Sorting Station", x: 24, y: 16, w: 420, h: 44),
            HmiElement(kind: .button, text: "START", tag: "BtnStart", x: 24, y: 96, w: 220, h: 96),
            HmiElement(kind: .lamp, text: "Running", tag: "LampRun", x: 280, y: 96, w: 180, h: 96),
            HmiElement(kind: .lamp, text: "Blade", tag: "Blade", x: 496, y: 96, w: 180, h: 96, colorOn: "red"),
            HmiElement(kind: .textLabel, text: "Boxes in batch", x: 24, y: 232, w: 260, h: 36),
            HmiElement(kind: .ioField, text: "Count", tag: "BatchCounter", x: 24, y: 280, w: 220, h: 76),
            HmiElement(kind: .bar, text: "Batch", tag: "BatchCounter", x: 280, y: 280, w: 396, h: 76),
            HmiElement(kind: .lamp, text: "Batch full", tag: "BatchFull", x: 496, y: 232, w: 180, h: 36, colorOn: "orange")
        ]
        p.hmi = HmiDevice(screens: [screen])
        return p
    }

    /// The simplest starter project: a motor latched ON with a Set coil
    /// and latched OFF with a Reset coil, plus one small HMI screen.
    static func motorProject() -> TiaProject {
        var p = newProject(name: "MotorOnOff")
        p.devices[0].tags = [
            PlcTag(name: "BtnOn", dataType: "Bool", address: "%I0.0", comment: "ON button — latch"),
            PlcTag(name: "BtnOff", dataType: "Bool", address: "%I0.1", comment: "OFF button — unlatch"),
            PlcTag(name: "Motor", dataType: "Bool", address: "%Q0.0", comment: "Motor contactor")
        ]
        func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }
        p.devices[0].blocks[0].networks = [
            LadNetwork(title: "Latch ON — set the motor",
                       comment: "One press on ON: the (S) coil latches the motor on.",
                       series: [el(.contactNO, "BtnOn")],
                       output: el(.coilSet, "Motor")),
            LadNetwork(title: "Latch OFF — reset the motor",
                       comment: "One press on OFF: the (R) coil unlatches the motor.",
                       series: [el(.contactNO, "BtnOff")],
                       output: el(.coilReset, "Motor"))
        ]
        p.watchTags = ["BtnOn", "BtnOff", "Motor"]
        var screen = HmiScreen(name: "Screen_1")
        screen.elements = [
            HmiElement(kind: .textLabel, text: "Motor Control", x: 24, y: 16, w: 420, h: 44),
            HmiElement(kind: .button, text: "ON", tag: "BtnOn", x: 24, y: 110, w: 220, h: 110),
            HmiElement(kind: .button, text: "OFF", tag: "BtnOff", x: 280, y: 110, w: 220, h: 110),
            HmiElement(kind: .lamp, text: "Motor", tag: "Motor", x: 536, y: 110, w: 180, h: 110),
            HmiElement(kind: .symbol, text: "Motor", tag: "Motor", x: 280, y: 250, w: 170, h: 140, symbol: "motor"),
            HmiElement(kind: .textLabel, text: "ON latches (S) — OFF unlatches (R)", x: 24, y: 260, w: 240, h: 36)
        ]
        p.hmi = HmiDevice(screens: [screen])
        return p
    }
}

// MARK: - Compile diagnostics

struct Diagnostic: Identifiable {
    var id = UUID()
    var isError: Bool
    var path: String
    var text: String
    var time: String
}
