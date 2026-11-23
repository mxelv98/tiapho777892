import SwiftUI

/// Liquid Glass design system (materials-based, iOS 16+).
/// Principles translated from the MengTo glass skills: a flat, legible glass face;
/// the light lives on the rim — a bright top edge that fades down the sides;
/// a live backdrop showing through; springy, local press feedback.
enum Glass {
    static let emerald = Color(red: 0.06, green: 0.72, blue: 0.51)
    static let gold = Color(red: 0.98, green: 0.74, blue: 0.30)
    static let ink = Color(red: 0.02, green: 0.10, blue: 0.07)

    /// The rim light: bright at the top edge, fading to a faint line at the bottom.
    static func rim(_ opacity: Double = 1) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55 * opacity),
                Color.white.opacity(0.14 * opacity),
                Color.white.opacity(0.03 * opacity),
                Color.white.opacity(0.22 * opacity)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.04)
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Glass.emerald.opacity(0.30))
                        .frame(width: 340, height: 340)
                        .blur(radius: 90)
                        .offset(x: -geo.size.width * 0.28, y: -geo.size.height * 0.30)
                    Circle()
                        .fill(Color(red: 0.05, green: 0.45, blue: 0.65).opacity(0.26))
                        .frame(width: 300, height: 300)
                        .blur(radius: 100)
                        .offset(x: geo.size.width * 0.34, y: -geo.size.height * 0.05)
                    Circle()
                        .fill(Glass.gold.opacity(0.13))
                        .frame(width: 260, height: 260)
                        .blur(radius: 95)
                        .offset(x: geo.size.width * 0.10, y: geo.size.height * 0.38)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// A glass card: translucent material face, rim-light stroke, deep soft shadow.
    func glassCard(corner: CGFloat = 22, tint: Color = .clear) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(tint.opacity(0.10))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Glass.rim(), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    /// A floating glass pill (tab bar, chips, player).
    func glassPill(tint: Color = .clear) -> some View {
        self
            .background(
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(tint.opacity(0.12))
                }
            )
            .overlay(Capsule().strokeBorder(Glass.rim(), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)
    }
}

/// Press feedback: a quick local squash toward the touch with a spring settle,
/// static under Reduce Motion (per the glass-button skill).
struct GlassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
