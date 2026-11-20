import SwiftUI

// MARK: - v4.0 project tools
//
// DataBlocksView — the global DB editor (rows with live values).
// CrossRefView — where every operand is used, plus project-wide rename
// (search & replace for tags and DB rows).
// FbdView — the same networks drawn and lightly edited as FBD.
// SclEditorView — text editor for SCL blocks (subset interpreter).

// MARK: Data blocks

struct DataBlocksView: View {
    @Binding var device: PlcDevice
    @ObservedObject var sim: Simulator
    @State private var selDB: Int = 0

    private var dbs: [PlcDataBlock] { device.dataBlocks ?? [] }

    private var rowsBinding: Binding<[DbRow]> {
        Binding(
            get: { dbs.indices.contains(selDB) ? dbs[selDB].rows : [] },
            set: { v in
                var all = dbs
                if all.indices.contains(selDB) { all[selDB].rows = v; device.dataBlocks = all }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button { addDB() } label: { Label("Add data block", systemImage: "plus").font(.system(size: 11)) }
                if !dbs.isEmpty {
                    Menu {
                        ForEach(Array(dbs.enumerated()), id: \.offset) { i, db in
                            Button("\(db.name) [DB\(db.number)]") { selDB = i }
                        }
                    } label: {
                        Label(dbs.indices.contains(selDB) ? "\(dbs[selDB].name) [DB\(dbs[selDB].number)]" : "Select DB",
                              systemImage: "cylinder.split.1x2").font(.system(size: 11.5))
                    }
                    Button { addRow() } label: { Label("Add row", systemImage: "plus.square").font(.system(size: 11)) }
                    Button(role: .destructive) { deleteDB() } label: { Label("Delete DB", systemImage: "trash").font(.system(size: 11)) }
                }
                Spacer()
                Text("Global data blocks").font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white)
            Divider()
            HStack(spacing: 0) {
                dbHeader("Name", 150); dbHeader("Data type", 92); dbHeader("Start value", 110); dbHeader("Live value", 110); dbHeader("Comment", 200)
                Spacer()
            }
            .background(Tia.paneHeader)
            if dbs.isEmpty {
                Text("No data blocks yet — add one. Rows become operands like \"DataBlock.Level\" in LAD, SCL and on the HMI.")
                    .font(.system(size: 12)).foregroundColor(.secondary).padding(14)
                Spacer()
            } else if dbs.indices.contains(selDB) {
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(rowsBinding) { $row in
                                dbRowView(dbName: dbs[selDB].name, row: $row)
                                Divider()
                            }
                        }
                        .frame(minWidth: 700)
                    }
                }
                .background(Color.white)
            }
            Spacer()
        }
        .background(Color.white)
    }

    private func dbHeader(_ t: String, _ w: CGFloat) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
            .frame(width: w, alignment: .leading).padding(.horizontal, 5).padding(.vertical, 4)
    }

    private func dbRowView(dbName: String, row: Binding<DbRow>) -> some View {
        let r = row.wrappedValue
        let key = "\(dbName).\(r.name)"
        return HStack(spacing: 0) {
            TextField("Name", text: row.name).font(.system(size: 11.5)).frame(width: 150).padding(.horizontal, 5)
            Picker("", selection: row.dataType) {
                ForEach(["Bool", "Int", "DInt", "Real", "Word", "Time"], id: \.self) { Text($0).font(.system(size: 11)) }
            }
            .pickerStyle(.menu).frame(width: 92)
            TextField("0", text: row.startValue).font(.system(size: 11.5)).frame(width: 110).padding(.horizontal, 5)
            Group {
                if r.dataType == "Bool" {
                    Text((sim.values[key] ?? false) ? "TRUE" : "FALSE")
                        .foregroundColor((sim.values[key] ?? false) ? Tia.runGreen : .secondary)
                } else {
                    Text(fmtNum(sim.num(key))).foregroundColor(Tia.tealText)
                }
            }
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .frame(width: 110, alignment: .leading).padding(.horizontal, 5)
            TextField("Comment", text: row.comment).font(.system(size: 11.5)).frame(width: 200).padding(.horizontal, 5)
            Button(role: .destructive) { deleteRow(rowId: r.id) } label: {
                Image(systemName: "trash").font(.system(size: 11))
            }
            Spacer()
        }
        .padding(.vertical, 2.5)
    }

    private func fmtNum(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 100000 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func addDB() {
        var all = dbs
        let n = all.count + 1
        all.append(PlcDataBlock(name: "DataBlock_\(n)", number: n, rows: [
            DbRow(name: "Value_1", dataType: "Real", startValue: "0")
        ]))
        device.dataBlocks = all
        selDB = all.count - 1
    }

    private func deleteDB() {
        guard dbs.indices.contains(selDB) else { return }
        var all = dbs
        all.remove(at: selDB)
        device.dataBlocks = all
        selDB = 0
    }

    private func addRow() {
        guard dbs.indices.contains(selDB) else { return }
        var all = dbs
        all[selDB].rows.append(DbRow(name: "Value_\(all[selDB].rows.count + 1)", dataType: "Real", startValue: "0"))
        device.dataBlocks = all
    }

    private func deleteRow(rowId: UUID) {
        guard dbs.indices.contains(selDB) else { return }
        var all = dbs
        all[selDB].rows.removeAll { $0.id == rowId }
        device.dataBlocks = all
    }
}

// MARK: Cross-reference + rename

struct CrossRefView: View {
    @Binding var device: PlcDevice
    @Binding var hmi: HmiDevice
    var watch: [String]
    var onRenameWatch: (String, String) -> Void
    @State private var query = ""
    @State private var renameTarget: String? = nil
    @State private var newName = ""

    private var operands: [String] {
        device.tags.map { $0.name } + (device.dataBlocks ?? []).flatMap { db in db.rows.map { "\(db.name).\($0.name)" } }
    }

    private func usages(of operand: String) -> [String] {
        var out: [String] = []
        for block in device.blocks {
            if block.language == "SCL" && (block.sclSource ?? "").contains(operand) {
                out.append("\(block.name) [\(block.type)\(block.number)] › SCL source")
            }
            for (ni, net) in block.networks.enumerated() {
                let els = net.series + net.branches.flatMap { $0 } + [net.output]
                for el in els {
                    var roles: [String] = []
                    if el.tag == operand { roles.append(el.kind.rawValue) }
                    if el.inputTag == operand { roles.append("IN2/CD/R/PV") }
                    if el.outTag == operand { roles.append("OUT") }
                    if !roles.isEmpty {
                        out.append("\(block.name) › Network \(ni + 1) › \(roles.joined(separator: ", "))")
                    }
                }
            }
        }
        for screen in hmi.screens {
            for el in screen.elements where el.tag == operand {
                out.append("HMI › \(screen.name) › \(el.kind.rawValue)")
            }
        }
        if watch.contains(operand) { out.append("Watch table_1") }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.secondary)
                TextField("Search operand…", text: $query).font(.system(size: 12))
                Spacer()
                Text("Cross-reference").font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(operands.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { op in
                        let uses = usages(of: op)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(op).font(.system(size: 12.5, weight: .bold, design: .monospaced)).foregroundColor(Tia.textDark)
                                Text("\(uses.count) use(s)").font(.system(size: 10.5)).foregroundColor(.secondary)
                                Spacer()
                                Button("Rename…") {
                                    renameTarget = op
                                    newName = op
                                }
                                .font(.system(size: 11))
                            }
                            ForEach(uses, id: \.self) { u in
                                Text("• \(u)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        Divider()
                    }
                }
            }
            .background(Color.white)
        }
        .background(Color.white)
        .alert("Rename operand", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("New name", text: $newName)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename everywhere") {
                if let old = renameTarget { rename(old: old, to: newName) }
                renameTarget = nil
            }
        } message: {
            Text("Updates the tag table, every block, the HMI and the watch table.")
        }
    }

    private func rename(old: String, to new: String) {
        let name = new.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != old else { return }
        var d = device
        if let i = d.tags.firstIndex(where: { $0.name == old }) {
            d.tags[i].name = name
        }
        if old.contains("."), !name.contains(".") { return }  // DB rows rename inside their DB only
        if old.contains("."), name.contains(".") {
            let op = old.split(separator: ".", maxSplits: 1)
            let nn = name.split(separator: ".", maxSplits: 1)
            if op.count == 2, nn.count == 2, op[0] == nn[0],
               let di = (d.dataBlocks ?? []).firstIndex(where: { $0.name == String(op[0]) }),
               let ri = (d.dataBlocks ?? [])[di].rows.firstIndex(where: { $0.name == String(op[1]) }) {
                d.dataBlocks?[di].rows[ri].name = String(nn[1])
            }
        }
        for bi in d.blocks.indices {
            for ni in d.blocks[bi].networks.indices {
                func fix(_ el: inout LadElement) {
                    if el.tag == old { el.tag = name }
                    if el.inputTag == old { el.inputTag = name }
                    if el.outTag == old { el.outTag = name }
                }
                for ei in d.blocks[bi].networks[ni].series.indices { fix(&d.blocks[bi].networks[ni].series[ei]) }
                for bri in d.blocks[bi].networks[ni].branches.indices {
                    for ei in d.blocks[bi].networks[ni].branches[bri].indices { fix(&d.blocks[bi].networks[ni].branches[bri][ei]) }
                }
                fix(&d.blocks[bi].networks[ni].output)
            }
            if let src = d.blocks[bi].sclSource {
                d.blocks[bi].sclSource = src.replacingOccurrences(of: "\"\(old)\"", with: "\"\(name)\"")
            }
        }
        device = d
        var h = hmi
        for si in h.screens.indices {
            for ei in h.screens[si].elements.indices where h.screens[si].elements[ei].tag == old {
                h.screens[si].elements[ei].tag = name
            }
        }
        hmi = h
        onRenameWatch(old, name)
    }
}

// MARK: FBD view (same networks, function-block rendering)

struct FbdView: View {
    @Binding var device: PlcDevice
    var blockIndex: Int
    @ObservedObject var sim: Simulator
    var online: Bool
    @Binding var insertRequest: LadElementKind?
    @State private var selNet: Int? = nil
    @State private var selPos: Int = -1
    @State private var selBranch: Int = -1    // -1 series, -2 output, >= 0 branch
    @State private var tagPickerFor: LadEditorView.TagTarget? = nil

    private var block: PlcBlock {
        device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex] : PlcBlock()
    }
    private var live: Bool { online && sim.powered }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(block.networks.enumerated()), id: \.element.id) { ni, net in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network \(ni + 1): \(net.title)")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(Tia.textDark)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(net.series.enumerated()), id: \.element.id) { ei, el in
                                    connector
                                    fbdBox(ni: ni, ei: ei, el: el, branch: -1)
                                }
                                if !net.branches.isEmpty {
                                    connector
                                    VStack(spacing: 4) {
                                        Text("OR").font(.system(size: 10, weight: .bold)).foregroundColor(Tia.textDark)
                                        ForEach(Array(net.branches.enumerated()), id: \.offset) { bi, branch in
                                            HStack(spacing: 0) {
                                                ForEach(Array(branch.enumerated()), id: \.element.id) { ei, el in
                                                    fbdBox(ni: ni, ei: ei, el: el, branch: bi)
                                                    if ei < branch.count - 1 { connector }
                                                }
                                            }
                                        }
                                    }
                                    .padding(6)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.8))
                                }
                                connector
                                fbdBox(ni: ni, ei: -2, el: net.output, branch: -2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(8)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border.opacity(0.6), lineWidth: 0.7))
                }
                Text("FBD renders the same networks as LAD — edits here change the LAD too. Tap a box to select it, long-press to change its operand.")
                    .font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            .padding(10)
        }
        .background(Color.white)
        .onChange(of: insertRequest) { kind in
            if let kind { insert(kind); insertRequest = nil }
        }
        .sheet(item: $tagPickerFor) { target in
            TagPickerSheet(tags: device.tags) { name in
                mutate(target) { $0.tag = name }
                tagPickerFor = nil
            }
        }
    }

    private var connector: some View {
        Rectangle().fill(Tia.wire).frame(width: 16, height: 1.8).padding(.vertical, 20)
    }

    private func fbdValue(_ el: LadElement) -> Bool {
        switch el.kind {
        case .contactNC: return !(sim.values[el.tag] ?? false)
        case .ctu, .ctud: return (sim.counts[el.instance] ?? 0) >= el.presetValue
        case .ctd: return (sim.counts[el.instance] ?? el.presetValue) <= 0
        default: return sim.values[el.tag] ?? false
        }
    }

    private func fbdBox(ni: Int, ei: Int, el: LadElement, branch: Int) -> some View {
        let selected = selNet == ni && selPos == ei && selBranch == branch
        let on = live && fbdValue(el)
        return VStack(spacing: 1) {
            Text(kindLabel(el)).font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
            Text(el.tag.isEmpty ? (el.instance.isEmpty ? "—" : el.instance) : el.tag)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Tia.textDark).lineLimit(1)
            Circle().fill(on ? Tia.onlineTrue : Color.gray.opacity(0.3)).frame(width: 7, height: 7)
        }
        .frame(width: 86)
        .padding(.vertical, 6)
        .background(selected ? Tia.selection : Tia.boxFillV3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(on ? Tia.onlineTrue : Tia.border, lineWidth: selected ? 1.4 : 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .contentShape(Rectangle())
        .onTapGesture {
            selNet = ni; selPos = ei; selBranch = branch
            if branch == -2 { deleteOrInfo(ni: ni, ei: ei, branch: branch) }
        }
        .onLongPressGesture {
            selNet = ni; selPos = ei; selBranch = branch
            tagPickerFor = LadEditorView.TagTarget(net: ni, pos: ei, branch: branch == -2 ? -1 : branch, field: "tag")
        }
    }

    private func kindLabel(_ el: LadElement) -> String {
        switch el.kind {
        case .contactNO: return "AND · | |"
        case .contactNC: return "AND · |/|"
        case .coil: return ":= ( )"
        case .coilSet: return ":= (S)"
        case .coilReset: return ":= (R)"
        default: return el.kind.rawValue.uppercased()
        }
    }

    private func deleteOrInfo(ni: Int, ei: Int, branch: Int) {
        // Output selection is informational in FBD; deletion lives in LAD.
    }

    private func mutate(_ t: LadEditorView.TagTarget, _ change: (inout LadElement) -> Void) {
        guard device.blocks.indices.contains(blockIndex) else { return }
        var b = device.blocks[blockIndex]
        guard b.networks.indices.contains(t.net) else { return }
        if t.pos == -2 { change(&b.networks[t.net].output) }
        else if t.branch >= 0 {
            if b.networks[t.net].branches.indices.contains(t.branch), b.networks[t.net].branches[t.branch].indices.contains(t.pos) {
                change(&b.networks[t.net].branches[t.branch][t.pos])
            }
        } else if b.networks[t.net].series.indices.contains(t.pos) {
            change(&b.networks[t.net].series[t.pos])
        }
        device.blocks[blockIndex] = b
    }

    private func insert(_ kind: LadElementKind) {
        let ni = selNet ?? (block.networks.count - 1)
        guard block.networks.indices.contains(ni) else { return }
        var el = LadElement(kind: kind)
        if kind == .coil || kind == .coilSet || kind == .coilReset || kind == .jmp || kind == .label || kind == .ret {
            if kind == .jmp || kind == .label { el.tag = "LBL1" }
            mutate(LadEditorView.TagTarget(net: ni, pos: -2, branch: -1, field: "")) { $0 = el }
            return
        }
        guard device.blocks.indices.contains(blockIndex) else { return }
        var b = device.blocks[blockIndex]
        let pos = selBranch == -1 && selPos >= 0 ? min(selPos + 1, b.networks[ni].series.count) : b.networks[ni].series.count
        b.networks[ni].series.insert(el, at: pos)
        device.blocks[blockIndex] = b
    }
}

// MARK: SCL editor

struct SclEditorView: View {
    @Binding var device: PlcDevice
    var blockIndex: Int
    @ObservedObject var sim: Simulator
    @State private var text: String = ""
    @State private var loadedFor: UUID? = nil

    private var block: PlcBlock {
        device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex] : PlcBlock()
    }

    static let template = """
    // SCL teaching subset: assignments, IF / ELSIF / ELSE, AND OR NOT,
    // comparisons and + - * / over tags and DB rows ("DB.Row").

    IF "BtnOn" THEN
        "Motor" := TRUE;
    ELSIF "BtnOff" THEN
        "Motor" := FALSE;
    END_IF;
    """

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor").foregroundColor(Tia.textDark)
                Text("\(block.name) [\(block.type)\(block.number)] — SCL").font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                Spacer()
                Button("Insert template") {
                    text = Self.template
                    save(text)
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Tia.toolbar)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
            TextEditor(text: $text)
                .font(.system(size: 12.5, design: .monospaced))
                .onChange(of: text) { save($0) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(device.tags.prefix(14)) { t in
                        HStack(spacing: 3) {
                            Text(t.name).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundColor(Tia.textDark)
                            if t.dataType == "Bool" {
                                Circle().fill((sim.values[t.name] ?? false) ? Tia.onlineTrue : Color.gray.opacity(0.35)).frame(width: 7, height: 7)
                            } else {
                                Text(fmtNum(sim.num(t.name))).font(.system(size: 10.5, design: .monospaced)).foregroundColor(Tia.tealText)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
            .background(Tia.pane)
        }
        .background(Color.white)
        .onAppear {
            if loadedFor != block.id {
                text = block.sclSource ?? ""
                loadedFor = block.id
            }
        }
    }

    private func fmtNum(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 100000 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func save(_ s: String) {
        guard device.blocks.indices.contains(blockIndex) else { return }
        if device.blocks[blockIndex].sclSource != s {
            device.blocks[blockIndex].sclSource = s
        }
    }
}
