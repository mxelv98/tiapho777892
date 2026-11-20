import SwiftUI

/// PLC tag table editor — the TIA grid: Name | Data type | Logical address | Comment.
struct TagTableView: View {
    @Binding var device: PlcDevice
    @State private var selected: UUID? = nil

    private let types = ["Bool", "Byte", "Word", "DWord", "Int", "DInt", "Real", "Time"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button { addTag() } label: { Label("Add new", systemImage: "plus").font(.system(size: 11)) }
                Button(role: .destructive) { deleteSelected() } label: { Label("Delete", systemImage: "trash").font(.system(size: 11)) }
                    .disabled(selected == nil)
                Spacer()
                Text("Default tag table").font(.system(size: 11, weight: .semibold))
                Text("Tags: \(device.tags.count)").font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white)
            Divider()
            HStack(spacing: 0) {
                headerCell("Name", 170)
                headerCell("Data type", 92)
                headerCell("Logical address", 118)
                headerCell("Comment", 220)
                Spacer()
            }
            .background(Tia.paneHeader)
            ScrollView(.horizontal, showsIndicators: false) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($device.tags) { $tag in
                        HStack(spacing: 0) {
                            TextField("Name", text: $tag.name)
                                .font(.system(size: 11.5)).frame(width: 170).padding(.horizontal, 5)
                            Picker("", selection: $tag.dataType) {
                                ForEach(types, id: \.self) { Text($0).font(.system(size: 11)) }
                            }
                            .pickerStyle(.menu).frame(width: 92)
                            TextField("%I0.0", text: $tag.address)
                                .font(.system(size: 11.5)).frame(width: 118).padding(.horizontal, 5)
                            TextField("Comment", text: $tag.comment)
                                .font(.system(size: 11.5)).frame(width: 220).padding(.horizontal, 5)
                            Spacer()
                        }
                        .padding(.vertical, 2.5)
                        .background(selected == tag.id ? Tia.selection : Color.white)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = tag.id }
                        Divider()
                    }
                }
                .frame(minWidth: 640)
            }
            }
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func headerCell(_ t: String, _ w: CGFloat) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold))
            .frame(width: w, alignment: .leading).padding(.horizontal, 5).padding(.vertical, 4)
    }

    private func addTag() {
        var used = Set(device.tags.compactMap { Int($0.address.filter { $0.isNumber }) })
        var bit = 0
        while used.contains(bit) { bit += 1 }
        _ = used
        device.tags.append(PlcTag(name: "Tag_\(device.tags.count + 1)", dataType: "Bool", address: "%I\(bit / 8).\(bit % 8)"))
    }

    private func deleteSelected() {
        guard let id = selected else { return }
        device.tags.removeAll { $0.id == id }
        selected = nil
    }
}
