import SwiftUI

// TIA Portal V16 chrome: light gray panes, white editors, blue selection,
// petrol accent. Text is drawn by us — no Siemens assets.
enum Tia {
    static let pane = Color(red: 0.94, green: 0.94, blue: 0.95)          // #F0F0F2-ish
    static let paneHeader = Color(red: 0.89, green: 0.90, blue: 0.92)
    static let border = Color(red: 0.72, green: 0.73, blue: 0.76)
    static let selection = Color(red: 0.80, green: 0.88, blue: 0.97)     // tree/list selection
    static let accent = Color(red: 0.0, green: 0.36, blue: 0.48)         // TIA petrol blue
    static let titleBar = Color(red: 0.24, green: 0.36, blue: 0.47)
    static let editorBG = Color.white
    static let networkBar = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let online = Color(red: 1.0, green: 0.55, blue: 0.0)          // TIA online orange
    static let runGreen = Color(red: 0.13, green: 0.62, blue: 0.24)
    static let errorRed = Color(red: 0.85, green: 0.15, blue: 0.12)
    static let fontSize: CGFloat = 12
}

struct PaneHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Tia.paneHeader)
        .overlay(Rectangle().frame(height: 0.7).foregroundColor(Tia.border), alignment: .bottom)
    }
}

struct ToolbarGlyph: View {
    let system: String
    let label: String
    var active: Bool = false
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: system).font(.system(size: 15))
                Text(label).font(.system(size: 8.5)).lineLimit(1)
            }
            .frame(width: 52, height: 34)
            .background(active ? Tia.selection : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(active ? Tia.accent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
}

extension View {
    func tiaPane() -> some View {
        background(Tia.pane)
            .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .leading)
    }
}
