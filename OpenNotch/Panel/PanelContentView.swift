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
                        HStack(spacing: 5) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 11))
                            Text("Home")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(height: 28)
                        .padding(.horizontal, 12)
                        .background(!safeSpaceManager.isSafeSpaceActive ? Color.white.opacity(0.1) : Color.clear)
                        .cornerRadius(16)
                        .foregroundStyle(!safeSpaceManager.isSafeSpaceActive ? .white : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)

                    Button(action: { safeSpaceManager.isSafeSpaceActive = true }) {
                        HStack(spacing: 5) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 11))
                            Text("Clipboard")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(height: 28)
                        .padding(.horizontal, 12)
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
            .frame(height: 28)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            if safeSpaceManager.isSafeSpaceActive {
                // Clipboard Tab — left: file drop, right: clipboard history
                HStack(alignment: .top, spacing: 12) {
                    SafeSpaceWidgetView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    ClipboardHistoryView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            } else {
                // Widgets Tab (Horizontal)
                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(orderedEnabledWidgets.enumerated()), id: \.element.id) { index, widget in
                        WidgetContainerView(widgetConfig: widget)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .clipped()

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
        .onAppear {
            Task { await ClaudeUsageService.shared.refresh() }
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
