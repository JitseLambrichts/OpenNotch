import SwiftUI

/// Renders the correct widget view for a given WidgetConfig.
struct WidgetContainerView: View {
    @Environment(\.appearance) private var appearance
    let widgetConfig: WidgetConfig

    var body: some View {
        Group {
            switch widgetConfig.id {
            case "dateTime":
                DateTimeWidget()
            case "nowPlaying":
                NowPlayingWidget()
            case "calendar":
                CalendarWidget()
            default:
                PlaceholderWidget(name: widgetConfig.id)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(appearance.backgroundOpacity)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}
