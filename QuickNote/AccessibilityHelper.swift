import AppKit
import ApplicationServices

enum AccessibilityHelper {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Pokud aplikace nemá Accessibility oprávnění, zobrazí systémový dialog.
    /// Pokud oprávnění už má, nedělá nic.
    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
