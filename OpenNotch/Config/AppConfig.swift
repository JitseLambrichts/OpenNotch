import Foundation
import SwiftUI

// MARK: – Root Config

struct AppConfig: Codable, Equatable {
    var widgets: [WidgetConfig]
    var appearance: AppearanceConfig

    static let `default` = AppConfig(
        widgets: [
            WidgetConfig(id: "clock", displayName: "Clock & Date", iconName: "clock", enabled: true, order: 0, settings: [:]),
            WidgetConfig(id: "dateTime", displayName: "Weekly Calendar", iconName: "calendar", enabled: true, order: 1, settings: [:]),
            WidgetConfig(id: "nowPlaying", displayName: "Now Playing", iconName: "music.note", enabled: true, order: 2, settings: [:]),
            WidgetConfig(id: "calendar", displayName: "Upcoming Events", iconName: "calendar.badge.clock", enabled: true, order: 3, settings: [:]),
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

extension AppearanceConfig {
    var color: Color {
        Color(hex: accentColor) ?? .blue
    }

    func font(size: Double? = nil, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let referenceSize: Double = 13.0
        let scaleFactor = fontSize / referenceSize
        let finalSize = (size ?? referenceSize) * scaleFactor

        if fontFamily.lowercased() == "system" {
            return .system(size: finalSize, weight: weight, design: design)
        } else {
            return .custom(fontFamily, size: finalSize).weight(weight)
        }
    }
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

// MARK: – Color Helpers

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
