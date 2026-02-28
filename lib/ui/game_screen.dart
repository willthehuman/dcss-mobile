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
import 'status_bar_widget.dart';
import 'txt_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final TileScene _tileScene;
  bool _assetsReady = false;
  int _assetsVersion = 0;

  @override
  void initState() {
    super.initState();
    _tileScene = TileScene(
      onTileTap: (point) {
        ref.read(gameStateProvider.notifier).sendTileClick(point);
      },
    );
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
      final int currentVersion = _assetsVersion;
      if (_assetsReady) {
        return;
      }
      _assetsVersion += 1;
      Future<void>(() async {
        await _tileScene.setTileAssets(
          sheetPaths: assets.sheetPaths,
          tileIndexResolver: assets.tileIndexResolver,
        );
        if (!mounted || currentVersion + 1 != _assetsVersion) {
          return;
        }
        setState(() {
          _assetsReady = true;
        });
      });
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 55,
              child: Stack(
                children: <Widget>[
                  // TEMP DEBUG — always visible in release, remove later
                  Container(
                    color: Colors.deepPurple,
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'tiles:${gameState.tileGrid.length} '
                      'log:${gameState.messageLog.length} '
                      'hp:${gameState.playerStats.hp} '
                      'ready:$_assetsReady',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  Positioned.fill(child: GameWidget(game: _tileScene)),
                  if (!_assetsReady)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        alignment: Alignment.center,
                        child: tileAssets.when(
                          data: (_) => const CircularProgressIndicator(),
                          loading: () => const CircularProgressIndicator(),
                          error: (Object error, StackTrace trace) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Unable to load tiles: $error',
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
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
              flex: 5,
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
