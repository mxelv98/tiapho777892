import SwiftUI

// MARK: - PLCSIM panel (v3 — built to the approved wireframe)
//
// Like S7-PLCSIM: a CPU control card (power, RUN/STOP, LEDs, MRES) and
// the SIM table — monitor every tag live, modify inputs and memory.
// Outputs are monitor-only; in the real tool you change them through
// the program, and the training build keeps that rule.

struct SimPanelView: View {
    var device: PlcDevice
    @ObservedObject var sim: Simulator

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(spacing: 0) {
                    cpuCard.frame(width: 210)
                    Divider()
                    simTable
                }
            } else {
                VStack(spacing: 0) {
                    cpuCard
                    Divider()
                    simTable
                }
            }
        }
        .background(Color.white)
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu").font(.system(size: 14)).foregroundColor(Tia.textDark)
                VStack(alignment: .leading, spacing: 0) {
                    Text("PLC_1").font(.system(size: 12.5, weight: .bold)).foregroundColor(Tia.textDark)
                    Text(device.cpuName).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            HStack(spacing: 6) {
                simButton(sim.powered ? "Power ON" : "Power OFF", icon: "power",
                          color: sim.powered ? Tia.runGreen : Color.gray) {
                    sim.power(!sim.powered)
                }
            }
            HStack(spacing: 6) {
                simButton("RUN", icon: "play.fill", color: sim.running ? Tia.runGreen : Tia.paneHeader,
                          dark: !sim.running) {
                    if sim.powered { sim.run(true) }
                }
                simButton("STOP", icon: "stop.fill", color: !sim.running && sim.powered ? .orange : Tia.paneHeader,
                          dark: sim.running || !sim.powered) {
                    if sim.powered { sim.run(false) }
                }
            }
            HStack(spacing: 10) {
                cpuLed("RUN", on: sim.powered && sim.running, color: Tia.runGreen)
                cpuLed("STOP", on: sim.powered && !sim.running, color: .orange)
                cpuLed("ERROR", on: false, color: Tia.errorRed)
                cpuLed("MAINT", on: false, color: .yellow)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan: 100ms").font(.system(size: 11)).foregroundColor(Tia.textDark)
                Text("Mode: PLCSIM (training)").font(.system(size: 11)).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                simButton("MRES", icon: "arrow.counterclockwise", color: Tia.paneHeader, dark: true) {
                    sim.reset()
                }
                simButton("Reset values", icon: "eraser", color: Tia.paneHeader, dark: true) {
                    sim.reset()
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Tia.pane)
    }

    private func simButton(_ label: String, icon: String, color: Color, dark: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(dark ? Tia.textDark : .white)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(color)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    private func cpuLed(_ label: String, on: Bool, color: Color) -> some View {
        VStack(spacing: 2) {
            Circle().fill(on ? color : Color.gray.opacity(0.3)).frame(width: 10, height: 10)
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundColor(Tia.textDark)
        }
    }

    private var simTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tableCell("Name", w: 130, bold: true)
                tableCell("Address", w: 64, bold: true)
                tableCell("Monitor", w: 92, bold: true)
                tableCell("Modify", w: 110, bold: true)
                Spacer()
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Tia.paneHeader)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(device.tags) { t in
                        simRow(t)
                    }
                }
            }
            Text("Modified values affect the simulation only — no connection to a real PLC.")
                .font(.system(size: 10)).foregroundColor(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tia.pane)
        }
    }

    private func simRow(_ t: PlcTag) -> some View {
        let value = sim.values[t.name] ?? false
        let isOutput = t.address.hasPrefix("%Q")
        return HStack(spacing: 0) {
            tableCell(t.name, w: 130)
            tableCell(t.address, w: 64)
            HStack(spacing: 5) {
                Circle().fill(value ? Tia.onlineTrue : Color.gray.opacity(0.35)).frame(width: 9, height: 9)
                Text(value ? "TRUE" : "FALSE")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Tia.textDark)
            }
            .frame(width: 92, alignment: .leading)
            if isOutput {
                Text("(output)").font(.system(size: 10.5)).foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
            } else {
                Toggle("", isOn: Binding(
                    get: { sim.values[t.name] ?? false },
                    set: { sim.setInput(t.name, $0) }
                ))
                .labelsHidden()
                .frame(width: 110, alignment: .leading)
            }
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Tia.border.opacity(0.45)), alignment: .bottom)
    }

    private func tableCell(_ s: String, w: CGFloat, bold: Bool = false) -> some View {
        Text(s)
            .font(.system(size: 11.5, weight: bold ? .bold : .regular))
            .foregroundColor(Tia.textDark)
            .lineLimit(1)
            .frame(width: w, alignment: .leading)
    }
}

// MARK: - Compact PLCSIM strip (portrait bottom-sheet tab)

struct SimStripView: View {
    var device: PlcDevice
    @ObservedObject var sim: Simulator
    var onExpand: () -> Void

    private var quickInputs: [PlcTag] {
        Array(device.tags.filter { $0.address.hasPrefix("%I") }.prefix(3))
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { sim.power(!sim.powered) } label: {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(sim.powered ? Tia.runGreen : .gray)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Tia.border, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            Button { if sim.powered { sim.run(!sim.running) } } label: {
                HStack(spacing: 4) {
                    Circle().fill(sim.powered ? (sim.running ? Tia.runGreen : .orange) : .gray)
                        .frame(width: 8, height: 8)
                    Text(sim.powered ? (sim.running ? "RUN" : "STOP") : "OFF")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundColor(Tia.textDark)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            Divider().frame(height: 30)
            ForEach(quickInputs) { t in
                VStack(spacing: 1) {
                    Toggle("", isOn: Binding(
                        get: { sim.values[t.name] ?? false },
                        set: { sim.setInput(t.name, $0) }
                    ))
                    .labelsHidden()
                    Text(shortAddr(t.address)).font(.system(size: 8.5)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: onExpand) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13)).foregroundColor(Tia.accent)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shortAddr(_ a: String) -> String {
        a.replacingOccurrences(of: "%", with: "")
    }
}
