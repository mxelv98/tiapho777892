import SwiftUI

// MARK: - HMI (v3 — built to the approved wireframe)
//
// Two separate modes, like WinCC: the screen EDITOR lives inside the
// Project View shell (800x480 KTP700 canvas, toolbox, tap-to-place,
// tag binding), and the RUNTIME is a full-screen takeover driven by
// the PLCSIM scan: buttons are momentary (press = SetBit, release =
// ResetBit), lamps and fields read live values.

struct HmiEditorView: View {
    @Binding var hmi: HmiDevice
    var tags: [PlcTag]
    @ObservedObject var sim: Simulator
    var onRuntime: () -> Void

    @State private var screenIndex = 0
    @State private var selectedId: UUID? = nil
    @State private var armed: HmiElementKind? = nil
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
    }

    private var editorBar: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(Array(hmi.screens.enumerated()), id: \.element.id) { i, sc in
                    Button(sc.name) { screenIndex = i; selectedId = nil }
                }
                Divider()
                Button("Add screen") {
                    var h = hmi
                    h.screens.append(HmiScreen(name: "Screen_\(h.screens.count + 1)"))
                    hmi = h
                    screenIndex = h.screens.count - 1
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 11))
                    Text(screen.name).font(.system(size: 12, weight: .semibold))
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
         (.bar, "Bar", "chart.bar")]
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
                Button { deleteEl(sel.id) } label: {
                    Image(systemName: "trash").foregroundColor(Tia.errorRed).font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                sizeStepper("W", value: sel.w) { setSize(sel.id, w: $0) }
                sizeStepper("H", value: sel.h) { setSize(sel.id, h: $0) }
                if sel.kind == .button {
                    Text("Press: SetBit · Release: ResetBit").font(.system(size: 10)).foregroundColor(.secondary)
                } else if sel.kind == .lamp {
                    Menu {
                        ForEach(["green", "red", "orange", "yellow"], id: \.self) { c in
                            Button(c.capitalized) { setColor(sel.id, c) }
                        }
                    } label: {
                        Text("On colour: \(sel.colorOn)").font(.system(size: 10.5)).foregroundColor(Tia.textDark)
                    }
                } else if sel.kind == .ioField || sel.kind == .bar {
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
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    private func sizeStepper(_ label: String, value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10.5, weight: .bold)).foregroundColor(Tia.textDark)
            Button { set(max(16, value - 8)) } label: { Image(systemName: "minus.circle").font(.system(size: 13)) }
            Text("\(Int(value))").font(.system(size: 11, design: .monospaced)).frame(width: 30)
            Button { set(min(760, value + 8)) } label: { Image(systemName: "plus.circle").font(.system(size: 13)) }
        }
        .foregroundColor(Tia.textDark)
        .buttonStyle(.plain)
    }

    // MARK: Mutations

    private func updateScreen(_ change: (inout HmiScreen) -> Void) {
        guard hmi.screens.indices.contains(screenIndex) else { return }
        var h = hmi
        change(&h.screens[screenIndex])
        hmi = h
    }

    private func place(_ kind: HmiElementKind, at p: CGPoint) {
        let size: (w: Double, h: Double)
        switch kind {
        case .button: size = (180, 84)
        case .lamp: size = (150, 84)
        case .ioField: size = (180, 64)
        case .textLabel: size = (260, 40)
        case .bar: size = (300, 64)
        }
        var el = HmiElement(kind: kind, text: kindLabel(kind))
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

    private func setTag(_ id: UUID, _ name: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].tag = name } }
    }
    private func setColor(_ id: UUID, _ c: String) {
        updateScreen { sc in if let i = sc.elements.firstIndex(where: { $0.id == id }) { sc.elements[i].colorOn = c } }
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
        }
    }
}

// MARK: - Element face (shared editor/runtime)

struct HmiElementFace: View {
    var el: HmiElement
    @ObservedObject var sim: Simulator
    var interactive: Bool

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
                    RoundedRectangle(cornerRadius: 6).fill(Tia.paneHeader)
                    RoundedRectangle(cornerRadius: 6).stroke(Tia.border, lineWidth: 1.2)
                    Text(el.text).font(.system(size: 15, weight: .bold)).foregroundColor(Tia.textDark)
                }
                .modifier(RuntimeButtonModifier(enabled: interactive && !el.tag.isEmpty) { v in
                    sim.setInput(el.tag, v)
                })
            case .lamp:
                VStack(spacing: 3) {
                    Circle()
                        .fill(on ? lampColor : Color(red: 0.85, green: 0.85, blue: 0.86))
                        .overlay(Circle().stroke(Tia.border, lineWidth: 1))
                        .frame(width: 30, height: 30)
                    Text(el.text).font(.system(size: 11.5)).foregroundColor(Tia.textDark).lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.001))
            case .ioField:
                HStack {
                    Text(el.text).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    Text(fieldValue).font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundColor(Tia.textDark)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 1))
                .onTapGesture {
                    if interactive, sim.values[el.tag] != nil {
                        sim.setInput(el.tag, !on)
                    }
                }
            case .textLabel:
                Text(el.text).font(.system(size: 14, weight: .semibold)).foregroundColor(Tia.textDark)
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
        guard pv > 0 else { return 0 }
        return min(1, max(0, CGFloat(sim.counts[el.tag] ?? 0) / CGFloat(pv)))
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
                                HmiElementFace(el: el, sim: sim, interactive: true)
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
    }
}
