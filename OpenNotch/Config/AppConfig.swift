import Foundation

// MARK: – Root Config

struct AppConfig: Codable, Equatable {
    var widgets: [WidgetConfig]
    var appearance: AppearanceConfig

    static let `default` = AppConfig(
        widgets: [
            WidgetConfig(id: "dateTime", displayName: "Date & Time", iconName: "clock.fill", enabled: true, order: 0, settings: [:]),
            WidgetConfig(id: "nowPlaying", displayName: "Now Playing", iconName: "music.note", enabled: true, order: 1, settings: [:]),
            WidgetConfig(id: "calendar", displayName: "Calendar", iconName: "calendar", enabled: true, order: 2, settings: [:]),
        ],
        appearance: .default
    )
}

// MARK: – Widget Config

struct WidgetConfig: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var iconName: String
    var enabled: Bool
    var order: Int
    var settings: [String: AnyCodableValue]
}

// MARK: – Appearance Config

struct AppearanceConfig: Codable, Equatable {
    var accentColor: String
    var fontFamily: String
    var fontSize: Double
    var backgroundOpacity: Double
    var enableHoverToOpen: Bool?

    static let `default` = AppearanceConfig(
        accentColor: "#007AFF",
        fontFamily: "System",
        fontSize: 13.0,
        backgroundOpacity: 0.85,
        enableHoverToOpen: true
    )
}

// MARK: – AnyCodableValue (type-erased JSON value)

enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(AnyCodableValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}
