import SwiftUI

struct ClockWidget: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            VStack(spacing: 4) {
                Text(context.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 36, weight: .light, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text(context.date.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 14, weight: .light, design: .default))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }
}
