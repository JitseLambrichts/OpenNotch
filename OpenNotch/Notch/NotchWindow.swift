import AppKit
import SwiftUI

// MARK: – Delegate Protocol

protocol NotchWindowDelegate: AnyObject {
    func notchWindowMouseEntered()
    func notchWindowMouseExited()
}

// MARK: – NotchWindowController (Safe Controller Pattern)

/// Manages an invisible NSPanel positioned exactly over the MacBook notch.
/// avoids NSWindow subclassing traps in Swift.
class NotchWindowController: NSObject {

    weak var notchDelegate: NotchWindowDelegate?
    private(set) var panel: NSPanel!
    private var trackingView: NotchTrackingView?

    func setup(screen: NSScreen) {
        let notchRect = screen.notchRect
        let hoverRect = notchRect.insetBy(dx: -30, dy: -4)

        panel = NSPanel(
            contentRect: hoverRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.canHide = false

        let tView = NotchTrackingView(frame: NSRect(origin: .zero, size: hoverRect.size))
        tView.controller = self
        panel.contentView = tView
        self.trackingView = tView
        
        panel.orderFrontRegardless()
    }

    func mouseEntered() {
        notchDelegate?.notchWindowMouseEntered()
    }

    func mouseExited() {
        notchDelegate?.notchWindowMouseExited()
    }
}

// MARK: – Mouse Tracking View

private class NotchTrackingView: NSView {
    weak var controller: NotchWindowController?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    override func mouseEntered(with event: NSEvent) {
        controller?.mouseEntered()
    }
    override func mouseExited(with event: NSEvent) {
        controller?.mouseExited()
    }
}
