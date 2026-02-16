import Carbon.HIToolbox

final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let handler: () -> Void

    private static var activeInstance: GlobalHotkey?
    private static var eventHandlerInstalled = false

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
    }

    deinit {
        unregister()
    }

    func register() {
        guard hotKeyRef == nil else { return }

        GlobalHotkey.activeInstance = self
        installEventHandlerOnce()

        let signature = OSType(0x4E514E48) // "NQNH"
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("[GlobalHotkey] Failed to register: \(status) (keyCode=\(keyCode), modifiers=\(String(modifiers, radix: 16)))")
        } else {
            print("[GlobalHotkey] Registered: keyCode=\(keyCode), modifiers=0x\(String(modifiers, radix: 16))")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if GlobalHotkey.activeInstance === self {
            GlobalHotkey.activeInstance = nil
        }
    }

    private func installEventHandlerOnce() {
        guard !GlobalHotkey.eventHandlerInstalled else { return }
        GlobalHotkey.eventHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                GlobalHotkey.activeInstance?.handler()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
}
