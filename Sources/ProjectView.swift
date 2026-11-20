import SwiftUI

enum EditorTab: Equatable {
    case deviceConfig
    case tagTable
    case block(String)   // block name
}

enum TreeNode: Equatable {
    case deviceConfig, tagTable, block(String), root
}

/// The Project view — TIA Portal's four regions on one screen:
/// project tree (left), tabbed editors (center), task cards (right),
/// inspector window (bottom), menu + toolbar on top, status bar below.
struct ProjectView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var tab: EditorTab = .deviceConfig
    @State private var node: TreeNode = .deviceConfig
    @State private var diagnostics: [Diagnostic] = []
    @State private var compileSummary: String? = nil
    @State private var inspectorTab = "Properties"
    @State private var online = false
    @State private var showSim = false
    @State private var selectedNetwork = 0
    @StateObject private var sim = Simulator()

    private var project: TiaProject { store.project! }
    private var device: PlcDevice { project.devices[0] }

    var body: some View {
        VStack(spacing: 0) {
            menuBar
            toolbar
            HStack(spacing: 0) {
                treePane.frame(width: 218)
                VStack(spacing: 0) {
                    tabBar
                    editorArea
                }
                .frame(maxWidth: .infinity)
                taskCards.frame(width: 224)
            }
            .frame(maxHeight: .infinity)
            inspector
            statusBar
        }
        .background(Tia.pane)
        .sheet(isPresented: $showSim) {
            SimPanelView(device: device).environmentObject(sim)
        }
        .onAppear { sim.attach(device) }
    }

    // MARK: menu + toolbar

    private var menuBar: some View {
        HStack(spacing: 14) {
            ForEach(["Project", "Edit", "View", "Insert", "Online", "Options", "Tools", "Window", "Help"], id: \.self) {
                Text($0).font(.system(size: 11.5))
            }
            Spacer()
            Text("\(project.name) — TIA Portal V16").font(.system(size: 11.5, weight: .semibold))
            Spacer()
            Button("Close project") { store.close() }.font(.system(size: 11.5))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(online ? Tia.online : Tia.titleBar)
        .foregroundColor(.white)
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            ToolbarGlyph(system: "doc.badge.plus", label: "New") { store.close() }
            ToolbarGlyph(system: "folder", label: "Open") { store.close() }
            ToolbarGlyph(system: "square.and.arrow.down", label: "Save") { store.save(project) }
            Divider().frame(height: 26)
            ToolbarGlyph(system: "checkmark.square", label: "Compile") { compile() }
            ToolbarGlyph(system: "arrow.down.to.line", label: "Download") { download() }
            Divider().frame(height: 26)
            ToolbarGlyph(system: online ? "wifi" : "wifi.slash", label: online ? "Offline" : "Online", active: online) { online.toggle() }
            ToolbarGlyph(system: "play.rectangle", label: "Simulation") { showSim = true }
            if let url = store.exportURL(project) {
                ShareLink(item: url) {
                    VStack(spacing: 1) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 15))
                        Text("Export").font(.system(size: 8.5)).lineLimit(1)
                    }
                    .frame(width: 52, height: 34)
                }
                .buttonStyle(.plain).foregroundColor(.primary)
            }
            Spacer()
            if let s = compileSummary {
                Text(s).font(.system(size: 10.5)).foregroundColor(diagnostics.contains { $0.isError } ? Tia.errorRed : .secondary)
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    // MARK: project tree

    private var treePane: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Project tree")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    treeRow(icon: "folder.fill", text: project.name, level: 0, sel: node == .root) { node = .root }
                    treeRow(icon: "cpu", text: "\(device.name) [\(device.cpuName)]", level: 1, sel: false) {}
                    treeRow(icon: "slider.horizontal.3", text: "Device configuration", level: 2, sel: node == .deviceConfig) {
                        node = .deviceConfig; tab = .deviceConfig
                    }
                    treeRow(icon: "curlybraces", text: "Program blocks", level: 2, sel: false) {}
                    ForEach(device.blocks) { b in
                        treeRow(icon: "square.stack.3d.up", text: "\(b.name) [\(b.type)\(b.number)]", level: 3, sel: node == .block(b.name)) {
                            node = .block(b.name); tab = .block(b.name)
                        }
                    }
                    treeRow(icon: "tag", text: "PLC tags", level: 2, sel: false) {}
                    treeRow(icon: "tablecells", text: "Default tag table [\(device.tags.count)]", level: 3, sel: node == .tagTable) {
                        node = .tagTable; tab = .tagTable
                    }
                    treeRow(icon: "eye", text: "Watch and force tables", level: 2, sel: false) {}
                    treeRow(icon: "antenna.radiowaves.left.and.right", text: "Online access", level: 1, sel: false) {}
                }
                .padding(.vertical, 4)
            }
        }
        .background(Tia.pane)
    }

    private func treeRow(icon: String, text: String, level: Int, sel: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10.5)).foregroundColor(Tia.accent).frame(width: 14)
                Text(text).font(.system(size: 11.5)).lineLimit(1)
                Spacer()
            }
            .padding(.leading, CGFloat(6 + level * 13)).padding(.trailing, 4).padding(.vertical, 2.5)
            .background(sel ? Tia.selection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: editors

    private var tabBar: some View {
        HStack(spacing: 2) {
            editorTabChip("Device configuration", .deviceConfig)
            editorTabChip("Default tag table", .tagTable)
            ForEach(device.blocks) { b in editorTabChip("\(b.name) (\(b.type)\(b.number))", .block(b.name)) }
            Spacer()
        }
        .padding(.horizontal, 4).padding(.top, 3)
        .background(Tia.pane)
    }

    private func editorTabChip(_ title: String, _ t: EditorTab) -> some View {
        Button { tab = t } label: {
            Text(title).font(.system(size: 11))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(tab == t ? Color.white : Tia.paneHeader)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var editorArea: some View {
        switch tab {
        case .deviceConfig:
            DeviceConfigView(device: deviceBinding)
        case .tagTable:
            TagTableView(device: deviceBinding)
        case .block(let name):
            if let idx = device.blocks.firstIndex(where: { $0.name == name }) {
                LadEditorView(device: deviceBinding, blockIndex: idx, selectedNetwork: $selectedNetwork)
                    .environmentObject(sim)
            } else {
                Text("Block not found").padding()
            }
        }
    }

    private var deviceBinding: Binding<PlcDevice> {
        Binding(
            get: { store.project?.devices.first ?? PlcDevice() },
            set: { newVal in if store.project != nil { store.project!.devices[0] = newVal } }
        )
    }

    // MARK: task cards

    @ViewBuilder private var taskCards: some View {
        VStack(spacing: 0) {
            if case .block = tab {
                PaneHeader(title: "Instructions")
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Basic instructions").font(.system(size: 11, weight: .semibold)).padding(.top, 4)
                        instructionRow("Normally open contact", .contactNO)
                        instructionRow("Normally closed contact", .contactNC)
                        instructionRow("Output coil", .coil)
                        instructionRow("Set output", .coilSet)
                        instructionRow("Reset output", .coilReset)
                        Text("Timer operations").font(.system(size: 11, weight: .semibold)).padding(.top, 8)
                        instructionRow("TON — on-delay", .ton)
                        Text("Counter operations").font(.system(size: 11, weight: .semibold)).padding(.top, 8)
                        instructionRow("CTU — count up", .ctu)
                        Text("Tap an instruction to add it to the selected network in Main.")
                            .font(.system(size: 10)).foregroundColor(.secondary).padding(.top, 8)
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                PaneHeader(title: "Catalog")
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        catalogRow("Controllers", 0, bold: true)
                        catalogRow("SIMATIC S7-1200", 1, bold: true)
                        catalogRow("CPU 1214C DC/DC/DC", 2, bold: false)
                        catalogRow("Signal modules", 0, bold: true)
                        catalogButton("SM 1221 DI 8 x 24 VDC", article: "6ES7 221-1BF32-0XB0", iAddr: "2", qAddr: "")
                        catalogButton("SM 1222 DQ 8 x 24 VDC", article: "6ES7 222-1BF32-0XB0", iAddr: "", qAddr: "2")
                        catalogButton("SM 1231 AI 4 x 13 bit", article: "6ES7 231-4HD32-0XB0", iAddr: "68…75", qAddr: "")
                        Text("Tap a signal module to add it to the rack.")
                            .font(.system(size: 10)).foregroundColor(.secondary).padding(.top, 8)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                }
            }
        }
        .background(Tia.pane)
        .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .leading)
    }

    private func instructionRow(_ title: String, _ kind: LadElementKind) -> some View {
        Button { addInstruction(kind) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.square").foregroundColor(Tia.accent).font(.system(size: 11))
                Text(title).font(.system(size: 11.5))
                Spacer()
            }
            .padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func catalogRow(_ title: String, _ level: Int, bold: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.down").font(.system(size: 8)).foregroundColor(.secondary)
            Text(title).font(.system(size: 11.5, weight: bold ? .semibold : .regular))
            Spacer()
        }
        .padding(.leading, CGFloat(level * 12)).padding(.vertical, 2.5)
    }

    private func catalogButton(_ title: String, article: String, iAddr: String, qAddr: String) -> some View {
        Button {
            var d = device
            let slot = (d.modules.map { $0.slot }.max() ?? 1) + 1
            d.modules.append(PlcModule(name: title, slot: slot, iAddress: iAddr, qAddress: qAddr, article: article))
            store.project!.devices[0] = d
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.square").foregroundColor(Tia.accent).font(.system(size: 11))
                Text(title).font(.system(size: 11.5))
                Spacer()
            }
            .padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addInstruction(_ kind: LadElementKind) {
        guard case .block(let name) = tab,
              let bi = device.blocks.firstIndex(where: { $0.name == name }) else { return }
        var d = device
        guard d.blocks[bi].networks.indices.contains(selectedNetwork) else { return }
        var el = LadElement(kind: kind)
        switch kind {
        case .ton: el.instance = "TON_\(selectedNetwork + 1)"; el.preset = "T#3s"; el.presetSeconds = 3
        case .ctu: el.instance = "CTU_\(selectedNetwork + 1)"; el.preset = "5"; el.presetValue = 5
        default: break
        }
        if kind == .coil || kind == .coilSet || kind == .coilReset {
            d.blocks[bi].networks[selectedNetwork].output = el
        } else {
            d.blocks[bi].networks[selectedNetwork].series.append(el)
        }
        store.project!.devices[0] = d
    }

    // MARK: inspector + status

    private var inspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Properties", "Info"], id: \.self) { t in
                    Button { inspectorTab = t } label: {
                        Text(t).font(.system(size: 11, weight: inspectorTab == t ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(inspectorTab == t ? Color.white : Tia.paneHeader)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("Inspector window").font(.system(size: 10.5)).foregroundColor(.secondary).padding(.trailing, 8)
            }
            .background(Tia.paneHeader)
            if inspectorTab == "Properties" {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("General").font(.system(size: 11, weight: .semibold))
                        Text("Name: \(device.name)").font(.system(size: 11))
                        Text("Device type: \(device.cpuName)").font(.system(size: 11))
                        Text("Article number: \(device.article)").font(.system(size: 11))
                        Text("Firmware version: \(device.firmware)").font(.system(size: 11))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System and clock memory").font(.system(size: 11, weight: .semibold))
                        Text("First scan: %M1.0   Always TRUE: %M1.2").font(.system(size: 11))
                        Text("Clock memory byte: %MB0 (10 Hz … 0.5 Hz)").font(.system(size: 11))
                    }
                    Spacer()
                }
                .padding(8)
                .frame(height: 86, alignment: .top)
                .background(Color.white)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if diagnostics.isEmpty {
                            Text("No messages. Compile the project to see diagnostics here.")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        ForEach(diagnostics) { d in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: d.isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(d.isError ? Tia.errorRed : .orange).font(.system(size: 11))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(d.text).font(.system(size: 11))
                                    Text(d.path).font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(d.time).font(.system(size: 10)).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 86)
                .background(Color.white)
            }
        }
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(online ? "Online" : "Offline").font(.system(size: 10.5, weight: .semibold))
            Text(device.name).font(.system(size: 10.5))
            Spacer()
            Text(sim.powered ? (sim.running ? "PLCSIM: RUN" : "PLCSIM: STOP") : "PLCSIM: off").font(.system(size: 10.5))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(online ? Tia.online : Tia.paneHeader)
    }

    // MARK: actions

    private func compile() {
        diagnostics = TiaCompiler.compile(project: project)
        let e = diagnostics.filter { $0.isError }.count
        let w = diagnostics.count - e
        compileSummary = "Compiling finished (errors: \(e); warnings: \(w))"
        inspectorTab = "Info"
    }

    private func download() {
        compile()
        if diagnostics.contains(where: { $0.isError }) {
            compileSummary = "Download failed: the project has errors."
            return
        }
        compileSummary = "Download to PLCSIM finished without errors."
        showSim = true
    }
}
