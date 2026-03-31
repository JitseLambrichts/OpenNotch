import Foundation
import Observation

/// Singleton managing config persistence, file watching, and change notification.
@Observable
final class ConfigManager {

    static let shared = ConfigManager()

    private(set) var config: AppConfig

    private let configURL: URL
    private var fileWatcherSource: DispatchSourceFileSystemObject?
    private let fileWatcherQueue = DispatchQueue(label: "com.opennotch.configwatcher", qos: .utility)

    private init() {
        // ~/Library/Application Support/OpenNotch/config.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("OpenNotch", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        self.configURL = appDir.appendingPathComponent("config.json")
        self.config = AppConfig.default

        loadOrCreateConfig()
        startFileWatcher()
    }

    // MARK: – Load / Save

    private func loadOrCreateConfig() {
        if FileManager.default.fileExists(atPath: configURL.path) {
            loadConfig()
        } else {
            // Write default config
            config = AppConfig.default
            saveConfig()
        }
    }

    func loadConfig() {
        do {
            let data = try Data(contentsOf: configURL)
            let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.config = decoded
            }
        } catch {
            NSLog("[ConfigManager] Failed to load config: \(error). Using defaults.")
            DispatchQueue.main.async { [weak self] in
                self?.config = AppConfig.default
            }
        }
    }

    func saveConfig() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("[ConfigManager] Failed to save config: \(error)")
        }
    }

    func updateConfig(_ newConfig: AppConfig) {
        DispatchQueue.main.async { [weak self] in
            self?.config = newConfig
            self?.saveConfig()
        }
    }

    /// Returns raw JSON data of current config (for API responses).
    func configJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(config)
    }

    // MARK: – File Watcher

    private func startFileWatcher() {
        // Ensure the file exists before watching
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }

        let fd = open(configURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: fileWatcherQueue
        )

        source.setEventHandler { [weak self] in
            // Debounce: wait briefly for write to finish
            Thread.sleep(forTimeInterval: 0.1)
            self?.loadConfig()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.fileWatcherSource = source
    }

    deinit {
        fileWatcherSource?.cancel()
    }
}
