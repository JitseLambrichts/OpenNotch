import SwiftUI
import Combine
import AppKit

// MARK: – Now Playing Data Model

struct NowPlayingInfo: Equatable {
    var trackName: String = ""
    var artistName: String = ""
    var albumName: String = ""
    var artworkURL: String = ""
    var isPlaying: Bool = false
    var appName: String = ""

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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Try Music.app first, then Spotify
            if let musicInfo = self?.queryApp(named: "Music", bundleID: "com.apple.Music") {
                DispatchQueue.main.async { self?.info = musicInfo }
                return
            }
            if let spotifyInfo = self?.queryApp(named: "Spotify", bundleID: "com.spotify.client") {
                DispatchQueue.main.async { self?.info = spotifyInfo }
                return
            }
            DispatchQueue.main.async { self?.info = NowPlayingInfo() }
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
            appName: name
        )
    }

    // MARK: – Playback Controls

    func togglePlayPause() {
        if info.appName == "Music" {
            runAppleScript("tell application \"Music\" to playpause")
        } else if info.appName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to playpause")
        }
        // Refresh immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    func nextTrack() {
        if info.appName == "Music" {
            runAppleScript("tell application \"Music\" to next track")
        } else if info.appName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    func previousTrack() {
        if info.appName == "Music" {
            runAppleScript("tell application \"Music\" to previous track")
        } else if info.appName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to previous track")
        }
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
