import SwiftUI

/// Placeholder widget for future development.
struct PlaceholderWidget: View {
    let name: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 18))
                .foregroundStyle(.gray.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Coming soon")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
