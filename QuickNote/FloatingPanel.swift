import AppKit

final class FloatingPanel: NSPanel {
    init(
        size: NSSize = NSSize(width: 480, height: 180),
        hidesOnDeactivate: Bool = true
    ) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        self.hidesOnDeactivate = hidesOnDeactivate
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
