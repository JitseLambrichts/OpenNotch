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
    }
}
