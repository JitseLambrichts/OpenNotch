import AppKit
import SwiftUI

/// Manages the expanding/collapsing widget panel.
/// Uses a controller-based design to avoid NSPanel subclassing traps in Swift.
class NotchPanelController: NSObject {

    private let panelWidth: CGFloat = 420
    private let panelHeight: CGFloat = 340
    private let cornerRadius: CGFloat = 16
    private(set) var panel: NSPanel!

    private var targetScreen: NSScreen?
    private var configManager: ConfigManager?

    private var hostingView: NSHostingView<PanelContentView>?
    private var visualEffectView: NSVisualEffectView?

    private var expandedFrame: CGRect = .zero
    private var collapsedFrame: CGRect = .zero

    func setup(screen: NSScreen, configManager: ConfigManager) {
        self.targetScreen = screen
        self.configManager = configManager

        let notchRect = screen.notchRect
        let collapsed = CGRect(
            x: notchRect.midX - 60,
            y: notchRect.minY,
            width: 120,
            height: 1
        )

        self.collapsedFrame = collapsed
        self.expandedFrame = CGRect(
            x: notchRect.midX - panelWidth / 2,
            y: notchRect.minY - panelHeight,
            width: panelWidth,
            height: panelHeight
        )

        panel = NSPanel(
            contentRect: collapsed,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none

        setupContent()
        panel.setFrame(collapsed, display: false)
    }

    private func setupContent() {
        guard let configManager = configManager else { return }
        
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: expandedFrame.size))
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        self.visualEffectView = effectView

        let contentView = PanelContentView(configManager: configManager)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(origin: .zero, size: expandedFrame.size)
        hosting.autoresizingMask = [.width, .height]

        effectView.addSubview(hosting)
        panel.contentView = effectView
        self.hostingView = hosting
    }

    func showAnimated() {
        guard !panel.isVisible else { return }
        panel.setFrame(collapsedFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(expandedFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hideAnimated() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(collapsedFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}
