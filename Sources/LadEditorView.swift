import SwiftUI

// MARK: - LAD editor (v3 — built to the approved wireframe)
//
// Block interface on top, favorites bar, then the networks. Operand
// labels are two lines: the %address in SF Mono Bold teal (#007B8A),
// the "name" in grey below it. Timer/counter boxes are #EFEFEF with a
// header band and the instance name above the box. Online, a live wire
// is solid green (#1E9E4A) and a dead wire dashed blue (#3A7BD5).
// Editing is tap-to-target: tap an element to select it (insertion
// points (+) appear), then tap a favorite or a task-card instruction to
// insert there. Double-tap toggles NO<->NC and cycles () -> S -> R.
// Pinch zooms 50–200% with semantic levels; the HUD has a Fit button.

struct LadEditorView: View {
    @Binding var device: PlcDevice
    var blockIndex: Int
    @ObservedObject var sim: Simulator
    var online: Bool
    @Binding var insertRequest: LadElementKind?

    @State private var zoom: CGFloat = 1.0
    @State private var pinchStart: CGFloat? = nil
    @State private var showInterface = true
    @State private var selNet: Int? = nil
    @State private var selPos: Int = -1          // series index; -2 = output; -3 = parallel idx encoded separately
    @State private var selParallel: Int? = nil   // parallel index when selected
    @State private var insNet: Int? = nil        // insertion target network
    @State private var insPos: Int = 0           // insertion index in series (0...count)
    @State private var tagPickerFor: TagTarget? = nil

    struct TagTarget: Identifiable {
        var id = UUID()
        var net: Int
        var pos: Int        // series index, or -2 for output
        var parallel: Bool
    }

    private var block: PlcBlock {
        device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex] : PlcBlock()
    }
    private var live: Bool { online && sim.powered }
    private var showDetail: Bool { zoom >= 0.78 }        // semantic level: comments + (+) points
    private var z: CGFloat { zoom }

    var body: some View {
        VStack(spacing: 0) {
            interfaceBar
            favoritesBar
            GeometryReader { geo in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 14 * z) {
                        ForEach(Array(block.networks.enumerated()), id: \.element.id) { ni, net in
                            networkView(ni, net)
                        }
                        addNetworkButton
                    }
                    .padding(10 * z)
                    .frame(minWidth: geo.size.width, alignment: .leading)
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { v in
                                if pinchStart == nil { pinchStart = zoom }
                                zoom = min(2.0, max(0.5, (pinchStart ?? 1) * v))
                            }
                            .onEnded { _ in pinchStart = nil }
                    )
                }
                .background(Color.white)
                .overlay(alignment: .bottomTrailing) {
                    ZoomHUD(zoom: $zoom) { fit(geo.size.width) }
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    if selNet != nil { actionStrip.padding(8) }
                }
            }
        }
        .background(Color.white)
        .onChange(of: insertRequest) { kind in
            if let kind { insert(kind); insertRequest = nil }
        }
        .sheet(item: $tagPickerFor) { target in
            TagPickerSheet(tags: device.tags) { name in
                assignTag(target, name)
                tagPickerFor = nil
            }
        }
    }

    private func fit(_ width: CGFloat) {
        zoom = min(2.0, max(0.5, (width - 16) / 640))
    }

    // MARK: Block interface + favorites

    private var interfaceBar: some View {
        VStack(spacing: 0) {
            Button { showInterface.toggle() } label: {
                HStack(spacing: 5) {
                    Image(systemName: showInterface ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("Block interface").font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Text("\(block.name) [\(block.type)\(block.number)] — \(block.language)")
                        .font(.system(size: 10.5)).foregroundColor(.secondary)
                }
                .foregroundColor(Tia.textDark)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Tia.networkBar)
            if showInterface, let rows = block.interfaceRows, !rows.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Name").frame(width: 130, alignment: .leading)
                        Text("Data type").frame(width: 70, alignment: .leading)
                        Text("Comment").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 10, weight: .bold)).foregroundColor(Tia.textDark)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    ForEach(rows) { r in
                        HStack {
                            Text("\(r.section) · \(r.name)").frame(width: 130, alignment: .leading)
                            Text(r.dataType).frame(width: 70, alignment: .leading)
                            Text(r.comment).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(size: 10.5)).foregroundColor(Tia.textDark)
                        .padding(.horizontal, 8).padding(.vertical, 1.5)
                    }
                }
                .background(Color.white)
                .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
            }
        }
    }

    private var favoritesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(favorites, id: \.kind) { f in
                    Button { insert(f.kind) } label: {
                        Text(f.glyph)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Tia.textDark)
                            .frame(width: 42, height: 28)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 36)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var favorites: [(kind: LadElementKind, glyph: String)] {
        [(.contactNO, "┤├"), (.contactNC, "┤/├"), (.coil, "( )"), (.coilSet, "(S)"),
         (.coilReset, "(R)"), (.pTrig, "┤P├"), (.nTrig, "┤N├"), (.notOp, "NOT"),
         (.ton, "TON"), (.tof, "TOF"), (.tp, "TP"), (.ctu, "CTU"), (.ctd, "CTD")]
    }

    // MARK: Network rendering

    private func networkView(_ ni: Int, _ net: LadNetwork) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("▾ Network \(ni + 1):")
                    .font(.system(size: 12 * z, weight: .bold)).foregroundColor(Tia.textDark)
                TextField("Title", text: titleBinding(ni))
                    .font(.system(size: 12 * z)).foregroundColor(Tia.textDark)
                if selNet == ni {
                    Button { deleteNetwork(ni) } label: {
                        Image(systemName: "trash").font(.system(size: 11 * z)).foregroundColor(Tia.errorRed)
                    }
                    .buttonStyle(.plain)
                }
            }
            if showDetail && !net.comment.isEmpty {
                Text(net.comment).font(.system(size: 10.5 * z).italic()).foregroundColor(.secondary)
            }
            rungView(ni, net)
            if !net.parallel.isEmpty {
                parallelView(ni, net)
            }
        }
        .padding(6 * z)
        .frame(width: 640 * z, alignment: .leading)
        .background(selNet == ni ? Color(red: 0.97, green: 0.98, blue: 1.0) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border.opacity(0.6), lineWidth: 0.7))
        .onTapGesture { selNet = ni }
    }

    private func rungView(_ ni: Int, _ net: LadNetwork) -> some View {
        let flows = flowStates(net)
        return HStack(alignment: .top, spacing: 0) {
            // power rail
            Rectangle()
                .fill(live ? (sim.running ? Tia.onlineTrue : Tia.onlineFalse) : Tia.wire)
                .frame(width: 3.5 * z, height: 64 * z)
                .padding(.trailing, 2)
            ForEach(Array(net.series.enumerated()), id: \.element.id) { ei, el in
                if showDetail && insNet == ni && insPos == ei {
                    insertPoint { }
                }
                wireSegment(on: flows[ei])
                elementCell(ni, ei, el, parallel: false)
            }
            wireSegment(on: flows.last ?? true)
            outputCell(ni, net.output)
        }
    }

    private func parallelView(_ ni: Int, _ net: LadNetwork) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(live ? Tia.onlineTrue : Tia.wire).frame(width: 3.5 * z, height: 30 * z)
                .padding(.trailing, 2)
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(live ? Tia.onlineTrue : Tia.wire).frame(width: 30 * z, height: 1.6 * z)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(net.parallel.enumerated()), id: \.element.id) { ei, el in
                        elementCell(ni, ei, el, parallel: true)
                        wireSegment(on: live)
                    }
                }
            }
            Spacer()
        }
        .padding(.leading, 6 * z)
    }

    private func wireSegment(on: Bool) -> some View {
        let color: Color = live ? (on ? Tia.onlineTrue : Tia.onlineFalse) : Tia.wire
        return ZStack {
            if live && !on {
                DashedLine().stroke(color, lineWidth: 1.6 * z)
            } else {
                Rectangle().fill(color).frame(height: 1.8 * z)
            }
        }
        .frame(width: 14 * z, height: 64 * z)
    }

    private func insertPoint(action: @escaping () -> Void) -> some View {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 15 * z))
            .foregroundColor(Tia.accent)
            .frame(width: 16 * z, height: 64 * z)
    }

    // MARK: Elements

    @ViewBuilder
    private func elementCell(_ ni: Int, _ ei: Int, _ el: LadElement, parallel: Bool) -> some View {
        let selected = selNet == ni && (parallel ? selParallel == ei : (selParallel == nil && selPos == ei))
        VStack(spacing: 1) {
            if isBox(el.kind) {
                boxView(ni, ei, el, parallel: parallel)
            } else {
                operandLabel(el)
                LadGlyph(kind: el.kind, color: Tia.wire, scale: z)
                    .frame(width: 46 * z, height: 30 * z)
            }
        }
        .padding(3 * z)
        .background(selected ? Tia.selection : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(selected ? Tia.accent : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { toggleKind(ni, ei, parallel: parallel) }
        .onTapGesture {
            selNet = ni
            if parallel { selParallel = ei; selPos = -1 } else { selParallel = nil; selPos = ei }
            insNet = ni; insPos = ei + 1
        }
        .onLongPressGesture {
            selNet = ni
            if parallel { selParallel = ei; selPos = -1 } else { selParallel = nil; selPos = ei }
            tagPickerFor = TagTarget(net: ni, pos: ei, parallel: parallel)
        }
    }

    @ViewBuilder
    private func outputCell(_ ni: Int, _ el: LadElement) -> some View {
        let selected = selNet == ni && selParallel == nil && selPos == -2
        VStack(spacing: 1) {
            if isBox(el.kind) {
                boxView(ni, -2, el, parallel: false)
            } else {
                operandLabel(el)
                LadGlyph(kind: el.kind, color: Tia.wire, scale: z)
                    .frame(width: 46 * z, height: 30 * z)
            }
        }
        .padding(3 * z)
        .background(selected ? Tia.selection : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(selected ? Tia.accent : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { toggleKind(ni, -2, parallel: false) }
        .onTapGesture {
            selNet = ni; selParallel = nil; selPos = -2
            insNet = ni; insPos = block.networks[ni].series.count
        }
        .onLongPressGesture {
            selNet = ni; selParallel = nil; selPos = -2
            tagPickerFor = TagTarget(net: ni, pos: -2, parallel: false)
        }
    }

    private func operandLabel(_ el: LadElement) -> some View {
        VStack(spacing: 0) {
            Text(addressOf(el.tag))
                .font(.system(size: 10.5 * z, weight: .bold, design: .monospaced))
                .foregroundColor(Tia.labelTeal)
            Text(el.tag.isEmpty ? "\"???\"" : "\"\(el.tag)\"")
                .font(.system(size: 10 * z))
                .foregroundColor(Tia.nameGrey)
        }
        .frame(height: 26 * z)
        .onTapGesture {
            // label tap is handled by the cell (selection); the picker
            // opens on long-press, as in the touch matrix.
        }
    }

    private func boxView(_ ni: Int, _ ei: Int, _ el: LadElement, parallel: Bool) -> some View {
        VStack(spacing: 1) {
            Text(el.instance.isEmpty ? "???" : el.instance)
                .font(.system(size: 9.5 * z)).foregroundColor(.secondary)
            VStack(spacing: 0) {
                Text(kindName(el.kind))
                    .font(.system(size: 10.5 * z, weight: .bold)).foregroundColor(Tia.textDark)
                    .frame(width: 92 * z, height: 15 * z)
                    .background(Tia.boxHeader)
                HStack {
                    Text(isTimer(el.kind) ? "IN" : (el.kind == .ctu ? "CU" : "CD"))
                        .font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text("Q").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Circle()
                        .fill((sim.values[el.tag] ?? false) && live ? Tia.onlineTrue : Color.gray.opacity(0.4))
                        .frame(width: 7 * z, height: 7 * z)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 14 * z)
                HStack {
                    Text(isTimer(el.kind) ? "PT" : "PV").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text(el.preset).font(.system(size: 9.5 * z, weight: .semibold, design: .monospaced)).foregroundColor(Tia.textDark)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 14 * z)
                if isCounter(el.kind) {
                    HStack {
                        Text("CV").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                        Spacer()
                        Text("\(sim.counts[el.instance] ?? 0)")
                            .font(.system(size: 9.5 * z, weight: .bold, design: .monospaced))
                            .foregroundColor(live ? Tia.onlineTrue : Tia.textDark)
                    }
                    .padding(.horizontal, 4 * z)
                    .frame(height: 14 * z)
                }
            }
            .frame(width: 96 * z)
            .background(Tia.boxFillV3)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.wire, lineWidth: 0.9))
        }
    }

    // MARK: Floating action strip (selection)

    private var actionStrip: some View {
        HStack(spacing: 4) {
            stripButton("Toggle", "arrow.triangle.2.circlepath") {
                if let ni = selNet { toggleKind(ni, selParallel ?? selPos, parallel: selParallel != nil) }
            }
            stripButton("Tag", "tag") {
                if let ni = selNet {
                    tagPickerFor = TagTarget(net: ni, pos: selPos, parallel: selParallel != nil)
                }
            }
            stripButton("Branch", "arrow.branch") { addBranch() }
            stripButton("Delete", "trash") { deleteSelected() }
        }
        .padding(4)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Tia.border, lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    private func stripButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 8.5))
            }
            .foregroundColor(Tia.textDark)
            .frame(width: 48, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addNetworkButton: some View {
        Button {
            updateBlock { $0.networks.append(LadNetwork(title: "New network", output: LadElement(kind: .coil))) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle").font(.system(size: 12 * z))
                Text("Add network").font(.system(size: 11.5 * z, weight: .semibold))
            }
            .foregroundColor(Tia.accent)
            .padding(.vertical, 6 * z)
        }
        .buttonStyle(.plain)
    }

    // MARK: Editing operations

    private func updateBlock(_ change: (inout PlcBlock) -> Void) {
        guard device.blocks.indices.contains(blockIndex) else { return }
        var b = device.blocks[blockIndex]
        change(&b)
        device.blocks[blockIndex] = b
    }

    private func insert(_ kind: LadElementKind) {
        let ni = insNet ?? selNet ?? (block.networks.count - 1)
        guard block.networks.indices.contains(ni) else { return }
        var el = LadElement(kind: kind)
        if isBox(kind) {
            el.instance = "\(kindName(kind))_\(ni + 1)"
            if isCounter(kind) { el.preset = "5"; el.presetValue = 5 }
        }
        if kind == .coil || kind == .coilSet || kind == .coilReset {
            // a coil from the palette replaces the network output, like TIA
            updateBlock { $0.networks[ni].output = el }
            selNet = ni; selPos = -2; selParallel = nil
            return
        }
        let pos = min(insPos, block.networks[ni].series.count)
        updateBlock { $0.networks[ni].series.insert(el, at: pos) }
        selNet = ni; selPos = pos; selParallel = nil
        insPos = pos + 1
    }

    private func toggleKind(_ ni: Int, _ pos: Int, parallel: Bool) {
        updateBlock { b in
            func flip(_ el: inout LadElement) {
                switch el.kind {
                case .contactNO: el.kind = .contactNC
                case .contactNC: el.kind = .contactNO
                case .pTrig: el.kind = .nTrig
                case .nTrig: el.kind = .pTrig
                case .coil: el.kind = .coilSet
                case .coilSet: el.kind = .coilReset
                case .coilReset: el.kind = .coil
                default: break
                }
            }
            if parallel {
                if b.networks[ni].parallel.indices.contains(pos) { flip(&b.networks[ni].parallel[pos]) }
            } else if pos == -2 {
                flip(&b.networks[ni].output)
            } else if b.networks[ni].series.indices.contains(pos) {
                flip(&b.networks[ni].series[pos])
            }
        }
    }

    private func deleteSelected() {
        guard let ni = selNet else { return }
        if let pi = selParallel {
            updateBlock { if $0.networks[ni].parallel.indices.contains(pi) { $0.networks[ni].parallel.remove(at: pi) } }
            selParallel = nil
        } else if selPos >= 0 {
            updateBlock { if $0.networks[ni].series.indices.contains(selPos) { $0.networks[ni].series.remove(at: selPos) } }
            selPos = -1
        }
    }

    private func deleteNetwork(_ ni: Int) {
        updateBlock { if $0.networks.indices.contains(ni) { $0.networks.remove(at: ni) } }
        selNet = nil; selPos = -1; selParallel = nil
    }

    private func addBranch() {
        guard let ni = selNet else { return }
        updateBlock { $0.networks[ni].parallel.append(LadElement(kind: .contactNO)) }
    }

    private func assignTag(_ target: TagTarget, _ name: String) {
        updateBlock { b in
            if target.parallel {
                if b.networks[target.net].parallel.indices.contains(target.pos) {
                    b.networks[target.net].parallel[target.pos].tag = name
                }
            } else if target.pos == -2 {
                b.networks[target.net].output.tag = name
            } else if b.networks[target.net].series.indices.contains(target.pos) {
                b.networks[target.net].series[target.pos].tag = name
            }
        }
    }

    private func titleBinding(_ ni: Int) -> Binding<String> {
        Binding(
            get: { block.networks.indices.contains(ni) ? block.networks[ni].title : "" },
            set: { v in updateBlock { if $0.networks.indices.contains(ni) { $0.networks[ni].title = v } } }
        )
    }

    // MARK: Helpers

    private func addressOf(_ tag: String) -> String {
        device.tags.first { $0.name == tag }?.address ?? "%??"
    }

    private func isBox(_ k: LadElementKind) -> Bool { isTimer(k) || isCounter(k) }
    private func isTimer(_ k: LadElementKind) -> Bool { k == .ton || k == .tof || k == .tp }
    private func isCounter(_ k: LadElementKind) -> Bool { k == .ctu || k == .ctd }
    private func kindName(_ k: LadElementKind) -> String {
        switch k {
        case .ton: return "TON"
        case .tof: return "TOF"
        case .tp: return "TP"
        case .ctu: return "CTU"
        case .ctd: return "CTD"
        default: return ""
        }
    }

    /// Prefix power flow through the series rung, for the online wire
    /// colours. Mirrors the simulator's value table; edge contacts are
    /// approximated by their current operand value.
    private func flowStates(_ net: LadNetwork) -> [Bool] {
        guard live else { return Array(repeating: true, count: net.series.count + 1) }
        var states: [Bool] = []
        var power = true
        for el in net.series {
            states.append(power)
            switch el.kind {
            case .notOp: power = !power
            case .contactNC: power = power && !(sim.values[el.tag] ?? false)
            default: power = power && (sim.values[el.tag] ?? false)
            }
        }
        states.append(power)
        return states
    }
}

// MARK: - Glyphs & dashed wire

struct LadGlyph: View {
    var kind: LadElementKind
    var color: Color
    var scale: CGFloat = 1
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, mid = h / 2
            let lw: CGFloat = 1.8 * scale
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: mid)); p.addLine(to: CGPoint(x: w, y: mid))
                }.stroke(color, lineWidth: lw)
                switch kind {
                case .contactNO, .pTrig, .nTrig:
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.32, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: w * 0.32, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: w * 0.68, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: w * 0.68, y: mid + h * 0.34))
                    }.stroke(color, lineWidth: lw)
                    if kind != .contactNO {
                        Text(kind == .pTrig ? "P" : "N")
                            .font(.system(size: 11 * scale, weight: .bold))
                            .foregroundColor(Tia.textDark)
                            .position(x: w * 0.5, y: mid)
                    }
                case .contactNC:
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.32, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: w * 0.32, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: w * 0.68, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: w * 0.68, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: w * 0.24, y: mid + h * 0.30)); p.addLine(to: CGPoint(x: w * 0.76, y: mid - h * 0.30))
                    }.stroke(color, lineWidth: lw)
                case .coil, .coilSet, .coilReset:
                    Path { p in
                        p.addArc(center: CGPoint(x: w * 0.40, y: mid), radius: h * 0.30, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                        p.addArc(center: CGPoint(x: w * 0.60, y: mid), radius: h * 0.30, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                    }.stroke(color, lineWidth: lw)
                    if kind != .coil {
                        Text(kind == .coilSet ? "S" : "R")
                            .font(.system(size: 10 * scale, weight: .bold))
                            .foregroundColor(Tia.textDark)
                            .position(x: w * 0.5, y: mid)
                    }
                case .notOp:
                    RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: lw)
                        .frame(width: w * 0.62, height: h * 0.62)
                        .position(x: w * 0.5, y: mid)
                    Text("NOT").font(.system(size: 8.5 * scale, weight: .bold))
                        .foregroundColor(Tia.textDark)
                        .position(x: w * 0.5, y: mid)
                default:
                    EmptyView()
                }
            }
        }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p.strokedPath(StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
    }
}

// MARK: - Tag picker (operand autocomplete, like the touch matrix)

struct TagPickerSheet: View {
    var tags: [PlcTag]
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationView {
            List {
                ForEach(tags.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { t in
                    Button {
                        onPick(t.name)
                    } label: {
                        HStack {
                            Text(t.address)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Tia.labelTeal)
                                .frame(width: 58, alignment: .leading)
                            Text(t.name).font(.system(size: 13)).foregroundColor(Tia.textDark)
                            Spacer()
                            Text(t.dataType).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Tag name or address")
            .navigationTitle("Select operand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
