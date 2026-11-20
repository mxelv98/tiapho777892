import SwiftUI

enum EditorTab: Equatable {
    case deviceConfig
    case tagTable
    case block(Int)
    case hmi
    case watch
    case dataTypes
    case online
}

/// The Project view: menu bar, toolbar, project tree, tabbed editors,
/// task cards (Catalog / Instructions), inspector, status bar.
/// On a phone: landscape shows the full shell; portrait keeps the editor
/// full-width and slides the tree / task cards over it — like the real
/// Portal squeezed onto the phone, never crushed.
struct ProjectView: View {
    @EnvironmentObject var store: ProjectStore
    @StateObject private var sim = Simulator()
    @State private var tab: EditorTab = .block(0)
    @State private var inspectorTab = 0
    @State private var diagnostics: [Diagnostic] = []
    @State private var compiled = false
    @State private var showTree = false
    @State private var showTasks = false
    @State private var cardTab = 0
    @State private var catalogQuery = ""

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            VStack(spacing: 0) {
                menuBar(landscape: landscape)
                toolbar
                breadcrumb(landscape: landscape)
                if landscape {
                    HStack(spacing: 0) {
                        tree.frame(width: 218)
                        editor
                        tasks.frame(width: 218)
                    }
                } else {
                    editor
                }
                inspector.frame(height: 118)
                statusBar
            }
            .background(Tia.pane)
            .overlay(alignment: .leading) {
                if !landscape && showTree {
                    HStack(spacing: 0) {
                        tree.frame(width: 250)
                            .background(Tia.pane)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 3)
                        Color.black.opacity(0.25).onTapGesture { showTree = false }
                    }
                    .transition(.move(edge: .leading))
                }
            }
            .overlay(alignment: .trailing) {
                if !landscape && showTasks {
                    HStack(spacing: 0) {
                        Color.black.opacity(0.25).onTapGesture { showTasks = false }
                        tasks.frame(width: 250)
                            .background(Tia.pane)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: -3)
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showTree)
        .animation(.easeInOut(duration: 0.18), value: showTasks)
        .onAppear { if let d = store.project?.devices.first { sim.attach(d) } }
        .onChange(of: store.project?.devices.first?.blocks.first?.networks.count) { _ in
            if let d = store.project?.devices.first { sim.attach(d) }
        }
    }

    private var project: TiaProject { store.project! }
    private var device: PlcDevice { project.devices[0] }
    private var deviceBinding: Binding<PlcDevice> {
        Binding(get: { store.project?.devices[0] ?? PlcDevice() },
                set: { store.updateDevice($0) })
    }

    // MARK: menu bar / toolbar / breadcrumb / status bar

    private func menuBar(landscape: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Wordmark(large: false)
                Divider().frame(height: 14)
                ForEach(["Project", "Edit", "View", "Insert", "Online", "Options", "Tools", "Window", "Help"], id: \.self) { m in
                    Text(m).font(.system(size: 12)).foregroundColor(Tia.textDark).lineLimit(1)
                }
                Text("— \(project.name) - TIA PHONE").font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .background(Color(white: 0.97))
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                tbtn("doc.badge.plus", "New") { }
                tbtn("folder", "Open") { store.close() }
                tbtn("square.and.arrow.down", "Save") { store.save(project) }
                Divider().frame(height: 18)
                tbtn("checkmark.shield", "Compile") { compile() }
                tbtn("arrow.down.circle", "Download") { compile() }
                Divider().frame(height: 18)
                tbtn("play.circle", "Start simulation") { if !sim.powered { sim.power(true) }; sim.run(true) }
                tbtn("stop.circle", "Stop simulation") { sim.run(false) }
                Divider().frame(height: 18)
                if let url = store.exportURL(project) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").foregroundColor(Tia.textDark)
                    }
                    .frame(width: 30, height: 26)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
        }
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private func tbtn(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(Tia.textDark)
                Text(label).font(.system(size: 8)).foregroundColor(Tia.textDark).lineLimit(1)
            }
            .frame(width: 52, height: 30)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.001)))
        }
        .buttonStyle(.plain)
    }

    private func breadcrumb(landscape: Bool) -> some View {
        HStack(spacing: 6) {
            if !landscape {
                Button { showTree = true } label: {
                    Label("Tree", systemImage: "sidebar.left").font(.system(size: 11))
                }
            }
            Image(systemName: "folder").font(.system(size: 10))
            Text(project.name).font(.system(size: 11, weight: .semibold))
            Image(systemName: "chevron.right").font(.system(size: 8))
            Text(device.name).font(.system(size: 11))
            Image(systemName: "chevron.right").font(.system(size: 8))
            Text(tabTitle).font(.system(size: 11))
            Spacer()
            if sim.powered {
                Label("ONLINE", systemImage: "wifi").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange))
            }
            if !landscape {
                Button { showTasks = true } label: {
                    Label("Tasks", systemImage: "sidebar.right").font(.system(size: 11))
                }
            }
        }
        .foregroundColor(sim.powered ? .white : Tia.textDark)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(sim.powered ? Color.orange : Tia.headerBand)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var tabTitle: String {
        switch tab {
        case .deviceConfig: return "Device configuration"
        case .tagTable: return "PLC tags"
        case .block(let i): return device.blocks.indices.contains(i) ? "\(device.blocks[i].name) [\(device.blocks[i].type) \(device.blocks[i].number)]" : "Block"
        case .hmi: return "\(project.hmi?.name ?? "HMI") · Screens"
        case .watch: return "Watch and force tables"
        case .dataTypes: return "PLC data types"
        case .online: return "Online & diagnostics"
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Text(compiled ? "Compiled successfully" : "Ready").font(.system(size: 11))
            if compiled {
                Text("0 errors").foregroundColor(Color(red: 0.55, green: 0.95, blue: 0.6))
                Text("0 warnings").foregroundColor(Color(red: 0.55, green: 0.95, blue: 0.6))
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(sim.powered ? (sim.running ? Tia.runGreen : .orange) : Color(white: 0.55))
                    .frame(width: 8, height: 8)
                Text(sim.powered ? (sim.running ? "RUN" : "STOP") : "Offline").font(.system(size: 11, weight: .semibold))
            }
            Text(device.cpuName).font(.system(size: 11))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Tia.statusBar)
    }

    // MARK: project tree

    private var tree: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Project tree").font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                .padding(.horizontal, 8).padding(.vertical, 5)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    node(icon: "folder.fill", text: project.name, bold: true, depth: 0) { }
                    node(icon: "cpu", text: "\(device.name) [\(device.cpuName)]", depth: 1) { tab = .deviceConfig }
                    node(icon: "gearshape", text: "Device configuration", depth: 2, active: tab == .deviceConfig) { tab = .deviceConfig; showTree = false }
                    node(icon: "curlybraces", text: "Program blocks", depth: 2) { }
                    ForEach(Array(device.blocks.enumerated()), id: \.element.id) { bi, b in
                        node(icon: "doc.text", text: "\(b.name) [\(b.type) \(b.number)]", depth: 3, active: tab == .block(bi)) {
                            tab = .block(bi); showTree = false
                        }
                    }
                    node(icon: "tablecells", text: "PLC tags", depth: 2) { }
                    node(icon: "tablecells", text: "Default tag table", depth: 3, active: tab == .tagTable) { tab = .tagTable; showTree = false }
                    node(icon: "character.book.closed", text: "PLC data types", depth: 2, active: tab == .dataTypes) { tab = .dataTypes; showTree = false }
                    node(icon: "binoculars", text: "Watch and force tables", depth: 2) { }
                    node(icon: "binoculars", text: "Watch_table_1", depth: 3, active: tab == .watch) { tab = .watch; showTree = false }
                    if let h = project.hmi {
                        node(icon: "rectangle.on.rectangle", text: "\(h.name) [\(h.panel)]", depth: 1) { tab = .hmi }
                        node(icon: "rectangle.on.rectangle", text: "HMI screens", depth: 2) { }
                        ForEach(h.screens) { s in
                            node(icon: "rectangle", text: s.name, depth: 3, active: tab == .hmi) { tab = .hmi; showTree = false }
                        }
                    }
                    node(icon: "wifi", text: "Online & diagnostics", depth: 1, active: tab == .online) { tab = .online; showTree = false }
                    node(icon: "books.vertical", text: "Documentation", depth: 1) { }
                }
                .padding(.horizontal, 4)
            }
        }
        .background(Tia.pane)
        .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .trailing)
    }

    private func node(icon: String, text: String, bold: Bool = false, depth: Int, active: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(Tia.textDark)
                Text(text).font(.system(size: 12, weight: bold ? .semibold : .regular))
                    .foregroundColor(Tia.textDark).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 13 + 4).padding(.vertical, 3).padding(.trailing, 4)
            .background(active ? Tia.selection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: editors

    @ViewBuilder private var editor: some View {
        VStack(spacing: 0) {
            editorTabs
            Group {
                switch tab {
                case .deviceConfig:
                    DeviceConfigView(device: deviceBinding)
                case .tagTable:
                    TagTableView(device: deviceBinding)
                case .block(let bi):
                    if device.blocks.indices.contains(bi) {
                        LadEditorView(block: device.blocks[bi], tags: device.tags, sim: sim) { nb in
                            var d = device; d.blocks[bi] = nb; store.updateDevice(d)
                        }
                    }
                case .hmi:
                    if let h = project.hmi {
                        HmiView(hmi: h, tags: device.tags, counterInstances: counterInstances, sim: sim) { store.updateHmi($0) }
                    } else {
                        VStack(spacing: 10) {
                            Text("No HMI device in this project.").foregroundColor(.secondary)
                            Button("Add KTP700 Basic PN") { store.updateHmi(HmiDevice()) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white)
                    }
                case .watch:
                    WatchTableView(tags: device.tags, watch: project.watchTags ?? [], sim: sim) { store.updateWatch($0) }
                case .dataTypes:
                    dataTypesPage
                case .online:
                    onlinePage
                }
            }
            SimPanelView(device: device).environmentObject(sim)
        }
        .background(Color.white)
    }

    private var counterInstances: [String] {
        var out: [String] = []
        for b in device.blocks { for n in b.networks {
            for el in n.series + [n.output] where el.kind == .ctu || el.kind == .ctd {
                if !el.instance.isEmpty && !out.contains(el.instance) { out.append(el.instance) }
            }
        } }
        return out
    }

    private var editorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                etab("Device configuration", active: tab == .deviceConfig) { tab = .deviceConfig }
                etab("Default tag table", active: tab == .tagTable) { tab = .tagTable }
                ForEach(Array(device.blocks.enumerated()), id: \.element.id) { bi, b in
                    etab("\(b.name) [\(b.type) \(b.number)]", active: tab == .block(bi)) { tab = .block(bi) }
                }
                if project.hmi != nil { etab("Screen_1", active: tab == .hmi) { tab = .hmi } }
                etab("Watch_table_1", active: tab == .watch) { tab = .watch }
            }
            .padding(.horizontal, 4).padding(.top, 3)
        }
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private func etab(_ title: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11.5, weight: active ? .semibold : .regular))
                .foregroundColor(Tia.textDark).lineLimit(1)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(active ? Color.white : Tia.toolbar)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    // MARK: static pages (data types / online & diagnostics)

    private var dataTypesPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PLC data types").font(.system(size: 13, weight: .semibold)).foregroundColor(Tia.textDark)
                .padding(10)
            ForEach([
                ("TON_TIME", "System type — IEC on-delay timer instance data"),
                ("TOF_TIME", "System type — IEC off-delay timer instance data"),
                ("TP_TIME", "System type — IEC pulse timer instance data"),
                ("CTU_INT", "System type — count-up counter (Int)"),
                ("CTD_INT", "System type — count-down counter (Int)"),
                ("CTUD_INT", "System type — count up/down counter (Int)"),
                ("R_TRIG", "System type — rising-edge detection"),
                ("F_TRIG", "System type — falling-edge detection")
            ], id: \.0) { name, desc in
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed").foregroundColor(Tia.textDark)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                        Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Rectangle().frame(height: 0.5).foregroundColor(Tia.border)
            }
            Text("System types are created automatically when you insert a timer or counter instruction.")
                .font(.system(size: 11)).foregroundColor(.secondary).padding(10)
            Spacer()
        }
        .background(Color.white)
    }

    private var onlinePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Online & diagnostics — \(device.name)").font(.system(size: 13, weight: .semibold)).foregroundColor(Tia.textDark)
                .padding(10)
            ForEach([
                ("Device type", device.cpuName),
                ("Article number", device.article),
                ("Firmware", device.firmware),
                ("IP address", "192.168.0.1"),
                ("Connection", sim.powered ? "Online — simulated (PLCSIM panel below)" : "Offline"),
                ("Operating mode", sim.powered ? (sim.running ? "RUN" : "STOP") : "—"),
                ("Diagnostics buffer", "No errors. The most recent event: CPU in RUN (simulated).")
            ], id: \.0) { k, v in
                HStack(alignment: .top, spacing: 8) {
                    Text(k).font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark).frame(width: 130, alignment: .leading)
                    Text(v).font(.system(size: 12)).foregroundColor(Tia.textDark)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                Rectangle().frame(height: 0.5).foregroundColor(Tia.border)
            }
            Text("Training replica: the connection is simulated by the built-in PLCSIM — no real PLC is contacted.")
                .font(.system(size: 11)).foregroundColor(.secondary).padding(10)
            Spacer()
        }
        .background(Color.white)
    }

    // MARK: task cards (Catalog / Instructions)

    private var tasks: some View {
        VStack(spacing: 0) {
            Picker("", selection: $cardTab) {
                Text("Catalog").tag(0)
                Text("Instructions").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(6)
            if cardTab == 0 { catalogCard } else { instructionsCard }
        }
        .background(Tia.pane)
        .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .leading)
    }

    private var catalogCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Filter… e.g. 1214 or SM 1223", text: $catalogQuery)
                    .font(.system(size: 12)).foregroundColor(Tia.textDark)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if catalogQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                        ForEach(Catalog.families) { fam in
                            DisclosureGroup {
                                ForEach(fam.entries) { e in catalogRow(e) }
                            } label: {
                                Text(fam.title).font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 2)
                        }
                    } else {
                        ForEach(Catalog.search(catalogQuery), id: \.entry.id) { pair in
                            catalogRow(pair.entry)
                        }
                        if Catalog.search(catalogQuery).isEmpty {
                            Text("No catalog entries match.").font(.system(size: 12)).foregroundColor(.secondary).padding(8)
                        }
                    }
                    Text("Tap a CPU to replace the device CPU; tap a module to add it to the rack.")
                        .font(.system(size: 10.5)).foregroundColor(.secondary).padding(8)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func catalogRow(_ e: CatalogEntry) -> some View {
        Button { applyCatalog(e) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(e.name).font(.system(size: 12)).foregroundColor(Tia.textDark).lineLimit(1)
                Text("\(e.article)\(e.version.isEmpty ? "" : " · \(e.version)")").font(.system(size: 10.5)).foregroundColor(.secondary).lineLimit(1)
            }
            .padding(.leading, 14).padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applyCatalog(_ e: CatalogEntry) {
        var d = device
        if e.family.hasPrefix("CPU") {
            d.cpuName = e.name
            d.article = e.article
            d.firmware = e.version.isEmpty ? d.firmware : e.version
            if !d.modules.isEmpty {
                d.modules[0].name = device.name
                d.modules[0].article = e.article
                d.modules[0].firmware = e.version
            }
        } else {
            let slot = (d.modules.map { $0.slot }.max() ?? 1) + 1
            d.modules.append(PlcModule(name: e.name, slot: slot, iAddress: "", qAddress: "",
                                       article: e.article, firmware: e.version))
        }
        store.updateDevice(d)
        tab = .deviceConfig
        showTasks = false
    }

    private var instructionsCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(InstructionCatalog.families) { fam in
                    DisclosureGroup {
                        ForEach(fam.items) { item in
                            Button { addInstruction(item) } label: {
                                HStack(spacing: 6) {
                                    Text(item.symbol)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(item.kind == nil ? .secondary : Tia.textDark)
                                        .frame(width: 38)
                                        .padding(.vertical, 2)
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.border, lineWidth: 0.6))
                                    Text(item.name)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(item.kind == nil ? .secondary : Tia.textDark)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                    if item.kind == nil {
                                        Text("SCL").font(.system(size: 9)).foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 8).padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(item.kind == nil)
                        }
                    } label: {
                        Text(fam.title).font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 2)
                }
                Text("Tap an instruction to append it to the last network of Main. Items marked SCL are part of the SCL course in this training build.")
                    .font(.system(size: 10.5)).foregroundColor(.secondary).padding(8)
            }
            .padding(.vertical, 4)
        }
    }

    private func addInstruction(_ item: InstructionItem) {
        guard let el = InstructionCatalog.makeElement(item, tags: device.tags),
              tabIsBlockOrMain else { return }
        var d = device
        guard !d.blocks.isEmpty, !d.blocks[0].networks.isEmpty else { return }
        let li = d.blocks[0].networks.count - 1
        if el.kind == .coil || el.kind == .coilSet || el.kind == .coilReset {
            d.blocks[0].networks[li].output = el
        } else {
            d.blocks[0].networks[li].series.append(el)
        }
        store.updateDevice(d)
        tab = .block(0)
        showTasks = false
    }

    private var tabIsBlockOrMain: Bool { true }

    // MARK: inspector + compile

    private var inspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                inspTab("Properties", 0)
                inspTab("Info", 1)
                inspTab("Diagnostics", 2)
                Spacer()
            }
            .background(Tia.toolbar)
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if inspectorTab == 0 {
                        propRow("Name", tabTitle)
                        propRow("Device", "\(device.name) — \(device.cpuName)")
                        propRow("Comment", project.comment.isEmpty ? "—" : project.comment)
                    } else {
                        if diagnostics.isEmpty {
                            Text("No messages. Run Compile (checkmark-shield in the toolbar) to check the program.")
                                .font(.system(size: 11.5)).foregroundColor(Tia.textDark)
                        }
                        ForEach(diagnostics) { d in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: d.isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                                    .foregroundColor(d.isError ? .red : Tia.runGreen).font(.system(size: 11))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(d.path).font(.system(size: 10.5)).foregroundColor(.secondary)
                                    Text(d.text).font(.system(size: 11.5)).foregroundColor(Tia.textDark)
                                }
                                Spacer()
                                Text(d.time).font(.system(size: 10.5)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
            }
            .background(Color.white)
        }
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    private func inspTab(_ title: String, _ i: Int) -> some View {
        Button { inspectorTab = i } label: {
            Text(title).font(.system(size: 11.5, weight: inspectorTab == i ? .semibold : .regular))
                .foregroundColor(Tia.textDark)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(inspectorTab == i ? Color.white : Tia.toolbar)
        }
        .buttonStyle(.plain)
    }

    private func propRow(_ k: String, _ v: String) -> some View {
        HStack(spacing: 8) {
            Text(k).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Tia.textDark).frame(width: 70, alignment: .leading)
            Text(v).font(.system(size: 11.5)).foregroundColor(Tia.textDark).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func compile() {
        diagnostics = Compiler.compile(device)
        compiled = !diagnostics.contains(where: { $0.isError })
        inspectorTab = 1
    }
}
