import SwiftUI

// MARK: - Device configuration (v3 — built to the approved wireframe)
//
// Device view: the rack drawn on the blue-grey device background, the
// Device overview table underneath, and the detail tabs (Properties /
// IO tags / System constants / Texts) for the selected module. CPU LEDs
// are live from PLCSIM in online mode. Nothing is ever crushed: the
// rack and the table scroll horizontally.

struct DeviceConfigView: View {
    @Binding var device: PlcDevice
    @ObservedObject var sim: Simulator
    var online: Bool
    @State private var selectedId: UUID? = nil
    @State private var detailTab = 0
    @State private var viewTab = 0

    private var selected: PlcModule? {
        device.modules.first { $0.id == selectedId } ?? device.modules.first
    }
    private var live: Bool { online && sim.powered }

    var body: some View {
        VStack(spacing: 0) {
            viewTabs
            if viewTab == 0 {
                rackArea
                overviewTable
                detailArea
            } else {
                VStack(spacing: 6) {
                    Image(systemName: viewTab == 1 ? "network" : "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 26)).foregroundColor(.secondary)
                    Text(viewTab == 1 ? "Network view — the CPU and the KTP700 are connected over PROFINET (HMI_Connection_1)."
                                      : "Topology view — port-to-port interconnections are a PC exercise; the training build covers the Device view.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tia.rackBG)
            }
        }
        .background(Tia.rackBG)
        .onAppear { if selectedId == nil { selectedId = device.modules.first?.id } }
    }

    private var viewTabs: some View {
        HStack(spacing: 2) {
            ForEach(Array(["Device view", "Network view", "Topology view"].enumerated()), id: \.offset) { i, t in
                Button { viewTab = i } label: {
                    Text(t).font(.system(size: 11.5, weight: viewTab == i ? .semibold : .regular))
                        .foregroundColor(Tia.textDark)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(viewTab == i ? Color.white : Tia.paneHeader)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("PLC_1").font(.system(size: 11.5, weight: .semibold)).foregroundColor(Tia.textDark)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(Tia.pane)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    // MARK: Rack

    private var rackArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(Color(red: 0.55, green: 0.58, blue: 0.62))
                    .frame(height: 8)
                    .overlay(Text("Rail").font(.system(size: 8)).foregroundColor(.white), alignment: .leading)
                HStack(alignment: .top, spacing: 5) {
                    ForEach(device.modules) { m in
                        moduleCard(m)
                    }
                    emptySlot(1)
                    emptySlot(2)
                }
            }
            .padding(10)
        }
        .frame(height: 148)
        .background(Tia.rackBG)
    }

    private func moduleCard(_ m: PlcModule) -> some View {
        let isCPU = m.slot == 1
        let sel = selected?.id == m.id
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(m.slot)").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                Spacer()
                if isCPU {
                    HStack(spacing: 4) {
                        led("RUN", on: live && sim.running, color: Tia.runGreen)
                        led("STOP", on: live && !sim.running, color: .orange)
                        led("ERR", on: false, color: Tia.errorRed)
                    }
                }
            }
            Text(isCPU ? device.cpuName : m.name)
                .font(.system(size: 9.5, weight: .bold)).foregroundColor(.white)
                .lineLimit(3)
            Spacer()
            if isCPU {
                Text("TIA PHONE").font(.system(size: 8, weight: .heavy)).foregroundColor(Tia.siemensTeal)
                Text(device.article).font(.system(size: 7.5)).foregroundColor(.white.opacity(0.8)).lineLimit(1)
            } else {
                Text(m.iAddress.isEmpty ? "" : "I \(m.iAddress)")
                    .font(.system(size: 8)).foregroundColor(.white.opacity(0.85))
                Text(m.qAddress.isEmpty ? "" : "Q \(m.qAddress)")
                    .font(.system(size: 8)).foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(6)
        .frame(width: isCPU ? 108 : 82, height: 112)
        .background(isCPU ? Tia.cpuDark : Tia.moduleBlue)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(sel ? Tia.accent : Color.white.opacity(0.35), lineWidth: sel ? 2 : 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onTapGesture { selectedId = m.id }
    }

    private func led(_ label: String, on: Bool, color: Color) -> some View {
        VStack(spacing: 1) {
            Circle().fill(on ? color : Color.white.opacity(0.25)).frame(width: 7, height: 7)
            Text(label).font(.system(size: 6)).foregroundColor(.white.opacity(0.8))
        }
    }

    private func emptySlot(_ n: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "plus").font(.system(size: 15)).foregroundColor(.secondary)
            Text("Empty").font(.system(size: 9)).foregroundColor(.secondary)
            Text("add from Catalog").font(.system(size: 7.5)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 82, height: 112)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundColor(.secondary))
    }

    // MARK: Device overview

    private var overviewTable: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Device overview")
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    overviewRow(cells: ["Module", "Rack", "Slot", "I address", "Q address", "Type", "Article no.", "Firmware"], header: true, m: nil)
                    ForEach(device.modules) { m in
                        overviewRow(cells: [m.name, "0", "\(m.slot)", m.iAddress, m.qAddress,
                                            m.slot == 1 ? device.cpuName : m.name, m.article, m.firmware],
                                    header: false, m: m)
                    }
                }
            }
        }
        .background(Color.white)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    private func overviewRow(cells: [String], header: Bool, m: PlcModule?) -> some View {
        let widths: [CGFloat] = [170, 44, 44, 76, 76, 170, 168, 70]
        let sel = m != nil && selected?.id == m?.id
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(c)
                    .font(.system(size: 11, weight: header ? .bold : .regular))
                    .foregroundColor(Tia.textDark)
                    .lineLimit(1)
                    .frame(width: widths[i], alignment: .leading)
                    .padding(.horizontal, 5)
            }
        }
        .padding(.vertical, 3)
        .background(header ? Tia.paneHeader : (sel ? Tia.selection : Color.white))
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Tia.border.opacity(0.5)), alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { if let m { selectedId = m.id } }
    }

    // MARK: Detail tabs

    private var detailArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(Array(["Properties", "IO tags", "System constants", "Texts"].enumerated()), id: \.offset) { i, t in
                    Button { detailTab = i } label: {
                        Text(t).font(.system(size: 11, weight: detailTab == i ? .semibold : .regular))
                            .foregroundColor(Tia.textDark)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(detailTab == i ? Color.white : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Tia.paneHeader)
            ScrollView {
                detailContent
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 96)
            .background(Color.white)
        }
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .top)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch detailTab {
        case 0:
            VStack(alignment: .leading, spacing: 3) {
                if let m = selected {
                    detailRow("Name", m.slot == 1 ? "PLC_1" : m.name)
                    detailRow("Type", m.slot == 1 ? device.cpuName : m.name)
                    detailRow("Article no.", m.slot == 1 ? device.article : m.article)
                    detailRow("Firmware", m.slot == 1 ? device.firmware : m.firmware)
                    detailRow("Slot", "\(m.slot) · Rack 0")
                }
            }
        case 1:
            VStack(alignment: .leading, spacing: 2) {
                if device.tags.isEmpty {
                    Text("No tags yet — add them in the PLC tag table.").font(.system(size: 11.5)).foregroundColor(.secondary)
                }
                ForEach(device.tags) { t in
                    HStack(spacing: 8) {
                        Text(t.address).font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Tia.labelTeal).frame(width: 56, alignment: .leading)
                        Text(t.name).font(.system(size: 11.5)).foregroundColor(Tia.textDark)
                        Text(t.dataType).font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 3) {
                ForEach(device.modules) { m in
                    detailRow("Local~\(m.name)", m.slot == 1 ? "CPU" : "Module")
                }
                detailRow("Local~Common", "System")
            }
        default:
            VStack(alignment: .leading, spacing: 3) {
                detailRow("Device name", "PLC_1")
                detailRow("Comment", "Training station — S7-1200")
            }
        }
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(k).font(.system(size: 11.5, weight: .semibold)).foregroundColor(Tia.textDark)
                .frame(width: 110, alignment: .leading)
            Text(v).font(.system(size: 11.5)).foregroundColor(Tia.textDark)
        }
    }
}
