import SwiftUI

// MARK: - Project View shell (v3 — built to the approved wireframes)
//
// Landscape: the full V16 desktop layout. Menu bar 36pt, pane-header /
// editor-tab row 28pt, inspector header 26pt + content 74pt, status bar
// 24pt (#1A1D21). Side panes are 210pt and collapse to 28pt vertical
// rails with one tap, exactly like V16.
// Portrait: the editor takes 100% of the width. The tree and the task
// cards become slide-over drawers, the inspector a bottom sheet whose
// tabs are Properties | Info | Diagnostics | PLCSIM.

enum OpenTab: String, Identifiable {
    case device, block, tags, watch, hmi, sim, db, xref
    var id: String { rawValue }
    var title: String {
        switch self {
        case .device: return "Device configuration"
        case .block: return "Main [OB1]"
        case .tags: return "PLC tags"
        case .watch: return "Watch table"
        case .hmi: return "KTP700 / Screen_1"
        case .sim: return "PLCSIM"
        case .db: return "Data blocks"
        case .xref: return "Cross-reference"
        }
    }
    var icon: String {
        switch self {
        case .device: return "cpu"
        case .block: return "list.bullet.rectangle"
        case .tags: return "tag"
        case .watch: return "binoculars"
        case .hmi: return "rectangle.on.rectangle"
        case .sim: return "play.rectangle"
        case .db: return "cylinder.split.1x2"
        case .xref: return "arrow.triangle.branch"
        }
    }
}

enum SheetTab: String, CaseIterable {
    case properties = "Properties", info = "Info", diag = "Diagnostics", plcsim = "PLCSIM"
}

struct ProjectView: View {
    @EnvironmentObject var store: ProjectStore
    @StateObject private var sim = Simulator()
    @State private var device = PlcDevice()
    @State private var hmi = HmiDevice()
    @State private var loaded = false

    @State private var openTabs: [OpenTab] = [.device, .block, .tags, .hmi]
    @State private var activeTab: OpenTab = .block
    @State private var blockIndex = 0

    @State private var treeCollapsed = false
    @State private var cardsCollapsed = false
    @State private var inspectorOpen = true
    @State private var sheetTab: SheetTab = .info
    @State private var sheetOpen = false
    @State private var showTreeDrawer = false
    @State private var showCardsDrawer = false

    @State private var online = false
    @State private var diags: [Diagnostic] = []
    @State private var compileNote = "Not compiled yet in this session."
    @State private var insertRequest: LadElementKind? = nil
    @State private var showRuntime = false

    private var project: TiaProject? { store.project }
    private var projectName: String { project?.name ?? "Project" }

    private var deviceBinding: Binding<PlcDevice> {
        Binding(get: { device }, set: { device = $0; store.updateDevice($0) })
    }
    private var hmiBinding: Binding<HmiDevice> {
        Binding(get: { hmi }, set: { hmi = $0; store.updateHmi($0) })
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                VStack(spacing: 0) {
                    if landscape { menuBar } else { compactBar }
                    if !landscape && online && sim.powered { onlineStrip }
                    if landscape {
                        HStack(spacing: 0) {
                            if treeCollapsed {
                                CollapsedRail(title: "Project tree") { treeCollapsed = false }
                            } else {
                                VStack(spacing: 0) {
                                    paneHeader("Project tree") { treeCollapsed = true }
                                    treePane
                                }
                                .frame(width: 210)
                                .background(Tia.pane)
                            }
                            VStack(spacing: 0) {
                                tabStrip
                                editorContent
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Tia.editorBG)
                            if cardsCollapsed {
                                CollapsedRail(title: "Task cards") { cardsCollapsed = false }
                            } else {
                                VStack(spacing: 0) {
                                    paneHeader("Task cards") { cardsCollapsed = true }
                                    cardsPane
                                }
                                .frame(width: 210)
                                .background(Tia.pane)
                            }
                        }
                        inspectorLandscape
                    } else {
                        editorContent
                        inspectorPortrait
                    }
                    StatusBarV3(projectName: projectName, running: sim.running, powered: sim.powered,
                                online: online) { store.close() }
                }
                if !landscape && showTreeDrawer { drawer(left: true) }
                if !landscape && showCardsDrawer { drawer(left: false) }
            }
        }
        .background(Tia.pane)
        .onAppear {
            guard !loaded, let p = store.project, let d = p.devices.first else { return }
            device = d
            hmi = p.hmi ?? HmiDevice()
            sim.attach(d)
            loaded = true
        }
        .fullScreenCover(isPresented: $showRuntime) {
            HmiRuntimeView(hmi: hmi, sim: sim) { showRuntime = false }
        }
    }

    // MARK: Bars

    private var menuBar: some View {
        HStack(spacing: 2) {
            LogoMark(size: 22)
            ForEach(["Project", "Edit", "View", "Online", "Options", "Help"], id: \.self) { m in
                Text(m).font(.system(size: 12)).foregroundColor(Tia.textDark)
                    .padding(.horizontal, 7).padding(.vertical, 3)
            }
            Divider().frame(height: 22).padding(.horizontal, 4)
            toolbarButtons
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 36)
        .background(Tia.titleBar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var compactBar: some View {
        HStack(spacing: 2) {
            Button { showTreeDrawer = true } label: {
                Image(systemName: "sidebar.left").font(.system(size: 16)).frame(width: 36, height: 36)
            }
            Menu {
                ForEach(openTabs) { t in
                    Button { activeTab = t } label: { Label(t.title, systemImage: t.icon) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(activeTab.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Tia.textDark)
            }
            Spacer()
            toolbarButtons
            Button { showCardsDrawer = true } label: {
                Image(systemName: "wrench.and.screwdriver").font(.system(size: 15)).frame(width: 36, height: 36)
            }
        }
        .foregroundColor(Tia.textDark)
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(Tia.titleBar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var toolbarButtons: some View {
        HStack(spacing: 0) {
            ToolbarGlyph(system: "square.and.arrow.down", label: "Save") { saveAll() }
            ToolbarGlyph(system: "checkmark.circle", label: "Compile") { compile() }
            ToolbarGlyph(system: "arrow.down.to.line", label: "Download") { download() }
            ToolbarGlyph(system: "globe", label: "Online", active: online) { toggleOnline() }
            ToolbarGlyph(system: sim.running ? "stop.fill" : "play.fill",
                         label: sim.running ? "STOP" : "RUN", active: sim.running) {
                if sim.powered { sim.run(!sim.running) }
            }
            ToolbarGlyph(system: "rectangle.on.rectangle", label: "Runtime", active: showRuntime) {
                if activeTab != .hmi { open(.hmi) }
                showRuntime = true
            }
        }
    }

    private var onlineStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill").font(.system(size: 8)).foregroundColor(.white)
            Text("ONLINE — Monitoring (100ms)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Tia.online)
    }

    private func paneHeader(_ title: String, collapse: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
            Spacer()
            Button(action: collapse) {
                Image(systemName: "chevron.left").font(.system(size: 9, weight: .bold)).foregroundColor(Tia.textDark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background(Tia.paneHeader)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var tabStrip: some View {
        HStack(spacing: 2) {
            ForEach(openTabs) { t in
                HStack(spacing: 5) {
                    Image(systemName: t.icon).font(.system(size: 10))
                    Text(t.title).font(.system(size: 11, weight: activeTab == t ? .semibold : .regular)).lineLimit(1)
                    Button { close(t) } label: {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(Tia.textDark)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(activeTab == t ? Color.white : Tia.paneHeader)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                .onTapGesture { activeTab = t }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .frame(height: 28)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    // MARK: Editor content

    @ViewBuilder
    private var editorContent: some View {
        switch activeTab {
        case .device:
            DeviceConfigView(device: deviceBinding, sim: sim, online: online)
        case .block:
            blockEditor
        case .tags:
            TagTableView(device: deviceBinding)
        case .watch:
            WatchTableView(tags: device.tags, watch: project?.watchTags ?? [], sim: sim) { w in
                store.updateWatch(w)
            }
        case .hmi:
            HmiEditorView(hmi: hmiBinding, tags: device.tags, sim: sim) { showRuntime = true }
        case .sim:
            SimPanelView(device: device, sim: sim)
        case .db:
            DataBlocksView(device: deviceBinding, sim: sim)
        case .xref:
            CrossRefView(device: deviceBinding, hmi: hmiBinding, watch: project?.watchTags ?? []) { old, new in
                if let w = store.project?.watchTags, w.contains(old) {
                    store.updateWatch(w.map { $0 == old ? new : $0 })
                }
            }
        }
    }

    private var blockLanguage: Binding<String> {
        Binding(
            get: { device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex].language : "LAD" },
            set: { lang in
                var d = device
                guard d.blocks.indices.contains(blockIndex) else { return }
                d.blocks[blockIndex].language = lang
                if lang == "SCL" && (d.blocks[blockIndex].sclSource ?? "").isEmpty {
                    d.blocks[blockIndex].sclSource = SclEditorView.template
                }
                device = d
                store.updateDevice(d)
            }
        )
    }

    @ViewBuilder
    private var blockEditor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Language").font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
                Picker("", selection: blockLanguage) {
                    ForEach(["LAD", "FBD", "SCL"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
                Text(device.blocks.indices.contains(blockIndex) ? "\(device.blocks[blockIndex].name) [\(device.blocks[blockIndex].type)\(device.blocks[blockIndex].number)]" : "")
                    .font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(Tia.pane)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
            let lang = device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex].language : "LAD"
            if lang == "FBD" {
                FbdView(device: deviceBinding, blockIndex: blockIndex, sim: sim,
                        online: online, insertRequest: $insertRequest)
            } else if lang == "SCL" {
                SclEditorView(device: deviceBinding, blockIndex: blockIndex, sim: sim)
            } else {
                LadEditorView(device: deviceBinding, blockIndex: blockIndex, sim: sim,
                              online: online, insertRequest: $insertRequest)
            }
        }
    }

    // MARK: Tree & cards

    private var treePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                treeRow(icon: "folder", label: projectName, level: 0, bold: true) {}
                treeRow(icon: "cpu", label: "PLC_1 [\(device.cpuName)]", level: 1, bold: true) {}
                treeRow(icon: "slider.horizontal.3", label: "Device configuration", level: 2,
                        selected: activeTab == .device) { open(.device) }
                treeRow(icon: "folder", label: "Program blocks", level: 2, bold: true) {}
                ForEach(Array(device.blocks.enumerated()), id: \.offset) { i, b in
                    treeRow(icon: "list.bullet.rectangle",
                            label: "\(b.name) [\(b.type)\(b.number)]", level: 3,
                            selected: activeTab == .block && blockIndex == i) {
                        blockIndex = i; open(.block)
                    }
                }
                treeRow(icon: "plus.square", label: "Add block (FC)…", level: 3) {
                    var d = device
                    let n = d.blocks.count + 1
                    var nb = PlcBlock(name: "Block_\(n)", number: n, type: "FC")
                    nb.interfaceRows = [InterfaceVar(name: "Temp_1", section: "Temp", dataType: "Bool")]
                    d.blocks.append(nb)
                    device = d
                    store.updateDevice(d)
                    blockIndex = d.blocks.count - 1
                    open(.block)
                }
                treeRow(icon: "tag", label: "PLC tags (\(device.tags.count))", level: 2,
                        selected: activeTab == .tags) { open(.tags) }
                treeRow(icon: "cylinder.split.1x2", label: "Data blocks (\(device.dataBlocks?.count ?? 0))", level: 2,
                        selected: activeTab == .db) { open(.db) }
                treeRow(icon: "arrow.triangle.branch", label: "Cross-reference", level: 2,
                        selected: activeTab == .xref) { open(.xref) }
                treeRow(icon: "binoculars", label: "Watch table_1", level: 2,
                        selected: activeTab == .watch) { open(.watch) }
                treeRow(icon: "rectangle.on.rectangle", label: "HMI_1 [KTP700 Basic]", level: 1, bold: true) {}
                treeRow(icon: "rectangle", label: hmi.screens.first?.name ?? "Screen_1", level: 2,
                        selected: activeTab == .hmi) { open(.hmi) }
                treeRow(icon: "play.rectangle", label: "PLCSIM", level: 1,
                        selected: activeTab == .sim) { open(.sim) }
            }
            .padding(.vertical, 4)
        }
    }

    private func treeRow(icon: String, label: String, level: Int, bold: Bool = false,
                         selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10.5)).frame(width: 14)
                Text(label).font(.system(size: 11.5, weight: bold ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(Tia.textDark)
            .padding(.leading, CGFloat(6 + level * 14))
            .padding(.trailing, 4)
            .frame(height: 22)
            .background(selected ? Tia.selection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cardsPane: some View {
        TaskCardsView(onInstruction: { kind in
            if activeTab != .block { open(.block) }
            insertRequest = kind
        }, onCatalog: { entry, isCPU in
            applyCatalog(entry, isCPU: isCPU)
        })
    }

    // MARK: Inspector

    private var inspectorTabs: some View {
        HStack(spacing: 2) {
            ForEach(SheetTab.allCases, id: \.rawValue) { t in
                Button {
                    sheetTab = t
                    inspectorOpen = true
                    sheetOpen = true
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 11, weight: sheetTab == t ? .semibold : .regular))
                        .foregroundColor(Tia.textDark)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(sheetTab == t ? Color.white : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var inspectorLandscape: some View {
        VStack(spacing: 0) {
            HStack {
                inspectorTabs
                Button { inspectorOpen.toggle() } label: {
                    Image(systemName: inspectorOpen ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(Tia.textDark)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
            .background(Tia.paneHeader)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
            if inspectorOpen {
                inspectorContent.frame(height: 74)
            }
        }
        .background(Tia.pane)
    }

    private var inspectorPortrait: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { sheetOpen.toggle() }
            } label: {
                VStack(spacing: 3) {
                    Capsule().fill(Tia.border).frame(width: 44, height: 4)
                    HStack {
                        inspectorTabs
                        Image(systemName: sheetOpen ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .bold)).foregroundColor(Tia.textDark)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Tia.paneHeader)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
            if sheetOpen {
                inspectorContent.frame(height: 190)
            }
        }
        .background(Tia.pane)
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch sheetTab {
        case .properties:
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    switch activeTab {
                    case .block:
                        let b = device.blocks.indices.contains(blockIndex) ? device.blocks[blockIndex] : nil
                        propRow("General", "Name: \(b?.name ?? "Main")")
                        propRow("Interface", "Number: \(b?.number ?? 1) (\(b?.type ?? "OB"))")
                        propRow("Attributes", "Language: \(b?.language ?? "LAD")")
                        propRow("Compilation", compileNote)
                    case .device:
                        propRow("General", "\(device.cpuName) — \(device.article) / \(device.firmware)")
                        propRow("Modules", "\(device.modules.count) modules in the rack")
                    case .hmi:
                        propRow("General", "KTP700 Basic PN — 800 × 480")
                        propRow("Screens", "\(hmi.screens.count) screen(s)")
                    default:
                        propRow("General", activeTab.title)
                    }
                }
                .padding(8)
            }
            .background(Color.white)
        case .info:
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Compile: \(compileNote)").font(.system(size: 11.5)).foregroundColor(Tia.textDark)
                    Text("Project: \(projectName) — PLC_1 [\(device.cpuName)] + HMI_1 [KTP700 Basic]")
                        .font(.system(size: 11.5)).foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
        case .diag:
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if diags.isEmpty {
                        Text("No messages. Run Compile to check the program.")
                            .font(.system(size: 11.5)).foregroundColor(.secondary)
                    }
                    ForEach(diags) { d in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: d.isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(d.isError ? Tia.errorRed : .orange)
                                .font(.system(size: 11))
                            Text("\(d.path) — \(d.text)").font(.system(size: 11.5)).foregroundColor(Tia.textDark)
                            Spacer()
                            Text(d.time).font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
            }
            .background(Color.white)
        case .plcsim:
            SimStripView(device: device, sim: sim) { open(.sim); sheetOpen = false }
                .background(Color.white)
        }
    }

    private func propRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Tia.textDark).frame(width: 74, alignment: .leading)
            Text(v).font(.system(size: 11.5)).foregroundColor(Tia.textDark)
        }
    }

    // MARK: Drawers (portrait)

    private func drawer(left: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .onTapGesture { showTreeDrawer = false; showCardsDrawer = false }
            HStack(spacing: 0) {
                if !left { Spacer() }
                VStack(spacing: 0) {
                    HStack {
                        Text(left ? "Project tree" : "Task cards")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                        Spacer()
                        Button { showTreeDrawer = false; showCardsDrawer = false } label: {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(Tia.textDark)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Tia.paneHeader)
                    if left {
                        treePane
                    } else {
                        cardsPane
                    }
                }
                .frame(width: 280)
                .background(Tia.pane)
                .shadow(radius: 6)
                if left { Spacer() }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Actions

    private func open(_ t: OpenTab) {
        if !openTabs.contains(t) { openTabs.append(t) }
        activeTab = t
        showTreeDrawer = false
    }

    private func close(_ t: OpenTab) {
        guard openTabs.count > 1 else { return }
        openTabs.removeAll { $0 == t }
        if activeTab == t { activeTab = openTabs.last ?? .block }
    }

    private func saveAll() {
        store.updateDevice(device)
        store.updateHmi(hmi)
        if let p = store.project { store.save(p) }
        compileNote = "Saved \(timeNow())."
    }

    private func compile() {
        var p = project ?? TiaProject(name: projectName)
        if !p.devices.isEmpty { p.devices[0] = device }
        p.hmi = hmi
        diags = TiaCompiler.compile(project: p)
        let errs = diags.filter { $0.isError }.count
        let warns = diags.count - errs
        compileNote = "\(errs) Errors, \(warns) Warnings (\(projectName) / Main)"
        sheetTab = errs > 0 ? .diag : .info
        inspectorOpen = true
        sheetOpen = true
    }

    private func download() {
        sim.attach(device)
        sim.power(true)
        compileNote = "Downloaded to PLCSIM (training simulation). CPU is powered."
        sheetTab = .info
        inspectorOpen = true
    }

    private func toggleOnline() {
        online.toggle()
        if online && !sim.powered {
            sim.attach(device)
            sim.power(true)
        }
    }

    private func applyCatalog(_ entry: CatalogEntry, isCPU: Bool) {
        var d = device
        if isCPU {
            d.cpuName = entry.name
            d.article = entry.article
            d.firmware = entry.version
            if !d.modules.isEmpty {
                d.modules[0].name = "PLC_1"
                d.modules[0].article = entry.article
                d.modules[0].firmware = entry.version
            }
        } else {
            let slot = (d.modules.map { $0.slot }.max() ?? 1) + 1
            d.modules.append(PlcModule(name: entry.name, slot: slot,
                                        iAddress: "", qAddress: "",
                                        article: entry.article, firmware: entry.version))
        }
        device = d
        store.updateDevice(d)
    }

    private func timeNow() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - Task cards (Instructions + Catalog)

struct TaskCardsView: View {
    var onInstruction: (LadElementKind) -> Void
    var onCatalog: (CatalogEntry, Bool) -> Void
    @State private var card = 0
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $card) {
                Text("Instructions").tag(0)
                Text("Catalog").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(6)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundColor(.secondary)
                TextField("Search...", text: $query).font(.system(size: 11.5))
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
            .padding(.horizontal, 6).padding(.bottom, 6)
            ScrollView {
                if card == 0 { instructions } else { catalog }
            }
        }
        .background(Tia.pane)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(InstructionCatalog.families) { fam in
                Text(fam.title).font(.system(size: 11, weight: .bold)).foregroundColor(Tia.textDark)
                    .padding(.top, 6).padding(.horizontal, 6)
                ForEach(fam.items.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { item in
                    Button {
                        if let k = item.kind { onInstruction(k) }
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.symbol)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(item.kind == nil ? .secondary : Tia.accent)
                                .frame(width: 40, alignment: .leading)
                            Text(item.name)
                                .font(.system(size: 11.5))
                                .foregroundColor(item.kind == nil ? .secondary : Tia.textDark)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Catalog.families) { fam in
                Text(fam.title).font(.system(size: 11, weight: .bold)).foregroundColor(Tia.textDark)
                    .padding(.top, 6).padding(.horizontal, 6)
                ForEach(fam.entries.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.article.contains(query) }) { e in
                    Button { onCatalog(e, fam.title.hasPrefix("CPU")) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Tia.textDark).lineLimit(1)
                            Text("\(e.article) · \(e.version)").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                            Text(e.desc).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 8)
    }
}
