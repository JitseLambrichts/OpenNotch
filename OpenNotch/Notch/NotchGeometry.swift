import AppKit

// MARK: – NSScreen Notch Geometry Extension

extension NSScreen {

    /// Whether this screen has a camera notch (MacBook Pro 2021+).
    var hasNotch: Bool {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top > 0
        }
        return false
    }

    /// The height of the notch / menu-bar safe-area inset.
    var notchHeight: CGFloat {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top
        }
        return 0
    }

    /// Rectangle of the notch in **screen coordinates** (origin at bottom-left).
    var notchRect: CGRect {
        guard hasNotch else { return .zero }
        if #available(macOS 12.0, *) {
            let leftArea = auxiliaryTopLeftArea ?? .zero
            let rightArea = auxiliaryTopRightArea ?? .zero

            // The notch sits between the two auxiliary areas, at the top of the screen.
            let screenTop = frame.maxY
            let notchLeft = frame.origin.x + leftArea.width
            let notchWidth = frame.width - leftArea.width - rightArea.width
            let notchH = safeAreaInsets.top

            return CGRect(
                x: notchLeft,
                y: screenTop - notchH,
                width: notchWidth,
                height: notchH
            )
        }
        return .zero
    }

    /// Size of the notch area.
    var notchSize: CGSize {
        return notchRect.size
    }

    /// The center X of the notch in screen coordinates.
    var notchCenterX: CGFloat {
        return notchRect.midX
    }
}
