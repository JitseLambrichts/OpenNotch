import Foundation
import AppKit

struct ClipboardItem: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    var isPinned: Bool

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.isPinned = false
    }
}

@Observable
class ClipboardService {
    static let shared = ClipboardService()

    private(set) var items: [ClipboardItem] = []
    var copiedItemId: UUID? = nil

    private var lastChangeCount: Int
    private var timer: Timer?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startPolling()
    }

    private func startPolling() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Skip if identical to most recently inserted item
        guard items.first?.text != text else { return }

        // Remove existing non-pinned duplicate so it re-floats to top
        items.removeAll { !$0.isPinned && $0.text == text }

        let newItem = ClipboardItem(text: text)
        let insertIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.count
        items.insert(newItem, at: insertIndex)

        enforceLimit()
    }

    private func enforceLimit(maxNonPinned: Int = 15) {
        while items.filter({ !$0.isPinned }).count > maxNonPinned {
            guard let last = items.lastIndex(where: { !$0.isPinned }) else { break }
            items.remove(at: last)
        }
    }

    func copy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount

        // Bubble non-pinned item to top of unpinned section
        if !item.isPinned, let idx = items.firstIndex(where: { $0.id == item.id }) {
            let moved = items.remove(at: idx)
            let insertIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.count
            items.insert(moved, at: insertIndex)
        }

        copiedItemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            if self.copiedItemId == item.id { self.copiedItemId = nil }
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        items = pinned + unpinned
        enforceLimit()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }
}
