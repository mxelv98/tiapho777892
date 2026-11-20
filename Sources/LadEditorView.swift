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
    @State private var insParallel = false       // insertion targets the parallel branch
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

    // MARK: Network rendering — strict grid geometry (Part 2)
    //
    // One fixed grid for every network: a thick left rail, then a wire
    // stub of exactly one cell width, then elements in consecutive
    // cells. Every element's input and output sit on the same
    // centerline; wires are horizontal or vertical only and run glyph
    // edge to glyph edge. The output element always lands in the same
    // right-hand column (blockUnits). Labels are positioned around the
    // glyph and never move the centerline.

    private let cellW: CGFloat = 64
    private let railW: CGFloat = 9

    private func units(of el: LadElement) -> Int { isBox(el.kind) ? 2 : 1 }
    private func netUnits(_ net: LadNetwork) -> Int {
        net.series.reduce(0) { $0 + units(of: $1) } + units(of: net.output)
    }
    private var blockUnits: Int { max(1, block.networks.map(netUnits).max() ?? 1) }
    private func colX(_ col: Int) -> CGFloat { railW + cellW + CGFloat(col) * cellW }
    private var contentW: CGFloat { max(colX(blockUnits) + 14, 330) }
    private func netHasBox(_ net: LadNetwork) -> Bool {
        (net.series + net.parallel + [net.output]).contains { isBox($0.kind) }
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
        let hasPar = !net.parallel.isEmpty
        let by = y + 56
        let canvasH = rungH(net) + (hasPar ? 56 : 0)
        let flows = flowStates(net)
        let bFlows = branchFlowStates(net)
        let seriesOut = flows.last ?? true
        let branchOut = hasPar ? (bFlows.last ?? false) : false
        let outCol = blockUnits - units(of: net.output)
        var cols: [Int] = []
        var c = 0
        for el in net.series { cols.append(c); c += units(of: el) }
        let seriesEnd = c
        var bcols: [Int] = []
        var bc = 0
        for el in net.parallel { bcols.append(bc); bc += units(of: el) }
        let branchEnd = bc
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
                hWire(x1: colX(outCol), x2: colX(outCol) + 4, y: y, on: seriesOut || branchOut)
            }
            ForEach(Array(net.series.enumerated()), id: \.element.id) { ei, el in
                if isBox(el.kind) {
                    hWire(x1: colX(cols[ei]), x2: colX(cols[ei]) + 4, y: y, on: flows[ei])
                    hWire(x1: colX(cols[ei] + 2) - 4, x2: colX(cols[ei] + 2), y: y, on: flows[ei + 1])
                }
                cellView(ni: ni, ei: ei, el: el, parallel: false, isOutput: false,
                         colPt: colX(cols[ei]), rowTop: 0, rowH: rungH(net), cyLocal: y,
                         inOn: flows[ei], outOn: flows[ei + 1])
            }
            cellView(ni: ni, ei: -2, el: net.output, parallel: false, isOutput: true,
                     colPt: colX(outCol), rowTop: 0, rowH: rungH(net), cyLocal: y,
                     inOn: seriesOut || branchOut, outOn: seriesOut || branchOut)
            if hasPar {
                vWire(x: colX(0), y1: y, y2: by, on: true)
                vWire(x: colX(outCol), y1: y, y2: by, on: branchOut)
                junctionDot(x: colX(0), y: y, on: true)
                junctionDot(x: colX(outCol), y: y, on: branchOut)
                if branchEnd < outCol {
                    hWire(x1: colX(branchEnd), x2: colX(outCol), y: by, on: branchOut)
                }
                ForEach(Array(net.parallel.enumerated()), id: \.element.id) { ei, el in
                    if isBox(el.kind) {
                        hWire(x1: colX(bcols[ei]), x2: colX(bcols[ei]) + 4, y: by, on: bFlows[ei])
                        hWire(x1: colX(bcols[ei] + 2) - 4, x2: colX(bcols[ei] + 2), y: by, on: bFlows[ei + 1])
                    }
                    cellView(ni: ni, ei: ei, el: el, parallel: true, isOutput: false,
                             colPt: colX(bcols[ei]), rowTop: by - 28, rowH: 56, cyLocal: 28,
                             inOn: bFlows[ei], outOn: bFlows[ei + 1])
                }
            }
            if showDetail && insNet == ni && !insParallel {
                ForEach(0...net.series.count, id: \.self) { p in
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15 * z))
                        .foregroundColor(Tia.accent)
                        .position(x: colX(p < cols.count ? cols[p] : seriesEnd) * z, y: y * z)
                        .allowsHitTesting(false)
                }
            }
            if showDetail && insNet == ni && insParallel && hasPar {
                ForEach(0...net.parallel.count, id: \.self) { p in
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15 * z))
                        .foregroundColor(Tia.accent)
                        .position(x: colX(p < bcols.count ? bcols[p] : branchEnd) * z, y: by * z)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: contentW * z, height: canvasH * z)
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
    private func cellView(ni: Int, ei: Int, el: LadElement, parallel: Bool, isOutput: Bool,
                          colPt: CGFloat, rowTop: CGFloat, rowH: CGFloat, cyLocal: CGFloat,
                          inOn: Bool, outOn: Bool) -> some View {
        let selected = selNet == ni && (isOutput
            ? (selParallel == nil && selPos == -2)
            : (parallel ? selParallel == ei : (selParallel == nil && selPos == ei)))
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
                selParallel = nil; selPos = -2
                insNet = ni; insPos = block.networks[ni].series.count; insParallel = false
            } else if parallel {
                selParallel = ei; selPos = -1
                insNet = ni; insPos = ei + 1; insParallel = true
            } else {
                selParallel = nil; selPos = ei
                insNet = ni; insPos = ei + 1; insParallel = false
            }
        }
        .onLongPressGesture {
            selNet = ni
            if isOutput { selParallel = nil; selPos = -2 }
            else if parallel { selParallel = ei; selPos = -1 }
            else { selParallel = nil; selPos = ei }
            tagPickerFor = TagTarget(net: ni, pos: isOutput ? -2 : ei, parallel: parallel)
        }
    }

    private func boxCellContent(_ el: LadElement, wdt: CGFloat, cy: CGFloat) -> some View {
        let bw = wdt - 8
        let bh: CGFloat = 53
        return ZStack(alignment: .topLeading) {
            Text(el.instance.isEmpty ? "???" : el.instance)
                .font(.system(size: 9.5 * z)).foregroundColor(.secondary)
                .position(x: wdt / 2 * z, y: (cy - bh / 2 - 7) * z)
            boxBody(el)
                .frame(width: bw * z, height: bh * z)
                .position(x: wdt / 2 * z, y: cy * z)
        }
    }

    private func boxBody(_ el: LadElement) -> some View {
        VStack(spacing: 0) {
            Text(kindName(el.kind))
                .font(.system(size: 10.5 * z, weight: .bold)).foregroundColor(Tia.textDark)
                .frame(maxWidth: .infinity)
                .frame(height: 14 * z)
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
            .frame(height: 13 * z)
            HStack {
                Text(isTimer(el.kind) ? "PT" : "PV").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                Spacer()
                Text(el.preset).font(.system(size: 9.5 * z, weight: .semibold, design: .monospaced)).foregroundColor(Tia.textDark)
            }
            .padding(.horizontal, 4 * z)
            .frame(height: 13 * z)
            if isTimer(el.kind) {
                HStack {
                    Text("ET").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text(String(format: "%.1fs", sim.timerET[el.instance] ?? 0))
                        .font(.system(size: 9.5 * z, weight: .semibold, design: .monospaced))
                        .foregroundColor(live ? Tia.onlineTrue : Tia.textDark)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
            }
            if isCounter(el.kind) {
                HStack {
                    Text("CV").font(.system(size: 9.5 * z)).foregroundColor(Tia.textDark)
                    Spacer()
                    Text("\(sim.counts[el.instance] ?? 0)")
                        .font(.system(size: 9.5 * z, weight: .bold, design: .monospaced))
                        .foregroundColor(live ? Tia.onlineTrue : Tia.textDark)
                }
                .padding(.horizontal, 4 * z)
                .frame(height: 13 * z)
            }
        }
        .background(Tia.boxFillV3)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.wire, lineWidth: 0.9))
    }

    // MARK: Floating action strip (selection)

    private var actionStrip: some View {
        HStack(spacing: 4) {
            stripButton("Toggle", "arrow.triangle.2.circlepath") {
                if let ni = selNet { toggleKind(ni, selParallel ?? selPos, parallel: selParallel != nil) }
            }
            stripButton("Tag", "tag") {
                if let ni = selNet {
                    tagPickerFor = TagTarget(net: ni, pos: selParallel ?? selPos, parallel: selParallel != nil)
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
        if insParallel && insNet == ni {
            // insertion into the parallel branch, after the tapped element
            let pos = min(insPos, block.networks[ni].parallel.count)
            updateBlock { $0.networks[ni].parallel.insert(el, at: pos) }
            selNet = ni; selParallel = pos; selPos = -1
            insPos = pos + 1
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

    /// Prefix power flow through the parallel branch, same rule as the
    /// series rung (the branch is fed from the left junction).
    private func branchFlowStates(_ net: LadNetwork) -> [Bool] {
        guard live else { return Array(repeating: true, count: net.parallel.count + 1) }
        var states: [Bool] = []
        var power = true
        for el in net.parallel {
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
