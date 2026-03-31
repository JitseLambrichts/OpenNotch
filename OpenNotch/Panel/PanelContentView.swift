import SwiftUI

/// Root SwiftUI view inside the NotchPanel. Composes widgets based on config.
struct PanelContentView: View {
    @Bindable var configManager: ConfigManager

    var body: some View {
        VStack(spacing: 0) {
            // Notch connector (rounded tab connecting to notch)
            NotchConnectorShape()
                .fill(Color.clear)
                .frame(height: 12)

            // Widget area
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(sortedEnabledWidgets) { widgetConfig in
                        WidgetContainerView(widgetConfig: widgetConfig)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .environment(\.appearance, configManager.config.appearance)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: sortedEnabledWidgets.map(\.id))
    }

    private var sortedEnabledWidgets: [WidgetConfig] {
        configManager.config.widgets
            .filter { $0.enabled }
            .sorted { $0.order < $1.order }
    }
}

// MARK: – Environment Keys

struct AppearanceEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppearanceConfig = .default
}

extension EnvironmentValues {
    var appearance: AppearanceConfig {
        get { self[AppearanceEnvironmentKey.self] }
        set { self[AppearanceEnvironmentKey.self] = newValue }
    }
}

// MARK: – Notch Connector Shape

struct NotchConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Draws a subtle rounded tab that visually connects panel to notch
        Path { p in
            let w = rect.width
            let h = rect.height
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * 0.5))
            p.addQuadCurve(
                to: CGPoint(x: h * 0.5, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
            p.addLine(to: CGPoint(x: w - h * 0.5, y: 0))
            p.addQuadCurve(
                to: CGPoint(x: w, y: h * 0.5),
                control: CGPoint(x: w, y: 0)
            )
            p.addLine(to: CGPoint(x: w, y: h))
        }
    }
}
