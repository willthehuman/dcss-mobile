import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String defaultServerUrl = 'wss://crawl.dcss.io/socket';

/// Known DCSS WebTiles servers that support HTTPS/WSS.
const List<({String name, String shortname, String location, String url})>
    knownServers = [
  (
    name: 'crawl.dcss.io',
    shortname: 'CDI',
    location: 'New York 🇺🇸',
    url: 'wss://crawl.dcss.io/socket',
  ),
  (
    name: 'crawl.project357.org',
    shortname: 'CPO',
    location: 'Sydney 🇦🇺',
    url: 'wss://crawl.project357.org/socket',
  ),
  (
    name: 'crawl.nemelex.cards',
    shortname: 'CNC',
    location: 'South Korea 🇰🇷',
    url: 'wss://crawl.nemelex.cards/socket',
  ),
  (
    name: 'underhound.eu:8080',
    shortname: 'CUE',
    location: 'Europe 🇪🇺',
    url: 'wss://underhound.eu:8080/socket',
  ),
];
const String appVersion = '1.0.0+1';

class AppSettings {
  const AppSettings({
    this.serverUrl = defaultServerUrl,
    this.tileScaleMultiplier = 1.0,
    this.messageLogFontSize = 14.0,
    this.hapticsEnabled = true,
    this.showGridLines = false,
  });

  final String serverUrl;
  final double tileScaleMultiplier;
  final double messageLogFontSize;
  final bool hapticsEnabled;
  final bool showGridLines;

  AppSettings copyWith({
    String? serverUrl,
    double? tileScaleMultiplier,
    double? messageLogFontSize,
    bool? hapticsEnabled,
    bool? showGridLines,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      tileScaleMultiplier: tileScaleMultiplier ?? this.tileScaleMultiplier,
      messageLogFontSize: messageLogFontSize ?? this.messageLogFontSize,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      showGridLines: showGridLines ?? this.showGridLines,
    );
  }
}
final tileBaseUrlProvider = StateProvider<String>((ref) => '');

final settingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (Ref ref) => AppSettingsNotifier(),
);

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const String _serverUrlKey = 'settings.serverUrl';
  static const String _tileScaleKey = 'settings.tileScaleMultiplier';
  static const String _messageFontSizeKey = 'settings.messageLogFontSize';
  static const String _hapticsKey = 'settings.hapticsEnabled';
  static const String _gridLinesKey = 'settings.showGridLines';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    state = state.copyWith(
      serverUrl: prefs.getString(_serverUrlKey) ?? defaultServerUrl,
      tileScaleMultiplier: prefs.getDouble(_tileScaleKey) ?? 1.0,
      messageLogFontSize: prefs.getDouble(_messageFontSizeKey) ?? 14.0,
      hapticsEnabled: prefs.getBool(_hapticsKey) ?? true,
      showGridLines: prefs.getBool(_gridLinesKey) ?? false,
    );
  }

  Future<void> setServerUrl(String value) async {
    final String normalized = value.trim().isEmpty ? defaultServerUrl : value;
    state = state.copyWith(serverUrl: normalized);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalized);
  }

  Future<void> setTileScaleMultiplier(double value) async {
    state = state.copyWith(tileScaleMultiplier: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_tileScaleKey, value);
  }

  Future<void> setMessageLogFontSize(double value) async {
    state = state.copyWith(messageLogFontSize: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_messageFontSizeKey, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, value);
  }

  Future<void> setShowGridLines(bool value) async {
    state = state.copyWith(showGridLines: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gridLinesKey, value);
  }
}
