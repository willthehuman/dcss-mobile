import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_state.dart';
import '../game/tile_loader.dart';
import '../game/tile_scene.dart';
import '../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import 'keyboard/keyboard_panel.dart';
import 'menu_overlay.dart';
import 'message_log_widget.dart';
import 'popups/ui_popup_overlay.dart';
import 'status_bar_widget.dart';
import 'targeting_overlay.dart';
import 'text_input_overlay.dart';
import 'txt_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final TileScene _tileScene;
  bool _assetsReady = false;
  bool _assetLoadStarted = false;
  TileAssets? _lastLoadedAssets;

  @override
  void initState() {
    super.initState();
    _tileScene = TileScene(
      onTileTap: (point) {
        final GameState gs = ref.read(gameStateProvider);
        if (gs.isInTargetingMode) {
          // In targeting mode a tile tap moves the cursor to that tile.
          // We do NOT auto-send Enter here — the player uses "Describe [v]"
          // when they want to describe the tile they tapped.
          ref.read(gameStateProvider.notifier).sendTileClick(point);
        } else {
          ref.read(gameStateProvider.notifier).sendTileClick(point);
        }
      },
    );
  }

  /// Remap Move-tab digit/numpad keycodes to vi-key keycodes when in
  /// targeting mode, so the keyboard panel moves the cursor rather than
  /// attempting to walk the player.
  ///
  /// The Move tab sends the character codes for '1'-'9' (49-57).
  /// DCSS webtiles cursor movement uses vi-keys (hjklyubn).
  int _remapForTargeting(int keycode) {
    switch (keycode) {
      case 56: return 107; // '8' (N)  → k
      case 50: return 106; // '2' (S)  → j
      case 52: return 104; // '4' (W)  → h
      case 54: return 108; // '6' (E)  → l
      case 55: return 121; // '7' (NW) → y
      case 57: return 117; // '9' (NE) → u
      case 49: return 98;  // '1' (SW) → b
      case 51: return 110; // '3' (SE) → n
      default: return keycode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameState gameState = ref.watch(gameStateProvider);
    final AppSettings settings = ref.watch(settingsProvider);
    final AsyncValue<TileAssets> tileAssets = ref.watch(tileAssetsProvider);

    _tileScene.updateFromState(
      tileGrid: gameState.tileGrid,
      playerPos: gameState.playerPos,
      cursorPos: gameState.cursorPos,
      tileScaleMultiplier: settings.tileScaleMultiplier,
      showGridLines: settings.showGridLines,
    );

    tileAssets.whenData((TileAssets assets) {
      final bool hasData =
          assets.sheetPaths.isNotEmpty || assets.sheetBytes.isNotEmpty;
      if (!hasData) return;
      if (_assetLoadStarted && identical(assets, _lastLoadedAssets)) return;

      _assetLoadStarted = true;
      _lastLoadedAssets = assets;
      Future<void>(() async {
        await _tileScene.setTileAssets(
          sheetPaths: assets.sheetPaths,
          sheetBytes: assets.sheetBytes,
          tileIndexResolver: assets.tileIndexResolver,
        );
        if (mounted) setState(() => _assetsReady = true);
      });
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 52,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: GameWidget(game: _tileScene)),
                  if (tileAssets is AsyncLoading)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  // Targeting overlay: slim banner + Describe/Exit buttons.
                  // Hidden while a popup is open (popup takes priority).
                  if (gameState.isInTargetingMode && gameState.uiPopup == null)
                    TargetingOverlay(
                      onKeycode: (int keycode) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendKeyCode(keycode);
                      },
                      onExit: () {
                        ref
                            .read(gameStateProvider.notifier)
                            .exitTargetingMode();
                      },
                    ),
                  if (gameState.activeMenu != null)
                    MenuOverlay(
                      menu: gameState.activeMenu!,
                      onHotkey: (int keycode) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendKeyCode(keycode);
                      },
                      onDismiss: () {
                        ref.read(gameStateProvider.notifier).dismissMenu();
                      },
                      tileAssets: tileAssets.valueOrNull,
                    ),
                  if (gameState.txtPayload != null)
                    TxtOverlay(
                      payload: gameState.txtPayload!,
                      onKeycode: (int keycode) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendKeyCode(keycode);
                      },
                    ),
                  if (gameState.uiPopup != null)
                    UiPopupOverlay(
                      uiType: gameState.uiPopup!.uiType,
                      payload: gameState.uiPopup!.payload,
                      onKeycode: (int keycode) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendKeyCode(keycode);
                      },
                      onTextInput: (String text) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendTextInput(text);
                      },
                    ),
                  if (gameState.textInputState != null)
                    TextInputOverlay(
                      inputState: gameState.textInputState!,
                      onSubmit: (String text) {
                        ref
                            .read(gameStateProvider.notifier)
                            .sendTextInput(text);
                      },
                      onDismiss: () {
                        ref.read(gameStateProvider.notifier).dismissTextInput();
                      },
                    ),
                  // TEMP DEBUG — remove before release
                  Container(
                    color: Colors.deepPurple,
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'tiles:${gameState.tileGrid.length} '
                      'log:${gameState.messageLog.length} '
                      'hp:${gameState.playerStats.hp} '
                      'ready:$_assetsReady '
                      '${gameState.isInTargetingMode ? "[TARGET]" : ""}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: MessageLogWidget(
                messages: gameState.messageLog,
                fontSize: settings.messageLogFontSize,
              ),
            ),
            Expanded(
              flex: 8,
              child: StatusBarWidget(
                stats: gameState.playerStats,
                onOpenSettings: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 30,
              child: KeyboardPanel(
                hapticsEnabled: settings.hapticsEnabled,
                onKeycode: (int keycode) {
                  final bool targeting =
                      ref.read(gameStateProvider).isInTargetingMode;

                  if (targeting) {
                    if (keycode == 27) {
                      // ESC exits targeting mode.
                      ref
                          .read(gameStateProvider.notifier)
                          .exitTargetingMode();
                      return;
                    }
                    // Remap Move-tab digit keys to vi-keys for cursor movement.
                    final int remapped = _remapForTargeting(keycode);
                    ref
                        .read(gameStateProvider.notifier)
                        .sendKeyCode(remapped);
                    return;
                  }

                  ref.read(gameStateProvider.notifier).sendKeyCode(keycode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
