import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_state.dart';
import '../game/tile_loader.dart';
import 'app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _serverController;
  late Future<double> _cacheSizeFuture;

  @override
  void initState() {
    super.initState();
    _serverController =
        TextEditingController(text: ref.read(settingsProvider).serverUrl);
    _cacheSizeFuture = TileLoaderService.cacheSizeInMb();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(settingsProvider);
    final GameState gameState = ref.watch(gameStateProvider);

    if (_serverController.text.trim().isEmpty) {
      _serverController.text = settings.serverUrl;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _serverController,
            decoration: const InputDecoration(
              labelText: 'Server URL override',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setServerUrl(
                    _serverController.text.trim(),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Server URL saved.')),
              );
            },
            child: const Text('Save server URL'),
          ),
          const SizedBox(height: 18),
          Text(
              'Tile scale: ${settings.tileScaleMultiplier.toStringAsFixed(2)}x'),
          Slider(
            min: 0.75,
            max: 2.0,
            divisions: 25,
            value: settings.tileScaleMultiplier.clamp(0.75, 2.0).toDouble(),
            onChanged: (double value) {
              ref.read(settingsProvider.notifier).setTileScaleMultiplier(value);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Message log font size: ${settings.messageLogFontSize.toStringAsFixed(0)}',
          ),
          Slider(
            min: 10,
            max: 18,
            divisions: 8,
            value: settings.messageLogFontSize.clamp(10, 18).toDouble(),
            onChanged: (double value) {
              ref.read(settingsProvider.notifier).setMessageLogFontSize(value);
            },
          ),
          SwitchListTile(
            value: settings.hapticsEnabled,
            title: const Text('Haptic feedback'),
            onChanged: (bool value) {
              ref.read(settingsProvider.notifier).setHapticsEnabled(value);
            },
          ),
          SwitchListTile(
            value: settings.showGridLines,
            title: const Text('Show grid lines on tile viewport'),
            onChanged: (bool value) {
              ref.read(settingsProvider.notifier).setShowGridLines(value);
            },
          ),
          const Divider(height: 28),
          FutureBuilder<double>(
            future: _cacheSizeFuture,
            builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
              final double sizeMb = snapshot.data ?? 0;
              final bool loading =
                  snapshot.connectionState == ConnectionState.waiting;
              return ListTile(
                title: const Text('Tile cache'),
                subtitle: Text(
                  loading
                      ? 'Calculating cache size...'
                      : '${sizeMb.toStringAsFixed(2)} MB cached',
                ),
                trailing: OutlinedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          await TileLoaderService.clearCache();
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _cacheSizeFuture =
                                TileLoaderService.cacheSizeInMb();
                          });
                        },
                  child: const Text('Clear cache'),
                ),
              );
            },
          ),
          const Divider(height: 28),
          const ListTile(
            title: Text('App version'),
            subtitle: Text(appVersion),
          ),
          ListTile(
            title: const Text('Server version'),
            subtitle: Text(gameState.versionInfo ?? 'Unknown'),
          ),
        ],
      ),
    );
  }
}
