import SwiftUI

// TIA Portal V16 chrome, measured from the real application:
// light panes, dark text, light-blue selection, petrol accent,
// near-black status bar, orange title/breadcrumb bar in online mode.
enum Tia {
    static let pane = Color(red: 0.93, green: 0.93, blue: 0.94)
    static let paneHeader = Color(red: 0.88, green: 0.89, blue: 0.91)
    static let border = Color(red: 0.66, green: 0.68, blue: 0.72)
    static let selection = Color(red: 0.78, green: 0.89, blue: 1.0)      // tree/list selection #C7E3FF
    static let accent = Color(red: 0.0, green: 0.36, blue: 0.48)         // TIA petrol blue
    static let titleBar = Color(red: 0.96, green: 0.96, blue: 0.97)      // menu bar is light in V16
    static let editorBG = Color.white
    static let networkBar = Color(red: 0.90, green: 0.91, blue: 0.93)
    static let online = Color(red: 1.0, green: 0.55, blue: 0.0)          // TIA online orange
    static let runGreen = Color(red: 0.13, green: 0.62, blue: 0.24)
    static let errorRed = Color(red: 0.85, green: 0.15, blue: 0.12)
    static let statusBar = Color(red: 0.13, green: 0.13, blue: 0.14)     // TIA status bar is near-black
    static let rackBG = Color(red: 0.85, green: 0.88, blue: 0.91)        // device view background
    static let moduleBlue = Color(red: 0.45, green: 0.55, blue: 0.68)    // rack module face
    static let cpuDark = Color(red: 0.23, green: 0.28, blue: 0.33)       // CPU body
    static let siemensTeal = Color(red: 0.0, green: 0.62, blue: 0.58)    // SIEMENS label / operand address teal
    static let textDark = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let boxFill = Color(red: 0.93, green: 0.94, blue: 0.96)       // TON/CTU box fill
    static let fontSize: CGFloat = 12
    // v2 aliases used by the newer editors
    static let toolbar = Color(red: 0.95, green: 0.95, blue: 0.96)
    static let headerBand = Color(red: 0.90, green: 0.91, blue: 0.93)
    static let boxHeader = Color(red: 0.85, green: 0.87, blue: 0.90)
    static let tealText = Color(red: 0.0, green: 0.45, blue: 0.55)
    static let wire = Color(red: 0.15, green: 0.15, blue: 0.16)
    // v3 wireframe tokens (from the approved design sheets)
    static let statusBarV3 = Color(red: 0.102, green: 0.114, blue: 0.129)  // #1A1D21
    static let labelTeal = Color(red: 0.0, green: 0.482, blue: 0.541)      // #007B8A operand address
    static let nameGrey = Color(red: 0.106, green: 0.133, blue: 0.157)     // #1B2228 operand name
    static let boxFillV3 = Color(red: 0.937, green: 0.937, blue: 0.937)    // #EFEFEF timer/counter box
    static let onlineTrue = Color(red: 0.118, green: 0.620, blue: 0.290)   // #1E9E4A live wire TRUE
    static let onlineFalse = Color(red: 0.227, green: 0.482, blue: 0.835)  // #3A7BD5 live wire FALSE
    static let railWidth: CGFloat = 28
}

struct PaneHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(Tia.textDark)
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
                Image(systemName: system).font(.system(size: 15)).foregroundColor(active ? Tia.accent : Tia.textDark)
                Text(label).font(.system(size: 8.5)).lineLimit(1).foregroundColor(Tia.textDark)
            }
            .frame(width: 52, height: 34)
            .background(active ? Tia.selection : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(active ? Tia.accent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func tiaPane() -> some View {
        background(Tia.pane)
            .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .leading)
    }
}

/// Our own logo — drawn, not copied: a petrol-to-teal rounded square with a
/// white LAD rung (rail, normally-open contact, coil) and a green RUN dot.
struct LogoMark: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.25, blue: 0.34),
                                              Color(red: 0.0, green: 0.59, blue: 0.53)],
                                     startPoint: .top, endPoint: .bottom))
            GeometryReader { g in
                let w = g.size.width, h = g.size.height, mid = h * 0.46
                Path { p in
                    p.move(to: CGPoint(x: w * 0.16, y: h * 0.26)); p.addLine(to: CGPoint(x: w * 0.16, y: h * 0.66))
                    p.move(to: CGPoint(x: w * 0.84, y: h * 0.26)); p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.66))
                    p.move(to: CGPoint(x: w * 0.16, y: mid)); p.addLine(to: CGPoint(x: w * 0.33, y: mid))
                    p.move(to: CGPoint(x: w * 0.33, y: mid - h * 0.10)); p.addLine(to: CGPoint(x: w * 0.33, y: mid + h * 0.10))
                    p.move(to: CGPoint(x: w * 0.47, y: mid - h * 0.10)); p.addLine(to: CGPoint(x: w * 0.47, y: mid + h * 0.10))
                    p.move(to: CGPoint(x: w * 0.47, y: mid)); p.addLine(to: CGPoint(x: w * 0.62, y: mid))
                    p.move(to: CGPoint(x: w * 0.76, y: mid)); p.addLine(to: CGPoint(x: w * 0.84, y: mid))
                }
                .stroke(Color.white, lineWidth: max(1.6, size * 0.035))
                Path { p in
                    p.addArc(center: CGPoint(x: w * 0.665, y: mid), radius: w * 0.055, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                    p.addArc(center: CGPoint(x: w * 0.725, y: mid), radius: w * 0.055, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                }
                .stroke(Color.white, lineWidth: max(1.6, size * 0.035))
                Circle().fill(Tia.runGreen)
                    .frame(width: size * 0.13, height: size * 0.13)
                    .position(x: w * 0.5, y: h * 0.80)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Wordmark used in the Portal view and headers — our name, TIA-style layout.
struct Wordmark: View {
    var large: Bool = true
    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: large ? 46 : 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("TIA PHONE").font(.system(size: large ? 21 : 15, weight: .heavy)).foregroundColor(Tia.textDark)
                Text("Totally Integrated Automation — Training Portal")
                    .font(.system(size: large ? 10 : 8.5)).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - v3 shared chrome (from the approved wireframes)

/// A collapsed side pane: a 28pt vertical rail with the pane title written
/// vertically, exactly like V16. Tapping it reopens the pane.
struct CollapsedRail: View {
    let title: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                Text(title).font(.system(size: 10, weight: .semibold))
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .frame(width: 12, height: 130)
            }
            .foregroundColor(Tia.textDark)
            .frame(width: Tia.railWidth)
            .frame(maxHeight: .infinity)
            .background(Tia.paneHeader)
            .overlay(Rectangle().frame(width: 0.7).foregroundColor(Tia.border), alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The zoom control from the wireframes: [ − ] [ 100% ] [ + ] [ Fit ].
/// Shared by the LAD editor, the rack view and the HMI canvas.
struct ZoomHUD: View {
    @Binding var zoom: CGFloat
    var onFit: () -> Void = {}
    var body: some View {
        HStack(spacing: 0) {
            Button { zoom = max(0.5, zoom - 0.1) } label: {
                Image(systemName: "minus").frame(width: 30, height: 24)
            }
            Text("\(Int((zoom * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 48)
            Button { zoom = min(2.0, zoom + 0.1) } label: {
                Image(systemName: "plus").frame(width: 30, height: 24)
            }
            Divider().frame(height: 16)
            Button(action: onFit) {
                Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 30, height: 24)
            }
        }
        .foregroundColor(Tia.textDark)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

/// The always-visible 24pt near-black status bar (#1A1D21) from the
/// wireframes: Portal shortcut left, project + CPU state right.
struct StatusBarV3: View {
    let projectName: String
    let running: Bool
    let powered: Bool
    let online: Bool
    var onPortal: () -> Void = {}
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPortal) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 10))
                    Text("Portal view").font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            Text("|").foregroundColor(.white.opacity(0.35)).font(.system(size: 10))
            Text(projectName).font(.system(size: 10.5)).foregroundColor(.white)
            Spacer()
            if online {
                Text("ONLINE").font(.system(size: 10, weight: .bold)).foregroundColor(Tia.online)
                Text("|").foregroundColor(.white.opacity(0.35)).font(.system(size: 10))
            }
            Circle().fill(powered ? (running ? Tia.runGreen : Color.orange) : Color.gray)
                .frame(width: 8, height: 8)
            Text(powered ? (running ? "RUN" : "STOP") : "—")
                .font(.system(size: 10.5, weight: .semibold)).foregroundColor(.white)
            Text("100ms").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.75))
            Text("|").foregroundColor(.white.opacity(0.35)).font(.system(size: 10))
            Text("CPU 1214C").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Tia.statusBarV3)
    }
}
