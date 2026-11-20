import SwiftUI

/// HMI screen editor + runtime, in the style of a WinCC screen:
/// a 350x230 canvas (KTP700 Basic proportions), elements bound to PLC tags.
/// In runtime mode, buttons drive the simulation and lamps/fields read it —
/// exactly the loop students test on the real panel.
struct HmiView: View {
    var hmi: HmiDevice
    var tags: [PlcTag]
    var counterInstances: [String]
    @ObservedObject var sim: Simulator
    var onChange: (HmiDevice) -> Void

    @State private var runtime = false
    @State private var selectedID: UUID?
    @State private var showProps = false

    private let canvasW: CGFloat = 350
    private let canvasH: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            bar
            GeometryReader { geo in
                let scale = min((geo.size.width - 16) / canvasW, (geo.size.height - 16) / canvasH)
                ZStack {
                    Color(white: 0.13).ignoresSafeArea()
                    ZStack {
                        Rectangle().fill(Color(red: 0.93, green: 0.95, blue: 0.96))
                        ForEach(hmi.screens[0].elements) { el in elementView(el, scale: scale) }
                    }
                    .frame(width: canvasW * scale, height: canvasH * scale)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            if let el = selected, !runtime {
                HStack(spacing: 10) {
                    Text(el.text.isEmpty ? el.kind.rawValue : el.text).font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
                    Text(el.tag).font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Button("Properties") { showProps = true }.font(.system(size: 12))
                    Button(role: .destructive) { deleteSelected() } label: { Image(systemName: "trash") }
                }
                .padding(.horizontal, 10).padding(.vertical, 6).background(Tia.pane)
            }
        }
        .sheet(isPresented: $showProps) { if let el = selected { propsSheet(el) } }
    }

    private var selected: HmiElement? { hmi.screens[0].elements.first(where: { $0.id == selectedID }) }

    private var bar: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle").foregroundColor(Tia.textDark)
            Text("\(hmi.name) · \(hmi.screens[0].name)").font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
            Text(hmi.panel).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Picker("", selection: $runtime) {
                Text("Design").tag(false)
                Text("Runtime").tag(true)
            }
            .pickerStyle(.segmented).frame(width: 150)
            if !runtime {
                Menu {
                    Button("Button") { add(.button) }
                    Button("Lamp / symbolic field") { add(.lamp) }
                    Button("I/O field") { add(.ioField) }
                    Button("Bar") { add(.bar) }
                    Button("Text field") { add(.textLabel) }
                } label: { Label("Add", systemImage: "plus").font(.system(size: 12)) }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Tia.toolbar)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    @ViewBuilder private func elementView(_ el: HmiElement, scale: CGFloat) -> some View {
        let isSel = selectedID == el.id && !runtime
        Group {
            switch el.kind {
            case .button:
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(runtime && (sim.values[el.tag] ?? false) ? Tia.accent : Color(white: 0.85))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.45), lineWidth: 1))
                    Text(el.text).font(.system(size: 12 * scale + 3, weight: .bold))
                        .foregroundColor(runtime && (sim.values[el.tag] ?? false) ? .white : Tia.textDark)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in if runtime { sim.setInput(el.tag, true) } }
                    .onEnded { _ in if runtime { sim.setInput(el.tag, false) } })
            case .lamp:
                let on = sim.values[el.tag] ?? false
                HStack(spacing: 5) {
                    Circle().fill(on ? lampColor(el.colorOn) : Color(white: 0.75))
                        .frame(width: 14 * scale + 4, height: 14 * scale + 4)
                        .overlay(Circle().stroke(Color(white: 0.45), lineWidth: 0.8))
                    Text(el.text).font(.system(size: 11 * scale + 3)).foregroundColor(Tia.textDark)
                }
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.6), lineWidth: 0.7)))
            case .ioField:
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(white: 0.45), lineWidth: 1))
                    Text("\(sim.counts[el.tag] ?? (sim.values[el.tag] == true ? 1 : 0))")
                        .font(.system(size: 15 * scale + 4, weight: .semibold, design: .monospaced))
                        .foregroundColor(Tia.textDark)
                }
            case .bar:
                let pv = max(sim.counterPV(el.tag), 1)
                let frac = min(Double(sim.counts[el.tag] ?? 0) / Double(pv), 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(el.text).font(.system(size: 10 * scale + 2)).foregroundColor(Tia.textDark)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white).overlay(Rectangle().stroke(Color(white: 0.45), lineWidth: 0.8))
                        Rectangle().fill(Tia.runGreen).frame(width: CGFloat(frac) * (el.w * scale - 2))
                    }
                }
            case .textLabel:
                Text(el.text).font(.system(size: 13 * scale + 3, weight: .semibold)).foregroundColor(Tia.textDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: el.w * scale, height: el.h * scale)
        .overlay(isSel ? Rectangle().stroke(Tia.accent, lineWidth: 2) : nil)
        .position(x: (el.x + el.w / 2) * scale, y: (el.y + el.h / 2) * scale)
        .onTapGesture { if !runtime { selectedID = el.id } }
        .gesture(DragGesture()
            .onChanged { v in if !runtime { move(el, dx: v.translation.width / scale, dy: v.translation.height / scale) } }
            .onEnded { _ in dragStart = nil })
    }

    private func lampColor(_ name: String) -> Color {
        switch name { case "red": return .red; case "orange": return .orange; case "blue": return Tia.accent; default: return Tia.runGreen }
    }

    @State private var dragStart: (id: UUID, x: Double, y: Double)?

    private func move(_ el: HmiElement, dx: Double, dy: Double) {
        selectedID = el.id
        if dragStart?.id != el.id { dragStart = (el.id, el.x, el.y) }
        guard let base = dragStart else { return }
        var h = hmi
        if let i = h.screens[0].elements.firstIndex(where: { $0.id == el.id }) {
            h.screens[0].elements[i].x = min(max(0, base.x + dx), Double(canvasW) - el.w)
            h.screens[0].elements[i].y = min(max(0, base.y + dy), Double(canvasH) - el.h)
            onChange(h)
        }
    }

    private func add(_ kind: HmiElementKind) {
        var h = hmi
        var el = HmiElement(kind: kind)
        el.x = 20 + Double(h.screens[0].elements.count % 5) * 14
        el.y = 20 + Double(h.screens[0].elements.count % 5) * 14
        switch kind {
        case .button: el.text = "Button"; el.tag = tags.first(where: { $0.address.hasPrefix("%I") })?.name ?? ""
        case .lamp: el.text = "Lamp"; el.tag = tags.first(where: { $0.address.hasPrefix("%Q") })?.name ?? ""
        case .ioField: el.text = "Value"; el.tag = counterInstances.first ?? ""; el.w = 110; el.h = 40
        case .bar: el.text = "Bar"; el.tag = counterInstances.first ?? ""; el.w = 170; el.h = 36
        case .textLabel: el.text = "Text"; el.w = 150; el.h = 24
        }
        h.screens[0].elements.append(el)
        selectedID = el.id
        onChange(h)
    }

    private func deleteSelected() {
        guard let id = selectedID else { return }
        var h = hmi
        h.screens[0].elements.removeAll { $0.id == id }
        selectedID = nil
        onChange(h)
    }

    private func propsSheet(_ el: HmiElement) -> some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Text", text: binding(el, \.text))
                }
                Section("Tag binding") {
                    if el.kind == .ioField || el.kind == .bar {
                        Picker("Counter instance", selection: binding(el, \.tag)) {
                            Text("—").tag("")
                            ForEach(counterInstances, id: \.self) { Text($0).tag($0) }
                        }
                    } else if el.kind != .textLabel {
                        Picker("PLC tag", selection: binding(el, \.tag)) {
                            Text("—").tag("")
                            ForEach(tags) { t in Text("\(t.name)  \(t.address)").tag(t.name) }
                        }
                    } else {
                        Text("Text fields have no tag binding.").foregroundColor(.secondary)
                    }
                }
                if el.kind == .lamp {
                    Section("Lamp colour when ON") {
                        Picker("Colour", selection: binding(el, \.colorOn)) {
                            Text("Green").tag("green"); Text("Red").tag("red")
                            Text("Orange").tag("orange"); Text("Blue").tag("blue")
                        }
                    }
                }
                Section("Size") {
                    Stepper("Width: \(Int(el.w))", value: binding(el, \.w), in: 40...300, step: 6)
                    Stepper("Height: \(Int(el.h))", value: binding(el, \.h), in: 18...120, step: 4)
                }
            }
            .navigationTitle("Properties")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showProps = false } } }
        }
    }

    private func binding(_ el: HmiElement, _ kp: WritableKeyPath<HmiElement, String>) -> Binding<String> {
        Binding(get: { hmi.screens[0].elements.first(where: { $0.id == el.id })?[keyPath: kp] ?? "" },
                set: { v in update(el) { $0[keyPath: kp] = v } })
    }
    private func binding(_ el: HmiElement, _ kp: WritableKeyPath<HmiElement, Double>) -> Binding<Double> {
        Binding(get: { hmi.screens[0].elements.first(where: { $0.id == el.id })?[keyPath: kp] ?? 0 },
                set: { v in update(el) { $0[keyPath: kp] = v } })
    }
    private func update(_ el: HmiElement, _ change: (inout HmiElement) -> Void) {
        var h = hmi
        if let i = h.screens[0].elements.firstIndex(where: { $0.id == el.id }) {
            change(&h.screens[0].elements[i])
            onChange(h)
        }
    }
}
