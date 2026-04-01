import Foundation
import AppKit
import SwiftUI

struct SafeSpaceItem: Identifiable, Hashable {
    let id = UUID()
    let originalURL: URL
    let temporaryURL: URL
    let thumbnail: NSImage
    let name: String

    init(originalURL: URL, temporaryURL: URL) {
        self.originalURL = originalURL
        self.temporaryURL = temporaryURL
        self.name = originalURL.lastPathComponent

        let workspace = NSWorkspace.shared
        self.thumbnail = workspace.icon(forFile: temporaryURL.path)
    }
}

@Observable
class SafeSpaceManager {
    static let shared = SafeSpaceManager()

    var items: [SafeSpaceItem] = []
    private let fileManager = FileManager.default
    private let safeSpaceDirectory: URL

    init() {
        // Use a dedicated directory in caches for the temporary files
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        safeSpaceDirectory = cachesDirectory.appendingPathComponent("OpenNotch_SafeSpace", isDirectory: true)

        setupDirectory()
        // Optionally, clear out old items on launch
        clearAllItems()
    }

    private func setupDirectory() {
        if !fileManager.fileExists(atPath: safeSpaceDirectory.path) {
            do {
                try fileManager.createDirectory(at: safeSpaceDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Safe Space directory: \(error)")
            }
        }
    }

    func add(urls: [URL]) {
        for url in urls {
            print("SafeSpaceManager trying to add: \(url.path)")
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Generate a unique filename to avoid collisions
            let uniqueFilename = UUID().uuidString + "_" + url.lastPathComponent
            let tempURL = safeSpaceDirectory.appendingPathComponent(uniqueFilename)

            do {
                // Copy the file to our managed temporary directory
                try fileManager.copyItem(at: url, to: tempURL)
                print("SafeSpaceManager successfully copied file to: \(tempURL.path)")

                let item = SafeSpaceItem(originalURL: url, temporaryURL: tempURL)
                DispatchQueue.main.async {
                    self.items.append(item)
                    print("SafeSpaceManager appended item to list. Total items: \(self.items.count)")
                }
            } catch {
                print("Failed to copy file to Safe Space: \(error)")
            }
        }
    }

    func remove(item: SafeSpaceItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let itemToRemove = items[index]
            do {
                try fileManager.removeItem(at: itemToRemove.temporaryURL)
            } catch {
                print("Failed to remove file from Safe Space: \(error)")
            }

            DispatchQueue.main.async {
                self.items.remove(at: index)
            }
        }
    }

    func clearAllItems() {
        for item in items {
            do {
                try fileManager.removeItem(at: item.temporaryURL)
            } catch {
                print("Failed to remove file: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.items.removeAll()
        }

        // Also wipe the directory just to be safe
        do {
            let contents = try fileManager.contentsOfDirectory(at: safeSpaceDirectory, includingPropertiesForKeys: nil)
            for file in contents {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear Safe Space directory: \(error)")
        }
    }
}
