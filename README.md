# DCSS Mobile

Native portrait Flutter client for **Dungeon Crawl Stone Soup (DCSS) Webtiles**.

This project targets sideloaded mobile builds and connects to any DCSS WebTiles server over WSS. The default server is `wss://crawl.dcss.io/socket`, with four well-known public servers selectable in-app and support for custom URLs.

<img width="645" height="1398" alt="IMG_1245" src="https://github.com/user-attachments/assets/5dac0a15-fba2-4cb3-b856-c18401ba714d" />

## What is included

**Networking**
- WebSocket connection manager with full DCSS Webtiles JSON protocol support
- HTTP tile image fetcher (`dio`) with local caching via `path_provider`

**Rendering**
- Flame-based tile viewport (`tile_scene.dart`)
- HTTP tile loader/cache (`tile_loader.dart`)
- Individual tile sprite widget (`tile_sprite_widget.dart`)
- DCSS color/markup text utilities (`dcss_text_util.dart`)

**UI**
- Login screen with built-in server picker and credential storage (`flutter_secure_storage`)
- In-game screen: tile viewport, status bar, and scrollable message log
- In-game menu overlay
- In-game text prompt overlay (`txt_overlay.dart`)
- Tabbed virtual keyboard panel with **5 layers**:
  - **Move** — 8-directional movement, wait, rest
  - **Act** — common actions (open, close, pick up, drop, …)
  - **Char** — character screens (inventory, spells, skills, …)
  - **Keys** — special keys (Enter, Escape, Tab, …)
  - **More** — less-common commands
  - Persistent **modifier strip** (Ctrl / Shift toggles)
- Settings screen with persistent preferences (`shared_preferences`)

**State management**
- Riverpod throughout (`flutter_riverpod`)

## Supported Servers

| Short | Name | Location | WSS URL |
|-------|------|----------|---------|
| CDI | crawl.dcss.io | New York 🇺🇸 | `wss://crawl.dcss.io/socket` |
| CPO | crawl.project357.org | Sydney 🇦🇺 | `wss://crawl.project357.org/socket` |
| CNC | crawl.nemelex.cards | South Korea 🇰🇷 | `wss://crawl.nemelex.cards/socket` |
| CUE | underhound.eu:8080 | Europe 🇪🇺 | `wss://underhound.eu:8080/socket` |

Custom server URLs can be entered manually in Settings.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Server URL | `wss://crawl.dcss.io/socket` | WebTiles server to connect to |
| Tile Scale Multiplier | `1.0` | Scales the tile viewport rendering size |
| Message Log Font Size | `14.0` | Font size for the in-game message log |
| Haptics Enabled | `true` | Vibration feedback on key presses |
| Show Grid Lines | `false` | Overlay grid lines on the tile viewport |

## Project Structure

```
lib/
├── main.dart                     # App entry point
├── app.dart                      # Root widget / router
├── game/
│   ├── game_state.dart           # Game state (Riverpod)
│   ├── tile_index.dart           # Tile ID → sprite mapping
│   ├── tile_loader.dart          # HTTP tile fetcher + cache
│   └── tile_scene.dart           # Flame tile scene renderer
├── network/
│   ├── dcss_protocol.dart        # Webtiles JSON protocol parser
│   └── websocket_manager.dart    # WebSocket connection manager
├── ui/
│   ├── game_screen.dart          # Main in-game screen
│   ├── login_screen.dart         # Login + server picker
│   ├── menu_overlay.dart         # In-game menu overlay
│   ├── message_log_widget.dart   # Scrolling message log
│   ├── status_bar_widget.dart    # HP / MP / gold status bar
│   ├── tile_sprite_widget.dart   # Single tile sprite widget
│   ├── txt_overlay.dart          # In-game text prompt overlay
│   ├── dcss_text_util.dart       # DCSS color/markup rendering
│   └── keyboard/
│       ├── keyboard_panel.dart   # Tabbed keyboard container
│       ├── layer_tab_bar.dart    # Layer tab bar
│       ├── modifier_strip.dart   # Ctrl / Shift modifier toggles
│       ├── move_layer.dart       # Movement layer
│       ├── act_layer.dart        # Actions layer
│       ├── char_layer.dart       # Character layer
│       ├── keys_layer.dart       # Special keys layer
│       ├── more_layer.dart       # More commands layer
│       ├── key_button.dart       # Individual key button widget
│       ├── keyboard_action.dart  # Key action model
│       └── keyboard_layer.dart   # Layer base class / interface
├── settings/
│   ├── app_settings.dart         # Settings model + Riverpod notifier
│   └── settings_screen.dart      # Settings UI screen
└── utils/
    └── keycode_helpers.dart      # DCSS keycode conversion helpers
```

## Requirements

- Flutter `>=3.3.0` (Dart SDK `>=3.3.0 <4.0.0`)
- Android SDK (for APK/AAB builds)
- Xcode (for iOS local builds)

## Quick start

```bash
flutter pub get
flutter run
```

If platform folders are missing in your local checkout, scaffold them once:

```bash
flutter create --platforms=android,ios .
```

## Local release builds

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### iOS (unsigned)

```bash
flutter build ios --release --no-codesign
```

## GitHub Actions CI

Workflow file: `.github/workflows/build.yml`

It runs on pushes to `main`, pull requests, manual dispatch, and version tags (`v*`).

Pipeline steps:

1. Checkout code
2. Setup Java + Flutter
3. Auto-generate missing `android/` and `ios/` folders if needed
4. `flutter pub get`
5. `flutter analyze`
6. Run tests when present
7. Build Android APK + AAB
8. Upload Android artifacts
9. Run iOS validation build (`flutter build ios --release --no-codesign`) on macOS
10. Package an unsigned IPA from `Runner.app`
11. For tag pushes (`v*`), publish a GitHub Release with APK/AAB/IPA attached

### Triggering a release build

Push a tag like:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow will create a GitHub Release and attach:

- `app-release.apk`
- `app-release.aab`
- `dcss-mobile-unsigned.ipa`

## Notes

- CI validates iOS compilation with `--no-codesign` but does not produce a signed IPA.
- This app is intended for sideloading/testing, not app store submission.
