import SwiftUI

/// Root SwiftUI view inside the NotchPanel. Composes widgets based on config.
struct PanelContentView: View {
    @Bindable var configManager: ConfigManager
    var topPadding: CGFloat = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header Row (Settings)
            HStack(spacing: 12) {
                Spacer()

                Button(action: openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Widgets Area (Horizontal)
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(orderedEnabledWidgets.enumerated()), id: \.element.id) { index, widget in
                    WidgetContainerView(widgetConfig: widget)
                        .frame(maxWidth: .infinity)

                    if index < orderedEnabledWidgets.count - 1 {
                        Divider()
                            .frame(height: 100)
                            .background(Color.white.opacity(0.05))
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .padding(.top, topPadding)
        .environment(\.appearance, configManager.config.appearance)
    }

    private var orderedEnabledWidgets: [WidgetConfig] {
        configManager.config.widgets
            .filter(\.enabled)
            .sorted { $0.order < $1.order }
    }

    private func openSettings() {
        guard let url = URL(string: "http://localhost:7331/") else { return }
        openURL(url)
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
