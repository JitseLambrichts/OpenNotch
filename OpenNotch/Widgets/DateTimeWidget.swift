import SwiftUI

/// Month title with a 7-day current-week calendar strip.
struct DateTimeWidget: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let now = Date()
            let calendar = Calendar.current
            let month = now.formatted(.dateTime.month(.wide).year())
            let weekDates = currentWeekDates(from: now, calendar: calendar)
            
            Text(month)
                .font(appearance.font(size: 24, weight: .bold))
                .foregroundStyle(.white)
            
            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    let dayNum = calendar.component(.day, from: date)
                    let isToday = calendar.isDateInToday(date)

                    VStack(spacing: 6) {
                        Text(weekdayLetter(for: date))
                            .font(appearance.font(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(isToday ? 0.95 : 0.45))

                        Text(String(format: "%02d", dayNum))
                            .font(appearance.font(size: 15, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isToday ? appearance.color : .white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isToday ? appearance.color.opacity(0.16) : Color.white.opacity(0.04))
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func currentWeekDates(from referenceDate: Date, calendar: Calendar) -> [Date] {
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return [referenceDate]
        }

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }

    private func weekdayLetter(for date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()

}
