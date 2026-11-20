import SwiftUI

/// Watch table editor — like TIA's watch tables: choose tags, monitor their
/// live values from PLCSIM, and modify (force) values to test the program.
struct WatchTableView: View {
    var tags: [PlcTag]
    var watch: [String]
    @ObservedObject var sim: Simulator
    var onChange: ([String]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "binoculars").foregroundColor(Tia.textDark)
                Text("Watch_table_1").font(.system(size: 12, weight: .semibold)).foregroundColor(Tia.textDark)
                Spacer()
                Menu {
                    ForEach(tags.filter { !watch.contains($0.name) }) { t in
                        Button("\(t.name)   \(t.address)") { onChange(watch + [t.name]) }
                    }
                } label: { Label("Add tag", systemImage: "plus").font(.system(size: 12)) }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Tia.toolbar)
            .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)

            header
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(watch.enumerated()), id: \.offset) { i, name in
                        row(i: i, name: name)
                        Rectangle().frame(height: 0.5).foregroundColor(Tia.border)
                    }
                    if watch.isEmpty {
                        Text("The watch table is empty — add tags to monitor them.")
                            .font(.system(size: 12)).foregroundColor(.secondary).padding(14)
                    }
                }
            }
            .background(Color.white)
            HStack(spacing: 6) {
                Circle().fill(sim.powered ? Tia.runGreen : Color(white: 0.7)).frame(width: 8, height: 8)
                Text(sim.powered ? (sim.running ? "Monitoring: CPU in RUN — values update every scan." : "Monitoring: CPU powered, STOP mode.")
                                  : "Monitoring offline — power the CPU in the PLCSIM panel.")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 5).background(Tia.pane)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            cell("Name", 150, bold: true); cell("Address", 70, bold: true)
            cell("Format", 60, bold: true); cell("Monitor value", 100, bold: true)
            cell("Modify", 70, bold: true); cell("", 30, bold: true)
        }
        .background(Tia.headerBand)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private func row(i: Int, name: String) -> some View {
        let tag = tags.first(where: { $0.name == name })
        let isCounter = sim.counts[name] != nil
        let isNumeric = (tag?.dataType != nil && tag?.dataType != "Bool") || (tag == nil && sim.nums[name] != nil)
        let v = sim.values[name] ?? false
        return HStack(spacing: 0) {
            cell("\"\(name)\"", 150)
            cell(tag?.address ?? "—", 70)
            cell(isCounter ? "DEC" : (isNumeric ? "DEC" : "BIN"), 60)
            HStack {
                if isCounter {
                    Text("\(sim.counts[name] ?? 0)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(Tia.tealText)
                } else if isNumeric {
                    Text(fmtNum(sim.num(name))).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(Tia.tealText)
                } else {
                    Text(v ? "TRUE" : "FALSE")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(v ? Tia.runGreen : .secondary)
                }
                Spacer()
            }.frame(width: 100).padding(.leading, 6)
            HStack {
                if isNumeric {
                    Stepper("", value: Binding(
                        get: { sim.num(name) },
                        set: { sim.setOperandNum(name, $0) }
                    ), step: tag?.dataType == "Real" ? 0.5 : 1)
                    .labelsHidden()
                } else if !isCounter {
                    Button(v ? "0" : "1") { sim.setInput(name, !v) }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Tia.toolbar)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Tia.border, lineWidth: 0.7)))
                        .foregroundColor(Tia.textDark)
                }
                Spacer()
            }.frame(width: 70).padding(.leading, 6)
            Button { var w = watch; w.remove(at: i); onChange(w) } label: {
                Image(systemName: "trash").font(.system(size: 11)).foregroundColor(.red)
            }.frame(width: 30)
        }
        .padding(.vertical, 4)
        .background(i % 2 == 1 ? Tia.pane.opacity(0.55) : Color.white)
    }

    private func fmtNum(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 100000 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func cell(_ s: String, _ w: CGFloat, bold: Bool = false) -> some View {
        Text(s).font(.system(size: 12, weight: bold ? .semibold : .regular))
            .foregroundColor(Tia.textDark)
            .frame(width: w, alignment: .leading).padding(.leading, 6).lineLimit(1)
    }
}
