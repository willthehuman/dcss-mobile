# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- Install dependencies and generate platform folders (if missing):  
  `flutter pub get`  
  `flutter create --platforms=android,ios .`

- Run the app (debug):  
  `flutter run`

- Analyze code:  
  `flutter analyze --no-fatal-infos --no-fatal-warnings`

- Run tests:  
  `flutter test`

- Build Android release:  
  `flutter build apk --release`  
  `flutter build appbundle --release`

- Build iOS (unsigned):  
  `flutter build ios --release --no-codesign`

- Build web/PWA:  
  `flutter build web --release --base-href "/dcss-mobile/"`

## Architecture

This is a Flutter mobile (portrait-only) client for Dungeon Crawl Stone Soup Webtiles, using Riverpod for state management, Flame for tile rendering, and a WebSocket connection to a DCSS Webtiles server.

### Core Layers
- **Network**: `websocket_manager.dart` + `dcss_protocol.dart` handle persistent WSS connection and JSON protocol parsing for game state, messages, and input commands.
- **Game State**: `game_state.dart` (Riverpod providers) holds live game data received from the server (map tiles, player status, messages).
- **Rendering**: Flame `TileScene` (`tile_scene.dart`) renders the central viewport using pre-fetched tile sprites. `TileIndexResolver` and tile sheets from the server provide sprite coordinates. `tile_loader.dart` fetches/caches PNG tiles via HTTP + `dio`.
- **UI**: 
  - `LoginScreen` for server selection and login.
  - `GameScreen` combines Flame viewport, status bar, message log, virtual keyboard, and overlays.
  - Virtual keyboard (`keyboard/`): 5 tabbed layers + modifier strip that sends key commands (move/act/char/keys/more).
  - Overlays for menus and text input (`txt_overlay.dart`, `menu_overlay.dart`).

State flows from WebSocket events to Riverpod notifiers to widgets and the Flame game. Tile images and game text use custom markup parsers.

See README.md for full details on supported servers, settings, and CI/CD.
