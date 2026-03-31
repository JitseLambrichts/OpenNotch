import SwiftUI
import Combine

// MARK: – Now Playing Data Model

struct NowPlayingInfo: Equatable {
    var trackName: String = ""
    var artistName: String = ""
    var albumName: String = ""
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
                    return trackName & "|||" & artistName & "|||" & albumName & "|||playing"
                else if player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||paused"
                else
                    return "|||||||stopped"
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
                    return trackName & "|||" & artistName & "|||" & albumName & "|||playing"
                else if player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||paused"
                else
                    return "|||||||stopped"
                end if
            end tell
            """
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        guard error == nil, let output = result.stringValue else { return nil }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }

        let track = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let state = parts[3]

        if track.isEmpty && artist.isEmpty { return nil }

        return NowPlayingInfo(
            trackName: track,
            artistName: artist,
            albumName: album,
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
        HStack(spacing: 16) {
            if service.info.isEmpty {
                // No media playing
                Label("No media playing", systemImage: "music.note")
                    .font(appearance.font(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Album Art
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [appearance.color, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.8))
                        )

                    // Source Mini Icon
                    Image(systemName: service.info.appName == "Spotify" ? "record.circle.fill" : "apple.logo")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .padding(2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(service.info.trackName)
                            .font(appearance.font(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(service.info.artistName)
                            .font(appearance.font(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    // Playback controls (Compact)
                    HStack(spacing: 16) {
                        Button(action: { service.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        Button(action: { service.togglePlayPause() }) {
                            Image(systemName: service.info.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)

                        Button(action: { service.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}
