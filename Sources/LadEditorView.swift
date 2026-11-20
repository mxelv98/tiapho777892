import SwiftUI

// MARK: - LAD editor (v3 — built to the approved wireframe)
//
// Block interface on top, favorites bar, then the networks. Operand
// labels: the %address in SF Mono Bold teal (#007B8A) above the symbol,
// the "name" in grey below it. Timer/counter boxes are #EFEFEF with a
// header band and the instance name above the box. Online, a live wire
// is solid green (#1E9E4A) and a dead wire dashed blue (#3A7BD5).
// Editing is tap-to-target: tap an element to select it (insertion
// points (+) appear), then tap a favorite or a task-card instruction to
// insert there. Kind changes (NO<->NC, () -> S -> R) live on the action
// strip's Toggle button — deliberately NOT a double-tap: stacking a
// double-tap recognizer on every cell delayed each tap by the
// double-tap window and left elements feeling stuck (fixed v3.3 after
// reverse-engineering the TIA editor's single-click model).
// Pinch zooms 50–200% with semantic levels; the HUD has a Fit button.
// Part 2: the rung is drawn on one strict grid — thick rail, a stub of
// exactly one cell, fixed cells, one centerline, output column aligned.
// v4.0: the full instruction set (SR/RS, TONR, CTUD, CMP, MATH, MOVE,
// PID, JMP/LABEL/RET), any number of parallel branches, undo/redo,
// network duplication, and a Params sheet for box operands/constants.

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
    @State private var selPos: Int = -1          // index in series or in the selected branch; -2 = output
    @State private var selBranch: Int? = nil     // branch index when a branch element is selected
    @State private var insNet: Int? = nil        // insertion target network
    @State private var insPos: Int = 0           // insertion index
    @State private var insBranch: Int? = nil     // insertion targets this branch (nil = series)
    @State private var tagPickerFor: TagTarget? = nil
    @State private var paramsFor: TagTarget? = nil
    @State private var undoStack: [PlcBlock] = []
    @State private var redoStack: [PlcBlock] = []

    struct TagTarget: Identifiable {
        var id = UUID()
        var net: Int
        var pos: Int        // series/branch index, or -2 for output
        var branch: Int     // -1 = series, >= 0 = branch index
        var field: String   // "tag" / "inputTag" / "outTag"
    }

    private var block: PlcBlock {
        device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex] : PlcBlock()
    }
    private var live: Bool { online && sim.powered }
    private var showDetail: Bool { zoom >= 0.78 }        // semantic level: comments + (+) points
    private var z: CGFloat { zoom }
    private var numericTags: [PlcTag] { device.tags.filter { $0.dataType != "Bool" } }
    private var dbOperands: [String] {
        (device.dataBlocks ?? []).flatMap { db in db.rows.map { "\(db.name).\($0.name)" } }
    }

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
            TagPickerSheet(tags: device.tags, extra: dbOperands) { name in
                assignTag(target, name)
                tagPickerFor = nil
            }
        }
        .sheet(item: $paramsFor) { target in
            paramsSheet(target)
        }
    }

    private func fit(_ width: CGFloat) {
        zoom = min(2.0, max(0.5, (width - 16) / contentW))
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
        HStack(spacing: 2) {
            Button { undo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .bold))
                    .foregroundColor(undoStack.isEmpty ? .gray : Tia.textDark)
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.plain).disabled(undoStack.isEmpty)
            Button { redo() } label: {
                Image(systemName: "arrow.uturn.forward").font(.system(size: 12, weight: .bold))
                    .foregroundColor(redoStack.isEmpty ? .gray : Tia.textDark)
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.plain).disabled(redoStack.isEmpty)
            Divider().frame(height: 22)
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
        }
        .frame(height: 36)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var favorites: [(kind: LadElementKind, glyph: String)] {
        [(.contactNO, "┤├"), (.contactNC, "┤/├"), (.coil, "( )"), (.coilSet, "(S)"),
         (.coilReset, "(R)"), (.pTrig, "┤P├"), (.nTrig, "┤N├"), (.notOp, "NOT"),
         (.ton, "TON"), (.tof, "TOF"), (.tp, "TP"), (.tonr, "TONR"),
         (.ctu, "CTU"), (.ctd, "CTD"), (.ctud, "CTUD"),
         (.sr, "SR"), (.rs, "RS"), (.cmp, "CMP"), (.math, "MATH"),
         (.move, "MOVE"), (.pid, "PID"), (.jmp, "JMP"), (.label, "LBL"), (.ret, "RET")]
    }

    // MARK: Network rendering — strict grid geometry (Part 2)
    //
    // One fixed grid for every network: a thick left rail, then a wire
    // stub of exactly one cell width, then elements in consecutive
    // cells. Every element's input and output sit on the same
    // centerline; wires are horizontal or vertical only and run glyph
    // edge to glyph edge. The output element always lands in the same
    // right-hand column (blockUnits). Labels are positioned around the
    // glyph and never move the centerline. v4.0: branches are a list —
    // each branch gets its own row under the main rung.

    private let cellW: CGFloat = 64
    private let railW: CGFloat = 9

    private func units(of el: LadElement) -> Int { isBox(el.kind) ? 2 : 1 }
    private func netUnits(_ net: LadNetwork) -> Int {
        let branchMax = net.branches.map { b in b.reduce(0) { $0 + units(of: $1) } }.max() ?? 0
        return max(net.series.reduce(0) { $0 + units(of: $1) }, branchMax) + units(of: net.output)
    }
    private var blockUnits: Int { max(1, block.networks.map(netUnits).max() ?? 1) }
    private func colX(_ col: Int) -> CGFloat { railW + cellW + CGFloat(col) * cellW }
    private var contentW: CGFloat { max(colX(blockUnits) + 14, 330) }
    private func netHasBox(_ net: LadNetwork) -> Bool {
        (net.series + net.branches.flatMap { $0 } + [net.output]).contains { isBox($0.kind) }
    }
    private func rungH(_ net: LadNetwork) -> CGFloat { netHasBox(net) ? 108 : 78 }
    private func wireY(_ net: LadNetwork) -> CGFloat { netHasBox(net) ? 46 : 36 }
    private func flowColor(_ on: Bool) -> Color { live ? (on ? Tia.onlineTrue : Tia.onlineFalse) : Tia.wire }

    private func networkView(_ ni: Int, _ net: LadNetwork) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("▾ Network \(ni + 1):")
                    .font(.system(size: 12 * z, weight: .bold)).foregroundColor(Tia.textDark)
                TextField("Title", text: titleBinding(ni))
                    .font(.system(size: 12 * z)).foregroundColor(Tia.textDark)
                if selNet == ni {
                    Button { duplicateNetwork(ni) } label: {
                        Image(systemName: "square.on.square").font(.system(size: 11 * z)).foregroundColor(Tia.textDark)
                    }
                    .buttonStyle(.plain)
                    Button { deleteNetwork(ni) } label: {
                        Image(systemName: "trash").font(.system(size: 11 * z)).foregroundColor(Tia.errorRed)
                    }
                    .buttonStyle(.plain)
                }
            }
            if showDetail && !net.comment.isEmpty {
                Text(net.comment).font(.system(size: 10.5 * z).italic()).foregroundColor(.secondary)
            }
            rungCanvas(ni, net)
        }
        .padding(6 * z)
        .frame(width: contentW * z, alignment: .leading)
        .background(selNet == ni ? Color(red: 0.97, green: 0.98, blue: 1.0) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border.opacity(0.6), lineWidth: 0.7))
        // No tap gesture here: a network-level recognizer fought the
        // title TextField and the cells (focus/selection sticking).
        // Network selection happens on the canvas background and cells.
    }

    private func rungCanvas(_ ni: Int, _ net: LadNetwork) -> some View {
        let y = wireY(net)
        let branchYs: [CGFloat] = net.branches.indices.map { y + 56 * CGFloat($0 + 1) }
        let canvasH = rungH(net) + CGFloat(net.branches.count) * 56
        let flows = flowFor(net.series)
        let bFlows = net.branches.map { flowFor($0) }
        let seriesOut = flows.last ?? true
        let anyBranchOut = bFlows.map { $0.last ?? false }.contains(true)
        let outCol = blockUnits - units(of: net.output)
        var cols: [Int] = []
        var c = 0
        for el in net.series { cols.append(c); c += units(of: el) }
        let seriesEnd = c
        return ZStack(alignment: .topLeading) {
            // canvas background: taps on empty wire/space select the
            // network (cells above it take their own taps first)
            Rectangle().fill(Color.white.opacity(0.001))
                .frame(width: contentW * z, height: canvasH * z)
                .onTapGesture { selNet = ni }
            // thick left power rail
            Rectangle()
                .fill(live ? Tia.onlineTrue : Color(red: 0.16, green: 0.18, blue: 0.20))
                .frame(width: railW * z, height: canvasH * z)
            // stub: rail to first element, exactly one cell wide
            hWire(x1: railW, x2: colX(0), y: y, on: true)
            // gap wire: last series element to the output column
            if outCol > seriesEnd {
                hWire(x1: colX(seriesEnd), x2: colX(outCol) + (isBox(net.output.kind) ? 4 : 0), y: y, on: seriesOut)
            }
            if isBox(net.output.kind) && outCol == seriesEnd {
                hWire(x1: colX(outCol), x2: colX(outCol) + 4, y: y, on: seriesOut || anyBranchOut)
            }
            ForEach(Array(net.series.enumerated()), id: \.element.id) { ei, el in
                if isBox(el.kind) {
                    hWire(x1: colX(cols[ei]), x2: colX(cols[ei]) + 4, y: y, on: flows[ei])
                    hWire(x1: colX(cols[ei] + 2) - 4, x2: colX(cols[ei] + 2), y: y, on: flows[ei + 1])
                }
                cellView(ni: ni, ei: ei, el: el, branch: -1, isOutput: false,
                         colPt: colX(cols[ei]), rowTop: 0, rowH: rungH(net), cyLocal: y,
                         inOn: flows[ei], outOn: flows[ei + 1])
            }
            cellView(ni: ni, ei: -2, el: net.output, branch: -1, isOutput: true,
                     colPt: colX(outCol), rowTop: 0, rowH: rungH(net), cyLocal: y,
                     inOn: seriesOut || anyBranchOut, outOn: seriesOut || anyBranchOut)
            if !net.branches.isEmpty {
                let lastBy = branchYs[branchYs.count - 1]
                vWire(x: colX(0), y1: y, y2: lastBy, on: true)
                vWire(x: colX(outCol), y1: y, y2: lastBy, on: anyBranchOut)
                junctionDot(x: colX(0), y: y, on: true)
                junctionDot(x: colX(outCol), y: y, on: anyBranchOut)
                ForEach(Array(net.branches.enumerated()), id: \.offset) { bi, branch in
                    let by = branchYs[bi]
                    let bcols = branchCols(branch)
                    ForEach(Array(branch.enumerated()), id: \.element.id) { ei, el in
                        if isBox(el.kind) {
                            hWire(x1: colX(bcols[ei]), x2: colX(bcols[ei]) + 4, y: by, on: bFlows[bi][ei])
                            hWire(x1: colX(bcols[ei] + 2) - 4, x2: colX(bcols[ei] + 2), y: by, on: bFlows[bi][ei + 1])
                        }
                        cellView(ni: ni, ei: ei, el: el, branch: bi, isOutput: false,
                                 colPt: colX(bcols[ei]), rowTop: by - 28, rowH: 56, cyLocal: 28,
                                 inOn: bFlows[bi][ei], outOn: bFlows[bi][ei + 1])
                    }
                    if branchEnd(branch) < outCol {
                        hWire(x1: colX(branchEnd(branch)), x2: colX(outCol), y: by, on: bFlows[bi].last ?? false)
                    }
                }
            }
            if showDetail && insNet == ni && insBranch == nil {
                ForEach(0...net.series.count, id: \.self) { p in
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15 * z))
                        .foregroundColor(Tia.accent)
                        .position(x: colX(p < cols.count ? cols[p] : seriesEnd) * z, y: y * z)
                        .allowsHitTesting(false)
                }
            }
            if showDetail && insNet == ni, let ib = insBranch, net.branches.indices.contains(ib) {
                let branch = net.branches[ib]
                let bcols = branchCols(branch)
                ForEach(0...branch.count, id: \.self) { p in
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15 * z))
                        .foregroundColor(Tia.accent)
                        .position(x: colX(p < bcols.count ? bcols[p] : branchEnd(branch)) * z, y: branchYs[ib] * z)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: contentW * z, height: canvasH * z)
    }

    private func branchCols(_ branch: [LadElement]) -> [Int] {
        var out: [Int] = []
        var c = 0
        for el in branch { out.append(c); c += units(of: el) }
        return out
    }
    private func branchEnd(_ branch: [LadElement]) -> Int {
        branch.reduce(0) { $0 + units(of: $1) }
    }

    @ViewBuilder
    private func hWire(x1: CGFloat, x2: CGFloat, y: CGFloat, on: Bool) -> some View {
        if x2 > x1 + 0.5 {
            ZStack {
                if live && !on {
                    DashedLine().stroke(Tia.onlineFalse, lineWidth: 1.6 * z)
                } else {
                    Rectangle().fill(flowColor(on)).frame(height: 1.8 * z)
                }
            }
            .frame(width: (x2 - x1) * z, height: 6 * z)
            .offset(x: x1 * z, y: (y - 3) * z)
        }
    }

    private func vWire(x: CGFloat, y1: CGFloat, y2: CGFloat, on: Bool) -> some View {
        Rectangle().fill(flowColor(on))
            .frame(width: 1.8 * z, height: (y2 - y1) * z)
            .offset(x: (x - 0.9) * z, y: y1 * z)
    }

    private func junctionDot(x: CGFloat, y: CGFloat, on: Bool) -> some View {
        Circle().fill(flowColor(on))
            .frame(width: 5.5 * z, height: 5.5 * z)
            .offset(x: (x - 2.75) * z, y: (y - 2.75) * z)
    }

    // MARK: Elements

    @ViewBuilder
    private func cellView(ni: Int, ei: Int, el: LadElement, branch: Int, isOutput: Bool,
                          colPt: CGFloat, rowTop: CGFloat, rowH: CGFloat, cyLocal: CGFloat,
                          inOn: Bool, outOn: Bool) -> some View {
        let selected = selNet == ni && (isOutput
            ? (selBranch == nil && selPos == -2)
            : (branch == -1 ? (selBranch == nil && selPos == ei) : (selBranch == branch && selPos == ei)))
        let wdt = CGFloat(units(of: el)) * cellW
        ZStack(alignment: .topLeading) {
            if selected {
                RoundedRectangle(cornerRadius: 3).fill(Tia.selection)
                    .frame(width: wdt * z, height: rowH * z)
                RoundedRectangle(cornerRadius: 3).stroke(Tia.accent, lineWidth: 1)
                    .frame(width: wdt * z, height: rowH * z)
            }
            if isBox(el.kind) {
                boxCellContent(el, wdt: wdt, cy: cyLocal)
            } else if isOutput && (el.kind == .jmp || el.kind == .label || el.kind == .ret) {
                Text(el.kind == .ret ? "RET" : (el.kind == .jmp ? "JMP \(el.tag)" : "▸ \(el.tag)"))
                    .font(.system(size: 10.5 * z, weight: .bold, design: .monospaced))
                    .foregroundColor(Tia.textDark)
                    .padding(.horizontal, 5 * z).padding(.vertical, 3 * z)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.wire, lineWidth: 0.9))
                    .position(x: wdt / 2 * z, y: cyLocal * z)
            } else {
                Text(addressOf(el.tag))
                    .font(.system(size: 10.5 * z, weight: .bold, design: .monospaced))
                    .foregroundColor(Tia.labelTeal)
                    .position(x: wdt / 2 * z, y: (cyLocal - 17) * z)
                LadGlyph(kind: el.kind, colorIn: flowColor(inOn), colorOut: flowColor(outOn), scale: z)
                    .frame(width: wdt * z, height: 30 * z)
                    .position(x: wdt / 2 * z, y: cyLocal * z)
                Text(el.tag.isEmpty ? "\"???\"" : "\"\(el.tag)\"")
                    .font(.system(size: 10 * z))
                    .foregroundColor(Tia.nameGrey)
                    .position(x: wdt / 2 * z, y: (cyLocal + 23) * z)
            }
        }
        .frame(width: wdt * z, height: rowH * z)
        .offset(x: colPt * z, y: rowTop * z)
        .contentShape(Rectangle())
        // ONE tap recognizer + ONE long-press (tag picker). The previous
        // stack (double-tap + tap + long-press on every cell, inside a
        // scroll view with a pinch gesture) delayed or swallowed taps
        // and left elements stuck — the TIA editor selects with a
        // single click, and so does this.
        .onTapGesture {
            selNet = ni
            if isOutput {
                selBranch = nil; selPos = -2
                insNet = ni; insPos = block.networks[ni].series.count; insBranch = nil
            } else if branch >= 0 {
                selBranch = branch; selPos = ei
                insNet = ni; insPos = ei + 1; insBranch = branch
            } else {
                selBranch = nil; selPos = ei
                insNet = ni; insPos = ei + 1; insBranch = nil
            }
        }
        .onLongPressGesture {
            selNet = ni
            if isOutput { selBranch = nil; selPos = -2 }
            else if branch >= 0 { selBranch = branch; selPos = ei }
            else { selBranch = nil; selPos = ei }
            tagPickerFor = TagTarget(net: ni, pos: isOutput ? -2 : ei, branch: branch, field: "tag")
        }
    }

    private func boxHeight(_ kind: LadElementKind) -> CGFloat {
        switch kind {
        case .ctud: return 66
        case .sr, .rs, .cmp, .move: return 40
        default: return 53
        }
    }

    private func boxCellContent(_ el: LadElement, wdt: CGFloat, cy: CGFloat) -> some View {
        let bw = wdt - 8
        let bh = boxHeight(el.kind)
        return ZStack(alignment: .topLeading) {
            Text(el.instance.isEmpty ? "???" : el.instance)
                .font(.system(size: 9.5 * z)).foregroundColor(.secondary)
                .position(x: wdt / 2 * z, y: (cy - bh / 2 - 7) * z)
            boxBody(el)
                .frame(width: bw * z, height: bh * z)
                .position(x: wdt / 2 * z, y: cy * z)
        }
    }

    private func boxRow(_ l: String, _ r: String, bold: Bool = false, green: Bool = false) -> some View {
        HStack {
            Text(l).font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
            Spacer()
            Text(r).font(.system(size: 9.5 * z, weight: bold ? .bold : .semibold, design: .monospaced))
                .foregroundColor(green && live ? Tia.onlineTrue : Tia.textDark)
                .lineLimit(1)
        }
        .padding(.horizontal, 4 * z)
        .frame(height: 13 * z)
    }

    private func fmtNum(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 100000 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func boxBody(_ el: LadElement) -> some View {
        VStack(spacing: 0) {
            Text(kindName(el.kind))
                .font(.system(size: 10.5 * z, weight: .bold)).foregroundColor(Tia.textDark)
                .frame(maxWidth: .infinity)
                .frame(height: 14 * z)
                .background(Tia.boxHeader)
            switch el.kind {
            case .ton, .tof, .tp, .tonr:
                HStack {
                    Text("IN").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text("Q").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Circle()
                        .fill((sim.values[el.tag] ?? false) && live ? Tia.onlineTrue : Color.gray.opacity(0.4))
                        .frame(width: 7 * z, height: 7 * z)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
                boxRow("PT", el.preset)
                HStack {
                    Text("ET").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text(String(format: "%.1fs", sim.timerET[el.instance] ?? 0))
                        .font(.system(size: 9.5 * z, weight: .semibold, design: .monospaced))
                        .foregroundColor(live ? Tia.onlineTrue : Tia.textDark)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
            case .ctu, .ctd:
                HStack {
                    Text(el.kind == .ctu ? "CU" : "CD").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text("Q").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Circle()
                        .fill((sim.values[el.tag] ?? false) && live ? Tia.onlineTrue : Color.gray.opacity(0.4))
                        .frame(width: 7 * z, height: 7 * z)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
                boxRow("PV", el.preset)
                boxRow("CV", "\(sim.counts[el.instance] ?? 0)", bold: true, green: true)
            case .ctud:
                boxRow("CU", "↑")
                boxRow("CD", el.inputTag.isEmpty ? "—" : el.inputTag)
                boxRow("PV", el.preset)
                boxRow("CV", "\(sim.counts[el.instance] ?? 0)", bold: true, green: true)
            case .sr, .rs:
                HStack {
                    Text("S").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text("Q").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Circle()
                        .fill((sim.values[el.tag] ?? false) && live ? Tia.onlineTrue : Color.gray.opacity(0.4))
                        .frame(width: 7 * z, height: 7 * z)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
                boxRow("R", el.inputTag.isEmpty ? "—" : el.inputTag)
            case .cmp:
                boxRow(shortName(el.tag), fmtNum(sim.num(el.tag)), green: true)
                boxRow(el.op.isEmpty ? "GT" : el.op, el.useConst ? fmtNum(el.constValue) : "\(shortName(el.inputTag)) \(fmtNum(sim.num(el.inputTag)))", green: true)
            case .math:
                boxRow(shortName(el.tag), fmtNum(sim.num(el.tag)), green: true)
                boxRow(el.useConst ? fmtNum(el.constValue) : shortName(el.inputTag),
                       el.useConst ? "" : fmtNum(sim.num(el.inputTag)), green: true)
                boxRow("→ \(shortName(el.outTag))", fmtNum(sim.num(el.outTag)), bold: true, green: true)
            case .move:
                boxRow(shortName(el.tag), fmtNum(sim.num(el.tag)), green: true)
                boxRow("→ \(shortName(el.outTag))", fmtNum(sim.num(el.outTag)), bold: true, green: true)
            case .pid:
                boxRow("SP \(shortName(el.tag))", fmtNum(sim.num(el.tag)), green: true)
                boxRow("PV \(shortName(el.inputTag))", fmtNum(sim.num(el.inputTag)), green: true)
                boxRow("OUT \(shortName(el.outTag))", fmtNum(sim.num(el.outTag)) + " %", bold: true, green: true)
            default:
                EmptyView()
            }
        }
        .background(Tia.boxFillV3)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.wire, lineWidth: 0.9))
    }

    private func shortName(_ s: String) -> String {
        s.count <= 10 ? s : String(s.prefix(9)) + "…"
    }

    // MARK: Floating action strip (selection)

    private var selIsBox: Bool {
        guard let el = selectedElement else { return false }
        return isBox(el.kind)
    }

    private var selectedElement: LadElement? {
        guard let ni = selNet, block.networks.indices.contains(ni) else { return nil }
        let net = block.networks[ni]
        if selPos == -2 { return net.output }
        if let b = selBranch {
            return net.branches.indices.contains(b) && net.branches[b].indices.contains(selPos) ? net.branches[b][selPos] : nil
        }
        return net.series.indices.contains(selPos) ? net.series[selPos] : nil
    }

    private var actionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                stripButton("Toggle", "arrow.triangle.2.circlepath") {
                    if let ni = selNet { toggleKind(ni, selPos, branch: selBranch ?? -1) }
                }
                stripButton("Tag", "tag") {
                    if let ni = selNet {
                        tagPickerFor = TagTarget(net: ni, pos: selPos, branch: selBranch ?? -1, field: "tag")
                    }
                }
                if selIsBox {
                    stripButton("IN2 / R", "arrow.right.to.line") {
                        if let ni = selNet {
                            tagPickerFor = TagTarget(net: ni, pos: selPos, branch: selBranch ?? -1, field: "inputTag")
                        }
                    }
                    stripButton("OUT", "arrow.up.forward.square") {
                        if let ni = selNet {
                            tagPickerFor = TagTarget(net: ni, pos: selPos, branch: selBranch ?? -1, field: "outTag")
                        }
                    }
                    stripButton("Params", "slider.horizontal.3") {
                        if let ni = selNet {
                            paramsFor = TagTarget(net: ni, pos: selPos, branch: selBranch ?? -1, field: "")
                        }
                    }
                }
                stripButton("Branch", "arrow.branch") { addBranch() }
                stripButton("Delete", "trash") { deleteSelected() }
            }
            .padding(4)
        }
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
            .frame(width: 52, height: 32)
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

    // MARK: Params sheet (box operands & constants)

    private func elAt(_ t: TagTarget) -> LadElement? {
        guard block.networks.indices.contains(t.net) else { return nil }
        let net = block.networks[t.net]
        if t.pos == -2 { return net.output }
        if t.branch >= 0 {
            return net.branches.indices.contains(t.branch) && net.branches[t.branch].indices.contains(t.pos)
                ? net.branches[t.branch][t.pos] : nil
        }
        return net.series.indices.contains(t.pos) ? net.series[t.pos] : nil
    }

    private func mutateEl(_ t: TagTarget, _ change: (inout LadElement) -> Void) {
        updateBlock { b in
            guard b.networks.indices.contains(t.net) else { return }
            if t.pos == -2 { change(&b.networks[t.net].output) }
            else if t.branch >= 0 {
                if b.networks[t.net].branches.indices.contains(t.branch),
                   b.networks[t.net].branches[t.branch].indices.contains(t.pos) {
                    change(&b.networks[t.net].branches[t.branch][t.pos])
                }
            } else if b.networks[t.net].series.indices.contains(t.pos) {
                change(&b.networks[t.net].series[t.pos])
            }
        }
    }

    private func paramsSheet(_ target: TagTarget) -> some View {
        let el = elAt(target) ?? LadElement()
        return NavigationView {
            Form {
                Section(header: Text(kindName(el.kind))) {
                    if el.kind == .cmp || el.kind == .math {
                        Picker("Operation", selection: Binding(
                            get: { el.op.isEmpty ? (el.kind == .cmp ? "GT" : "ADD") : el.op },
                            set: { v in mutateEl(target) { $0.op = v } }
                        )) {
                            ForEach(el.kind == .cmp ? ["EQ", "NE", "GT", "GE", "LT", "LE"] : ["ADD", "SUB", "MUL", "DIV", "SHL", "SHR"], id: \.self) { Text($0) }
                        }
                        Toggle("IN2 is a constant", isOn: Binding(
                            get: { el.useConst },
                            set: { v in mutateEl(target) { $0.useConst = v } }
                        ))
                        if el.useConst {
                            Stepper("Constant: \(fmtNum(el.constValue))", value: Binding(
                                get: { el.constValue },
                                set: { v in mutateEl(target) { $0.constValue = v } }
                            ), step: 1)
                        }
                    }
                    if isTimer(el.kind) {
                        Stepper("PT: \(String(format: "%.1f", el.presetSeconds)) s", value: Binding(
                            get: { el.presetSeconds },
                            set: { v in mutateEl(target) { $0.presetSeconds = v; $0.preset = "T#\(fmtNum(v))s" } }
                        ), in: 0.5...600, step: 0.5)
                    }
                    if isCounter(el.kind) {
                        Stepper("PV: \(el.presetValue)", value: Binding(
                            get: { el.presetValue },
                            set: { v in mutateEl(target) { $0.presetValue = v; $0.preset = "\(v)" } }
                        ), in: 1...999)
                    }
                    if el.kind == .pid {
                        Stepper("Kp (gain): \(String(format: "%.1f", el.kp))", value: Binding(
                            get: { el.kp }, set: { v in mutateEl(target) { $0.kp = v } }
                        ), in: 0...50, step: 0.1)
                        Stepper("Ti (integral): \(String(format: "%.1f", el.ti)) s", value: Binding(
                            get: { el.ti }, set: { v in mutateEl(target) { $0.ti = v } }
                        ), in: 0...300, step: 0.5)
                        Stepper("Td (derivative): \(String(format: "%.1f", el.td)) s", value: Binding(
                            get: { el.td }, set: { v in mutateEl(target) { $0.td = v } }
                        ), in: 0...60, step: 0.1)
                    }
                    if !el.instance.isEmpty || isBox(el.kind) {
                        HStack {
                            Text("Instance").foregroundColor(.secondary)
                            Spacer()
                            Text(el.instance).font(.system(.body, design: .monospaced))
                        }
                    }
                }
                Section {
                    Button("Done") { paramsFor = nil }
                }
            }
            .navigationTitle("Instruction parameters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Editing operations

    private func updateBlock(_ change: (inout PlcBlock) -> Void) {
        guard device.blocks.indices.contains(blockIndex) else { return }
        undoStack.append(block)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack = []
        var b = device.blocks[blockIndex]
        change(&b)
        for i in b.networks.indices { b.networks[i].syncParallel() }
        device.blocks[blockIndex] = b
    }

    private func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(block)
        device.blocks[blockIndex] = prev
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(block)
        device.blocks[blockIndex] = next
    }

    private func insert(_ kind: LadElementKind) {
        let ni = insNet ?? selNet ?? (block.networks.count - 1)
        guard block.networks.indices.contains(ni) else { return }
        var el = LadElement(kind: kind)
        let num1 = numericTags.first?.name ?? ""
        let num2 = numericTags.dropFirst().first?.name ?? num1
        let num3 = numericTags.dropFirst(2).first?.name ?? num2
        switch kind {
        case .ton, .tof, .tp:
            el.instance = "\(kindName(kind))_\(ni + 1)"
        case .tonr:
            el.instance = "TONR_\(ni + 1)"; el.preset = "T#10s"; el.presetSeconds = 10
        case .ctu, .ctd, .ctud:
            el.instance = "\(kindName(kind))_\(ni + 1)"; el.preset = "5"; el.presetValue = 5
        case .sr:
            el.instance = "SR_\(ni + 1)"
        case .rs:
            el.instance = "RS_\(ni + 1)"
        case .cmp:
            el.op = "GT"; el.tag = num1; el.useConst = true; el.constValue = 10
        case .math:
            el.op = "ADD"; el.tag = num1; el.inputTag = num2; el.outTag = num2
        case .move:
            el.tag = num1; el.outTag = num2
        case .pid:
            el.instance = "PID_\(ni + 1)"; el.tag = num1; el.inputTag = num2; el.outTag = num3
        case .jmp, .label:
            el.tag = "LBL1"
        default:
            break
        }
        if kind == .coil || kind == .coilSet || kind == .coilReset || kind == .jmp || kind == .label || kind == .ret {
            // coils and program-control elements live in the output slot, like TIA
            updateBlock { $0.networks[ni].output = el }
            selNet = ni; selPos = -2; selBranch = nil
            return
        }
        if let ib = insBranch, insNet == ni, block.networks[ni].branches.indices.contains(ib) {
            let pos = min(insPos, block.networks[ni].branches[ib].count)
            updateBlock { $0.networks[ni].branches[ib].insert(el, at: pos) }
            selNet = ni; selBranch = ib; selPos = pos
            insPos = pos + 1
            return
        }
        let pos = min(insPos, block.networks[ni].series.count)
        updateBlock { $0.networks[ni].series.insert(el, at: pos) }
        selNet = ni; selPos = pos; selBranch = nil
        insPos = pos + 1
    }

    private func toggleKind(_ ni: Int, _ pos: Int, branch: Int) {
        let target = TagTarget(net: ni, pos: pos, branch: branch, field: "")
        mutateEl(target) { el in
            switch el.kind {
            case .contactNO: el.kind = .contactNC
            case .contactNC: el.kind = .contactNO
            case .pTrig: el.kind = .nTrig
            case .nTrig: el.kind = .pTrig
            case .coil: el.kind = .coilSet
            case .coilSet: el.kind = .coilReset
            case .coilReset: el.kind = .coil
            case .sr: el.kind = .rs
            case .rs: el.kind = .sr
            case .cmp:
                let ops = ["EQ", "NE", "GT", "GE", "LT", "LE"]
                let i = ops.firstIndex(of: el.op) ?? 2
                el.op = ops[(i + 1) % ops.count]
            case .math:
                let ops = ["ADD", "SUB", "MUL", "DIV", "SHL", "SHR"]
                let i = ops.firstIndex(of: el.op) ?? 0
                el.op = ops[(i + 1) % ops.count]
            default: break
            }
        }
    }

    private func deleteSelected() {
        guard let ni = selNet else { return }
        if let b = selBranch {
            updateBlock {
                if $0.networks[ni].branches.indices.contains(b), $0.networks[ni].branches[b].indices.contains(selPos) {
                    $0.networks[ni].branches[b].remove(at: selPos)
                    if $0.networks[ni].branches[b].isEmpty { $0.networks[ni].branches.remove(at: b) }
                }
            }
            selBranch = nil; selPos = -1
        } else if selPos >= 0 {
            updateBlock { if $0.networks[ni].series.indices.contains(selPos) { $0.networks[ni].series.remove(at: selPos) } }
            selPos = -1
        }
    }

    private func deleteNetwork(_ ni: Int) {
        updateBlock { if $0.networks.indices.contains(ni) { $0.networks.remove(at: ni) } }
        selNet = nil; selPos = -1; selBranch = nil
    }

    private func duplicateNetwork(_ ni: Int) {
        guard block.networks.indices.contains(ni) else { return }
        var copy = block.networks[ni]
        copy.id = UUID()
        copy.title = copy.title + " (copy)"
        copy.series = copy.series.map { var e = $0; e.id = UUID(); return e }
        copy.branches = copy.branches.map { br in br.map { var e = $0; e.id = UUID(); return e } }
        var out = copy.output; out.id = UUID(); copy.output = out
        updateBlock { $0.networks.insert(copy, at: ni + 1) }
    }

    private func addBranch() {
        guard let ni = selNet else { return }
        updateBlock { $0.networks[ni].branches.append([LadElement(kind: .contactNO)]) }
    }

    private func assignTag(_ target: TagTarget, _ name: String) {
        mutateEl(target) { el in
            switch target.field {
            case "inputTag": el.inputTag = name
            case "outTag": el.outTag = name
            default: el.tag = name
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
        if tag.contains(".") { return tag }   // data-block operand
        return device.tags.first { $0.name == tag }?.address ?? "%??"
    }

    private func isBox(_ k: LadElementKind) -> Bool {
        isTimer(k) || isCounter(k) || k == .sr || k == .rs || k == .cmp || k == .math || k == .move || k == .pid
    }
    private func isTimer(_ k: LadElementKind) -> Bool { k == .ton || k == .tof || k == .tp || k == .tonr }
    private func isCounter(_ k: LadElementKind) -> Bool { k == .ctu || k == .ctd || k == .ctud }
    private func kindName(_ k: LadElementKind) -> String {
        switch k {
        case .ton: return "TON"
        case .tof: return "TOF"
        case .tp: return "TP"
        case .tonr: return "TONR"
        case .ctu: return "CTU"
        case .ctd: return "CTD"
        case .ctud: return "CTUD"
        case .sr: return "SR"
        case .rs: return "RS"
        case .cmp: return "CMP"
        case .math: return "MATH"
        case .move: return "MOVE"
        case .pid: return "PID"
        default: return ""
        }
    }

    private func cmpLocal(_ el: LadElement) -> Bool {
        let a = sim.num(el.tag)
        let b = el.useConst ? el.constValue : sim.num(el.inputTag)
        switch el.op {
        case "EQ": return abs(a - b) < 0.0001
        case "NE": return abs(a - b) >= 0.0001
        case "GE": return a >= b
        case "LT": return a < b
        case "LE": return a <= b
        default: return a > b
        }
    }

    /// Prefix power flow through a rung (series or one branch), for the
    /// online wire colours. Mirrors the simulator's semantics.
    private func flowFor(_ elements: [LadElement]) -> [Bool] {
        guard live else { return Array(repeating: true, count: elements.count + 1) }
        var states: [Bool] = []
        var power = true
        for el in elements {
            states.append(power)
            switch el.kind {
            case .notOp: power = !power
            case .contactNC: power = power && !(sim.values[el.tag] ?? false)
            case .cmp: power = power && cmpLocal(el)
            case .ctu: power = power && (sim.counts[el.instance] ?? 0) >= el.presetValue
            case .ctd: power = power && (sim.counts[el.instance] ?? el.presetValue) <= 0
            case .ctud: power = power && (sim.counts[el.instance] ?? 0) >= el.presetValue
            case .math, .move, .pid, .jmp, .label, .ret: break   // power passes through
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
    var colorIn: Color
    var colorOut: Color
    var scale: CGFloat = 1

    private func stubEnds(_ w: CGFloat) -> (CGFloat, CGFloat) {
        switch kind {
        case .coil, .coilSet, .coilReset: return (w * 0.25, w * 0.75)
        case .notOp: return (w * 0.19, w * 0.81)
        default: return (w * 0.36, w * 0.64)
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height, mid = h / 2
            let lw: CGFloat = 1.8 * scale
            // Stub ends: the wire runs from each cell edge to the symbol
            // edge exactly — the symbol never bridges its own gap.
            let (a, b) = stubEnds(w)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: mid)); p.addLine(to: CGPoint(x: a, y: mid))
                }.stroke(colorIn, lineWidth: lw)
                Path { p in
                    p.move(to: CGPoint(x: b, y: mid)); p.addLine(to: CGPoint(x: w, y: mid))
                }.stroke(colorOut, lineWidth: lw)
                switch kind {
                case .contactNO, .pTrig, .nTrig:
                    Path { p in
                        p.move(to: CGPoint(x: a, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: a, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: b, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: b, y: mid + h * 0.34))
                    }.stroke(colorOut, lineWidth: lw)
                    if kind != .contactNO {
                        Text(kind == .pTrig ? "P" : "N")
                            .font(.system(size: 11 * scale, weight: .bold))
                            .foregroundColor(Tia.textDark)
                            .position(x: w * 0.5, y: mid)
                    }
                case .contactNC:
                    Path { p in
                        p.move(to: CGPoint(x: a, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: a, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: b, y: mid - h * 0.34)); p.addLine(to: CGPoint(x: b, y: mid + h * 0.34))
                        p.move(to: CGPoint(x: w * 0.24, y: mid + h * 0.30)); p.addLine(to: CGPoint(x: w * 0.76, y: mid - h * 0.30))
                    }.stroke(colorOut, lineWidth: lw)
                case .coil, .coilSet, .coilReset:
                    Path { p in
                        p.addArc(center: CGPoint(x: w * 0.42, y: mid), radius: w * 0.17, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                        p.addArc(center: CGPoint(x: w * 0.58, y: mid), radius: w * 0.17, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                    }.stroke(colorOut, lineWidth: lw)
                    if kind != .coil {
                        Text(kind == .coilSet ? "S" : "R")
                            .font(.system(size: 10 * scale, weight: .bold))
                            .foregroundColor(Tia.textDark)
                            .position(x: w * 0.5, y: mid)
                    }
                case .notOp:
                    RoundedRectangle(cornerRadius: 2).stroke(colorOut, lineWidth: lw)
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
    var extra: [String] = []        // data-block operands ("DB.Row")
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
                if !extra.isEmpty {
                    Section(header: Text("Data blocks")) {
                        ForEach(extra.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { name in
                            Button {
                                onPick(name)
                            } label: {
                                HStack {
                                    Image(systemName: "cylinder.split.1x2").font(.system(size: 11)).foregroundColor(Tia.labelTeal)
                                    Text(name).font(.system(size: 13)).foregroundColor(Tia.textDark)
                                    Spacer()
                                }
                            }
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
