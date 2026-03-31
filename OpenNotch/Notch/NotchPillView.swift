import SwiftUI

/// A subtle animated pill view rendered inside the notch hover zone.
struct NotchPillView: View {
    @State private var isGlowing = false

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isGlowing ? 0.15 : 0.05),
                        Color.white.opacity(isGlowing ? 0.08 : 0.02)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 80, height: 6)
            .shadow(color: .white.opacity(isGlowing ? 0.3 : 0.0), radius: 8, x: 0, y: 2)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isGlowing)
            .onAppear {
                isGlowing = true
            }
    }
}
