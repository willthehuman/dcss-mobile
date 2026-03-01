import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'tile_index.dart';
import '../settings/app_settings.dart';

const String _defaultStaticBaseUrl = 'https://crawl.develz.org/static';

class TileAssets {
  const TileAssets({
    required this.sheetPaths,
    required this.tileIndexResolver,
  });

  final Map<String, String> sheetPaths;
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
    'tileinfo-gui.js',     // ← gui BEFORE icons (matches C++ TEX_GUI)
    'tileinfo-icons.js',   // ← icons LAST (matches C++ TEX_ICONS)
  ];

  static const List<String> _tileInfoSheets = <String>[
    'floor.png',
    'wall.png',
    'feat.png',
    'main.png',
    'player.png',
    'gui.png',     // ← gui BEFORE icons
    'icons.png',   // ← icons LAST
  ];


  Future<TileAssets> prepareTiles({
    String staticBaseUrl = _defaultStaticBaseUrl,
    bool forceRefresh = false,
  }) async {
    debugPrint('[TileLoader] fetching: $staticBaseUrl/tileinfo-dngn.js');

    final Directory cacheDir = await _tileCacheDirectory();

    final List<String> tileInfoContents = <String>[];
    for (final String script in _tileInfoScripts) {
      final String scriptUrl = '$staticBaseUrl/$script';
      final String localName = script.split('/').last;
      final String content = await _downloadTextWithCache(
        url: scriptUrl,
        localFileName: localName,
        directory: cacheDir,
        forceRefresh: forceRefresh,
      );
      tileInfoContents.add(content);
    }

    for (int i = 0; i < tileInfoContents.length; i++) {
      final String js = tileInfoContents[i];
      final int tiIdx = js.indexOf('var tile_info');
      if (tiIdx >= 0) {
        debugPrint('[TileLoader] sub[$i] tile_info: ${js.substring(tiIdx, (tiIdx + 300).clamp(0, js.length))}');
      }
      else {
        debugPrint('[TileLoader] sub[$i] NO get_tile_info found');
      }
    }

    final String joinedTileInfo = tileInfoContents.join('\n');

    final Set<String> discoveredSheets = _extractSheetPngNames(joinedTileInfo);
    discoveredSheets.addAll(_tileInfoSheets);

    for (final String sheet in discoveredSheets) {
      final String normalized = _normalizeSheetName(sheet);
      final File f = File('${cacheDir.path}/${Platform.pathSeparator}$normalized');
      debugPrint('[TileLoader] sheet $normalized exists: ${f.existsSync()}');
    }

    final Map<String, String> sheetPaths = <String, String>{};
    for (final String sheetName in discoveredSheets) {
      final String normalizedSheet = _normalizeSheetName(sheetName);
      final String sheetUrl = '$staticBaseUrl/$normalizedSheet';
      final File file = await _downloadBinaryWithCache(
        url: sheetUrl,
        localFileName: normalizedSheet,
        directory: cacheDir,
        forceRefresh: forceRefresh,
      );
      sheetPaths[normalizedSheet] = file.path;
    }
    final Map<int, TileLocation> indexMap = _parseTileIndexMap(tileInfoContents);
    return TileAssets(
      sheetPaths: sheetPaths,
      tileIndexResolver: TileIndexResolver(indexMap),
    );
  }

  Future<Directory> _tileCacheDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir =
        Directory('${docs.path}${Platform.pathSeparator}tiles');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _downloadTextWithCache({
    required String url,
    required String localFileName,
    required Directory directory,
    required bool forceRefresh,
  }) async {
    final File localFile = File(
      '${directory.path}${Platform.pathSeparator}$localFileName',
    );
    final Map<String, String> headers = await _cacheHeadersFor(
      localFile,
      forceRefresh,
    );

    try {
      final Response<String> response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          validateStatus: (int? status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );

      debugPrint('[TileLoader] HTTP ${response.statusCode} for $url');

      if (response.statusCode == 304 && await localFile.exists()) {
        return localFile.readAsString();
      }

      final String body = response.data ?? '';
      if (body.isNotEmpty) {
        await localFile.writeAsString(body);
        await _persistCacheHeaders(localFile, response.headers);
        return body;
      }
    } catch (e) {
      debugPrint('[TileLoader] download failed for $url — $e');
    }

    if (await localFile.exists()) {
      debugPrint('[TileLoader] using cached $localFileName');
      return localFile.readAsString();
    }
    debugPrint('[TileLoader] no cache and no download for $localFileName');
    return '';
  }

  Future<File> _downloadBinaryWithCache({
    required String url,
    required String localFileName,
    required Directory directory,
    required bool forceRefresh,
  }) async {
    final File localFile = File(
      '${directory.path}${Platform.pathSeparator}$localFileName',
    );

    final Map<String, String> headers = await _cacheHeadersFor(
      localFile,
      forceRefresh,
    );

    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (int? status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );
      debugPrint('[TileLoader] image HTTP ${response.statusCode} for $url');  // ← add
      if (response.statusCode == 304 && await localFile.exists()) {
        return localFile;
      }

      final List<int>? bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        await localFile.writeAsBytes(bytes, flush: true);
        await _persistCacheHeaders(localFile, response.headers);
      }
    } catch (e) {
        debugPrint('[TileLoader] image failed: $url — $e');  // ← was catch (_) {}
    }

    return localFile;
  }

  Future<Map<String, String>> _cacheHeadersFor(
    File localFile,
    bool forceRefresh,
  ) async {
    if (forceRefresh || !await localFile.exists()) {
      return <String, String>{};
    }

    final File metaFile = File('${localFile.path}.meta.json');
    if (!await metaFile.exists()) {
      return <String, String>{};
    }

    try {
      final Map<String, dynamic> meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final Map<String, String> headers = <String, String>{};

      final String? etag = meta['etag']?.toString();
      final String? lastModified = meta['lastModified']?.toString();

      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
      if (lastModified != null && lastModified.isNotEmpty) {
        headers['If-Modified-Since'] = lastModified;
      }
      return headers;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _persistCacheHeaders(File localFile, Headers headers) async {
    final String? etag = headers.value('etag');
    final String? lastModified = headers.value('last-modified');

    final Map<String, dynamic> meta = <String, dynamic>{
      'etag': etag,
      'lastModified': lastModified,
      'savedAt': DateTime.now().toIso8601String(),
    };

    final File metaFile = File('${localFile.path}.meta.json');
    await metaFile.writeAsString(jsonEncode(meta));
  }

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

  for (int i = 0; i < jsFiles.length && i < _tileInfoSheets.length; i++) {
    final String sheet = _tileInfoSheets[i];
    final String js = jsFiles[i];
    final int startOffset = _extractStartOffset(js);
    final List<TileLocation> locs = _parseSingleTileInfo(js, sheet);
    debugPrint('[TileLoader] ${sheet}: ${locs.length} entries at offset $startOffset');
    for (int j = 0; j < locs.length; j++) {
      indexMap[startOffset + j] = locs[j];
    }
  }
  return indexMap;
}


List<TileLocation> _parseSingleTileInfo(String js, String sheet) {
  final List<TileLocation> locs = <TileLocation>[];
  final int start = js.indexOf('var tile_info');
  // For abstract modules with no tile_info array, search the whole file.
  final String searchArea = start >= 0 ? js.substring(start) : js;

  // Match each {...} block that contains at least sx and sy fields.
  final RegExp blockRe = RegExp(r'\{[^}]+\}');
  for (final RegExpMatch blockMatch in blockRe.allMatches(searchArea)) {
    final String block = blockMatch.group(0)!;
    final int? sx = _extractIntField(block, 'sx');
    final int? sy = _extractIntField(block, 'sy');
    if (sx == null || sy == null) continue;
    final int? ex = _extractIntField(block, 'ex');
    final int? ey = _extractIntField(block, 'ey');
    final int w = (ex != null && ex > sx) ? (ex - sx) : 32;
    final int h = (ey != null && ey > sy) ? (ey - sy) : 32;
    locs.add(TileLocation(sheet: sheet, x: sx, y: sy, w: w, h: h));
  }
  return locs;
}

/// Extracts the global starting offset from the first `exports.XXX = val = N;`
/// pattern found in the JS file.
int _extractStartOffset(String js) {
  final RegExp re = RegExp(r'exports\.\w+\s*=\s*val\s*=\s*(\d+)');
  final RegExpMatch? m = re.firstMatch(js);
  return m != null ? (int.tryParse(m.group(1) ?? '') ?? 0) : 0;
}

/// Extracts a named integer field (e.g. `sx:32`) from a tile info block string.
int? _extractIntField(String block, String key) {
  final RegExpMatch? m = RegExp('\\b${RegExp.escape(key)}\\s*:\\s*(\\d+)').firstMatch(block);
  return m != null ? int.tryParse(m.group(1) ?? '') : null;
}


  String _normalizeSheetName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return 'dngn.png';  // ← was 'dungeon.png'

    final String baseName = trimmed.replaceAll('\\', '/').split('/').last;
    String normalized = baseName;
    if (!normalized.toLowerCase().endsWith('.png')) {
      normalized = '$normalized.png';
    }

    // ← DELETE the dngn → dungeon remapping block entirely
    return normalized;
  }


  static Future<Directory> cacheDirectory() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir =
        Directory('${docs.path}${Platform.pathSeparator}tiles');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<double> cacheSizeInMb() async {
    final Directory dir = await cacheDirectory();
    int totalBytes = 0;

    await for (final FileSystemEntity entity in dir.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final String path = entity.path.toLowerCase();
      if (path.endsWith('.png') ||
          path.endsWith('.js') ||
          path.endsWith('.json')) {
        totalBytes += await entity.length();
      }
    }

    return totalBytes / (1024 * 1024);
  }

  static Future<void> clearCache() async {
    final Directory dir = await cacheDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }
}

final tileLoaderProvider = Provider<TileLoaderService>(
  (Ref ref) => TileLoaderService(),
);

final tileAssetsProvider = FutureProvider<TileAssets>((Ref ref) async {
  final TileLoaderService loader = ref.watch(tileLoaderProvider);
  final String serverUrl = ref.watch(settingsProvider).serverUrl;
  final String gameClientVersion = ref.watch(tileBaseUrlProvider); // reuse this provider

  if (gameClientVersion.isEmpty) {
    // Not logged in yet — return empty, will re-run when game_client arrives
    return TileAssets(sheetPaths: const <String, String>{},
        tileIndexResolver: TileIndexResolver(const <int, TileLocation>{}));
  }

  final Uri wsUri = Uri.parse(serverUrl);
  final String staticBase = gameClientVersion.isNotEmpty
      ? 'https://${wsUri.host}/gamedata/$gameClientVersion' // hash-based path
      : 'https://${wsUri.host}/static'; // legacy fallback

  debugPrint('[TileLoader] staticBase resolved to: $staticBase');
  return loader.prepareTiles(staticBaseUrl: staticBase);
});

