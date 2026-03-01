# Capto (capto-macos)

Native macOS menu bar app for quick note-taking with Supabase storage.

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
├── NoteService.swift        # Title generation (Claude AI) + Supabase save
├── SupabaseService.swift    # Supabase REST API client
├── SonioxService.swift      # Voice-to-text via Soniox API
├── GlobalHotkey.swift       # Carbon global hotkey (Ctrl+Opt+Cmd+I)
├── SettingsView.swift       # API keys & shortcut configuration
├── ShortcutRecorder.swift   # Hotkey recording UI
└── AccessibilityHelper.swift # System accessibility prompt
```

## App Icon

- Generated via `~/Projects/icon-generator` (key: `capto`, symbol: inbox tray + arrow)
- Asset: `Capto/Assets.xcassets/AppIcon.appiconset/`

## Key Patterns

- Notes saved directly to Supabase (no local filesystem storage)
- AI title generation via Anthropic Claude API (fallback: first 7 words)
- Supabase URL, service key, user ID stored in **UserDefaults**
- Global hotkey via Carbon HIToolbox
- Voice-to-text via Soniox (hold right Option key)
- App Sandbox disabled (required for global hotkey + accessibility)
