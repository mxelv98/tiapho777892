import SwiftUI

/// LAD editor — networks drawn the way TIA draws them: block interface on
/// top, title bar, comment, power rail, contacts / coils / boxes, and the
/// zoom control at the bottom right. Operand labels are two lines:
/// %address in teal bold, then the "name" in quotes, exactly like TIA.
struct LadEditorView: View {
    var block: PlcBlock
    var tags: [PlcTag]
    var sim: Simulator?
    var onChange: (PlcBlock) -> Void

    @State private var editing: LadElement?
    @State private var editingPath: (net: Int, series: Int?, isOutput: Bool, isParallel: Bool) = (0, nil, false, false)
    @State private var zoom: CGFloat = 1.0
    @State private var showInterface = true
    @State private var editingVar: InterfaceVar?
    @State private var varName = ""
    @State private var varSection = "Temp"
    @State private var varType = "Bool"

    private var monitoring: Bool { (sim?.powered ?? false) }
    private var wireColor: Color { monitoring ? Tia.runGreen : Tia.wire }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    favoritesBar
                    if block.interfaceRows != nil { interfaceSection }
                    ForEach(Array(block.networks.enumerated()), id: \.element.id) { ni, net in
                        networkView(ni: ni, net: net)
                    }
                    Button {
                        var b = block
                        b.networks.append(LadNetwork(title: "", output: LadElement(kind: .coil, tag: tags.first?.name ?? "")))
                        onChange(b)
                    } label: {
                        Label("Add network", systemImage: "plus.rectangle.on.rectangle")
                            .font(.system(size: 12)).foregroundColor(Tia.accent)
                    }
                    .padding(10)
                }
                .background(Color.white)
            }
            .background(Color.white)
            zoomControl
        }
        .sheet(item: $editing) { el in elementSheet(el) }
        .sheet(isPresented: Binding(get: { editingVar != nil }, set: { if !$0 { editingVar = nil } })) { varSheet }
    }

    // MARK: zoom (bottom-right, like the real editor)

    private var zoomControl: some View {
        HStack(spacing: 2) {
            Button { zoom = max(0.5, zoom - 0.25) } label: { Image(systemName: "minus") }
            Text("\(Int(zoom * 100))%").font(.system(size: 11, weight: .medium)).frame(width: 40)
            Button { zoom = min(2, zoom + 0.25) } label: { Image(systemName: "plus") }
        }
        .foregroundColor(Tia.textDark)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.7)))
        .padding(8)
    }

    // MARK: favorites bar — every symbol of the taught set, drawn as glyphs

    private var favoritesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(InstructionCatalog.families.flatMap { $0.items }.filter { $0.kind != nil }) { item in
                    Button { addToLastNetwork(item) } label: {
                        VStack(spacing: 1) {
                            glyph(item.symbol).frame(height: 20)
                            Text(item.symbol).font(.system(size: 8)).foregroundColor(.secondary)
                        }
                        .frame(width: 40, height: 36)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Tia.pane))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
        }
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    @ViewBuilder private func glyph(_ s: String) -> some View {
        switch s {
        case "| |": glyphPath { p in
            p.move(to: CGPoint(x: 2, y: 10)); p.addLine(to: CGPoint(x: 13, y: 10))
            p.move(to: CGPoint(x: 13, y: 3)); p.addLine(to: CGPoint(x: 13, y: 17))
            p.move(to: CGPoint(x: 27, y: 3)); p.addLine(to: CGPoint(x: 27, y: 17))
            p.move(to: CGPoint(x: 27, y: 10)); p.addLine(to: CGPoint(x: 38, y: 10)) }
        case "|/|": glyphPath { p in
            p.move(to: CGPoint(x: 2, y: 10)); p.addLine(to: CGPoint(x: 13, y: 10))
            p.move(to: CGPoint(x: 13, y: 3)); p.addLine(to: CGPoint(x: 13, y: 17))
            p.move(to: CGPoint(x: 27, y: 3)); p.addLine(to: CGPoint(x: 27, y: 17))
            p.move(to: CGPoint(x: 27, y: 10)); p.addLine(to: CGPoint(x: 38, y: 10))
            p.move(to: CGPoint(x: 11, y: 17)); p.addLine(to: CGPoint(x: 29, y: 3)) }
        case "|P|", "|N|":
            ZStack {
                glyphPath { p in
                    p.move(to: CGPoint(x: 2, y: 10)); p.addLine(to: CGPoint(x: 13, y: 10))
                    p.move(to: CGPoint(x: 13, y: 3)); p.addLine(to: CGPoint(x: 13, y: 17))
                    p.move(to: CGPoint(x: 27, y: 3)); p.addLine(to: CGPoint(x: 27, y: 17))
                    p.move(to: CGPoint(x: 27, y: 10)); p.addLine(to: CGPoint(x: 38, y: 10)) }
                Text(s == "|P|" ? "P" : "N").font(.system(size: 9, weight: .bold)).foregroundColor(Tia.textDark)
                    .background(Color.white)
            }
        case "( )", "(S)", "(R)":
            ZStack {
                glyphPath { p in
                    p.move(to: CGPoint(x: 2, y: 10)); p.addLine(to: CGPoint(x: 12, y: 10))
                    p.addArc(center: CGPoint(x: 19, y: 10), radius: 7, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                    p.addArc(center: CGPoint(x: 21, y: 10), radius: 7, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                    p.move(to: CGPoint(x: 28, y: 10)); p.addLine(to: CGPoint(x: 38, y: 10)) }
                if s != "( )" {
                    Text(s == "(S)" ? "S" : "R").font(.system(size: 9, weight: .bold)).foregroundColor(Tia.textDark)
                }
            }
        case "NOT":
            Text("NOT").font(.system(size: 9, weight: .bold)).foregroundColor(Tia.textDark)
                .padding(.horizontal, 3).overlay(Rectangle().stroke(Tia.wire, lineWidth: 1))
        default:
            Text(s).font(.system(size: 10, weight: .bold)).foregroundColor(Tia.textDark)
                .padding(.horizontal, 4).padding(.vertical, 2)
                .overlay(Rectangle().stroke(Tia.wire, lineWidth: 1))
        }
    }

    private func glyphPath(_ build: (inout Path) -> Void) -> some View {
        Path { p in build(&p) }.stroke(Tia.wire, lineWidth: 1.4).frame(width: 40, height: 20)
    }

    // MARK: block interface

    private var interfaceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { showInterface.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: showInterface ? "chevron.down" : "chevron.right")
                    Text("Block interface").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(block.name) [\(block.type) \(block.number)]").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .foregroundColor(Tia.textDark)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Tia.headerBand)
            }
            .buttonStyle(.plain)
            if showInterface {
                HStack(spacing: 0) {
                    ifaceCell("Name", 130, bold: true); ifaceCell("Section", 70, bold: true)
                    ifaceCell("Data type", 70, bold: true); ifaceCell("Comment", 170, bold: true)
                }.background(Color(white: 0.96))
                ForEach(block.interfaceRows ?? []) { v in
                    Button { openVar(v) } label: {
                        HStack(spacing: 0) {
                            ifaceCell(v.name, 130); ifaceCell(v.section, 70)
                            ifaceCell(v.dataType, 70); ifaceCell(v.comment, 170)
                        }
                    }.buttonStyle(.plain)
                    Rectangle().frame(height: 0.5).foregroundColor(Tia.border)
                }
                Button {
                    var b = block
                    var rows = b.interfaceRows ?? []
                    rows.append(InterfaceVar(name: "Var_\(rows.count)", section: "Temp", dataType: "Bool"))
                    b.interfaceRows = rows
                    onChange(b)
                } label: {
                    Label("Add variable", systemImage: "plus").font(.system(size: 11)).foregroundColor(Tia.accent)
                }.padding(.horizontal, 8).padding(.vertical, 4)
            }
            Rectangle().frame(height: 0.7).foregroundColor(Tia.border)
        }
    }

    private func ifaceCell(_ s: String, _ w: CGFloat, bold: Bool = false) -> some View {
        Text(s).font(.system(size: 11.5, weight: bold ? .semibold : .regular)).foregroundColor(Tia.textDark)
            .frame(width: w, alignment: .leading).padding(.leading, 6).padding(.vertical, 2).lineLimit(1)
    }

    private func openVar(_ v: InterfaceVar) {
        editingVar = v; varName = v.name; varSection = v.section; varType = v.dataType
    }

    private var varSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $varName)
                Picker("Section", selection: $varSection) {
                    ForEach(["Input", "Output", "InOut", "Static", "Temp", "Constant", "Return"], id: \.self) { Text($0).tag($0) }
                }
                Picker("Data type", selection: $varType) {
                    ForEach(["Bool", "Byte", "Word", "Int", "DInt", "Real", "Time"], id: \.self) { Text($0).tag($0) }
                }
                if let v = editingVar {
                    Button("Delete variable", role: .destructive) {
                        var b = block
                        b.interfaceRows?.removeAll { $0.id == v.id }
                        onChange(b); editingVar = nil
                    }
                }
            }
            .navigationTitle("Variable")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingVar = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let v = editingVar {
                            var b = block
                            if let i = b.interfaceRows?.firstIndex(where: { $0.id == v.id }) {
                                b.interfaceRows?[i].name = varName
                                b.interfaceRows?[i].section = varSection
                                b.interfaceRows?[i].dataType = varType
                                onChange(b)
                            }
                        }
                        editingVar = nil
                    }
                }
            }
        }
    }

    // MARK: networks

    private func networkView(ni: Int, net: LadNetwork) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Network \(ni + 1):").font(.system(size: 12 * zoom, weight: .bold)).foregroundColor(Tia.textDark)
                TextField("Title", text: titleBinding(ni))
                    .font(.system(size: 12 * zoom)).foregroundColor(Tia.textDark)
                Spacer()
                Menu {
                    Button("Add parallel branch") { addParallel(ni) }
                    Button("Delete network", role: .destructive) {
                        var b = block; b.networks.remove(at: ni); onChange(b)
                    }
                } label: { Image(systemName: "ellipsis.circle").foregroundColor(.secondary) }
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Tia.headerBand)
            TextField("Comment", text: commentBinding(ni))
                .font(.system(size: 11 * zoom)).foregroundColor(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 2)
            rung(ni: ni, net: net)
            Rectangle().frame(height: 0.7).foregroundColor(Tia.border)
        }
    }

    private func rung(ni: Int, net: LadNetwork) -> some View {
        let z = zoom
        let elW: CGFloat = 92 * z, boxW: CGFloat = 118 * z
        let rungH: CGFloat = (net.parallel.isEmpty ? 104 : 148) * z
        let midY: CGFloat = 56 * z
        let contentW = 26 + net.series.reduce(CGFloat(0)) { $0 + (isBox($1.kind) ? boxW : elW) } + elW + 20
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(wireColor).frame(width: 2.4, height: rungH).offset(x: 10)
            Rectangle().fill(wireColor).frame(width: 2.4, height: rungH).offset(x: max(contentW - 4, 300))
            HStack(alignment: .top, spacing: 0) {
                Color.clear.frame(width: 12)
                ForEach(Array(net.series.enumerated()), id: \.element.id) { si, el in
                    elementView(el, z: z)
                        .onTapGesture { editingPath = (ni, si, false, false); editing = el }
                }
                elementView(net.output, z: z)
                    .onTapGesture { editingPath = (ni, nil, true, false); editing = net.output }
                Spacer(minLength: 0)
            }
            .offset(y: midY - 52 * z)
            if !net.parallel.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: 12 + elW)
                    ForEach(Array(net.parallel.enumerated()), id: \.element.id) { pi, el in
                        elementView(el, z: z)
                            .onTapGesture { editingPath = (ni, pi, false, true); editing = el }
                    }
                    Spacer(minLength: 0)
                }
                .offset(y: midY + 2 * z)
                Rectangle().fill(wireColor).frame(width: 2, height: 46 * z)
                    .offset(x: 12 + elW / 2, y: midY - 46 * z + 4)
            }
        }
        .frame(width: max(contentW, 340), height: rungH)
    }

    @ViewBuilder private func elementView(_ el: LadElement, z: CGFloat) -> some View {
        switch el.kind {
        case .ton, .tof, .tp: timerBox(el, z: z)
        case .ctu, .ctd: counterBox(el, z: z)
        case .notOp:
            VStack(spacing: 1) {
                label(el, z: z)
                ZStack {
                    Rectangle().fill(Tia.boxFill).frame(width: 44 * z, height: 22 * z)
                        .overlay(Rectangle().stroke(wireColor, lineWidth: 1.2))
                    Text("NOT").font(.system(size: 10 * z, weight: .bold)).foregroundColor(Tia.textDark)
                }
                .frame(width: 92 * z, height: 46 * z)
            }
            .frame(width: 92 * z)
        default: contactOrCoil(el, z: z)
        }
    }

    private func isBox(_ k: LadElementKind) -> Bool { [.ton, .tof, .tp, .ctu, .ctd].contains(k) }

    private func contactOrCoil(_ el: LadElement, z: CGFloat) -> some View {
        let live = monitoring && (sim?.values[el.tag] ?? false)
        let col = live ? Tia.runGreen : wireColor
        return VStack(spacing: 1) {
            label(el, z: z)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 23 * z)); p.addLine(to: CGPoint(x: 92 * z, y: 23 * z))
                }.stroke(col, lineWidth: 1.6)
                switch el.kind {
                case .contactNO, .contactNC, .pTrig, .nTrig:
                    Path { p in
                        p.move(to: CGPoint(x: 33 * z, y: 8 * z)); p.addLine(to: CGPoint(x: 33 * z, y: 38 * z))
                        p.move(to: CGPoint(x: 59 * z, y: 8 * z)); p.addLine(to: CGPoint(x: 59 * z, y: 38 * z))
                        if el.kind == .contactNC {
                            p.move(to: CGPoint(x: 30 * z, y: 38 * z)); p.addLine(to: CGPoint(x: 62 * z, y: 8 * z))
                        }
                    }.stroke(col, lineWidth: 1.8)
                    if el.kind == .pTrig || el.kind == .nTrig {
                        Text(el.kind == .pTrig ? "P" : "N")
                            .font(.system(size: 11 * z, weight: .bold)).foregroundColor(Tia.textDark)
                            .background(Color.white)
                    }
                default: // coils
                    Path { p in
                        p.addArc(center: CGPoint(x: 41 * z, y: 23 * z), radius: 13 * z, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                        p.addArc(center: CGPoint(x: 51 * z, y: 23 * z), radius: 13 * z, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                    }.stroke(col, lineWidth: 1.8)
                    if el.kind == .coilSet || el.kind == .coilReset {
                        Text(el.kind == .coilSet ? "S" : "R")
                            .font(.system(size: 11 * z, weight: .bold)).foregroundColor(Tia.textDark)
                            .background(Color.white)
                    }
                }
            }
            .frame(width: 92 * z, height: 46 * z)
        }
        .frame(width: 92 * z)
    }

    /// Two-line operand label, exactly TIA's style: %I0.0 teal bold / "TagName".
    @ViewBuilder private func label(_ el: LadElement, z: CGFloat) -> some View {
        if el.kind == .notOp {
            Text(" ").font(.system(size: 10 * z))
            Text(" ").font(.system(size: 9.5 * z))
        } else {
            let tag = tags.first(where: { $0.name == el.tag })
            Text(tag?.address ?? "???").font(.system(size: 10 * z, weight: .bold)).foregroundColor(Tia.tealText)
            Text("\"\(el.tag)\"").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark).lineLimit(1)
        }
    }

    private func timerBox(_ el: LadElement, z: CGFloat) -> some View {
        let title = el.kind == .ton ? "TON" : (el.kind == .tof ? "TOF" : "TP")
        return VStack(spacing: 1) {
            Text("\"\(el.instance)\"").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark).lineLimit(1)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Text(title).font(.system(size: 10.5 * z, weight: .bold)).foregroundColor(Tia.textDark)
                        .frame(width: 118 * z, height: 17 * z).background(Tia.boxHeader)
                    Rectangle().fill(Tia.boxFill).frame(width: 118 * z, height: 62 * z)
                }
                .overlay(Rectangle().stroke(wireColor, lineWidth: 1.2))
                VStack(alignment: .leading, spacing: 3 * z) {
                    pinRow("IN", "", z)
                    pinRow("PT", el.preset, z)
                    pinRow("Q", "\"\(el.tag)\"", z)
                    pinRow("ET", "—", z)
                }
                .padding(.top, 21 * z).padding(.horizontal, 5 * z)
            }
            .frame(width: 118 * z, height: 79 * z)
        }
        .frame(width: 118 * z)
    }

    private func counterBox(_ el: LadElement, z: CGFloat) -> some View {
        let isUp = el.kind == .ctu
        let cv = sim?.counts[el.instance]
        return VStack(spacing: 1) {
            Text("\"\(el.instance)\"").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark).lineLimit(1)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Text(isUp ? "CTU" : "CTD").font(.system(size: 10.5 * z, weight: .bold)).foregroundColor(Tia.textDark)
                        .frame(width: 118 * z, height: 17 * z).background(Tia.boxHeader)
                    Rectangle().fill(Tia.boxFill).frame(width: 118 * z, height: 74 * z)
                }
                .overlay(Rectangle().stroke(wireColor, lineWidth: 1.2))
                VStack(alignment: .leading, spacing: 3 * z) {
                    pinRow(isUp ? "CU" : "CD", el.inputTag.isEmpty ? "" : "\"\(el.inputTag)\"", z)
                    pinRow("R", "", z)
                    pinRow("PV", el.preset, z)
                    pinRow("Q", "\"\(el.tag)\"", z)
                    pinRow("CV", cv.map { "\($0)" } ?? "—", z)
                }
                .padding(.top, 21 * z).padding(.horizontal, 5 * z)
            }
            .frame(width: 118 * z, height: 91 * z)
        }
        .frame(width: 118 * z)
    }

    private func pinRow(_ pin: String, _ val: String, _ z: CGFloat) -> some View {
        HStack(spacing: 3) {
            Text(pin).font(.system(size: 9.5 * z, weight: .semibold)).foregroundColor(Tia.textDark)
            Text(val).font(.system(size: 9.5 * z)).foregroundColor(Tia.tealText).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: editing

    private func addToLastNetwork(_ item: InstructionItem) {
        guard let el = InstructionCatalog.makeElement(item, tags: tags), !block.networks.isEmpty else { return }
        var b = block
        let li = b.networks.count - 1
        if el.kind == .coil || el.kind == .coilSet || el.kind == .coilReset {
            b.networks[li].output = el
        } else {
            b.networks[li].series.append(el)
        }
        onChange(b)
    }

    private func addParallel(_ ni: Int) {
        var b = block
        b.networks[ni].parallel.append(LadElement(kind: .contactNO, tag: tags.first?.name ?? ""))
        onChange(b)
    }

    private func titleBinding(_ ni: Int) -> Binding<String> {
        Binding(get: { block.networks[ni].title },
                set: { v in var b = block; b.networks[ni].title = v; onChange(b) })
    }
    private func commentBinding(_ ni: Int) -> Binding<String> {
        Binding(get: { block.networks[ni].comment },
                set: { v in var b = block; b.networks[ni].comment = v; onChange(b) })
    }

    private func elementSheet(_ el: LadElement) -> some View {
        ElementSheet(element: el, tags: tags) { newEl in
            var b = block
            let p = editingPath
            if p.isOutput { b.networks[p.net].output = newEl }
            else if p.isParallel { if let i = p.series { b.networks[p.net].parallel[i] = newEl } }
            else if let i = p.series { b.networks[p.net].series[i] = newEl }
            onChange(b)
            editing = nil
        } onDelete: {
            var b = block
            let p = editingPath
            if p.isParallel { if let i = p.series { b.networks[p.net].parallel.remove(at: i) } }
            else if let i = p.series { b.networks[p.net].series.remove(at: i) }
            onChange(b)
            editing = nil
        } onCancel: { editing = nil }
    }
}

/// Element properties — the sheet TIA would call "Properties" for the
/// selected instruction: operand picker, instance, preset.
struct ElementSheet: View {
    @State var element: LadElement
    var tags: [PlcTag]
    var onSave: (LadElement) -> Void
    var onDelete: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Instruction") {
                    Picker("Type", selection: $element.kind) {
                        Text("Contact NO  --| |--").tag(LadElementKind.contactNO)
                        Text("Contact NC  --|/|--").tag(LadElementKind.contactNC)
                        Text("Coil  --( )--").tag(LadElementKind.coil)
                        Text("Set coil  --(S)--").tag(LadElementKind.coilSet)
                        Text("Reset coil  --(R)--").tag(LadElementKind.coilReset)
                        Text("Positive edge  --|P|--").tag(LadElementKind.pTrig)
                        Text("Negative edge  --|N|--").tag(LadElementKind.nTrig)
                        Text("NOT — invert RLO").tag(LadElementKind.notOp)
                        Text("TON — on-delay timer").tag(LadElementKind.ton)
                        Text("TOF — off-delay timer").tag(LadElementKind.tof)
                        Text("TP — pulse timer").tag(LadElementKind.tp)
                        Text("CTU — count up").tag(LadElementKind.ctu)
                        Text("CTD — count down").tag(LadElementKind.ctd)
                    }
                }
                switch element.kind {
                case .ton, .tof, .tp:
                    Section("Timer") {
                        TextField("Instance name", text: $element.instance)
                        Stepper("PT: \(element.presetSeconds, specifier: "%.1f") s  (\(element.preset))", value: $element.presetSeconds, in: 0.5...60, step: 0.5)
                            .onChange(of: element.presetSeconds) { v in element.preset = "T#\(Self.fmtSecs(v))s" }
                        Picker("Output tag (Q)", selection: $element.tag) {
                            Text("—").tag("")
                            ForEach(tags) { t in Text("\(t.name)  \(t.address)").tag(t.name) }
                        }
                    }
                case .ctu, .ctd:
                    Section("Counter") {
                        TextField("Instance name", text: $element.instance)
                        Picker(element.kind == .ctu ? "Count input tag (CU)" : "Count input tag (CD)", selection: $element.inputTag) {
                            Text("Rung power").tag("")
                            ForEach(tags) { t in Text("\(t.name)  \(t.address)").tag(t.name) }
                        }
                        Stepper("Preset value (PV): \(element.presetValue)", value: $element.presetValue, in: 1...999)
                            .onChange(of: element.presetValue) { v in element.preset = "\(v)" }
                        Picker("Output tag (Q)", selection: $element.tag) {
                            Text("—").tag("")
                            ForEach(tags) { t in Text("\(t.name)  \(t.address)").tag(t.name) }
                        }
                        Text("Reset: use a Reset coil whose operand is the counter instance name.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                case .notOp:
                    Section { Text("NOT inverts the rung power at this point. It has no operand.").font(.footnote).foregroundColor(.secondary) }
                default:
                    Section("Operand") {
                        Picker("Tag", selection: $element.tag) {
                            Text("—").tag("")
                            ForEach(tags) { t in Text("\(t.name)  \(t.address)").tag(t.name) }
                        }
                        TextField("or type a tag name", text: $element.tag)
                    }
                }
                Section {
                    Button("Delete element", role: .destructive) { onDelete() }
                }
            }
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { onSave(element) } }
            }
        }
    }

    static func fmtSecs(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
