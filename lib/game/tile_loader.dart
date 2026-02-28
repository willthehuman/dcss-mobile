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
    'js/tileinfo-dngn.js',
    'js/tileinfo-player.js',
  ];

  static const List<String> _fallbackSheets = <String>[
    'dungeon.png',
    'player.png',
    'gui.png',
  ];

  Future<TileAssets> prepareTiles({
    String staticBaseUrl = _defaultStaticBaseUrl,
    bool forceRefresh = false,
  }) async {
    debugPrint('[TileLoader] fetching: $staticBaseUrl/js/tileinfo-dngn.js');

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

    final String joinedTileInfo = tileInfoContents.join('\n');

    final Set<String> discoveredSheets = _extractSheetPngNames(joinedTileInfo);
    discoveredSheets.addAll(_fallbackSheets);

    final Map<String, String> sheetPaths = <String, String>{};
    for (final String sheetName in discoveredSheets) {
      final String normalizedSheet = _normalizeSheetName(sheetName);
      final String sheetUrl = '$staticBaseUrl/tiles/$normalizedSheet';
      final File file = await _downloadBinaryWithCache(
        url: sheetUrl,
        localFileName: normalizedSheet,
        directory: cacheDir,
        forceRefresh: forceRefresh,
      );
      sheetPaths[normalizedSheet] = file.path;
    }

    final Map<int, TileLocation> indexMap = _parseTileIndexMap(joinedTileInfo);
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

      if (response.statusCode == 304 && await localFile.exists()) {
        return localFile;
      }

      final List<int>? bytes = response.data;
      if (bytes != null && bytes.isNotEmpty) {
        await localFile.writeAsBytes(bytes, flush: true);
        await _persistCacheHeaders(localFile, response.headers);
      }
    } catch (_) {
      // Fallback to cached file.
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

  Map<int, TileLocation> _parseTileIndexMap(String jsText) {
    final Map<int, TileLocation> indexMap = <int, TileLocation>{};

    final List<RegExp> patterns = <RegExp>[
      RegExp(
        r'''\[(\d+)\]\s*=\s*\[\s*["']([^"']+?\.png)["']\s*,\s*(\d+)\s*,\s*(\d+)''',
      ),
      RegExp(
        r'''(\d+)\s*:\s*\[\s*["']([^"']+?\.png)["']\s*,\s*(\d+)\s*,\s*(\d+)''',
      ),
      RegExp(
        r'''["']index["']\s*:\s*(\d+).*?["']sheet["']\s*:\s*["']([^"']+)["'].*?["'](?:col|x)["']\s*:\s*(\d+).*?["'](?:row|y)["']\s*:\s*(\d+)''',
        dotAll: true,
      ),
    ];

    for (final RegExp pattern in patterns) {
      for (final RegExpMatch match in pattern.allMatches(jsText)) {
        final int? index = int.tryParse(match.group(1) ?? '');
        final String sheetRaw = match.group(2) ?? '';
        final int? col = int.tryParse(match.group(3) ?? '');
        final int? row = int.tryParse(match.group(4) ?? '');
        if (index == null || col == null || row == null || sheetRaw.isEmpty) {
          continue;
        }

        indexMap[index] = TileLocation(
          sheet: _normalizeSheetName(sheetRaw),
          col: col,
          row: row,
        );
      }
    }

    return indexMap;
  }

  String _normalizeSheetName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'dungeon.png';
    }

    final String baseName = trimmed.replaceAll('\\', '/').split('/').last;
    String normalized = baseName;
    if (!normalized.toLowerCase().endsWith('.png')) {
      normalized = '$normalized.png';
    }

    if (normalized == 'dngn.png') {
      return 'dungeon.png';
    }
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

// Change tileAssetsProvider to derive the static URL from settings
final tileAssetsProvider = FutureProvider<TileAssets>(
  (Ref ref) async {
    final TileLoaderService loader = ref.watch(tileLoaderProvider);
    final String serverUrl = ref.watch(settingsProvider).serverUrl;

    final Uri wsUri = Uri.parse(serverUrl);
    // Strip the socket/webtiles suffix from the path to get the game prefix
    // e.g. /0.34/socket → /0.34,  /socket → (empty)
    final String gamePath =
        wsUri.path.replaceAll(RegExp(r'/(socket|webtiles)$'), '');
    final String staticBase = 'https://${wsUri.host}$gamePath/static';

    return loader.prepareTiles(staticBaseUrl: staticBase);
  },
);
