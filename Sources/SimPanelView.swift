import SwiftUI

/// S7-PLCSIM panel — styled after the real PLCSIM compact window:
/// power, RUN/STOP, and the I/Q watch area where students drive the inputs.
struct SimPanelView: View {
    let device: PlcDevice
    @EnvironmentObject var sim: Simulator
    @Environment(\.dismiss) private var dismiss

    private var inputs: [PlcTag] { device.tags.filter { $0.address.hasPrefix("%I") } }
    private var outputs: [PlcTag] { device.tags.filter { $0.address.hasPrefix("%Q") } }
    private var memory: [PlcTag] { device.tags.filter { $0.address.hasPrefix("%M") } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "cpu.fill").foregroundColor(Tia.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("S7-PLCSIM").font(.system(size: 14, weight: .bold))
                    Text("\(device.name) — \(device.cpuName)").font(.system(size: 10.5)).foregroundColor(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(10)
            .background(Tia.paneHeader)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                // controls, like the PLCSIM compact view
                VStack(spacing: 12) {
                    Button {
                        sim.attach(device)
                        sim.power(!sim.powered)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "power").font(.system(size: 20))
                                .foregroundColor(sim.powered ? Tia.runGreen : .secondary)
                            Text(sim.powered ? "Power on" : "Power off").font(.system(size: 9.5))
                        }
                        .frame(width: 74, height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 0) {
                        modeButton("RUN", active: sim.running && sim.powered, color: Tia.runGreen) { sim.run(true) }
                        modeButton("STOP", active: !sim.running && sim.powered, color: Tia.errorRed) { sim.run(false) }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.8))
                    Text(sim.powered ? (sim.running ? "CPU in RUN" : "CPU in STOP") : "CPU is off")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(sim.running && sim.powered ? Tia.runGreen : .secondary)
                    Button("Reset values") { sim.reset() }.font(.system(size: 10.5))
                    if !sim.counts.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Counters").font(.system(size: 10, weight: .semibold))
                            ForEach(sim.counts.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                Text("\(k): CV = \(v)").font(.system(size: 10.5))
                            }
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .frame(width: 128)
                .background(Tia.pane)
                Divider()
                // watch area
                ScrollView {
                    HStack(alignment: .top, spacing: 14) {
                        watchColumn("Inputs", tags: inputs, isInput: true)
                        watchColumn("Outputs", tags: outputs, isInput: false)
                        if !memory.isEmpty { watchColumn("Memory", tags: memory, isInput: false) }
                    }
                    .padding(10)
                }
                .background(Color.white)
            }
        }
        .onAppear { sim.attach(device) }
    }

    private func modeButton(_ title: String, active: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .bold))
                .frame(width: 52, height: 30)
                .background(active ? color.opacity(0.25) : Color.white)
                .foregroundColor(active ? color : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!sim.powered)
    }

    private func watchColumn(_ title: String, tags: [PlcTag], isInput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11.5, weight: .bold))
            ForEach(tags) { t in
                HStack(spacing: 7) {
                    if isInput {
                        Toggle("", isOn: Binding(
                            get: { sim.values[t.name] ?? false },
                            set: { sim.setInput(t.name, $0) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                            .disabled(!sim.powered)
                    } else {
                        Circle()
                            .fill((sim.values[t.name] ?? false) ? Tia.runGreen : Color.gray.opacity(0.35))
                            .frame(width: 13, height: 13)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t.name).font(.system(size: 11.5))
                        Text(t.address).font(.system(size: 9.5)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(width: 168)
                Divider()
            }
        }
    }
}
