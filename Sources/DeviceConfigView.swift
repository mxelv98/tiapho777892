import SwiftUI

/// Device configuration editor: "Device view" with the rack drawn like TIA,
/// and the "Device overview" table underneath.
struct DeviceConfigView: View {
    @Binding var device: PlcDevice
    @State private var selectedSlot: Int? = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Device view").font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.accent)
                Text("Network view").font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Text("Zoom 100%").font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white)
            Divider()
            // rack
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(device.modules) { m in
                        rackSlot(m)
                    }
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Tia.border, lineWidth: 1)
                            .frame(width: 54, height: 118)
                            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
                    }
                }
                .padding(10)
            }
            .frame(height: 142)
            .background(Tia.rackBG)
            Divider()
            // device overview table
            ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                tableHeader
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(device.modules) { m in
                            HStack(spacing: 0) {
                                cell(m.name, 190, bold: m.slot == 1)
                                cell("\(m.slot / 100)", 46)
                                cell("\(m.slot)", 46)
                                cell(m.iAddress, 70)
                                cell(m.qAddress, 70)
                                cell(m.slot == 1 ? device.cpuName : m.name, 190)
                                cell(m.article, 170)
                                cell(m.firmware, 70)
                                Spacer()
                            }
                            .background(selectedSlot == m.slot ? Tia.selection : Color.white)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedSlot = m.slot }
                            Divider()
                        }
                    }
                }
            }
            .frame(minWidth: 860)
            }
            .background(Color.white)
            detailsSection
        }
        .background(Color.white)
    }

    // Details view under the device view, like the real editor:
    // Properties / IO tags / System constants / Texts tabs.
    @State private var detailTab = 0

    private var detailsSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(Array(["Properties", "IO tags", "System constants", "Texts"].enumerated()), id: \.offset) { i, t in
                    Button { detailTab = i } label: {
                        Text(t).font(.system(size: 11, weight: detailTab == i ? .semibold : .regular))
                            .foregroundColor(Tia.textDark)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(detailTab == i ? Color.white : Tia.toolbar)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .background(Tia.toolbar)
            Group {
                switch detailTab {
                case 1:
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(device.tags) { t in
                                HStack(spacing: 0) {
                                    cell(t.name, 190)
                                    cell(t.dataType, 92)
                                    cell(t.address, 118)
                                    cell(t.comment, 220)
                                    Spacer()
                                }
                                Divider()
                            }
                            if device.tags.isEmpty {
                                Text("No IO tags.").font(.system(size: 11)).foregroundColor(.secondary).padding(8)
                            }
                        }
                    }
                    .frame(height: 92)
                case 2:
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Default_DI_DQ — system constant, value 16#7A0").font(.system(size: 11)).foregroundColor(Tia.textDark)
                        Text("Local — system constant of the CPU's integrated IO").font(.system(size: 11)).foregroundColor(Tia.textDark)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                case 3:
                    Text("No texts defined for this device.").font(.system(size: 11)).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                default:
                    if let m = device.modules.first(where: { $0.slot == (selectedSlot ?? 1) }) ?? device.modules.first {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Name: \(m.name)").font(.system(size: 11)).foregroundColor(Tia.textDark)
                            Text("Article no.: \(m.article.isEmpty ? "—" : m.article)   Firmware: \(m.firmware.isEmpty ? "—" : m.firmware)").font(.system(size: 11)).foregroundColor(Tia.textDark)
                            Text("I address: \(m.iAddress.isEmpty ? "—" : m.iAddress)   Q address: \(m.qAddress.isEmpty ? "—" : m.qAddress)").font(.system(size: 11)).foregroundColor(Tia.textDark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }
                }
            }
            .background(Color.white)
        }
    }

    private func rackSlot(_ m: PlcModule) -> some View {
        VStack(spacing: 2) {
            Text("\(m.slot)").font(.system(size: 8.5)).foregroundColor(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(m.slot == 1 ? Tia.cpuDark : Tia.moduleBlue)
                VStack(spacing: 3) {
                    if m.slot == 1 {
                        Text("SIEMENS").font(.system(size: 7, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Tia.siemensTeal)
                        Text("S7-1200").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                        RoundedRectangle(cornerRadius: 1).fill(Color(red: 0.2, green: 0.25, blue: 0.3)).frame(width: 34, height: 20)
                        HStack(spacing: 2) {
                            Circle().fill(Tia.runGreen).frame(width: 4, height: 4)
                            Circle().fill(Color.orange).frame(width: 4, height: 4)
                            Circle().fill(Color.gray).frame(width: 4, height: 4)
                        }
                    }
                    Text(m.slot == 1 ? "1214C" : String(m.name.prefix(9)))
                        .font(.system(size: 7.5)).foregroundColor(.white).multilineTextAlignment(.center)
                }
                .padding(3)
            }
            .frame(width: 54, height: 96)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(selectedSlot == m.slot ? Tia.accent : Tia.border, lineWidth: selectedSlot == m.slot ? 2 : 0.7))
        }
        .onTapGesture { selectedSlot = m.slot }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            cell("Module", 190, bold: true)
            cell("Rack", 46, bold: true)
            cell("Slot", 46, bold: true)
            cell("I address", 70, bold: true)
            cell("Q address", 70, bold: true)
            cell("Type", 190, bold: true)
            cell("Article no.", 170, bold: true)
            cell("Firmware", 70, bold: true)
            Spacer()
        }
        .background(Tia.paneHeader)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }

    private func cell(_ text: String, _ width: CGFloat, bold: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, weight: bold ? .semibold : .regular))
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .lineLimit(1)
    }
}
