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
    // v4.0 — the extended instruction set
    case sr          // SR flip-flop box (reset dominant)
    case rs          // RS flip-flop box (set dominant)
    case tonr        // TONR time accumulator
    case ctud        // CTUD count up and down
    case cmp         // comparator box (op: EQ/NE/GT/GE/LT/LE)
    case math        // arithmetic box (op: ADD/SUB/MUL/DIV/SHL/SHR)
    case move        // MOVE box
    case pid         // PID_Compact-style box
    case jmp         // jump to label (output position)
    case label       // label definition (output position)
    case ret         // return from block (output position)
}

struct LadElement: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: LadElementKind = .contactNO
    var tag: String = ""          // contact/coil operand; for timer/counter boxes the Q output tag
    var instance: String = ""     // timer/counter instance name, e.g. "TON_1"
    var preset: String = "T#3s"   // PT / PV as text, like TIA shows
    var presetValue: Int = 5      // counter PV
    var presetSeconds: Double = 3 // timer PT in seconds
    var inputTag: String = ""     // counter count-input tag (CU / CD); v4: 2nd operand / R input / PID PV
    // v4.0 additions — decoded with decodeIfPresent so older project
    // files (which lack these keys) still open.
    var op: String = ""           // cmp: EQ/NE/GT/GE/LT/LE · math: ADD/SUB/MUL/DIV/SHL/SHR
    var outTag: String = ""       // math/move/cmp/pid result operand
    var constValue: Double = 0    // constant 2nd operand when useConst
    var useConst: Bool = false
    var kp: Double = 2.0          // PID gain
    var ti: Double = 8.0          // PID integral time (s)
    var td: Double = 0.0          // PID derivative time (s)
}

extension LadElement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(LadElementKind.self, forKey: .kind) ?? .contactNO
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        instance = try c.decodeIfPresent(String.self, forKey: .instance) ?? ""
        preset = try c.decodeIfPresent(String.self, forKey: .preset) ?? "T#3s"
        presetValue = try c.decodeIfPresent(Int.self, forKey: .presetValue) ?? 5
        presetSeconds = try c.decodeIfPresent(Double.self, forKey: .presetSeconds) ?? 3
        inputTag = try c.decodeIfPresent(String.self, forKey: .inputTag) ?? ""
        op = try c.decodeIfPresent(String.self, forKey: .op) ?? ""
        outTag = try c.decodeIfPresent(String.self, forKey: .outTag) ?? ""
        constValue = try c.decodeIfPresent(Double.self, forKey: .constValue) ?? 0
        useConst = try c.decodeIfPresent(Bool.self, forKey: .useConst) ?? false
        kp = try c.decodeIfPresent(Double.self, forKey: .kp) ?? 2.0
        ti = try c.decodeIfPresent(Double.self, forKey: .ti) ?? 8.0
        td = try c.decodeIfPresent(Double.self, forKey: .td) ?? 0.0
    }
}

struct LadNetwork: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = ""
    var comment: String = ""
    var series: [LadElement] = []
    var parallel: [LadElement] = []          // legacy single branch (= branches.first)
    var branches: [[LadElement]] = []        // v4.0: any number of parallel branches
    var output: LadElement = LadElement(kind: .coil)

    // Declared explicitly: with both init(from:) and encode(to:) custom,
    // the compiler no longer synthesizes CodingKeys for this struct.
    enum CodingKeys: String, CodingKey {
        case id, title, comment, series, parallel, branches, output
    }
}

extension LadNetwork {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        comment = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
        series = try c.decodeIfPresent([LadElement].self, forKey: .series) ?? []
        let par = try c.decodeIfPresent([LadElement].self, forKey: .parallel) ?? []
        if let br = try c.decodeIfPresent([[LadElement]].self, forKey: .branches) {
            branches = br
            parallel = br.first ?? []
        } else {
            parallel = par
            branches = par.isEmpty ? [] : [par]
        }
        output = try c.decodeIfPresent(LadElement.self, forKey: .output) ?? LadElement(kind: .coil)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(comment, forKey: .comment)
        try c.encode(series, forKey: .series)
        try c.encode(branches.first ?? parallel, forKey: .parallel)
        try c.encode(branches, forKey: .branches)
        try c.encode(output, forKey: .output)
    }

    /// Keep the legacy `parallel` mirror in sync after branch edits.
    mutating func syncParallel() { parallel = branches.first ?? [] }
}

struct PlcTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var dataType: String = "Bool"
    var address: String = ""      // %I0.0 / %Q0.0 / %M0.0 …
    var comment: String = ""
    var startValue: String? = nil // v4.0: numeric tags start value (optional: older files)
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
    var sclSource: String? = nil               // v4.0: SCL text when language == "SCL"
}

// MARK: - Data blocks (v4.0)

struct DbRow: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var dataType: String = "Real"   // Bool / Int / DInt / Real / Word / Time
    var startValue: String = "0"
    var comment: String = ""
}

struct PlcDataBlock: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "DataBlock"
    var number: Int = 1
    var comment: String = ""
    var rows: [DbRow] = []
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
    var dataBlocks: [PlcDataBlock]? = nil      // v4.0 (optional: older files)
}

// MARK: - HMI (v2)

enum HmiElementKind: String, Codable, CaseIterable {
    case button, lamp, ioField, textLabel, bar
    case gauge, slider, toggleSwitch, symbol   // Studio additions (v3.3)
    case trend                                  // v4.0: live trend of a numeric operand
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
    // v4.0 — WinCC-style project data (optional: older files)
    var alarms: [HmiAlarm]? = nil
    var recipes: [HmiRecipe]? = nil
    var users: [HmiUser]? = nil
}

// MARK: - HMI project data (v4.0)

struct HmiAlarm: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Alarm_1"
    var tag: String = ""          // Bool trigger operand
    var text: String = ""
    var alarmClass: String = "Errors"   // Errors / Warnings
}

struct RecipeValue: Identifiable, Codable, Equatable {
    var id = UUID()
    var tag: String = ""          // numeric operand
    var value: Double = 0
}

struct HmiRecipe: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "Recipe_1"
    var values: [RecipeValue] = []
}

struct HmiUser: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var pin: String = ""
    var group: String = "Operators"   // Administrators / Operators
}

extension HmiDevice {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "HMI_1"
        panel = try c.decodeIfPresent(String.self, forKey: .panel) ?? "KTP700 Basic PN"
        screens = try c.decodeIfPresent([HmiScreen].self, forKey: .screens) ?? [HmiScreen()]
        startScreen = try c.decodeIfPresent(Int.self, forKey: .startScreen) ?? 0
        alarms = try c.decodeIfPresent([HmiAlarm].self, forKey: .alarms)
        recipes = try c.decodeIfPresent([HmiRecipe].self, forKey: .recipes)
        users = try c.decodeIfPresent([HmiUser].self, forKey: .users)
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

    /// v4.0 demo: a PID temperature loop on a simulated tank. The PID box
    /// drives "HeaterPower" (0–100 %) and the built-in process model
    /// heats "TankTemp" toward the setpoint; a CMP box switches the
    /// heater contactor; the HMI shows a live trend. A data block holds
    /// the auto-mode flag the PID network reads as an operand.
    static func pidProject() -> TiaProject {
        var p = newProject(name: "PidLab")
        p.devices[0].tags = [
            PlcTag(name: "TempSP", dataType: "Real", address: "%MD0", comment: "Temperature setpoint (°C)", startValue: "60"),
            PlcTag(name: "TankTemp", dataType: "Real", address: "%MD4", comment: "Tank temperature (process value)", startValue: "20"),
            PlcTag(name: "HeaterPower", dataType: "Real", address: "%MD8", comment: "PID output 0–100 %"),
            PlcTag(name: "TankLevel", dataType: "Real", address: "%MD12", comment: "Tank level (process value %)", startValue: "35"),
            PlcTag(name: "PidActive", dataType: "Bool", address: "%M0.0", comment: "PID loop enabled"),
            PlcTag(name: "FillCmd", dataType: "Bool", address: "%M0.1", comment: "Fill command (HMI)"),
            PlcTag(name: "DrainCmd", dataType: "Bool", address: "%M0.2", comment: "Drain command (HMI)"),
            PlcTag(name: "Heater", dataType: "Bool", address: "%Q0.0", comment: "Heater contactor"),
            PlcTag(name: "Pump", dataType: "Bool", address: "%Q0.1", comment: "Fill pump"),
            PlcTag(name: "Valve", dataType: "Bool", address: "%Q0.2", comment: "Drain valve")
        ]
        p.devices[0].dataBlocks = [
            PlcDataBlock(name: "ProcessData", number: 1, comment: "Shared process settings", rows: [
                DbRow(name: "AutoMode", dataType: "Bool", startValue: "true", comment: "Enable the PID loop"),
                DbRow(name: "TempLimit", dataType: "Real", startValue: "90", comment: "High temperature limit"),
                DbRow(name: "BatchSize", dataType: "Int", startValue: "12", comment: "Pieces per batch")
            ])
        ]
        func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }
        var pid = LadElement(kind: .pid, tag: "TempSP", instance: "PID_1")
        pid.inputTag = "TankTemp"; pid.outTag = "HeaterPower"; pid.kp = 2.0; pid.ti = 8.0; pid.td = 0
        var cmp = LadElement(kind: .cmp, tag: "HeaterPower")
        cmp.op = "GT"; cmp.useConst = true; cmp.constValue = 5
        p.devices[0].blocks[0].networks = [
            LadNetwork(title: "PID loop — runs while ProcessData.AutoMode",
                       comment: "PID_Compact teaching model: SP = TempSP, PV = TankTemp, LMN = HeaterPower.",
                       series: [el(.contactNO, "ProcessData.AutoMode"), pid],
                       output: el(.coil, "PidActive")),
            LadNetwork(title: "Heater contactor while PID output above 5 %",
                       series: [cmp],
                       output: el(.coil, "Heater")),
            LadNetwork(title: "Fill pump mirrors the fill command",
                       series: [el(.contactNO, "FillCmd")],
                       output: el(.coil, "Pump")),
            LadNetwork(title: "Drain valve mirrors the drain command",
                       series: [el(.contactNO, "DrainCmd")],
                       output: el(.coil, "Valve"))
        ]
        p.watchTags = ["TempSP", "TankTemp", "HeaterPower", "Heater", "TankLevel"]
        var screen = HmiScreen(name: "Screen_1")
        screen.elements = [
            HmiElement(kind: .textLabel, text: "Tank temperature — PID", x: 24, y: 14, w: 460, h: 40),
            HmiElement(kind: .trend, text: "TankTemp", tag: "TankTemp", x: 24, y: 66, w: 470, h: 190),
            HmiElement(kind: .ioField, text: "Setpoint", tag: "TempSP", x: 520, y: 66, w: 200, h: 64),
            HmiElement(kind: .ioField, text: "Temp", tag: "TankTemp", x: 520, y: 142, w: 200, h: 64),
            HmiElement(kind: .bar, text: "Power %", tag: "HeaterPower", x: 520, y: 218, w: 200, h: 38),
            HmiElement(kind: .lamp, text: "Heater", tag: "Heater", x: 24, y: 276, w: 170, h: 64, colorOn: "red"),
            HmiElement(kind: .button, text: "FILL", tag: "FillCmd", x: 220, y: 276, w: 150, h: 64),
            HmiElement(kind: .button, text: "DRAIN", tag: "DrainCmd", x: 396, y: 276, w: 150, h: 64),
            HmiElement(kind: .gauge, text: "Level", tag: "TankLevel", x: 580, y: 262, w: 150, h: 130)
        ]
        var hmi = HmiDevice(screens: [screen])
        hmi.alarms = [HmiAlarm(name: "HighTemp", tag: "Heater", text: "Heater is ON", alarmClass: "Warnings")]
        hmi.recipes = [HmiRecipe(name: "Standard 60°C", values: [RecipeValue(tag: "TempSP", value: 60)]),
                       HmiRecipe(name: "Hot 80°C", values: [RecipeValue(tag: "TempSP", value: 80)])]
        p.hmi = hmi
        return p
    }

    /// v4.1 — MixingPlant: a three-vessel plant in the style of a real
    /// process HMI (pre-mix → preparation → storage). Tap the fill valve
    /// on the HMI and the vessel fills while a totalizer counts the
    /// litres; transfer pumps move the water on; heaters warm a vessel
    /// only above a safe level (interlock in the LAD); agitators stir.
    static func plantProject() -> TiaProject {
        var p = newProject(name: "MixingPlant")
        p.devices[0].tags = [
            PlcTag(name: "FillValve", dataType: "Bool", address: "%I0.0", comment: "Fill valve command (HMI)"),
            PlcTag(name: "Pump1Cmd", dataType: "Bool", address: "%I0.1", comment: "Transfer pump 1 command"),
            PlcTag(name: "Pump2Cmd", dataType: "Bool", address: "%I0.2", comment: "Transfer pump 2 command"),
            PlcTag(name: "Heat1Cmd", dataType: "Bool", address: "%I0.3", comment: "Heater 1 command"),
            PlcTag(name: "Heat2Cmd", dataType: "Bool", address: "%I0.4", comment: "Heater 2 command"),
            PlcTag(name: "Agit1Cmd", dataType: "Bool", address: "%I0.5", comment: "Agitator 1 command"),
            PlcTag(name: "Agit2Cmd", dataType: "Bool", address: "%I0.6", comment: "Agitator 2 command"),
            PlcTag(name: "DrainValve", dataType: "Bool", address: "%I0.7", comment: "Storage drain command"),
            PlcTag(name: "ValveV1301", dataType: "Bool", address: "%Q0.0", comment: "Fill valve output"),
            PlcTag(name: "Pump1", dataType: "Bool", address: "%Q0.1", comment: "Transfer pump pre-mix to preparation"),
            PlcTag(name: "Pump2", dataType: "Bool", address: "%Q0.2", comment: "Transfer pump preparation to storage"),
            PlcTag(name: "Heater1", dataType: "Bool", address: "%Q0.3", comment: "Pre-mix heater"),
            PlcTag(name: "Heater2", dataType: "Bool", address: "%Q0.4", comment: "Preparation heater"),
            PlcTag(name: "Agitator1", dataType: "Bool", address: "%Q0.5", comment: "Pre-mix agitator"),
            PlcTag(name: "Agitator2", dataType: "Bool", address: "%Q0.6", comment: "Preparation agitator"),
            PlcTag(name: "DrainOpen", dataType: "Bool", address: "%Q0.7", comment: "Storage drain valve"),
            PlcTag(name: "PremixLevel", dataType: "Real", address: "%MD0", comment: "Pre-mix level (L)", startValue: "0"),
            PlcTag(name: "PremixTotal", dataType: "Real", address: "%MD4", comment: "Total water filled (L)"),
            PlcTag(name: "PremixTemp", dataType: "Real", address: "%MD8", comment: "Pre-mix temperature (°C)", startValue: "20"),
            PlcTag(name: "PrepLevel", dataType: "Real", address: "%MD12", comment: "Preparation level (L)", startValue: "0"),
            PlcTag(name: "PrepTemp", dataType: "Real", address: "%MD16", comment: "Preparation temperature (°C)", startValue: "20"),
            PlcTag(name: "StorageLevel", dataType: "Real", address: "%MD20", comment: "Storage level (L)", startValue: "0"),
            PlcTag(name: "Agitator1RPM", dataType: "Real", address: "%MD24", comment: "Agitator 1 speed (RPM)"),
            PlcTag(name: "Agitator2RPM", dataType: "Real", address: "%MD28", comment: "Agitator 2 speed (RPM)")
        ]
        func el(_ k: LadElementKind, _ t: String) -> LadElement { LadElement(kind: k, tag: t) }
        func gt(_ tag: String, _ v: Double) -> LadElement {
            var c = LadElement(kind: .cmp, tag: tag); c.op = "GT"; c.useConst = true; c.constValue = v; return c
        }
        p.devices[0].blocks[0].networks = [
            LadNetwork(title: "Fill valve V1301",
                       series: [el(.contactNO, "FillValve")],
                       output: el(.coil, "ValveV1301")),
            LadNetwork(title: "Transfer pump 1 — only while pre-mix holds more than 2 L",
                       series: [el(.contactNO, "Pump1Cmd"), gt("PremixLevel", 2)],
                       output: el(.coil, "Pump1")),
            LadNetwork(title: "Transfer pump 2 — only while preparation holds more than 2 L",
                       series: [el(.contactNO, "Pump2Cmd"), gt("PrepLevel", 2)],
                       output: el(.coil, "Pump2")),
            LadNetwork(title: "Heater 1 — interlock: more than 10 L in the vessel",
                       series: [el(.contactNO, "Heat1Cmd"), gt("PremixLevel", 10)],
                       output: el(.coil, "Heater1")),
            LadNetwork(title: "Heater 2 — interlock: more than 10 L in the vessel",
                       series: [el(.contactNO, "Heat2Cmd"), gt("PrepLevel", 10)],
                       output: el(.coil, "Heater2")),
            LadNetwork(title: "Agitator 1",
                       series: [el(.contactNO, "Agit1Cmd")],
                       output: el(.coil, "Agitator1")),
            LadNetwork(title: "Agitator 2",
                       series: [el(.contactNO, "Agit2Cmd")],
                       output: el(.coil, "Agitator2")),
            LadNetwork(title: "Storage drain valve",
                       series: [el(.contactNO, "DrainValve")],
                       output: el(.coil, "DrainOpen"))
        ]
        p.watchTags = ["PremixLevel", "PremixTotal", "PremixTemp", "PrepLevel", "StorageLevel"]
        var screen = HmiScreen(name: "Plant")
        screen.elements = [
            HmiElement(kind: .textLabel, text: "MIXING PLANT — PRE-MIX · PREPARATION · STORAGE", x: 24, y: 10, w: 660, h: 34),
            HmiElement(kind: .button, text: "FILL VALVE", tag: "FillValve", x: 40, y: 48, w: 140, h: 38, action: "toggle"),
            HmiElement(kind: .button, text: "DRAIN", tag: "DrainValve", x: 620, y: 48, w: 140, h: 38, action: "toggle"),
            HmiElement(kind: .symbol, text: "PRE-MIX", tag: "PremixLevel", x: 40, y: 96, w: 170, h: 190, symbol: "tank"),
            HmiElement(kind: .symbol, text: "PREPARATION", tag: "PrepLevel", x: 315, y: 96, w: 170, h: 190, symbol: "tank"),
            HmiElement(kind: .symbol, text: "STORAGE", tag: "StorageLevel", x: 590, y: 96, w: 170, h: 190, symbol: "tank"),
            HmiElement(kind: .button, text: "PUMP 1", tag: "Pump1Cmd", x: 222, y: 170, w: 86, h: 40, action: "toggle"),
            HmiElement(kind: .button, text: "PUMP 2", tag: "Pump2Cmd", x: 492, y: 170, w: 86, h: 40, action: "toggle"),
            HmiElement(kind: .ioField, text: "Level L", tag: "PremixLevel", x: 40, y: 294, w: 170, h: 46),
            HmiElement(kind: .ioField, text: "Level L", tag: "PrepLevel", x: 315, y: 294, w: 170, h: 46),
            HmiElement(kind: .ioField, text: "Level L", tag: "StorageLevel", x: 590, y: 294, w: 170, h: 46),
            HmiElement(kind: .ioField, text: "Temp °C", tag: "PremixTemp", x: 40, y: 346, w: 170, h: 46),
            HmiElement(kind: .ioField, text: "Temp °C", tag: "PrepTemp", x: 315, y: 346, w: 170, h: 46),
            HmiElement(kind: .ioField, text: "Filled L", tag: "PremixTotal", x: 590, y: 346, w: 170, h: 46),
            HmiElement(kind: .button, text: "HEAT 1", tag: "Heat1Cmd", x: 40, y: 400, w: 110, h: 40, action: "toggle"),
            HmiElement(kind: .button, text: "AGIT 1", tag: "Agit1Cmd", x: 160, y: 400, w: 110, h: 40, action: "toggle"),
            HmiElement(kind: .button, text: "HEAT 2", tag: "Heat2Cmd", x: 315, y: 400, w: 110, h: 40, action: "toggle"),
            HmiElement(kind: .button, text: "AGIT 2", tag: "Agit2Cmd", x: 435, y: 400, w: 110, h: 40, action: "toggle"),
            HmiElement(kind: .lamp, text: "Pump 1", tag: "Pump1", x: 560, y: 400, w: 90, h: 40),
            HmiElement(kind: .lamp, text: "Heater 1", tag: "Heater1", x: 660, y: 400, w: 100, h: 40, colorOn: "red")
        ]
        var hmi = HmiDevice(screens: [screen])
        hmi.alarms = [HmiAlarm(name: "Filling", tag: "ValveV1301", text: "Filling the pre-mix vessel", alarmClass: "Warnings")]
        p.hmi = hmi
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
