import SwiftUI

struct ClockWidget: View {
    @Environment(\.appearance) private var appearance

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            VStack(spacing: 4) {
                Text(context.date.formatted(date: .omitted, time: .standard))
                    .font(appearance.font(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(context.date.formatted(date: .complete, time: .omitted))
                    .font(appearance.font(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }
}
