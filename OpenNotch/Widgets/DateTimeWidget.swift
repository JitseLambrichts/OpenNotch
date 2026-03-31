import SwiftUI

/// Live date and time widget with second-precise updates.
struct DateTimeWidget: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = context.date
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(appearance.font(size: 14))
                        .foregroundStyle(appearance.color)

                    Text(date, format: .dateTime.hour().minute().second())
                        .font(appearance.font(size: 28, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                HStack(spacing: 8) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(appearance.font(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))

                    Text(date, format: .dateTime.month(.wide).day())
                        .font(appearance.font(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))

                    Text("W\(Calendar.current.component(.weekOfYear, from: date))")
                        .font(appearance.font(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
