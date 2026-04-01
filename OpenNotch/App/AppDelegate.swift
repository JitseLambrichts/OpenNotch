import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: – Owned components
    private var statusItem: NSStatusItem!
    private var notchWindowController: NotchWindowController?
    private var notchPanelController: NotchPanelController?
    private var settingsServer: SettingsServer?

    // MARK: – State
    private var isHoverMode = false   // true when panel was opened via notch hover
    private var mouseMonitor: Any?
    private var globalKeyMonitor: Any?

    // MARK: – Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure config is loaded first
        _ = ConfigManager.shared

        NSLog("[AppDelegate] OpenNotch starting...")
        setupStatusItem()
        setupNotchWindow()
        setupNotchPanel()
        setupGlobalHotkey()
        setupMouseMonitor()
        startSettingsServer()
        NSLog("[AppDelegate] App ready.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        settingsServer?.stop()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: – Status Item (Menu Bar)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "OpenNotch"
            )
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showContextMenu(for: sender)
        } else {
            isHoverMode = false
            togglePanel()
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OpenNotch", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so left-click works next time
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    @objc private func openSettings() {
        if let url = URL(string: "http://localhost:7331") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupNotchWindow() {
        NSLog("[AppDelegate] Setting up notch detection...")
        let allScreens = NSScreen.screens
        NSLog("[AppDelegate] Detected \(allScreens.count) screens")
        
        for (i, s) in allScreens.enumerated() {
            NSLog("[AppDelegate] Screen \(i): \(s.frame), Insets: \(s.safeAreaInsets), HasNotch: \(s.hasNotch)")
        }

        guard let screen = allScreens.first(where: { $0.hasNotch }) ?? NSScreen.screens.first else {
            NSLog("[AppDelegate] No screen found")
            return
        }

        if !screen.hasNotch {
            NSLog("[AppDelegate] No notch found on any screen. Panel will default to top of primary screen.")
        } else {
            NSLog("[AppDelegate] Notch detected on screen! Geometry: \(screen.notchRect)")
        }
        
        notchWindowController = NotchWindowController()
        notchWindowController?.notchDelegate = self
        notchWindowController?.setup(screen: screen)
    }

    // MARK: – Notch Panel

    private func setupNotchPanel() {
        NSLog("[AppDelegate] Setting up widget panel...")
        let screen = NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
        guard let screen = screen else { return }
        let config = ConfigManager.shared
        
        notchPanelController = NotchPanelController()
        notchPanelController?.setup(screen: screen, configManager: config)
    }

    // MARK: – Mouse Monitoring
    
    private func setupMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handleGlobalMouseMove()
        }
    }

    private func handleGlobalMouseMove() {
        guard let config = ConfigManager.shared.config.appearance.enableHoverToOpen, config else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let notchRect = NSScreen.main?.notchRect ?? .zero
        let hoverArea = notchRect.insetBy(dx: -40, dy: -10) // generous hover area
        
        let isInsideNotch = hoverArea.contains(mouseLocation)
        let isPanelVisible = notchPanelController?.panel.isVisible ?? false

        if isInsideNotch {
            if !isPanelVisible {
                isHoverMode = true
                showPanel()
            }
        } else if isHoverMode && isPanelVisible {
            // Check if we exited the panel or the notch
            if let panel = notchPanelController?.panel {
                let panelFrame = panel.frame.insetBy(dx: -40, dy: -40)
                let exitArea = panelFrame.union(hoverArea)
                
                if !exitArea.contains(mouseLocation) {
                    isHoverMode = false
                    hidePanel()
                }
            }
        }
    }
    
    // MARK: – Actions
    
    func togglePanel() {
        guard let panel = notchPanelController?.panel else { return }
        if panel.isVisible {
            isHoverMode = false
            hidePanel()
        } else {
            isHoverMode = false
            showPanel()
        }
    }
    
    func showPanel() {
        notchPanelController?.showAnimated()
    }
    
    private func hidePanel() {
        notchPanelController?.hideAnimated()
        isHoverMode = false
    }

    // MARK: – Global Hotkey (backtick)

    private func setupGlobalHotkey() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 50 { // backtick
                DispatchQueue.main.async {
                    self?.isHoverMode = false
                    self?.togglePanel()
                }
            }
        }
    }

    // MARK: – Settings Server

    private func startSettingsServer() {
        settingsServer = SettingsServer()
        settingsServer?.start()
    }
}

// MARK: – NotchWindowDelegate

extension AppDelegate: NotchWindowDelegate {
    func notchWindowMouseEntered() {
        if let hoverEnabled = ConfigManager.shared.config.appearance.enableHoverToOpen, !hoverEnabled {
            return
        }

        guard let controller = notchPanelController, !controller.panel.isVisible else { return }
        isHoverMode = true
        showPanel()
    }

    func notchWindowMouseExited() {
    }

    func notchWindowDraggingEntered() {
        guard let controller = notchPanelController else { return }
        DispatchQueue.main.async {
            SafeSpaceManager.shared.isSafeSpaceActive = true // Force switch to Safe Space tab
            if !controller.panel.isVisible {
                self.isHoverMode = true
                self.showPanel()
            }
        }
    }
}
