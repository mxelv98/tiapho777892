import SwiftUI

/// LAD editor — networks drawn the way TIA draws them: title bar, comment,
/// power rail on the left, contacts / coils / boxes on the rung.
struct LadEditorView: View {
    @Binding var device: PlcDevice
    let blockIndex: Int
    @Binding var selectedNetwork: Int
    @EnvironmentObject var sim: Simulator
    @State private var editing: (network: Int, element: UUID, isOutput: Bool)? = nil

    private var block: PlcBlock { device.blocks[blockIndex] }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(block.name) (\(block.type)\(block.number))").font(.system(size: 12, weight: .semibold))
                Text("Number: \(block.number)   Type: \(block.type)   Language: LAD").font(.system(size: 10.5)).foregroundColor(.secondary)
                Spacer()
                Text("Favorites:").font(.system(size: 10.5)).foregroundColor(.secondary)
                favButton("contact", .contactNO)
                favButton("nc", .contactNC)
                favButton("coil", .coil)
                favButton("box", .ton)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white)
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(block.networks.enumerated()), id: \.element.id) { ni, net in
                        networkView(ni, net)
                    }
                    Button {
                        device.blocks[blockIndex].networks.append(LadNetwork(title: ""))
                    } label: {
                        Label("Add network", systemImage: "plus").font(.system(size: 11.5))
                    }
                    .padding(.bottom, 12)
                }
                .padding(8)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        }
        .background(Color.white)
        .sheet(item: editingBinding) { ctx in
            ElementEditor(device: $device, blockIndex: blockIndex, network: ctx.network,
                          elementID: ctx.element, isOutput: ctx.isOutput)
        }
    }

    private var editingBinding: Binding<EditingContext?> {
        Binding(
            get: { editing.map { EditingContext(network: $0.network, element: $0.element, isOutput: $0.isOutput) } },
            set: { editing = $0.map { ($0.network, $0.element, $0.isOutput) } }
        )
    }

    private func favButton(_ label: String, _ kind: LadElementKind) -> some View {
        Button { addElement(kind, to: min(selectedNetwork, block.networks.count - 1)) } label: {
            Text(label).font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: network rendering

    private func networkView(_ ni: Int, _ net: LadNetwork) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Network \(ni + 1):").font(.system(size: 11.5, weight: .bold))
                TextField("Title", text: titleBinding(ni)).font(.system(size: 11.5))
                Spacer()
                Button { selectedNetwork = ni } label: {
                    Text(selectedNetwork == ni ? "● selected" : "select").font(.system(size: 9.5)).foregroundColor(Tia.accent)
                }
                Button(role: .destructive) {
                    device.blocks[blockIndex].networks.remove(at: ni)
                } label: { Image(systemName: "trash").font(.system(size: 10.5)) }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selectedNetwork == ni ? Tia.selection : Tia.networkBar)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    rungRow(ni, elements: net.series, output: net.output, isBranch: false)
                    if !net.parallel.isEmpty {
                        rungRow(ni, elements: net.parallel, output: nil, isBranch: true)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
            HStack(spacing: 8) {
                Menu {
                    Button("Contact (NO)") { addElement(.contactNO, to: ni) }
                    Button("Contact (NC)") { addElement(.contactNC, to: ni) }
                    Button("TON timer") { addElement(.ton, to: ni) }
                    Button("CTU counter") { addElement(.ctu, to: ni) }
                    Button("Parallel contact (NO)") { addParallel(.contactNO, to: ni) }
                    Button("Parallel contact (NC)") { addParallel(.contactNC, to: ni) }
                } label: {
                    Label("Add element", systemImage: "plus.circle").font(.system(size: 10.5))
                }
                Menu {
                    Button("Coil") { setOutput(.coil, ni) }
                    Button("Set coil (S)") { setOutput(.coilSet, ni) }
                    Button("Reset coil (R)") { setOutput(.coilReset, ni) }
                    Button("TON timer") { setOutput(.ton, ni) }
                    Button("CTU counter") { setOutput(.ctu, ni) }
                } label: {
                    Label("Output: \(block.networks[ni].output.kind.rawValue)", systemImage: "arrow.right.circle").font(.system(size: 10.5))
                }
                Spacer()
            }
            .padding(.horizontal, 8).padding(.bottom, 5)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.8))
    }

    private func rungRow(_ ni: Int, elements: [LadElement], output: LadElement?, isBranch: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(Color.black).frame(width: 2, height: 46)
            wire
            ForEach(elements) { el in
                elementView(ni, el, isOutput: false)
                wire
            }
            if let out = output {
                elementView(ni, out, isOutput: true)
                wire
                Rectangle().fill(Color.black).frame(width: 2, height: 46)
            }
        }
    }

    private var wire: some View { Rectangle().fill(Color.black).frame(width: 12, height: 1.6).padding(.top, 22) }

    @ViewBuilder private func elementView(_ ni: Int, _ el: LadElement, isOutput: Bool) -> some View {
        let live = sim.powered && (sim.values[el.tag] ?? false)
        VStack(spacing: 1) {
            Text(el.kind == .ton || el.kind == .ctu ? el.instance : el.tag)
                .font(.system(size: 9.5)).foregroundColor(Tia.accent).lineLimit(1).frame(height: 12)
            Group {
                switch el.kind {
                case .contactNO: contactShape(nc: false, live: live)
                case .contactNC: contactShape(nc: true, live: live)
                case .coil, .coilSet, .coilReset: coilShape(el, live: live)
                case .ton, .ctu: boxShape(el, live: live)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(editing?.element == el.id ? Tia.accent : Color.clear, lineWidth: 1.4))
            Text(subLabel(el)).font(.system(size: 8.5)).foregroundColor(.secondary).frame(height: 10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNetwork = ni
            editing = (ni, el.id, isOutput)
        }
    }

    private func subLabel(_ el: LadElement) -> String {
        switch el.kind {
        case .ton: return el.tag
        case .ctu: return el.inputTag.isEmpty ? el.tag : "\(el.inputTag) → \(el.tag)"
        default: return ""
        }
    }

    private func contactShape(nc: Bool, live: Bool) -> some View {
        ZStack {
            Rectangle().fill(live ? Tia.runGreen : Color.black).frame(width: 40, height: 1.6)
            HStack(spacing: 10) {
                Rectangle().fill(Color.black).frame(width: 2, height: 20)
                Rectangle().fill(Color.black).frame(width: 2, height: 20)
            }
            if nc {
                Path { p in
                    p.move(to: CGPoint(x: 6, y: 20)); p.addLine(to: CGPoint(x: 34, y: 2))
                }.stroke(Color.black, lineWidth: 1.6).frame(width: 40, height: 22)
            }
        }
        .frame(width: 44, height: 24)
    }

    private func coilShape(_ el: LadElement, live: Bool) -> some View {
        ZStack {
            Rectangle().fill(live ? Tia.runGreen : Color.black).frame(width: 40, height: 1.6)
            Path { p in
                p.addArc(center: CGPoint(x: 14, y: 11), radius: 10, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            }.stroke(Color.black, lineWidth: 1.6).frame(width: 40, height: 22)
            Path { p in
                p.addArc(center: CGPoint(x: 26, y: 11), radius: 10, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
            }.stroke(Color.black, lineWidth: 1.6).frame(width: 40, height: 22)
            if el.kind == .coilSet { Text("S").font(.system(size: 10, weight: .bold)) }
            if el.kind == .coilReset { Text("R").font(.system(size: 10, weight: .bold)) }
        }
        .frame(width: 44, height: 24)
    }

    private func boxShape(_ el: LadElement, live: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(el.kind == .ton ? "TON" : "CTU").font(.system(size: 9, weight: .bold))
                Spacer()
                Text(el.kind == .ton ? "Time" : "Counter").font(.system(size: 7.5)).foregroundColor(.secondary)
            }
            HStack {
                Text(el.kind == .ton ? "IN" : "CU").font(.system(size: 8.5))
                Spacer()
                Text("Q").font(.system(size: 8.5))
                Circle().fill(live ? Tia.runGreen : Color.gray.opacity(0.4)).frame(width: 6, height: 6)
            }
            HStack {
                Text(el.kind == .ton ? "PT" : "PV").font(.system(size: 8.5))
                Spacer()
                Text(el.preset).font(.system(size: 8.5, weight: .semibold))
            }
        }
        .padding(4)
        .frame(width: 86)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.black, lineWidth: 1.1))
        .background(Color.white)
    }

    // MARK: edits

    private func titleBinding(_ ni: Int) -> Binding<String> {
        Binding(
            get: {
                let nets = device.blocks[blockIndex].networks
                return nets.indices.contains(ni) ? nets[ni].title : ""
            },
            set: { v in
                if device.blocks[blockIndex].networks.indices.contains(ni) {
                    device.blocks[blockIndex].networks[ni].title = v
                }
            })
    }

    private func addElement(_ kind: LadElementKind, to ni: Int) {
        guard device.blocks[blockIndex].networks.indices.contains(ni) else { return }
        var el = LadElement(kind: kind)
        if kind == .ton { el.instance = "TON_\(ni + 1)"; el.preset = "T#3s"; el.presetSeconds = 3 }
        if kind == .ctu { el.instance = "CTU_\(ni + 1)"; el.preset = "5"; el.presetValue = 5 }
        device.blocks[blockIndex].networks[ni].series.append(el)
        selectedNetwork = ni
    }

    private func addParallel(_ kind: LadElementKind, to ni: Int) {
        guard device.blocks[blockIndex].networks.indices.contains(ni) else { return }
        device.blocks[blockIndex].networks[ni].parallel.append(LadElement(kind: kind))
        selectedNetwork = ni
    }

    private func setOutput(_ kind: LadElementKind, _ ni: Int) {
        var el = LadElement(kind: kind)
        if kind == .ton { el.instance = "TON_\(ni + 1)"; el.preset = "T#3s"; el.presetSeconds = 3 }
        if kind == .ctu { el.instance = "CTU_\(ni + 1)"; el.preset = "5"; el.presetValue = 5 }
        device.blocks[blockIndex].networks[ni].output = el
    }
}

struct EditingContext: Identifiable {
    let network: Int
    let element: UUID
    let isOutput: Bool
    var id: String { "\(network)-\(element.uuidString)-\(isOutput)" }
}

/// Element editor sheet: pick the tag from the tag table, set instance and
/// preset for boxes, move or delete the element — like TIA's properties.
struct ElementEditor: View {
    @Binding var device: PlcDevice
    let blockIndex: Int
    let network: Int
    let elementID: UUID
    let isOutput: Bool
    @Environment(\.dismiss) private var dismiss

    private func find() -> (Int, Bool)? {
        let net = device.blocks[blockIndex].networks[network]
        if isOutput && net.output.id == elementID { return nil }
        if let i = net.series.firstIndex(where: { $0.id == elementID }) { return (i, false) }
        if let i = net.parallel.firstIndex(where: { $0.id == elementID }) { return (i, true) }
        return nil
    }

    private var element: LadElement? {
        let net = device.blocks[blockIndex].networks[network]
        if isOutput { return net.output }
        if let (i, par) = find() { return par ? net.parallel[i] : net.series[i] }
        return nil
    }

    private func mutate(_ f: (inout LadElement) -> Void) {
        if isOutput { f(&device.blocks[blockIndex].networks[network].output); return }
        guard let (i, par) = find() else { return }
        if par { f(&device.blocks[blockIndex].networks[network].parallel[i]) }
        else { f(&device.blocks[blockIndex].networks[network].series[i]) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let el = element {
                    Section("Operand") {
                        Picker("Tag", selection: Binding(
                            get: { el.tag }, set: { v in mutate { $0.tag = v } })) {
                            Text("(none)").tag("")
                            ForEach(device.tags) { t in Text("\(t.name)  (\(t.address))").tag(t.name) }
                        }
                        if el.kind == .contactNO || el.kind == .contactNC {
                            Picker("Contact", selection: Binding(
                                get: { el.kind }, set: { v in mutate { $0.kind = v } })) {
                                Text("Normally open  | |").tag(LadElementKind.contactNO)
                                Text("Normally closed  |/|").tag(LadElementKind.contactNC)
                            }
                        }
                    }
                    if el.kind == .ton || el.kind == .ctu {
                        Section(el.kind == .ton ? "Timer" : "Counter") {
                            TextField("Instance", text: Binding(
                                get: { el.instance }, set: { v in mutate { $0.instance = v } }))
                            if el.kind == .ton {
                                Stepper("PT: \(el.presetSeconds, specifier: "%.1f") s", value: Binding(
                                    get: { el.presetSeconds },
                                    set: { v in mutate { $0.presetSeconds = v; $0.preset = "T#\(String(format: "%.1f", v))s" } }),
                                    in: 0.5...60, step: 0.5)
                            } else {
                                Stepper("PV: \(el.presetValue)", value: Binding(
                                    get: { el.presetValue },
                                    set: { v in mutate { $0.presetValue = v; $0.preset = "\(v)" } }),
                                    in: 1...999)
                                Picker("Count input (CU)", selection: Binding(
                                    get: { el.inputTag }, set: { v in mutate { $0.inputTag = v } })) {
                                    Text("(rung power)").tag("")
                                    ForEach(device.tags) { t in Text("\(t.name)  (\(t.address))").tag(t.name) }
                                }
                            }
                        }
                    }
                    if !isOutput {
                        Section {
                            Button("Move left") { move(-1) }
                            Button("Move right") { move(1) }
                            Button("Delete element", role: .destructive) { delete(); dismiss() }
                        }
                    }
                } else {
                    Text("Element no longer exists.")
                }
            }
            .navigationTitle("Properties")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func move(_ dir: Int) {
        guard let (i, par) = find() else { return }
        if par {
            let j = i + dir
            guard device.blocks[blockIndex].networks[network].parallel.indices.contains(j) else { return }
            device.blocks[blockIndex].networks[network].parallel.swapAt(i, j)
        } else {
            let j = i + dir
            guard device.blocks[blockIndex].networks[network].series.indices.contains(j) else { return }
            device.blocks[blockIndex].networks[network].series.swapAt(i, j)
        }
    }

    private func delete() {
        if isOutput { return }
        guard let (i, par) = find() else { return }
        if par { device.blocks[blockIndex].networks[network].parallel.remove(at: i) }
        else { device.blocks[blockIndex].networks[network].series.remove(at: i) }
    }
}
