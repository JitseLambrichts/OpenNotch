import SwiftUI

/// Root SwiftUI view inside the NotchPanel. Composes widgets based on config.
struct PanelContentView: View {
    @Bindable var configManager: ConfigManager
    @Bindable var safeSpaceManager = SafeSpaceManager.shared
    var topPadding: CGFloat = 0
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header Row (Tabs & Settings)
            HStack(spacing: 12) {
                // Tab switcher
                HStack(spacing: 8) {
                    Button(action: { safeSpaceManager.isSafeSpaceActive = false }) {
                        Text("Widgets")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(!safeSpaceManager.isSafeSpaceActive ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(16)
                            .foregroundStyle(!safeSpaceManager.isSafeSpaceActive ? .white : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: { safeSpaceManager.isSafeSpaceActive = true }) {
                        Text("Safe Space")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(safeSpaceManager.isSafeSpaceActive ? Color.white.opacity(0.1) : Color.clear)
                            .cornerRadius(16)
                            .foregroundStyle(safeSpaceManager.isSafeSpaceActive ? .white : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(Color.black.opacity(0.2))
                .cornerRadius(20)

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

            if safeSpaceManager.isSafeSpaceActive {
                // Safe Space Tab
                SafeSpaceWidgetView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Widgets Tab (Horizontal)
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(orderedEnabledWidgets.enumerated()), id: \.element.id) { index, widget in
                        WidgetContainerView(widgetConfig: widget)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                        if index < orderedEnabledWidgets.count - 1 {
                            Divider()
                                .frame(height: 100)
                                .background(Color.white.opacity(0.05))
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 36)
            }
        }
        .padding(.top, topPadding)
        .environment(\.appearance, configManager.config.appearance)
        .overlay(alignment: .bottom) {
            if configManager.config.claudeUsage?.showBar != false {
                ClaudeUsageBarView()
                    .environment(\.appearance, configManager.config.appearance)
                    .padding(.horizontal, 24)
                    .padding(.bottom, safeSpaceManager.isSafeSpaceActive ? 8 : 14)
            }
        }
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
