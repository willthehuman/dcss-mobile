import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_state.dart';
import '../game/tile_loader.dart';
import '../game/tile_scene.dart';
import '../network/websocket_manager.dart';
import '../settings/app_settings.dart';
import '../settings/settings_screen.dart';
import 'keyboard/keyboard_panel.dart';
import 'menu_overlay.dart';
import 'message_log_widget.dart';
import 'status_bar_widget.dart';
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
  bool _returnedToLogin = false;

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
    final TileAssets? resolvedTileAssets = tileAssets.valueOrNull;
    final bool tileAssetDataReady = resolvedTileAssets != null &&
        (resolvedTileAssets.sheetPaths.isNotEmpty ||
            resolvedTileAssets.sheetBytes.isNotEmpty);

    ref.listen<WebsocketState>(
      websocketProvider,
      (WebsocketState? previous, WebsocketState next) {
        final bool sessionEnded =
            next.status == WebsocketConnectionStatus.error ||
            (previous?.isConnected == true &&
                next.status == WebsocketConnectionStatus.disconnected);
        if (sessionEnded) {
          _returnToLogin();
        }
      },
    );

    _tileScene.updateFromState(
      tileGrid: gameState.tileGrid,
      playerPos: gameState.playerPos,
      cursorPos: gameState.cursorPos,
      tileScaleMultiplier: settings.tileScaleMultiplier,
      showGridLines: settings.showGridLines,
    );

    tileAssets.whenData((TileAssets assets) {
      // Skip empty assets (not yet loaded) — check both maps since one will
      // always be empty depending on platform (web uses bytes, native uses paths).
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
                      tileAssets: tileAssetDataReady ? resolvedTileAssets : null,
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
                  ref.read(gameStateProvider.notifier).sendKeyCode(keycode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _returnToLogin() {
    if (!mounted || _returnedToLogin) {
      return;
    }

    _returnedToLogin = true;
    ref.read(gameStateProvider.notifier).reset();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
