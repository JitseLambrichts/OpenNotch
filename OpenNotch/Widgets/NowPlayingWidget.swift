import SwiftUI
import Combine
import AppKit
import Darwin

// MARK: – Now Playing Data Model

struct NowPlayingInfo: Equatable {
    var trackName: String = ""
    var artistName: String = ""
    var albumName: String = ""
    var artworkURL: String = ""
    var isPlaying: Bool = false
    var appName: String = ""
    var appBundleID: String = ""

    var isEmpty: Bool {
        trackName.isEmpty && artistName.isEmpty
    }
}

// MARK: – Now Playing Service (AppleScript-based)

@Observable
final class NowPlayingService {

    static let shared = NowPlayingService()

    private(set) var info = NowPlayingInfo()
    private var timer: Timer?
    private let mediaRemote = MediaRemoteBridge()

    private init() {
        startPolling()
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }
        timer?.tolerance = 1.0
        fetchNowPlaying()  // Immediate first fetch
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchNowPlaying() {
        mediaRemote.queryNowPlaying { [weak self] systemInfo in
            if let systemInfo {
                DispatchQueue.main.async { self?.info = systemInfo }
                return
            }

            DispatchQueue.global(qos: .utility).async {
                guard let self else { return }

                // Check browsers first
                if let browserInfo = self.queryRunningBrowsers() {
                    DispatchQueue.main.async { self.info = browserInfo }
                    return
                }

                // Fallback for environments where MediaRemote returns no active item.
                if let musicInfo = self.queryApp(named: "Music", bundleID: "com.apple.Music") {
                    DispatchQueue.main.async { self.info = musicInfo }
                    return
                }
                if let spotifyInfo = self.queryApp(named: "Spotify", bundleID: "com.spotify.client") {
                    DispatchQueue.main.async { self.info = spotifyInfo }
                    return
                }
                DispatchQueue.main.async { self.info = NowPlayingInfo() }
            }
        }
    }

    private func queryApp(named name: String, bundleID: String) -> NowPlayingInfo? {
        // Check if app is running first
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return nil }

        let script: String
        if name == "Music" {
            script = """
            tell application "Music"
                if player state is playing then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & "" & "|||playing"
                else if player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & "" & "|||paused"
                else
                    return "||||||||||||stopped"
                end if
            end tell
            """
        } else {
            script = """
            tell application "Spotify"
                if player state is playing then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set artworkURL to artwork url of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & artworkURL & "|||playing"
                else if player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set artworkURL to artwork url of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & artworkURL & "|||paused"
                else
                    return "||||||||||||stopped"
                end if
            end tell
            """
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        guard error == nil, let output = result.stringValue else { return nil }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }

        let track = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let artworkURL = parts[3]
        let state = parts[4]

        if track.isEmpty && artist.isEmpty { return nil }

        return NowPlayingInfo(
            trackName: track,
            artistName: artist,
            albumName: album,
            artworkURL: artworkURL,
            isPlaying: state == "playing",
            appName: name,
            appBundleID: bundleID
        )
    }

    private func queryRunningBrowsers() -> NowPlayingInfo? {
        let chromiumBrowsers = [
            "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac",
            "company.thebrowser.Browser", "com.vivaldi.Vivaldi"
        ]
        let webkitBrowsers = ["com.apple.Safari", "com.kagi.kagimacOS"]

        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier, let name = app.localizedName else { continue }

            if chromiumBrowsers.contains(bundleID) {
                if let info = queryChromiumBrowser(named: name, bundleID: bundleID) {
                    return info
                }
            } else if webkitBrowsers.contains(bundleID) {
                if let info = queryWebKitBrowser(named: name, bundleID: bundleID) {
                    return info
                }
            }
        }
        return nil
    }

    private func queryChromiumBrowser(named name: String, bundleID: String) -> NowPlayingInfo? {
        let script = """
        tell application "\(name)"
            repeat with w in windows
                repeat with t in tabs of w
                    set tabURL to URL of t
                    if tabURL contains "youtube.com" or tabURL contains "music.apple.com" or tabURL contains "spotify.com" or tabURL contains "soundcloud.com" then
                        set tabTitle to title of t
                        return tabTitle & "|||" & tabURL
                    end if
                end repeat
            end repeat
        end tell
        return "|||"
        """
        return executeBrowserScript(script: script, name: name, bundleID: bundleID)
    }

    private func queryWebKitBrowser(named name: String, bundleID: String) -> NowPlayingInfo? {
        // Safari requires checking 'do JavaScript' or relies solely on MediaRemote.
        // We'll try a basic AppleScript approach, but MediaRemote usually handles Safari well natively.
        // For Orion (kagi), it behaves similarly to Safari.
        let script = """
        tell application "\(name)"
            if (count of windows) > 0 then
                return (name of current tab of front window) & "|||" & (URL of current tab of front window)
            end if
        end tell
        return "|||"
        """
        // Note: Without robust "audible" detection in basic AppleScript for Safari,
        // this fallback might just grab the frontmost tab.
        // It's safer to rely on MediaRemote for Safari, but we provide this as a last-resort fallback.
        return executeBrowserScript(script: script, name: name, bundleID: bundleID)
    }

    private func executeBrowserScript(script: String, name: String, bundleID: String) -> NowPlayingInfo? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        guard error == nil, let output = result.stringValue else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }

        let rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let pageURL = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTitle.isEmpty else { return nil }

        let title = normalizeBrowserTrackTitle(rawTitle)
        let artist = inferBrowserSourceName(from: pageURL)

        return NowPlayingInfo(
            trackName: title,
            artistName: artist,
            albumName: "",
            artworkURL: "",
            isPlaying: true, // We assume it's playing if it's audible
            appName: name,
            appBundleID: bundleID
        )
    }

    private func normalizeBrowserTrackTitle(_ title: String) -> String {
        if title.hasSuffix(" - YouTube") {
            return String(title.dropLast(" - YouTube".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if title.hasSuffix(" - YouTube Music") {
            return String(title.dropLast(" - YouTube Music".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    private func inferBrowserSourceName(from pageURL: String) -> String {
        if pageURL.contains("youtube.com") || pageURL.contains("youtu.be") {
            return "YouTube"
        }
        if pageURL.contains("music.youtube.com") {
            return "YouTube Music"
        }
        if pageURL.contains("spotify.com") {
            return "Spotify Web"
        }
        return "Browser"
    }

    // MARK: – Playback Controls

    func togglePlayPause() {
        mediaRemote.sendCommand(.togglePlayPause)
        // Refresh immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    func nextTrack() {
        mediaRemote.sendCommand(.nextTrack)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    func previousTrack() {
        mediaRemote.sendCommand(.previousTrack)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }
}

// MARK: - System Now Playing Bridge (MediaRemote)

private final class MediaRemoteBridge {
    typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    typealias MRGetNowPlayingApplicationPID = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    typealias MRGetNowPlayingApplicationIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    typealias MRRegisterForNowPlayingNotifications = @convention(c) (DispatchQueue) -> Void
    typealias MRKeepAlive = @convention(c) () -> Void
    typealias MRUnregisterForNowPlayingNotifications = @convention(c) () -> Void
    typealias MRMediaRemoteSendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool

    enum MRCommand: UInt32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    private let handle: UnsafeMutableRawPointer?
    private let getNowPlayingInfoFn: MRGetNowPlayingInfo?
    private let getNowPlayingPIDFn: MRGetNowPlayingApplicationPID?
    private let getNowPlayingIsPlayingFn: MRGetNowPlayingApplicationIsPlaying?
    private let registerForNowPlayingNotificationsFn: MRRegisterForNowPlayingNotifications?
    private let keepAliveFn: MRKeepAlive?
    private let unregisterForNowPlayingNotificationsFn: MRUnregisterForNowPlayingNotifications?
    private let sendCommandFn: MRMediaRemoteSendCommand?

    private let titleKey: String
    private let artistKey: String
    private let albumKey: String
    private let playbackRateKey: String

    init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            self.handle = nil
            self.getNowPlayingInfoFn = nil
            self.getNowPlayingPIDFn = nil
            self.getNowPlayingIsPlayingFn = nil
            self.registerForNowPlayingNotificationsFn = nil
            self.keepAliveFn = nil
            self.unregisterForNowPlayingNotificationsFn = nil
            self.sendCommandFn = nil
            self.titleKey = "kMRMediaRemoteNowPlayingInfoTitle"
            self.artistKey = "kMRMediaRemoteNowPlayingInfoArtist"
            self.albumKey = "kMRMediaRemoteNowPlayingInfoAlbum"
            self.playbackRateKey = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
            return
        }

        self.handle = handle
        self.getNowPlayingInfoFn = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo")
            .map { unsafeBitCast($0, to: MRGetNowPlayingInfo.self) }
        self.getNowPlayingPIDFn = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID")
            .map { unsafeBitCast($0, to: MRGetNowPlayingApplicationPID.self) }
        self.getNowPlayingIsPlayingFn = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
            .map { unsafeBitCast($0, to: MRGetNowPlayingApplicationIsPlaying.self) }
        self.registerForNowPlayingNotificationsFn = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications")
            .map { unsafeBitCast($0, to: MRRegisterForNowPlayingNotifications.self) }
        self.keepAliveFn = dlsym(handle, "MRMediaRemoteKeepAlive")
            .map { unsafeBitCast($0, to: MRKeepAlive.self) }
        self.unregisterForNowPlayingNotificationsFn = dlsym(handle, "MRMediaRemoteUnregisterForNowPlayingNotifications")
            .map { unsafeBitCast($0, to: MRUnregisterForNowPlayingNotifications.self) }
        self.sendCommandFn = dlsym(handle, "MRMediaRemoteSendCommand")
            .map { unsafeBitCast($0, to: MRMediaRemoteSendCommand.self) }

        let resolvedTitleKey = Self.loadCFStringSymbol(handle: handle, symbolName: "kMRMediaRemoteNowPlayingInfoTitle")
        let resolvedArtistKey = Self.loadCFStringSymbol(handle: handle, symbolName: "kMRMediaRemoteNowPlayingInfoArtist")
        let resolvedAlbumKey = Self.loadCFStringSymbol(handle: handle, symbolName: "kMRMediaRemoteNowPlayingInfoAlbum")
        let resolvedPlaybackRateKey = Self.loadCFStringSymbol(handle: handle, symbolName: "kMRMediaRemoteNowPlayingInfoPlaybackRate")

        self.titleKey = resolvedTitleKey ?? "kMRMediaRemoteNowPlayingInfoTitle"
        self.artistKey = resolvedArtistKey ?? "kMRMediaRemoteNowPlayingInfoArtist"
        self.albumKey = resolvedAlbumKey ?? "kMRMediaRemoteNowPlayingInfoAlbum"
        self.playbackRateKey = resolvedPlaybackRateKey ?? "kMRMediaRemoteNowPlayingInfoPlaybackRate"

        let notificationQueue = DispatchQueue(label: "opennotch.mediaremote")
        keepAliveFn?()
        registerForNowPlayingNotificationsFn?(notificationQueue)
    }

    deinit {
        unregisterForNowPlayingNotificationsFn?()
        if let handle {
            dlclose(handle)
        }
    }

    func queryNowPlaying(completion: @escaping (NowPlayingInfo?) -> Void) {
        guard let getNowPlayingInfoFn else {
            completion(nil)
            return
        }

        let queue = DispatchQueue.global(qos: .utility)
        let group = DispatchGroup()
        var infoDict: [String: Any]?
        var pid: Int32?
        var isPlaying: Bool?

        group.enter()
        getNowPlayingInfoFn(queue) { dict in
            if let dict {
                infoDict = dict as? [String: Any]
            }
            group.leave()
        }

        if let getNowPlayingPIDFn {
            group.enter()
            getNowPlayingPIDFn(queue) { currentPID in
                pid = currentPID
                group.leave()
            }
        }

        if let getNowPlayingIsPlayingFn {
            group.enter()
            getNowPlayingIsPlayingFn(queue) { currentIsPlaying in
                isPlaying = currentIsPlaying
                group.leave()
            }
        }

        group.notify(queue: queue) {
            guard let infoDict else {
                completion(nil)
                return
            }

            let track = self.stringValue(
                from: infoDict,
                keys: [
                    self.titleKey,
                    "title",
                    "kMRMediaRemoteNowPlayingInfoTitle"
                ]
            )
            let artist = self.stringValue(
                from: infoDict,
                keys: [
                    self.artistKey,
                    "artist",
                    "kMRMediaRemoteNowPlayingInfoArtist"
                ]
            )
            let album = self.stringValue(
                from: infoDict,
                keys: [
                    self.albumKey,
                    "album",
                    "kMRMediaRemoteNowPlayingInfoAlbum"
                ]
            )

            if track.isEmpty && artist.isEmpty {
                completion(nil)
                return
            }

            let playbackRate = self.doubleValue(
                from: infoDict,
                keys: [
                    self.playbackRateKey,
                    "playbackRate"
                ]
            )

            let runningApp = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
            let appName = runningApp?.localizedName ?? ""
            let bundleID = runningApp?.bundleIdentifier ?? ""

            completion(
                NowPlayingInfo(
                    trackName: track,
                    artistName: artist,
                    albumName: album,
                    artworkURL: "",
                    isPlaying: isPlaying ?? (playbackRate > 0),
                    appName: appName,
                    appBundleID: bundleID
                )
            )
        }
    }

    func sendCommand(_ command: MRCommand) {
        _ = sendCommandFn?(command.rawValue, nil)
    }

    private static func loadCFStringSymbol(handle: UnsafeMutableRawPointer, symbolName: String) -> String? {
        guard let symbol = dlsym(handle, symbolName) else { return nil }
        let keyPointer = symbol.assumingMemoryBound(to: CFString?.self)
        guard let key = keyPointer.pointee else { return nil }
        return key as String
    }

    private func stringValue(from dict: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func doubleValue(from dict: [String: Any], keys: [String]) -> Double {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.doubleValue
            }
        }
        return 0
    }
}

// MARK: – Widget View

struct NowPlayingWidget: View {
    @Environment(\.appearance) private var appearance
    @State private var service = NowPlayingService.shared

    var body: some View {
        HStack(alignment: .center) {
            if service.info.isEmpty {
                // No media playing
                Label("No media playing", systemImage: "music.note")
                    .font(appearance.font(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            } else {
                // Main content: Vertically stacked (Album → Title/Artist → Controls)
                VStack(alignment: .center, spacing: 10) {
                    // Album Art with badge
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let artwork = URL(string: service.info.artworkURL), !service.info.artworkURL.isEmpty {
                                AsyncImage(url: artwork) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    default:
                                        artworkPlaceholder
                                    }
                                }
                            } else {
                                artworkPlaceholder
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Image(nsImage: sourceBadgeIcon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .padding(4)
                    }

                    // Track Info (Title + Artist)
                    VStack(alignment: .center, spacing: 4) {
                        Text(service.info.trackName)
                            .font(appearance.font(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(service.info.artistName)
                            .font(appearance.font(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Playback controls (Beneath the album art and info)
                    HStack(spacing: 12) {
                        Spacer()
                        
                        Button(action: { service.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        Button(action: { service.togglePlayPause() }) {
                            Image(systemName: service.info.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)

                        Button(action: { service.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                    .padding(.bottom, 5)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [appearance.color, .blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    private var sourceBadgeIcon: NSImage {
        if !service.info.appBundleID.isEmpty {
            return iconForApp(bundleIdentifier: service.info.appBundleID, fallbackSystemName: "music.note")
        }

        switch service.info.appName {
        case "Spotify":
            return iconForApp(bundleIdentifier: "com.spotify.client", fallbackSystemName: "music.note")
        case "Music":
            return iconForApp(bundleIdentifier: "com.apple.Music", fallbackSystemName: "music.note")
        default:
            return iconForApp(bundleIdentifier: Bundle.main.bundleIdentifier ?? "", fallbackSystemName: "app")
        }
    }

    private func iconForApp(bundleIdentifier: String, fallbackSystemName: String) -> NSImage {
        if let runningIcon = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.icon {
            runningIcon.size = NSSize(width: 64, height: 64)
            return runningIcon
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            appIcon.size = NSSize(width: 64, height: 64)
            return appIcon
        }

        if let symbolIcon = NSImage(systemSymbolName: fallbackSystemName, accessibilityDescription: nil) {
            symbolIcon.size = NSSize(width: 64, height: 64)
            return symbolIcon
        }

        return NSImage(size: NSSize(width: 64, height: 64))
    }

}
