import Foundation

/// Hardware catalog data, in the shape TIA Portal's catalog pane shows:
/// controller → CPUs → signal modules → communication → technology.
/// Article numbers and families follow the real S7-1200 system manual
/// structure so students learn to find modules the way they will on PC.
struct CatalogEntry: Identifiable {
    var id = UUID()
    var name: String
    var article: String
    var version: String
    var family: String
    var desc: String
}

struct CatalogFamily: Identifiable {
    var id = UUID()
    var title: String
    var entries: [CatalogEntry]
}

enum Catalog {
    static let families: [CatalogFamily] = [
        CatalogFamily(title: "CPU 1211C", entries: [
            CatalogEntry(name: "CPU 1211C DC/DC/DC", article: "6ES7 211-1AE40-0XB0", version: "V4.4", family: "CPU 1211C", desc: "6 DI / 4 DQ transistor, 2 AI"),
            CatalogEntry(name: "CPU 1211C AC/DC/Rly", article: "6ES7 211-1BE40-0XB0", version: "V4.4", family: "CPU 1211C", desc: "6 DI / 4 DQ relay, 2 AI"),
            CatalogEntry(name: "CPU 1211C DC/DC/Rly", article: "6ES7 211-1HE40-0XB0", version: "V4.4", family: "CPU 1211C", desc: "6 DI / 4 DQ relay, 2 AI")
        ]),
        CatalogFamily(title: "CPU 1212C", entries: [
            CatalogEntry(name: "CPU 1212C DC/DC/DC", article: "6ES7 212-1AE40-0XB0", version: "V4.4", family: "CPU 1212C", desc: "8 DI / 6 DQ transistor, 2 AI"),
            CatalogEntry(name: "CPU 1212C AC/DC/Rly", article: "6ES7 212-1BE40-0XB0", version: "V4.4", family: "CPU 1212C", desc: "8 DI / 6 DQ relay, 2 AI"),
            CatalogEntry(name: "CPU 1212C DC/DC/Rly", article: "6ES7 212-1HE40-0XB0", version: "V4.4", family: "CPU 1212C", desc: "8 DI / 6 DQ relay, 2 AI")
        ]),
        CatalogFamily(title: "CPU 1214C", entries: [
            CatalogEntry(name: "CPU 1214C DC/DC/DC", article: "6ES7 214-1AG40-0XB0", version: "V4.4", family: "CPU 1214C", desc: "14 DI / 10 DQ transistor, 2 AI"),
            CatalogEntry(name: "CPU 1214C AC/DC/Rly", article: "6ES7 214-1BG40-0XB0", version: "V4.4", family: "CPU 1214C", desc: "14 DI / 10 DQ relay, 2 AI"),
            CatalogEntry(name: "CPU 1214C DC/DC/Rly", article: "6ES7 214-1HG40-0XB0", version: "V4.4", family: "CPU 1214C", desc: "14 DI / 10 DQ relay, 2 AI")
        ]),
        CatalogFamily(title: "CPU 1215C", entries: [
            CatalogEntry(name: "CPU 1215C DC/DC/DC", article: "6ES7 215-1AG40-0XB0", version: "V4.4", family: "CPU 1215C", desc: "14 DI / 10 DQ, 2 AI / 2 AQ, 2 PROFINET ports"),
            CatalogEntry(name: "CPU 1215C AC/DC/Rly", article: "6ES7 215-1BG40-0XB0", version: "V4.4", family: "CPU 1215C", desc: "14 DI / 10 DQ relay, 2 AI / 2 AQ"),
            CatalogEntry(name: "CPU 1215C DC/DC/Rly", article: "6ES7 215-1HG40-0XB0", version: "V4.4", family: "CPU 1215C", desc: "14 DI / 10 DQ relay, 2 AI / 2 AQ")
        ]),
        CatalogFamily(title: "CPU 1217C", entries: [
            CatalogEntry(name: "CPU 1217C DC/DC/DC", article: "6ES7 217-1AG40-0XB0", version: "V4.4", family: "CPU 1217C", desc: "14 DI (4 HSC 1 MHz) / 10 DQ, 2 AI / 2 AQ")
        ]),
        CatalogFamily(title: "Digital input SM 1221", entries: [
            CatalogEntry(name: "SM 1221 DI 8x24VDC", article: "6ES7 221-1BF32-0XB0", version: "V2.0", family: "SM 1221", desc: "8 digital inputs, 24 V DC, sink/source"),
            CatalogEntry(name: "SM 1221 DI 16x24VDC", article: "6ES7 221-1BH32-0XB0", version: "V2.0", family: "SM 1221", desc: "16 digital inputs, 24 V DC, sink/source")
        ]),
        CatalogFamily(title: "Digital output SM 1222", entries: [
            CatalogEntry(name: "SM 1222 DQ 8x24VDC", article: "6ES7 222-1BF32-0XB0", version: "V2.0", family: "SM 1222", desc: "8 digital outputs, transistor 0.5 A"),
            CatalogEntry(name: "SM 1222 DQ 16x24VDC", article: "6ES7 222-1BH32-0XB0", version: "V2.0", family: "SM 1222", desc: "16 digital outputs, transistor 0.5 A"),
            CatalogEntry(name: "SM 1222 DQ 8xRLY", article: "6ES7 222-1HF32-0XB0", version: "V2.0", family: "SM 1222", desc: "8 relay outputs, 2 A"),
            CatalogEntry(name: "SM 1222 DQ 16xRLY", article: "6ES7 222-1HH32-0XB0", version: "V2.0", family: "SM 1222", desc: "16 relay outputs, 2 A")
        ]),
        CatalogFamily(title: "Digital in/out SM 1223", entries: [
            CatalogEntry(name: "SM 1223 DI 8/DQ 8x24VDC", article: "6ES7 223-1BH32-0XB0", version: "V2.0", family: "SM 1223", desc: "8 DI + 8 DQ transistor"),
            CatalogEntry(name: "SM 1223 DI 16/DQ 16x24VDC", article: "6ES7 223-1BL32-0XB0", version: "V2.0", family: "SM 1223", desc: "16 DI + 16 DQ transistor"),
            CatalogEntry(name: "SM 1223 DI 16/DQ 16xRLY", article: "6ES7 223-1PL32-0XB0", version: "V2.0", family: "SM 1223", desc: "16 DI + 16 DQ relay")
        ]),
        CatalogFamily(title: "Analog input SM 1231", entries: [
            CatalogEntry(name: "SM 1231 AI 4x13 bit", article: "6ES7 231-4HD32-0XB0", version: "V2.1", family: "SM 1231", desc: "4 analog inputs, ±10 V / 0–20 mA"),
            CatalogEntry(name: "SM 1231 AI 8x13 bit", article: "6ES7 231-4HF32-0XB0", version: "V2.1", family: "SM 1231", desc: "8 analog inputs, ±10 V / 0–20 mA"),
            CatalogEntry(name: "SM 1231 AI 4xRTD", article: "6ES7 231-5PD32-0XB0", version: "V2.1", family: "SM 1231", desc: "4 RTD inputs (Pt100…)"),
            CatalogEntry(name: "SM 1231 AI 4xTC", article: "6ES7 231-5QD32-0XB0", version: "V2.1", family: "SM 1231", desc: "4 thermocouple inputs")
        ]),
        CatalogFamily(title: "Analog output SM 1232", entries: [
            CatalogEntry(name: "SM 1232 AQ 2x14 bit", article: "6ES7 232-4HB32-0XB0", version: "V2.1", family: "SM 1232", desc: "2 analog outputs, ±10 V / 0–20 mA"),
            CatalogEntry(name: "SM 1232 AQ 4x14 bit", article: "6ES7 232-4HD32-0XB0", version: "V2.1", family: "SM 1232", desc: "4 analog outputs, ±10 V / 0–20 mA")
        ]),
        CatalogFamily(title: "Analog in/out SM 1234", entries: [
            CatalogEntry(name: "SM 1234 AI 4/AQ 2", article: "6ES7 234-4HE32-0XB0", version: "V2.1", family: "SM 1234", desc: "4 AI + 2 AQ")
        ]),
        CatalogFamily(title: "Communication", entries: [
            CatalogEntry(name: "CM 1241 RS232", article: "6ES7 241-1AH32-0XB0", version: "V2.2", family: "CM", desc: "Serial RS232, point-to-point / Modbus"),
            CatalogEntry(name: "CM 1241 RS422/485", article: "6ES7 241-1CH32-0XB0", version: "V2.2", family: "CM", desc: "Serial RS422/485, Modbus RTU"),
            CatalogEntry(name: "CM 1243-5 PROFIBUS DP master", article: "6GK7 243-5DX30-0XE0", version: "V1.3", family: "CM", desc: "PROFIBUS DP master"),
            CatalogEntry(name: "CB 1241 RS485", article: "6ES7 241-1CH30-1XB0", version: "V1.0", family: "CB", desc: "Communication board RS485 (CPU slot)"),
            CatalogEntry(name: "CSM 1277 compact switch", article: "6GK7 277-1AA10-0AA0", version: "", family: "Network", desc: "Unmanaged switch, 4 ports")
        ]),
        CatalogFamily(title: "Signal boards", entries: [
            CatalogEntry(name: "SB 1221 DI 4x24VDC 200kHz", article: "6ES7 221-3BD30-0XB0", version: "V1.0", family: "SB", desc: "4 fast digital inputs"),
            CatalogEntry(name: "SB 1222 DQ 4x24VDC 200kHz", article: "6ES7 222-1BD30-0XB0", version: "V1.0", family: "SB", desc: "4 fast digital outputs"),
            CatalogEntry(name: "SB 1231 AI 1x12 bit", article: "6ES7 231-4HA30-0XB0", version: "V1.0", family: "SB", desc: "1 analog input"),
            CatalogEntry(name: "SB 1232 AQ 1x12 bit", article: "6ES7 232-4HA30-0XB0", version: "V1.0", family: "SB", desc: "1 analog output")
        ])
    ]

    /// Filtered entries for the catalog search box.
    static func search(_ q: String) -> [(family: String, entry: CatalogEntry)] {
        let needle = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        var out: [(String, CatalogEntry)] = []
        for f in families {
            for e in f.entries where e.name.lowercased().contains(needle) || e.article.lowercased().contains(needle) {
                out.append((f.title, e))
            }
        }
        return out
    }
}

/// The Instructions task card structure, like the real one:
/// Basic instructions → Bit logic / Timer / Counter (functional here),
/// plus the extended families TIA lists (shown for orientation).
struct InstructionItem: Identifiable {
    var id = UUID()
    var name: String
    var symbol: String
    var kind: LadElementKind?   // nil = listed but not placeable in this course build
}

struct InstructionFamily: Identifiable {
    var id = UUID()
    var title: String
    var items: [InstructionItem]
}

enum InstructionCatalog {
    static let families: [InstructionFamily] = [
        InstructionFamily(title: "Bit logic operations", items: [
            InstructionItem(name: "Normally open contact", symbol: "| |", kind: .contactNO),
            InstructionItem(name: "Normally closed contact", symbol: "|/|", kind: .contactNC),
            InstructionItem(name: "Output coil", symbol: "( )", kind: .coil),
            InstructionItem(name: "Set output", symbol: "(S)", kind: .coilSet),
            InstructionItem(name: "Reset output", symbol: "(R)", kind: .coilReset),
            InstructionItem(name: "Scan operand for positive signal edge", symbol: "|P|", kind: .pTrig),
            InstructionItem(name: "Scan operand for negative signal edge", symbol: "|N|", kind: .nTrig),
            InstructionItem(name: "Invert RLO (NOT)", symbol: "NOT", kind: .notOp)
        ]),
        InstructionFamily(title: "Timer operations", items: [
            InstructionItem(name: "TP — Generate pulse", symbol: "TP", kind: .tp),
            InstructionItem(name: "TON — Generate on-delay", symbol: "TON", kind: .ton),
            InstructionItem(name: "TOF — Generate off-delay", symbol: "TOF", kind: .tof),
            InstructionItem(name: "TONR — Time accumulator", symbol: "TONR", kind: nil)
        ]),
        InstructionFamily(title: "Counter operations", items: [
            InstructionItem(name: "CTU — Count up", symbol: "CTU", kind: .ctu),
            InstructionItem(name: "CTD — Count down", symbol: "CTD", kind: .ctd),
            InstructionItem(name: "CTUD — Count up and down", symbol: "CTUD", kind: nil)
        ]),
        InstructionFamily(title: "Comparator operations", items: [
            InstructionItem(name: "CMP == Equal", symbol: "==", kind: nil),
            InstructionItem(name: "CMP <> Not equal", symbol: "<>", kind: nil),
            InstructionItem(name: "CMP >= Greater or equal", symbol: ">=", kind: nil),
            InstructionItem(name: "CMP <= Less or equal", symbol: "<=", kind: nil),
            InstructionItem(name: "IN_RANGE", symbol: "IN_R", kind: nil)
        ]),
        InstructionFamily(title: "Math functions", items: [
            InstructionItem(name: "ADD", symbol: "ADD", kind: nil),
            InstructionItem(name: "SUB", symbol: "SUB", kind: nil),
            InstructionItem(name: "MUL", symbol: "MUL", kind: nil),
            InstructionItem(name: "DIV", symbol: "DIV", kind: nil),
            InstructionItem(name: "CALCULATE", symbol: "CALC", kind: nil)
        ]),
        InstructionFamily(title: "Move operations", items: [
            InstructionItem(name: "MOVE", symbol: "MOVE", kind: nil),
            InstructionItem(name: "MOVE_BLK", symbol: "M_BLK", kind: nil),
            InstructionItem(name: "FILL_BLK", symbol: "FILL", kind: nil)
        ]),
        InstructionFamily(title: "Program control", items: [
            InstructionItem(name: "JMP — Jump if RLO = 1", symbol: "JMP", kind: nil),
            InstructionItem(name: "LABEL", symbol: "LBL", kind: nil),
            InstructionItem(name: "RET — Return", symbol: "RET", kind: nil)
        ])
    ]

    static func makeElement(_ item: InstructionItem, tags: [PlcTag]) -> LadElement? {
        guard let kind = item.kind else { return nil }
        var el = LadElement(kind: kind)
        switch kind {
        case .contactNO, .contactNC, .coil, .coilSet, .coilReset, .pTrig, .nTrig:
            el.tag = tags.first?.name ?? ""
        case .ton, .tof, .tp:
            el.instance = "\(kind.rawValue.uppercased())_1"
            el.preset = "T#3s"; el.presetSeconds = 3
        case .ctu, .ctd:
            el.instance = "\(kind.rawValue.uppercased())_1"
            el.preset = "5"; el.presetValue = 5
        case .notOp:
            break
        }
        return el
    }
}
