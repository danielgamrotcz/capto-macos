# Capto (capto-macos)

Native macOS menu bar app for quick note-taking with Notion integration.

## Tech Stack

- **Language:** Swift 5
- **UI:** SwiftUI + AppKit (macOS 14+)
- **Build:** Xcode 16+, XcodeGen
- **Dependencies:** None (pure Apple frameworks + Carbon for hotkeys)

## Commands

```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -scheme Capto -configuration Debug

# Build release
xcodebuild -scheme Capto -configuration Release
```

## Project Structure

```
Capto/
├── main.swift               # Entry point
├── AppDelegate.swift        # App lifecycle, menu bar, panel management
├── FloatingPanel.swift      # Borderless floating window
├── NoteInputView.swift      # Main SwiftUI input view
├── NoteTextEditor.swift     # Custom text editor with placeholder
├── NotionService.swift      # Notion API integration
├── NoteQueue.swift          # Offline queue persistence
├── GlobalHotkey.swift       # Carbon global hotkey (Ctrl+Opt+Cmd+I)
├── SettingsView.swift       # Token & shortcut configuration
├── ShortcutRecorder.swift   # Hotkey recording UI
└── AccessibilityHelper.swift # System accessibility prompt
```

## App Icon

- Generated via `~/Projects/icon-generator` (key: `capto`, symbol: inbox tray + arrow)
- Asset: `Capto/Assets.xcassets/AppIcon.appiconset/`

## Key Patterns

- Notion token + page ID stored in **UserDefaults** (user enters via Settings UI)
- Global hotkey via Carbon HIToolbox
- Offline queue persists notes to disk when network unavailable
- App Sandbox disabled (required for global hotkey + accessibility)
