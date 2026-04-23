import SwiftUI

struct ClipboardHistoryView: View {
    @State private var service = ClipboardService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
                Spacer()
                if service.items.contains(where: { !$0.isPinned }) {
                    Button(action: { service.clearUnpinned() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .help("Clear unpinned items")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if service.items.isEmpty {
                VStack {
                    Image(systemName: "clipboard")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("Nothing copied yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(service.items) { item in
                            ClipboardItemRow(item: item, service: service)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let service: ClipboardService
    @State private var isHovering = false

    var isCopied: Bool { service.copiedItemId == item.id }

    var body: some View {
        HStack(spacing: 5) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow.opacity(0.7))
                    .rotationEffect(.degrees(45))
            }

            Text(item.text)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isCopied ? Color.green.opacity(0.9) : .white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.2), value: isCopied)

            if isHovering {
                HStack(spacing: 3) {
                    Button(action: { service.togglePin(item) }) {
                        Image(systemName: item.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin")

                    Button(action: { service.remove(item) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            } else {
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.white.opacity(0.07) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { service.copy(item) }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
