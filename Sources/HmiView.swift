import SwiftUI

// MARK: - HMI Studio (v3.3 — Part 5 + Part 3 live values)
//
// Two modes, like WinCC: the STUDIO (screen editor) lives inside the
// Project View shell — 800x480 KTP700 canvas, a full toolbox (Button,
// Lamp, I/O field, Text, Bar, Gauge, Slider, Switch) plus a symbol
// library of original vector symbols (motor, pump, fan, valve, tank,
// conveyor, cylinder, heater, traffic light, E-stop, selector, limit
// switch). Every property is editable: text, tag binding, button
// action (momentary / toggle / set / reset / go-to-screen), colours,
// font size, position, size, layer order, duplicate. Screens can be
// added, duplicated, deleted, and one is marked as the start screen.
// The RUNTIME is a full-screen takeover driven by the PLCSIM scan:
// momentary buttons SetBit/ResetBit, symbols animate from live tags
// (a motor's shaft turns while its tag is ON, a tank fills from its
// counter), sliders write counter values, navigation buttons jump
// between screens.

struct HmiEditorView: View {
    @Binding var hmi: HmiDevice
    var tags: [PlcTag]
    @ObservedObject var sim: Simulator
    var onRuntime: () -> Void

    @State private var screenIndex = 0
    @State private var selectedId: UUID? = nil
    @State private var armed: HmiElementKind? = nil
    @State private var armedSymbol: String? = nil
    @State private var showLibrary = false
    @State private var dragOrigin: [UUID: CGPoint] = [:]

    private var screen: HmiScreen {
        hmi.screens.indices.contains(screenIndex) ? hmi.screens[screenIndex] : HmiScreen()
    }
    private var selected: HmiElement? { screen.elements.first { $0.id == selectedId } }

    var body: some View {
        VStack(spacing: 0) {
            editorBar
            toolboxRow
            GeometryReader { geo in
                let s = min((geo.size.width - 20) / 800, (geo.size.height - 20) / 480)
                ZStack {
                    Color(red: 0.88, green: 0.89, blue: 0.91)
                    canvas(s: s)
                        .frame(width: 800 * s, height: 480 * s)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            if let sel = selected { inspectorStrip(sel) }
        }
        .background(Tia.pane)
        .sheet(isPresented: $showLibrary) {
            SymbolLibrarySheet { name in
                armedSymbol = name
                armed = .symbol
            }
        }
    }

    private var editorBar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(Array(hmi.screens.enumerated()), id: \.element.id) { i, sc in
                    Button("\(hmi.startScreen == i ? "★ " : "")\(sc.name)") { screenIndex = i; selectedId = nil }
                }
                Divider()
                Button("Add screen") { addScreen() }
                Button("Duplicate screen") { duplicateScreen() }
                Button("Delete screen") { deleteScreen() }
                Button(hmi.startScreen == screenIndex ? "★ Start screen" : "Set as start screen") { setStartScreen() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 11))
                    Text("\(hmi.startScreen == screenIndex ? "★ " : "")\(screen.name)").font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(Tia.textDark)
            }
            Text("800 × 480").font(.system(size: 10.5)).foregroundColor(.secondary)
            Spacer()
            Button(action: onRuntime) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                    Text("Runtime").font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Tia.runGreen)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var toolboxRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(toolbox, id: \.kind) { t in
                    Button { armed = (armed == t.kind) ? nil : t.kind } label: {
                        HStack(spacing: 4) {
                            Image(systemName: t.icon).font(.system(size: 11))
                            Text(t.label).font(.system(size: 11))
                        }
                        .foregroundColor(armed == t.kind ? .white : Tia.textDark)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(armed == t.kind ? Tia.accent : Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
                Button { showLibrary = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "puzzlepiece").font(.system(size: 11))
                        Text("Symbols").font(.system(size: 11))
                    }
                    .foregroundColor(armed == .symbol ? .white : Tia.textDark)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(armed == .symbol ? Tia.accent : Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                if armed != nil {
                    Text("Tap the screen to place").font(.system(size: 10.5)).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 40)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private var toolbox: [(kind: HmiElementKind, label: String, icon: String)] {
        [(.button, "Button", "rectangle"),
         (.lamp, "Lamp", "circle"),
         (.ioField, "I/O field", "textbox"),
         (.textLabel, "Text", "textformat"),
         (.bar, "Bar", "chart.bar"),
         (.gauge, "Gauge", "speedometer"),
         (.slider, "Slider", "slider.horizontal.3"),
         (.toggleSwitch, "Switch", "switch.2")]
    }

    private func canvas(s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.border, lineWidth: 1))
            ForEach(screen.elements) { el in
                HmiElementFace(el: el, sim: sim, interactive: false)
                    .frame(width: el.w, height: el.h)
                    .scaleEffect(s)
                    .frame(width: el.w * s, height: el.h * s)
                    .position(x: (el.x + el.w / 2) * s, y: (el.y + el.h / 2) * s)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { v in
                                if dragOrigin[el.id] == nil { dragOrigin[el.id] = CGPoint(x: el.x, y: el.y) }
                                let o = dragOrigin[el.id]!
                                move(el.id, to: CGPoint(x: o.x + v.translation.width / s,
                                                        y: o.y + v.translation.height / s))
                                selectedId = el.id
                            }
                            .onEnded { _ in dragOrigin[el.id] = nil }
                    )
                    .onTapGesture { selectedId = el.id }
            }
            if let sel = selected {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Tia.accent, lineWidth: 1.6)
                    .frame(width: sel.w * s + 4, height: sel.h * s + 4)
                    .position(x: (sel.x + sel.w / 2) * s, y: (sel.y + sel.h / 2) * s)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 800 * s, height: 480 * s)
        .contentShape(Rectangle())
        .onTapGesture { loc in
            if let kind = armed {
                place(kind, at: CGPoint(x: loc.x / s, y: loc.y / s))
                armed = nil
            } else {
                selectedId = nil
            }
        }
    }

    private func inspectorStrip(_ sel: HmiElement) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(kindLabel(sel.kind)).font(.system(size: 11, weight: .bold)).foregroundColor(Tia.textDark)
                TextField("Text", text: elText(sel.id))
                    .font(.system(size: 12))
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                Menu {
                    ForEach(tags) { t in
                        Button("\(t.name)  (\(t.address))") { setTag(sel.id, t.name) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "tag").font(.system(size: 10))
                        Text(sel.tag.isEmpty ? "Bind tag" : sel.tag).font(.system(size: 11.5)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Tia.textDark)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                }
                Button { duplicateEl(sel.id) } label: {
                    Image(systemName: "plus.square.on.square").foregroundColor(Tia.textDark).font(.system(size: 13))
                }
                .buttonStyle(.plain)
                Button { deleteEl(sel.id) } label: {
                    Image(systemName: "trash").foregroundColor(Tia.errorRed).font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    sizeStepper("W", value: sel.w) { setSize(sel.id, w: $0) }
                    sizeStepper("H", value: sel.h) { setSize(sel.id, h: $0) }
                    sizeStepper("X", value: sel.x, step: 4, minV: 0, maxV: 800) { setPos(sel.id, x: $0) }
                    sizeStepper("Y", value: sel.y, step: 4, minV: 0, maxV: 480) { setPos(sel.id, y: $0) }
                    HStack(spacing: 3) {
                        Text("Layer").font(.system(size: 10.5, weight: .bold)).foregroundColor(Tia.textDark)
                        Button { moveZ(sel.id, up: true) } label: { Image(systemName: "chevron.up.circle").font(.system(size: 13)) }
                        Button { moveZ(sel.id, up: false) } label: { Image(systemName: "chevron.down.circle").font(.system(size: 13)) }
                    }
                    .foregroundColor(Tia.textDark)
                    .buttonStyle(.plain)
                    if sel.kind == .button || sel.kind == .textLabel || sel.kind == .lamp || sel.kind == .ioField || sel.kind == .symbol {
                        sizeStepper("Font", value: sel.fontSize, step: 1, minV: 9, maxV: 40) { setFont(sel.id, $0) }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if sel.kind == .button {
                        Menu {
                            ForEach(["momentary", "toggle", "set", "reset", "navigate"], id: \.self) { a in
                                Button(actionLabel(a)) { setAction(sel.id, a) }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("Action: \(actionLabel(sel.action))").font(.system(size: 11))
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Tia.textDark)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                        }
                        if sel.action == "navigate" {
                            Menu {
                                ForEach(hmi.screens) { sc in
                                    Button(sc.name) { setSymbol(sel.id, sc.name) }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(sel.symbol.isEmpty ? "Target screen" : "Go to: \(sel.symbol)").font(.system(size: 11))
                                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(Tia.textDark)
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                            }
                        } else if sel.action == "momentary" {
                            Text("Press: SetBit · Release: ResetBit").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    } else if sel.kind == .lamp {
                        Menu {
                            ForEach(["green", "red", "orange", "yellow"], id: \.self) { c in
                                Button(c.capitalized) { setColor(sel.id, c) }
                            }
                        } label: {
                            Text("On colour: \(sel.colorOn)").font(.system(size: 10.5)).foregroundColor(Tia.textDark)
                        }
                    } else if sel.kind == .symbol {
                        Text("Symbol: \(sel.symbol.isEmpty ? "motor" : sel.symbol) — binds to its tag; a Selector toggles on tap.")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    } else if sel.kind == .slider {
                        Text("Runtime: drag writes the bound counter's value (0…PV). Bind a counter instance above, or type it:")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        TextField("Binding", text: elText(sel.id, keyPath: \.tag))
                            .font(.system(size: 11))
                            .frame(width: 120)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                    } else if sel.kind == .ioField || sel.kind == .bar || sel.kind == .gauge {
                        Text("Bind a counter instance (e.g. BatchCounter) or a tag.")
                            .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                        TextField("Binding", text: elText(sel.id, keyPath: \.tag))
                            .font(.system(size: 11))
                            .frame(width: 130)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    private func sizeStepper(_ label: String, value: Double, step: Double = 8, minV: Double = 16, maxV: Double = 760, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10.5, weight: .bold)).foregroundColor(Tia.textDark)
            Button { set(max(minV, value - step)) } label: { Image(systemName: "minus.circle").font(.system(size: 13)) }
            Text("\(Int(value))").font(.system(size: 11, design: .monospaced)).frame(width: 30)
            Button { set(min(maxV, value + step)) } label: { Image(systemName: "plus.circle").font(.system(size: 13)) }
        }
        .foregroundColor(Tia.textDark)
        .buttonStyle(.plain)
    }

    private func actionLabel(_ a: String) -> String {
        switch a {
        case "toggle": return "Toggle"
        case "set": return "Set bit"
        case "reset": return "Reset bit"
        case "navigate": return "Go to screen"
        default: return "Momentary"
        }
    }

    // MARK: Mutations

    private func updateScreen(_ change: (inout HmiScreen) -> Void) {
        guard hmi.screens.indices.contains(screenIndex) else { return }
        var h = hmi
        change(&h.screens[screenIndex])
        hmi = h
    }

    private func updateHmi(_ change: (inout HmiDevice) -> Void) {
        var h = hmi
        change(&h)
        hmi = h
    }

    private func addScreen() {
        updateHmi { $0.screens.append(HmiScreen(name: "Screen_\($0.screens.count + 1)")) }
        screenIndex = hmi.screens.count - 1
        selectedId = nil
    }

    private func duplicateScreen() {
        guard hmi.screens.indices.contains(screenIndex) else { return }
        var copy = hmi.screens[screenIndex]
        copy.id = UUID()
        copy.name = hmi.screens[screenIndex].name + "_copy"
        copy.elements = copy.elements.map { e in var c = e; c.id = UUID(); return c }
        updateHmi { $0.screens.insert(copy, at: screenIndex + 1) }
        screenIndex += 1
        selectedId = nil
    }

    private func deleteScreen() {
        guard hmi.screens.count > 1, hmi.screens.indices.contains(screenIndex) else { return }
        let removed = screenIndex
        updateHmi { h in
            h.screens.remove(at: removed)
            if h.startScreen >= h.screens.count { h.startScreen = max(0, h.screens.count - 1) }
            else if h.startScreen > removed { h.startScreen -= 1 }
        }
        screenIndex = max(0, min(screenIndex, hmi.screens.count - 1))
        selectedId = nil
    }

    private func setStartScreen() {
        updateHmi { $0.startScreen = screenIndex }
    }

    private func place(_ kind: HmiElementKind, at p: CGPoint) {
        let size: (w: Double, h: Double)
        switch kind {
        case .button: size = (180, 84)
        case .lamp: size = (150, 84)
        case .ioField: size = (180, 64)
        case .textLabel: size = (260, 40)
        case .bar: size = (300, 64)
        case .gauge: size = (170, 150)
        case .slider: size = (280, 56)
        case .toggleSwitch: size = (190, 60)
        case .symbol: size = (150, 130)
        }
        var el = HmiElement(kind: kind, text: kindLabel(kind))
        if kind == .symbol {
            el.symbol = armedSymbol ?? "motor"
            el.text = HmiSymbols.all.first { $0.name == el.symbol }?.label ?? "Symbol"
        }
        el.w = size.w; el.h = size.h
        el.x = min(max(0, p.x - size.w / 2), 800 - size.w)
        el.y = min(max(0, p.y - size.h / 2), 480 - size.h)
        updateScreen { $0.elements.append(el) }
        selectedId = el.id
    }

    private func move(_ id: UUID, to p: CGPoint) {
        updateScreen { sc in
            if let i = sc.elements.firstIndex(where: { $0.id == id }) {
                sc.elements[i].x = min(max(0, p.x), 800 - sc.elements[i].w)
                sc.elements[i].y = min(max(0, p.y), 480 - sc.elements[i].h)
            }
        }
    }

    private func deleteEl(_ id: UUID) {
        updateScreen { $0.elements.removeAll { $0.id == id } }
        selectedId = nil
    }

    private func duplicateEl(_ id: UUID) {
        updateScreen { sc in
            if let i = sc.elements.firstIndex(where: { $0.id == id }) {
                var c = sc.elements[i]
                c.id = UUID()
                c.x = min(800 - c.w, c.x + 16)
                c.y = min(480 - c.h, c.y + 16)
                sc.elements.insert(c, at: i + 1)
                selectedId = c.id
            }
        }
    }

    private func moveZ(_ id: UUID, up: Bool) {
        updateScreen { sc in
            guard let i = sc.elements.firstIndex(where: { $0.id == id }) else { return }
            let j = up ? i + 1 : i - 1
            guard sc.elements.indices.contains(j) else { return }
            sc.elements.swapAt(i, j)
        }
    }

    private func setTag(_ id: UUID, _ name: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].tag = name } }
    }
    private func setColor(_ id: UUID, _ c: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].colorOn = c } }
    }
    private func setAction(_ id: UUID, _ a: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].action = a } }
    }
    private func setSymbol(_ id: UUID, _ s: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].symbol = s } }
    }
    private func setFont(_ id: UUID, _ v: Double) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].fontSize = v } }
    }
    private func setPos(_ id: UUID, x: Double? = nil, y: Double? = nil) {
        updateScreen { sc in
            if let i = sc.elements.firstIndex(where: { $0.id == id }) {
                if let x { sc.elements[i].x = min(max(0, x), 800 - sc.elements[i].w) }
                if let y { sc.elements[i].y = min(max(0, y), 480 - sc.elements[i].h) }
            }
        }
    }
    private func setSize(_ id: UUID, w: Double? = nil, h: Double? = nil) {
        updateScreen { sc in
            if let i = sc.elements.firstIndex(where: { $0.id == id }) {
                if let w { sc.elements[i].w = w }
                if let h { sc.elements[i].h = h }
            }
        }
    }

    private func elText(_ id: UUID, keyPath: WritableKeyPath<HmiElement, String> = \.text) -> Binding<String> {
        Binding(
            get: { screen.elements.first { $0.id == id }?[keyPath: keyPath] ?? "" },
            set: { v in updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i][keyPath: keyPath] = v } } }
        )
    }

    private func kindLabel(_ k: HmiElementKind) -> String {
        switch k {
        case .button: return "Button"
        case .lamp: return "Lamp"
        case .ioField: return "I/O field"
        case .textLabel: return "Text"
        case .bar: return "Bar"
        case .gauge: return "Gauge"
        case .slider: return "Slider"
        case .toggleSwitch: return "Switch"
        case .symbol: return "Symbol"
        }
    }
}

// MARK: - Symbol library

enum HmiSymbols {
    static let all: [(name: String, label: String, icon: String)] = [
        ("motor", "Motor", "gearshape.2"),
        ("pump", "Pump", "arrow.up.circle"),
        ("fan", "Fan", "fanblades"),
        ("valve", "Valve", "arrow.left.and.right"),
        ("tank", "Tank", "rectangle.portrait.fill"),
        ("conveyor", "Conveyor", "arrow.right"),
        ("cylinder", "Cylinder", "capsule"),
        ("heater", "Heater", "flame"),
        ("traffic", "Traffic light", "square.grid.3x3"),
        ("estop", "E-Stop", "octagon.fill"),
        ("selector", "Selector", "switch.2"),
        ("limit", "Limit switch", "slider.horizontal.3")
    ]
}

struct SymbolLibrarySheet: View {
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    private let cols = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(HmiSymbols.all, id: \.name) { s in
                        Button {
                            onPick(s.name)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: s.icon).font(.system(size: 22))
                                Text(s.label).font(.system(size: 11.5))
                            }
                            .foregroundColor(Tia.textDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Tia.border, lineWidth: 0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .background(Tia.pane)
            .navigationTitle("Symbol library")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Element face (shared editor/runtime)

struct HmiElementFace: View {
    var el: HmiElement
    @ObservedObject var sim: Simulator
    var interactive: Bool
    var onNavigate: ((String) -> Void)? = nil

    private var on: Bool { sim.values[el.tag] ?? false }
    private var lampColor: Color {
        switch el.colorOn {
        case "red": return Tia.errorRed
        case "orange": return .orange
        case "yellow": return .yellow
        default: return Tia.runGreen
        }
    }

    var body: some View {
        Group {
            switch el.kind {
            case .button:
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(el.action != "momentary" && on ? Tia.accent.opacity(0.30) : Tia.paneHeader)
                    RoundedRectangle(cornerRadius: 6).stroke(Tia.border, lineWidth: 1.2)
                    Text(el.text).font(.system(size: el.fontSize, weight: .bold)).foregroundColor(Tia.textDark)
                }
                .modifier(RuntimeButtonModifier(enabled: interactive && el.action == "momentary" && !el.tag.isEmpty) { v in
                    sim.setHMIInput(el.tag, v)
                })
                .onTapGesture {
                    guard interactive else { return }
                    switch el.action {
                    case "toggle": if !el.tag.isEmpty { sim.setHMIInput(el.tag, !on) }
                    case "set": if !el.tag.isEmpty { sim.setHMIInput(el.tag, true) }
                    case "reset": if !el.tag.isEmpty { sim.setHMIInput(el.tag, false) }
                    case "navigate": onNavigate?(el.symbol)
                    default: break
                    }
                }
            case .lamp:
                VStack(spacing: 3) {
                    Circle()
                        .fill(on ? lampColor : Color(red: 0.85, green: 0.85, blue: 0.86))
                        .overlay(Circle().stroke(Tia.border, lineWidth: 1))
                        .frame(width: 30, height: 30)
                    Text(el.text).font(.system(size: min(el.fontSize, 13))).foregroundColor(Tia.textDark).lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.001))
            case .ioField:
                HStack {
                    Text(el.text).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    Text(fieldValue).font(.system(size: el.fontSize, weight: .bold, design: .monospaced)).foregroundColor(Tia.textDark)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 1))
                .onTapGesture {
                    if interactive, sim.values[el.tag] != nil {
                        sim.setHMIInput(el.tag, !on)
                    }
                }
            case .textLabel:
                Text(el.text).font(.system(size: el.fontSize, weight: .semibold)).foregroundColor(Tia.textDark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .bar:
                VStack(spacing: 2) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(red: 0.90, green: 0.90, blue: 0.91))
                            Rectangle().fill(Tia.accent).frame(width: g.size.width * barFraction)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Tia.border, lineWidth: 0.8))
                    Text(el.text).font(.system(size: 10.5)).foregroundColor(.secondary)
                }
                .padding(4)
            case .gauge:
                VStack(spacing: 1) {
                    GeometryReader { g in
                        let w = g.size.width, h = g.size.height
                        let cx = w / 2, cy = h * 0.78, r = min(w * 0.44, h * 0.66)
                        let f = Double(barFraction)
                        let th = (180 + 180 * f) * Double.pi / 180
                        ZStack {
                            gaugeArc(cx: cx, cy: cy, r: r, from: 180, to: 360)
                                .stroke(Color(red: 0.88, green: 0.88, blue: 0.89), lineWidth: 6)
                            gaugeArc(cx: cx, cy: cy, r: r, from: 180, to: 180 + 180 * f)
                                .stroke(Tia.accent, lineWidth: 6)
                            Path { p in
                                p.move(to: CGPoint(x: cx, y: cy))
                                p.addLine(to: CGPoint(x: cx + r * 0.78 * CGFloat(cos(th)), y: cy + r * 0.78 * CGFloat(sin(th))))
                            }
                            .stroke(Tia.errorRed, lineWidth: 2)
                            Circle().fill(Tia.textDark).frame(width: 7, height: 7).position(x: cx, y: cy)
                        }
                    }
                    Text("\(el.text)  \(fieldValue)").font(.system(size: 10.5)).foregroundColor(Tia.textDark).lineLimit(1)
                }
                .padding(4)
            case .slider:
                VStack(spacing: 3) {
                    HStack {
                        Text(el.text).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                        Spacer()
                        Text("\(sliderValue)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Tia.textDark)
                    }
                    GeometryReader { g in
                        let f = sliderFraction
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 0.88, green: 0.88, blue: 0.89)).frame(height: 6)
                            Capsule().fill(Tia.accent).frame(width: g.size.width * f, height: 6)
                            Circle().fill(Color.white)
                                .overlay(Circle().stroke(Tia.border, lineWidth: 1))
                                .frame(width: 20, height: 20)
                                .position(x: g.size.width * f, y: g.size.height / 2)
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    if interactive {
                                        let f2 = min(1, max(0, v.location.x / max(1, g.size.width)))
                                        sim.setCounterValue(el.tag, Int((f2 * Double(sliderMax)).rounded()))
                                    }
                                }
                        )
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 1))
            case .toggleSwitch:
                HStack(spacing: 8) {
                    Capsule()
                        .fill(on ? Tia.runGreen : Color(red: 0.78, green: 0.78, blue: 0.80))
                        .frame(width: 48, height: 27)
                        .overlay(
                            Circle().fill(Color.white)
                                .overlay(Circle().stroke(Tia.border, lineWidth: 0.7))
                                .frame(width: 21, height: 21)
                                .padding(3),
                            alignment: on ? .trailing : .leading
                        )
                    Text(el.text).font(.system(size: el.fontSize)).foregroundColor(Tia.textDark).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.001))
                .onTapGesture {
                    if interactive && !el.tag.isEmpty { sim.setHMIInput(el.tag, !on) }
                }
            case .symbol:
                VStack(spacing: 2) {
                    HmiSymbolView(symbol: el.symbol, on: on, fraction: barFraction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !el.text.isEmpty {
                        Text(el.text).font(.system(size: min(el.fontSize, 12))).foregroundColor(Tia.textDark).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.001))
                .onTapGesture {
                    if interactive && el.symbol == "selector" && !el.tag.isEmpty {
                        sim.setHMIInput(el.tag, !on)
                    }
                }
            }
        }
    }

    private var fieldValue: String {
        if let c = sim.counts[el.tag] { return "\(c)" }
        if let v = sim.values[el.tag] { return v ? "TRUE" : "FALSE" }
        return el.tag.isEmpty ? "—" : "0"
    }

    private var barFraction: CGFloat {
        let pv = sim.counterPV(el.tag)
        guard pv > 0 else { return on ? 1 : 0 }
        return min(1, max(0, CGFloat(sim.counts[el.tag] ?? 0) / CGFloat(pv)))
    }

    private var sliderMax: Int {
        let pv = sim.counterPV(el.tag)
        return pv > 0 ? pv : 10
    }
    private var sliderValue: Int { sim.counts[el.tag] ?? 0 }
    private var sliderFraction: CGFloat {
        min(1, max(0, CGFloat(sliderValue) / CGFloat(sliderMax)))
    }

    private func gaugeArc(cx: CGFloat, cy: CGFloat, r: CGFloat, from: Double, to: Double) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                     startAngle: .degrees(from), endAngle: .degrees(to), clockwise: true)
        }
    }
}

/// Momentary-button behaviour for runtime faces: press sets, release resets.
struct RuntimeButtonModifier: ViewModifier {
    var enabled: Bool
    var action: (Bool) -> Void
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if enabled { action(true) } }
                .onEnded { _ in if enabled { action(false) } }
        )
    }
}

// MARK: - Symbols (original vector drawings, animated from live tags)

struct HmiSymbolView: View {
    var symbol: String
    var on: Bool
    var fraction: CGFloat

    var body: some View {
        switch symbol {
        case "fan": FanSymbol(on: on)
        case "pump": PumpSymbol(on: on)
        case "valve": ValveSymbol(on: on)
        case "tank": TankSymbol(fraction: fraction)
        case "conveyor": ConveyorSymbol(on: on)
        case "cylinder": CylinderSymbol(on: on)
        case "heater": HeaterSymbol(on: on)
        case "traffic": TrafficSymbol(on: on)
        case "estop": EStopSymbol()
        case "selector": SelectorSymbol(on: on)
        case "limit": LimitSymbol(on: on)
        default: MotorSymbol(on: on)
        }
    }
}

struct MotorSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cx = w / 2, cy = h / 2, r = min(w, h) * 0.26
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.72, green: 0.76, blue: 0.82))
                    .frame(width: w * 0.94, height: h * 0.84)
                    .position(x: cx, y: cy)
                RoundedRectangle(cornerRadius: 6).stroke(Tia.border, lineWidth: 1.2)
                    .frame(width: w * 0.94, height: h * 0.84)
                    .position(x: cx, y: cy)
                ForEach(0..<4, id: \.self) { i in
                    Rectangle().fill(Color(red: 0.58, green: 0.63, blue: 0.71))
                        .frame(width: w * 0.9, height: 1.5)
                        .position(x: cx, y: cy - h * 0.30 + CGFloat(i) * h * 0.20)
                }
                Circle().fill(Color.white).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                Circle().stroke(Tia.border, lineWidth: 1.2).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !on)) { ctx in
                    let a = on ? ctx.date.timeIntervalSinceReferenceDate * 240 : 0
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Rectangle().fill(Tia.textDark)
                                .frame(width: r * 0.34, height: r * 1.7)
                                .position(x: cx, y: cy)
                                .rotationEffect(.degrees(Double(i) * 60 + a))
                        }
                        Circle().fill(Tia.textDark).frame(width: r * 0.5, height: r * 0.5).position(x: cx, y: cy)
                    }
                }
                .frame(width: w, height: h)
                .position(x: cx, y: cy)
                Text("M").font(.system(size: r * 0.7, weight: .bold)).foregroundColor(.white)
                    .position(x: cx, y: cy)
            }
        }
    }
}

struct FanSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cx = w / 2, cy = h / 2, r = min(w, h) * 0.40
            ZStack {
                Circle().stroke(Tia.border, lineWidth: 1.5).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !on)) { ctx in
                    let a = on ? ctx.date.timeIntervalSinceReferenceDate * 300 : 0
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            ZStack {
                                Ellipse().fill(Color(red: 0.45, green: 0.62, blue: 0.85))
                                    .frame(width: r * 0.62, height: r * 1.05)
                                    .position(x: r, y: r * 0.55)
                            }
                            .frame(width: r * 2, height: r * 2)
                            .rotationEffect(.degrees(Double(i) * 120 + a))
                        }
                        Circle().fill(Tia.textDark).frame(width: r * 0.36, height: r * 0.36).position(x: r, y: r)
                    }
                    .frame(width: r * 2, height: r * 2)
                }
                .frame(width: r * 2, height: r * 2)
                .position(x: cx, y: cy)
            }
        }
    }
}

struct PumpSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cx = w / 2, cy = h * 0.56, r = min(w, h) * 0.32
            ZStack {
                Rectangle().fill(Color(red: 0.45, green: 0.62, blue: 0.85))
                    .frame(width: w * 0.16, height: h * 0.30)
                    .position(x: cx + r * 0.9, y: h * 0.18)
                Rectangle().fill(Tia.textDark)
                    .frame(width: w * 0.7, height: h * 0.10)
                    .position(x: cx, y: h * 0.95)
                Circle().fill(Color(red: 0.80, green: 0.86, blue: 0.94)).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                Circle().stroke(Tia.border, lineWidth: 1.4).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !on)) { ctx in
                    let a = on ? ctx.date.timeIntervalSinceReferenceDate * 260 : 0
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            ZStack {
                                Rectangle().fill(Tia.textDark)
                                    .frame(width: r * 0.30, height: r * 0.95)
                                    .position(x: r, y: r * 0.55)
                            }
                            .frame(width: r * 2, height: r * 2)
                            .rotationEffect(.degrees(Double(i) * 120 + a))
                        }
                        Circle().fill(Tia.textDark).frame(width: r * 0.4, height: r * 0.4).position(x: r, y: r)
                    }
                    .frame(width: r * 2, height: r * 2)
                }
                .frame(width: r * 2, height: r * 2)
                .position(x: cx, y: cy)
                Text("P").font(.system(size: r * 0.6, weight: .bold)).foregroundColor(Tia.textDark)
                    .position(x: cx - r * 1.35, y: cy)
            }
        }
    }
}

struct ValveSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cy = h * 0.58
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.04, y: cy)); p.addLine(to: CGPoint(x: w * 0.16, y: cy))
                    p.move(to: CGPoint(x: w * 0.84, y: cy)); p.addLine(to: CGPoint(x: w * 0.96, y: cy))
                }
                .stroke(Tia.textDark, lineWidth: 2.5)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.16, y: cy - h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.16, y: cy + h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.84, y: cy - h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.84, y: cy + h * 0.20))
                    p.closeSubpath()
                }
                .fill(on ? Tia.accent.opacity(0.55) : Color(red: 0.90, green: 0.90, blue: 0.91))
                Path { p in
                    p.move(to: CGPoint(x: w * 0.16, y: cy - h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.16, y: cy + h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.84, y: cy - h * 0.20))
                    p.addLine(to: CGPoint(x: w * 0.84, y: cy + h * 0.20))
                    p.closeSubpath()
                }
                .stroke(Tia.textDark, lineWidth: 1.6)
                Rectangle().fill(Tia.textDark).frame(width: 2.5, height: h * 0.24).position(x: w / 2, y: cy - h * 0.30)
                Rectangle().fill(Tia.errorRed).frame(width: w * 0.34, height: 4).position(x: w / 2, y: cy - h * 0.44)
            }
        }
    }
}

struct TankSymbol: View {
    var fraction: CGFloat
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let innerH = h - 10
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color(red: 0.85, green: 0.90, blue: 0.97))
                    .frame(width: w - 8, height: innerH * min(1, max(0, fraction)))
                    .padding(.bottom, 5)
                Rectangle().stroke(Tia.textDark, lineWidth: 1.8)
                    .frame(width: w - 4, height: h - 4)
                Text("\(Int(min(1, max(0, fraction)) * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Tia.textDark)
                    .position(x: w / 2, y: h / 2)
            }
            .frame(width: w, height: h)
        }
    }
}

struct ConveyorSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cy = h / 2
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.22)
                    .fill(Color(red: 0.80, green: 0.82, blue: 0.85))
                    .frame(width: w - 4, height: h * 0.52)
                    .position(x: w / 2, y: cy)
                RoundedRectangle(cornerRadius: h * 0.22).stroke(Tia.border, lineWidth: 1.4)
                    .frame(width: w - 4, height: h * 0.52)
                    .position(x: w / 2, y: cy)
                ForEach(0..<4, id: \.self) { i in
                    Circle().stroke(Tia.textDark, lineWidth: 1.3)
                        .frame(width: h * 0.30, height: h * 0.30)
                        .position(x: w * 0.14 + CGFloat(i) * w * 0.24, y: cy)
                }
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !on)) { ctx in
                    let phase = on ? (ctx.date.timeIntervalSinceReferenceDate * 46).truncatingRemainder(dividingBy: 52) : 0
                    ZStack {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0.72, green: 0.52, blue: 0.30))
                                .frame(width: 30, height: h * 0.34)
                                .position(x: CGFloat(i) * 52 + CGFloat(phase) - 20, y: cy - h * 0.42)
                        }
                    }
                    .frame(width: w, height: h)
                    .clipped()
                }
                .frame(width: w, height: h)
                .position(x: w / 2, y: cy)
            }
        }
    }
}

struct CylinderSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cy = h / 2
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.72, green: 0.76, blue: 0.82))
                    .frame(width: w * 0.52, height: h * 0.52)
                    .position(x: w * 0.28, y: cy)
                RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 1.3)
                    .frame(width: w * 0.52, height: h * 0.52)
                    .position(x: w * 0.28, y: cy)
                Rectangle().fill(Tia.textDark)
                    .frame(width: on ? w * 0.36 : w * 0.12, height: h * 0.14)
                    .position(x: w * 0.54 + (on ? w * 0.18 : w * 0.06), y: cy)
                Rectangle().fill(Color(red: 0.45, green: 0.62, blue: 0.85))
                    .frame(width: w * 0.06, height: h * 0.62)
                    .position(x: w * 0.54 + (on ? w * 0.36 : w * 0.12) + w * 0.03, y: cy)
            }
        }
    }
}

struct HeaterSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.94))
                    .frame(width: w * 0.94, height: h * 0.88)
                    .position(x: w / 2, y: h / 2)
                RoundedRectangle(cornerRadius: 5).stroke(Tia.border, lineWidth: 1.3)
                    .frame(width: w * 0.94, height: h * 0.88)
                    .position(x: w / 2, y: h / 2)
                Path { p in
                    for row in 0..<3 {
                        let yy = h * (0.30 + 0.20 * Double(row))
                        p.move(to: CGPoint(x: w * 0.18, y: yy))
                        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: yy),
                                       control: CGPoint(x: w * 0.50, y: yy - h * 0.13))
                    }
                }
                .stroke(on ? Tia.errorRed : Color(red: 0.70, green: 0.70, blue: 0.72), lineWidth: 2.4)
            }
        }
    }
}

struct TrafficSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let d = min(w * 0.34, h * 0.24)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.16, green: 0.17, blue: 0.19))
                    .frame(width: w * 0.52, height: h * 0.94)
                    .position(x: w / 2, y: h / 2)
                Circle().fill(on ? Color(red: 0.45, green: 0.16, blue: 0.16) : Tia.errorRed)
                    .frame(width: d, height: d).position(x: w / 2, y: h * 0.22)
                Circle().fill(Color(red: 0.45, green: 0.36, blue: 0.14))
                    .frame(width: d, height: d).position(x: w / 2, y: h * 0.50)
                Circle().fill(on ? Tia.runGreen : Color(red: 0.16, green: 0.35, blue: 0.20))
                    .frame(width: d, height: d).position(x: w / 2, y: h * 0.78)
            }
        }
    }
}

struct EStopSymbol: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let d = min(w, h) * 0.78
            ZStack {
                Circle().fill(.yellow).frame(width: d, height: d).position(x: w / 2, y: h / 2)
                Circle().stroke(Tia.border, lineWidth: 1.2).frame(width: d, height: d).position(x: w / 2, y: h / 2)
                Circle().fill(Tia.errorRed).frame(width: d * 0.68, height: d * 0.68).position(x: w / 2, y: h / 2)
                Text("STOP").font(.system(size: d * 0.16, weight: .black)).foregroundColor(.white)
                    .position(x: w / 2, y: h / 2)
            }
        }
    }
}

struct SelectorSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cx = w / 2, cy = h / 2, r = min(w, h) * 0.34
            ZStack {
                Circle().fill(Color(red: 0.20, green: 0.21, blue: 0.23)).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                Circle().stroke(Tia.border, lineWidth: 1.4).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
                ZStack {
                    Rectangle().fill(Color.white)
                        .frame(width: r * 0.30, height: r * 1.25)
                        .position(x: r, y: r * 0.45)
                }
                .frame(width: r * 2, height: r * 2)
                .position(x: cx, y: cy)
                .rotationEffect(.degrees(on ? 38 : -38))
                Circle().fill(Color.white).frame(width: r * 0.34, height: r * 0.34).position(x: cx, y: cy)
            }
        }
    }
}

struct LimitSymbol: View {
    var on: Bool
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let px = w * 0.30, py = h * 0.78
            let len = h * 0.52
            let ang = (on ? -18.0 : 28.0) * Double.pi / 180
            let ex = px + len * CGFloat(sin(ang))
            let ey = py - len * CGFloat(cos(ang))
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.72, green: 0.76, blue: 0.82))
                    .frame(width: w * 0.44, height: h * 0.30)
                    .position(x: px, y: py + h * 0.08)
                Path { p in
                    p.move(to: CGPoint(x: px, y: py))
                    p.addLine(to: CGPoint(x: ex, y: ey))
                }
                .stroke(Tia.textDark, lineWidth: 3)
                Circle().fill(Tia.errorRed).frame(width: h * 0.16, height: h * 0.16).position(x: ex, y: ey)
                Circle().fill(Tia.textDark).frame(width: h * 0.13, height: h * 0.13).position(x: px, y: py)
            }
        }
    }
}

// MARK: - Runtime (full screen)

struct HmiRuntimeView: View {
    var hmi: HmiDevice
    @ObservedObject var sim: Simulator
    var onExit: () -> Void
    @State private var screenIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onExit) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill").font(.system(size: 10))
                        Text("Exit").font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Tia.errorRed)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                Menu {
                    ForEach(Array(hmi.screens.enumerated()), id: \.element.id) { i, sc in
                        Button(sc.name) { screenIndex = i }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(hmi.screens.indices.contains(screenIndex) ? hmi.screens[screenIndex].name : "Screen_1")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
                Spacer()
                Circle().fill(sim.powered ? (sim.running ? Tia.runGreen : .orange) : .gray).frame(width: 9, height: 9)
                Text(sim.powered ? (sim.running ? "RUN" : "STOP") : "OFF")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                Text("100ms").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.7))
                Text("KTP700 Basic").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Tia.statusBarV3)
            GeometryReader { geo in
                let s = min(geo.size.width / 800, geo.size.height / 480)
                ZStack {
                    Color(red: 0.16, green: 0.17, blue: 0.19)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(Color.white)
                        if hmi.screens.indices.contains(screenIndex) {
                            ForEach(hmi.screens[screenIndex].elements) { el in
                                HmiElementFace(el: el, sim: sim, interactive: true, onNavigate: { name in
                                    if let i = hmi.screens.firstIndex(where: { $0.name == name }) { screenIndex = i }
                                })
                                    .frame(width: el.w, height: el.h)
                                    .position(x: el.x + el.w / 2, y: el.y + el.h / 2)
                            }
                        }
                    }
                    .frame(width: 800, height: 480)
                    .scaleEffect(s)
                    .frame(width: 800 * s, height: 480 * s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    if !sim.powered {
                        Text("PLCSIM is off — use Download / Online in the toolbar, then RUN.")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.black.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .position(x: geo.size.width / 2, y: geo.size.height - 26)
                    }
                }
            }
        }
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .onAppear {
            screenIndex = hmi.screens.indices.contains(hmi.startScreen) ? hmi.startScreen : 0
        }
    }
}
