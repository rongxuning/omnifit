import SwiftUI

extension Color {
    static let omniCanvas = Color(red: 248 / 255, green: 250 / 255, blue: 252 / 255)
    static let omniIce = Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255)
    static let omniCobalt = Color(red: 2 / 255, green: 132 / 255, blue: 199 / 255)
    static let omniInk = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)
    static let omniCoral = Color(red: 1, green: 107 / 255, blue: 107 / 255)
    static let omniMuted = Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255)
    static let omniIdle = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
}

struct CanvasBackground: View {
    var body: some View {
        ZStack {
            Color.omniCanvas
            LinearGradient(
                colors: [Color.omniIce.opacity(0.55), Color.omniIce.opacity(0.16), Color.omniCanvas.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .shadow(color: Color.omniInk.opacity(0.08), radius: 16, y: 8)
    }
}

extension View {
    func glass(radius: CGFloat = 24) -> some View {
        modifier(GlassCard(radius: radius))
    }
}

struct OmniWordmark: View {
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            Text("omni")
            Text("fit").foregroundStyle(Color.omniCobalt)
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.omniInk)
    }
}
