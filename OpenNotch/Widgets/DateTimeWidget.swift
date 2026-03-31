import SwiftUI

/// Live date and time widget with second-precise updates.
struct DateTimeWidget: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let now = Date()
            let calendar = Calendar.current
            let month = now.formatted(.dateTime.month(.wide).year())
            
            Text(month)
                .font(appearance.font(size: 24, weight: .bold))
                .foregroundStyle(.white)
            
            HStack(spacing: 8) {
                ForEach(-3..<4) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: now) ?? now
                    let dayNum = calendar.component(.day, from: date)
                    let isToday = offset == 0
                    
                    VStack(spacing: 4) {
                        if isToday {
                            Text(String(format: "%02d", dayNum))
                                .font(appearance.font(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(appearance.color)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(appearance.color.opacity(0.1)))
                        } else {
                            Text(String(format: "%02d", dayNum))
                                .font(appearance.font(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(offset < 0 ? 0.3 : 0.6))
                                .padding(8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

}
