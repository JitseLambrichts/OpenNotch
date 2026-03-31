<h1 align="center">OpenNotch</h1>

<p align="center">
  <strong>A macOS menu bar app that turns your MacBook's notch into a configurable widget hub.</strong>
</p>

<p align="center">
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-14.0%2B-blue.svg?logo=apple" alt="macOS 14.0+"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9-orange.svg?logo=swift" alt="Swift"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT"></a>
  <a href="http://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
</p>

<p align="center">
  <em>Hover over the notch to reveal a floating panel with live widgets — currently playing music, upcoming calendar events, date/time, and more.</em>
</p>

<br/>

<!-- TODO: Add a nice screenshot or GIF of the app in action here -->
<!-- <p align="center"><img src="docs/demo.gif" alt="OpenNotch Demo" width="600"/></p> -->

## ✨ Features

- **Notch integration** — hover over the MacBook notch to reveal the widget panel with a smooth spring animation
- **Configurable widgets** — Date & Time, Now Playing (Music.app / Spotify), Calendar events
- **Menu bar icon** — secondary entry point; left-click toggles the panel, right-click opens settings
- **Web-based settings** — configure widgets, appearance, and layout at `http://localhost:7331`
- **Hot-reload** — settings changes apply instantly without restarting
- **Auto-start** — installs as a login item via `launchd`

## 💻 Requirements

- **OS:** macOS 14.0+ (Sonoma)
- **Hardware:** MacBook with a notch (2021 MacBook Pro or later)
- **Build:** Xcode 15+

## 🚀 Installation

### Quick Install

```bash
git clone https://github.com/youruser/OpenNotch.git
cd OpenNotch
chmod +x install.sh
./install.sh
```

The install script will automatically:
1. Build the app with `xcodebuild`
2. Ad-hoc sign the binary (`codesign --deep --force --sign -`)
3. Copy `OpenNotch.app` to `/Applications`
4. Create a `launchd` plist for auto-start on login
5. Launch the app

### 🛠️ Manual Build

```bash
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -configuration Release build
```

## 🎮 Usage

| Action | Trigger |
|---|---|
| **Open panel** | Hover over the notch |
| **Close panel** | Move mouse away from the panel |
| **Toggle panel** | Click the menu bar icon or press `` ` `` (backtick) |
| **Open settings** | Right-click menu bar icon → **Settings**, or visit `http://localhost:7331` |
| **Quit** | Right-click menu bar icon → **Quit** |

## ⚙️ Settings

Open `http://localhost:7331` in any browser to configure:

- **Widgets** — toggle on/off, drag to reorder
- **Appearance** — accent color, font size, background opacity
- **Config file** — stored at `~/Library/Application Support/OpenNotch/config.json`

*Changes are saved automatically and applied instantly via hot-reload.*

## 🏗️ Architecture

```mermaid
graph TD;
    OpenNotchApp[OpenNotchApp<br>SwiftUI @main] --> AppDelegate;
    AppDelegate --> NSStatusItem[NSStatusItem<br>menu bar icon];
    AppDelegate --> NotchWindow[NotchWindow<br>invisible hover detection];
    AppDelegate --> NotchPanel[NotchPanel<br>expanding floating panel];
    AppDelegate --> SettingsServer[SettingsServer<br>FlyingFox HTTP :7331];
    SettingsServer --> ConfigManager[ConfigManager<br>JSON + file watcher];
```

## 📦 Dependencies

- [FlyingFox](https://github.com/swhitty/FlyingFox) — lightweight async HTTP server (via Swift Package Manager)

## 🧹 Uninstall

```bash
pkill -x OpenNotch
launchctl unload ~/Library/LaunchAgents/com.opennotch.app.plist
rm -rf /Applications/OpenNotch.app
rm ~/Library/LaunchAgents/com.opennotch.app.plist
rm -rf ~/Library/Application\ Support/OpenNotch

killall OpenNotch
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE="Manual"
open /Users/jitselambrichts/Library/Developer/Xcode/DerivedData/OpenNotch-bsxgnmezudeuhlauhylirrdlpkwh/Build/Products/Debug/OpenNotch.app
```

## 📄 License

This project is licensed under the [MIT License](LICENSE).