import SwiftUI

/// Root SwiftUI view inside the NotchPanel. Composes widgets based on config.
struct PanelContentView: View {
    @Bindable var configManager: ConfigManager
    var topPadding: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header Row (Nook, Tray, Settings)
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Label("Nook", systemImage: "flashlight.on.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.1)))

                    Label("Tray", systemImage: "archivebox.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .foregroundStyle(.white)

                Spacer()

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Widgets Area (Horizontal)
            HStack(alignment: .top, spacing: 0) {
                // Now Playing (Left)
                if let musicWidget = enabledWidget(id: "nowPlaying") {
                    WidgetContainerView(widgetConfig: musicWidget)
                        .frame(maxWidth: .infinity)
                }

                Divider()
                    .frame(height: 100)
                    .background(Color.white.opacity(0.05))
                    .padding(.vertical, 10)

                // Calendar (Center)
                if let calendarWidget = enabledWidget(id: "calendar") {
                    WidgetContainerView(widgetConfig: calendarWidget)
                        .frame(maxWidth: .infinity)
                }

                Divider()
                    .frame(height: 100)
                    .background(Color.white.opacity(0.05))
                    .padding(.vertical, 10)

                // Date Time (Right)
                if let dateTimeWidget = enabledWidget(id: "dateTime") {
                    WidgetContainerView(widgetConfig: dateTimeWidget)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
        .padding(.top, topPadding)
        .environment(\.appearance, configManager.config.appearance)
    }

    private func enabledWidget(id: String) -> WidgetConfig? {
        configManager.config.widgets.first(where: { $0.id == id && $0.enabled })
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
