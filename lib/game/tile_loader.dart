import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tile_index.dart';
import '../settings/app_settings.dart';

// dart:io types are only imported on native.
import 'tile_loader_io.dart'
    if (dart.library.html) 'tile_loader_web.dart';

const String _defaultStaticBaseUrl = 'https://crawl.develz.org/static';

/// CORS proxy base URL for web builds.
///
/// After deploying the Cloudflare Worker in worker/cors-proxy, replace the
/// placeholder below with your real worker URL, e.g.:
///   'https://dcss-cors-proxy.<your-subdomain>.workers.dev/proxy'
///
/// Leave empty ('') to skip the proxy (tiles will fail on web due to CORS).
const String _corsProxyBaseUrl = '';

/// Wraps [url] in the CORS proxy when running as a web build and a proxy URL
/// has been configured. On native builds the URL is returned unchanged.
String _proxied(String url) {
  if (!kIsWeb) return url;
  if (_corsProxyBaseUrl.isEmpty) return url;
  // Strip the scheme — the worker path is /proxy/<host>/<path>
  final String withoutScheme = url.replaceFirst(RegExp(r'^https?://'), '');
  return '$_corsProxyBaseUrl/$withoutScheme';
}

class TileAssets {
  const TileAssets({
    required this.sheetPaths,
    required this.sheetBytes,
    required this.tileIndexResolver,
  });

  /// Native: local file paths keyed by sheet name.
  /// Web: empty (use [sheetBytes] instead).
  final Map<String, String> sheetPaths;

  /// Web: raw PNG bytes keyed by sheet name.
  /// Native: empty (use [sheetPaths] instead).
  final Map<String, List<int>> sheetBytes;

  final TileIndexResolver tileIndexResolver;
}

class TileLoaderService {
  TileLoaderService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const List<String> _tileInfoScripts = <String>[
    'tileinfo-floor.js',
    'tileinfo-wall.js',
    'tileinfo-feat.js',
    'tileinfo-main.js',
    'tileinfo-player.js',
    'tileinfo-gui.js',
    'tileinfo-icons.js',
  ];

  static const List<String> _tileInfoSheets = <String>[
    'floor.png',
    'wall.png',
    'feat.png',
    'main.png',
    'player.png',
    'gui.png',
    'icons.png',
  ];

  Future<TileAssets> prepareTiles({
    String staticBaseUrl = _defaultStaticBaseUrl,
    bool forceRefresh = false,
  }) async {
    if (kIsWeb) {
      return _prepareTilesWeb(staticBaseUrl: staticBaseUrl);
    } else {
      return _prepareTilesNative(
          staticBaseUrl: staticBaseUrl, forceRefresh: forceRefresh);
    }
  }

  // ─── Web path ──────────────────────────────────────────────────────────────

  Future<TileAssets> _prepareTilesWeb({
    required String staticBaseUrl,
  }) async {
    final List<String> tileInfoContents = <String>[];
    for (final String script in _tileInfoScripts) {
      final String url = _proxied('$staticBaseUrl/$script');
      try {
        final Response<String> res = await _dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        tileInfoContents.add(res.data ?? '');
      } catch (e) {
        debugPrint('[TileLoader] web: failed $url — $e');
        tileInfoContents.add('');
      }
    }

    final String joinedTileInfo = tileInfoContents.join('\n');
    final Set<String> discoveredSheets = _extractSheetPngNames(joinedTileInfo);
    discoveredSheets.addAll(_tileInfoSheets);

    final Map<String, List<int>> sheetBytes = <String, List<int>>{};
    for (final String sheetName in discoveredSheets) {
      final String normalized = _normalizeSheetName(sheetName);
      final String url = _proxied('$staticBaseUrl/$normalized');
      try {
        final Response<List<int>> res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          sheetBytes[normalized] = res.data!;
        }
      } catch (e) {
        debugPrint('[TileLoader] web: image failed $url — $e');
      }
    }

    final Map<int, TileLocation> indexMap =
        _parseTileIndexMap(tileInfoContents);
    return TileAssets(
      sheetPaths: const <String, String>{},
      sheetBytes: sheetBytes,
      tileIndexResolver: TileIndexResolver(indexMap),
    );
  }

  // ─── Native path (dart:io via conditional import) ──────────────────────────

  Future<TileAssets> _prepareTilesNative({
    required String staticBaseUrl,
    required bool forceRefresh,
  }) async {
    final dynamic cacheDir = await tileCacheDirectory();

    final List<String> tileInfoContents = <String>[];
    for (final String script in _tileInfoScripts) {
      final String scriptUrl = '$staticBaseUrl/$script';
      final String localName = script.split('/').last;
      final String content = await downloadTextWithCache(
        dio: _dio,
        url: scriptUrl,
        localFileName: localName,
        directory: cacheDir,
        forceRefresh: forceRefresh,
      );
      tileInfoContents.add(content);
    }

    final String joinedTileInfo = tileInfoContents.join('\n');
    final Set<String> discoveredSheets = _extractSheetPngNames(joinedTileInfo);
    discoveredSheets.addAll(_tileInfoSheets);

    final Map<String, String> sheetPaths = <String, String>{};
    for (final String sheetName in discoveredSheets) {
      final String normalized = _normalizeSheetName(sheetName);
      final String sheetUrl = '$staticBaseUrl/$normalized';
      final String filePath = await downloadBinaryWithCache(
        dio: _dio,
        url: sheetUrl,
        localFileName: normalized,
        directory: cacheDir,
        forceRefresh: forceRefresh,
      );
      sheetPaths[normalized] = filePath;
    }

    final Map<int, TileLocation> indexMap =
        _parseTileIndexMap(tileInfoContents);
    return TileAssets(
      sheetPaths: sheetPaths,
      sheetBytes: const <String, List<int>>{},
      tileIndexResolver: TileIndexResolver(indexMap),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Set<String> _extractSheetPngNames(String jsText) {
    final Set<String> sheets = <String>{};
    final RegExp directPngPattern = RegExp(r'([a-zA-Z0-9_\-]+\.png)');
    for (final RegExpMatch match in directPngPattern.allMatches(jsText)) {
      final String? value = match.group(1);
      if (value != null && value.isNotEmpty) {
        sheets.add(_normalizeSheetName(value));
      }
    }
    final RegExp bareSheetPattern = RegExp(
      r'''["'](?:sheet|tileset)["']\s*:\s*["']([a-zA-Z0-9_\-]+)["']''',
    );
    for (final RegExpMatch match in bareSheetPattern.allMatches(jsText)) {
      final String? value = match.group(1);
      if (value != null && value.isNotEmpty) {
        sheets.add(_normalizeSheetName(value));
      }
    }
    return sheets.map(_normalizeSheetName).toSet();
  }

  Map<int, TileLocation> _parseTileIndexMap(List<String> jsFiles) {
    final Map<int, TileLocation> indexMap = <int, TileLocation>{};
    int offset = 0;
    for (int i = 0; i < jsFiles.length && i < _tileInfoSheets.length; i++) {
      final String sheet = _tileInfoSheets[i];
      final List<TileLocation> locs = _parseSingleTileInfo(jsFiles[i], sheet);
      debugPrint(
          '[TileLoader] $sheet: ${locs.length} entries at offset $offset');
      for (int j = 0; j < locs.length; j++) {
        indexMap[offset + j] = locs[j];
      }
      offset += locs.length;
    }
    return indexMap;
  }

  List<TileLocation> _parseSingleTileInfo(String js, String sheet) {
    final List<TileLocation> baseLocs = <TileLocation>[];
    final int start = js.indexOf('var tile_info');
    final String searchIn = start >= 0 ? js.substring(start) : js;
    final RegExp re = RegExp(
        r'ox\s*:\s*(\d+)\s*,\s*oy\s*:\s*(\d+)\s*,\s*sx\s*:\s*(\d+)\s*,\s*sy\s*:\s*(\d+)\s*,\s*ex\s*:\s*(\d+)\s*,\s*ey\s*:\s*(\d+)');
    for (final RegExpMatch m in re.allMatches(searchIn)) {
      final int? ox = int.tryParse(m.group(1) ?? '');
      final int? oy = int.tryParse(m.group(2) ?? '');
      final int? sx = int.tryParse(m.group(3) ?? '');
      final int? sy = int.tryParse(m.group(4) ?? '');
      final int? ex = int.tryParse(m.group(5) ?? '');
      final int? ey = int.tryParse(m.group(6) ?? '');
      if (sx != null && sy != null && ex != null && ey != null &&
          ox != null && oy != null) {
        baseLocs.add(TileLocation(
          sheet: sheet, x: sx, y: sy, w: ex - sx, h: ey - sy, ox: ox, oy: oy,
        ));
      }
    }
    final int baseTilesStart = js.indexOf('var _basetiles');
    if (baseTilesStart >= 0) {
      final int arrayStart = js.indexOf('[', baseTilesStart);
      final int arrayEnd = js.indexOf(']', arrayStart);
      if (arrayStart >= 0 && arrayEnd >= 0) {
        final String curArr = js.substring(arrayStart + 1, arrayEnd);
        final List<TileLocation> finalLocs = <TileLocation>[];
        final RegExp numRe = RegExp(r'\b(\d+)\b');
        for (final RegExpMatch m in numRe.allMatches(curArr)) {
          final int idx = int.parse(m.group(1)!);
          if (idx >= 0 && idx < baseLocs.length) {
            finalLocs.add(baseLocs[idx]);
          } else {
            finalLocs.add(
                TileLocation(sheet: sheet, x: 0, y: 0, w: 0, h: 0));
          }
        }
        if (finalLocs.isNotEmpty) return finalLocs;
      }
    }
    return baseLocs;
  }

  String _normalizeSheetName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'dngn.png';
    final String baseName = trimmed.replaceAll('\\', '/').split('/').last;
    String normalized = baseName;
    if (!normalized.toLowerCase().endsWith('.png')) {
      normalized = '$normalized.png';
    }
    return normalized;
  }

  // Cache size / clear helpers (native only — no-ops on web)
  static Future<double> cacheSizeInMb() async {
    if (kIsWeb) return 0.0;
    return nativeCacheSizeInMb();
  }

  static Future<void> clearCache() async {
    if (kIsWeb) return;
    await nativeClearCache();
  }
}

final tileLoaderProvider = Provider<TileLoaderService>(
  (Ref ref) => TileLoaderService(),
);

final tileAssetsProvider = FutureProvider<TileAssets>((Ref ref) async {
  final TileLoaderService loader = ref.watch(tileLoaderProvider);
  final String serverUrl = ref.watch(settingsProvider).serverUrl;
  final String gameClientVersion = ref.watch(tileBaseUrlProvider);

  if (gameClientVersion.isEmpty) {
    return TileAssets(
      sheetPaths: const <String, String>{},
      sheetBytes: const <String, List<int>>{},
      tileIndexResolver: TileIndexResolver(const <int, TileLocation>{}),
    );
  }

  final Uri wsUri = Uri.parse(serverUrl);
  final String staticBase = gameClientVersion.isNotEmpty
      ? 'https://${wsUri.host}/gamedata/$gameClientVersion'
      : 'https://${wsUri.host}/static';

  debugPrint('[TileLoader] staticBase resolved to: $staticBase');
  return loader.prepareTiles(staticBaseUrl: staticBase);
});
