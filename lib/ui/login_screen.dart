import 'dart:async';
import 'package:dcss_mobile/game/tile_loader.dart';

import '../game/game_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/websocket_manager.dart';
import '../settings/app_settings.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _rememberMeKey = 'auth.rememberMe';
  static const String _savedServerKey = 'auth.serverUrl';
  static const String _savedUsernameKey = 'auth.username';
  static const String _savedPasswordKey = 'auth.password';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _didAutoLoginAttempt = false;
  bool _navigatedToGame = false;
  String? _errorText;

 @override
void initState() {
  super.initState();
  _serverController.text = ref.read(settingsProvider).serverUrl;

  // Pre-subscribe GameStateNotifier NOW so it never misses game messages,
  // regardless of when PlayRequest fires relative to navigation.
  ref.read(gameStateProvider.notifier);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadSavedCredentials();
  });
}


  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WebsocketState>(
      websocketProvider,
      (WebsocketState? previous, WebsocketState next) {
        unawaited(_onSocketStateChanged(previous, next));
      },
    );
    ref.watch(tileAssetsProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Dungeon Crawl Stone Soup',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Webtiles mobile client',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: defaultServerUrl,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _connect(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _rememberMe,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remember me'),
                    onChanged: (bool? value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                  
                  if (_isSubmitting)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _statusLabel(ref.watch(websocketProvider).status),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 10),
                  if (_errorText != null && _errorText!.trim().isNotEmpty)
                    Text(
                      _errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadSavedCredentials() async {
    final String settingsServer = ref.read(settingsProvider).serverUrl;

    if (_serverController.text.trim().isEmpty) {
      _serverController.text = settingsServer;
    }

    final String rememberRaw =
        await _secureStorage.read(key: _rememberMeKey) ?? 'false';
    final bool remember = rememberRaw.toLowerCase() == 'true';

    if (!remember) {
      setState(() {
        _rememberMe = false;
      });
      return;
    }

    final String savedServer = await _secureStorage.read(key: _savedServerKey) ?? '';
    final String savedUsername =
        await _secureStorage.read(key: _savedUsernameKey) ?? '';
    final String savedPassword =
        await _secureStorage.read(key: _savedPasswordKey) ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _rememberMe = true;
      if (savedServer.trim().isNotEmpty) {
        _serverController.text = savedServer;
      }
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
    });

    if (savedUsername.trim().isNotEmpty && savedPassword.isNotEmpty) {
      _didAutoLoginAttempt = true;
      await _connect();
    }
  }

  Future<void> _connect() async {
    final String serverUrl = _serverController.text.trim();
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (serverUrl.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Server URL, username, and password are required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    await ref.read(settingsProvider.notifier).setServerUrl(serverUrl);
    await ref.read(websocketProvider.notifier).connect(
          serverUrl: serverUrl,
          username: username,
          password: password,
        );
  }

  Future<void> _onSocketStateChanged(
    WebsocketState? previous,
    WebsocketState next,
  ) async {
    if (!mounted) {
      return;
    }

    if (next.status == WebsocketConnectionStatus.error) {
      setState(() {
        _isSubmitting = false;
        _errorText = next.errorMessage ?? 'Unable to connect.';
      });
      return;
    }

    final bool connecting = next.status == WebsocketConnectionStatus.connecting ||
        next.status == WebsocketConnectionStatus.authenticating ||
        next.status == WebsocketConnectionStatus.reconnecting;

    if (connecting && !_isSubmitting) {
      setState(() {
        _isSubmitting = true;
      });
    }

    if (next.isConnected && !_navigatedToGame) {
      _navigatedToGame = true;
      if (_rememberMe) {
        await _saveCredentials();
      } else {
        await _clearCredentials();
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed('/game');
      return;
    }

    if (_didAutoLoginAttempt &&
        next.status == WebsocketConnectionStatus.disconnected &&
        next.errorMessage != null) {
      setState(() {
        _isSubmitting = false;
        _errorText = next.errorMessage;
      });
    }
  }

  Future<void> _saveCredentials() async {
    await _secureStorage.write(key: _rememberMeKey, value: 'true');
    await _secureStorage.write(key: _savedServerKey, value: _serverController.text.trim());
    await _secureStorage.write(key: _savedUsernameKey, value: _usernameController.text.trim());
    await _secureStorage.write(key: _savedPasswordKey, value: _passwordController.text);
  }

  Future<void> _clearCredentials() async {
    await _secureStorage.write(key: _rememberMeKey, value: 'false');
    await _secureStorage.delete(key: _savedServerKey);
    await _secureStorage.delete(key: _savedUsernameKey);
    await _secureStorage.delete(key: _savedPasswordKey);
  }

  String _statusLabel(WebsocketConnectionStatus status) {
    switch (status) {
      case WebsocketConnectionStatus.connecting:
        return 'Connecting to server…';
      case WebsocketConnectionStatus.authenticating:
        return 'Waiting for server greeting…';
      case WebsocketConnectionStatus.reconnecting:
        return 'Retrying connection…';
      default:
        return '';
    }
  }

}
