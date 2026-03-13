// Native (dart:io) cache helpers — NOT imported on web.
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> tileCacheDirectory() async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir =
      Directory('${docs.path}${Platform.pathSeparator}tiles');
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String> downloadTextWithCache({
  required Dio dio,
  required String url,
  required String localFileName,
  required Directory directory,
  required bool forceRefresh,
}) async {
  final File localFile = File(
    '${directory.path}${Platform.pathSeparator}$localFileName',
  );
  final Map<String, String> headers =
      await _cacheHeadersFor(localFile, forceRefresh);

  try {
    final Response<String> response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
        validateStatus: (int? s) => s != null && s >= 200 && s < 400,
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
  return '';
}

Future<String> downloadBinaryWithCache({
  required Dio dio,
  required String url,
  required String localFileName,
  required Directory directory,
  required bool forceRefresh,
}) async {
  final File localFile = File(
    '${directory.path}${Platform.pathSeparator}$localFileName',
  );
  final Map<String, String> headers =
      await _cacheHeadersFor(localFile, forceRefresh);

  try {
    final Response<List<int>> response = await dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: headers,
        validateStatus: (int? s) => s != null && s >= 200 && s < 400,
      ),
    );
    debugPrint('[TileLoader] image HTTP ${response.statusCode} for $url');
    if (response.statusCode == 304 && await localFile.exists()) {
      return localFile.path;
    }
    final List<int>? bytes = response.data;
    if (bytes != null && bytes.isNotEmpty) {
      await localFile.writeAsBytes(bytes, flush: true);
      await _persistCacheHeaders(localFile, response.headers);
    }
  } catch (e) {
    debugPrint('[TileLoader] image failed: $url — $e');
  }
  return localFile.path;
}

Future<double> nativeCacheSizeInMb() async {
  final Directory dir = await tileCacheDirectory();
  int totalBytes = 0;
  await for (final FileSystemEntity entity in dir.list(recursive: true)) {
    if (entity is! File) continue;
    final String path = entity.path.toLowerCase();
    if (path.endsWith('.png') ||
        path.endsWith('.js') ||
        path.endsWith('.json')) {
      totalBytes += await entity.length();
    }
  }
  return totalBytes / (1024 * 1024);
}

Future<void> nativeClearCache() async {
  final Directory dir = await tileCacheDirectory();
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);
}

Future<Map<String, String>> _cacheHeadersFor(
    File localFile, bool forceRefresh) async {
  if (forceRefresh || !await localFile.exists()) return <String, String>{};
  final File metaFile = File('${localFile.path}.meta.json');
  if (!await metaFile.exists()) return <String, String>{};
  try {
    final Map<String, dynamic> meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final Map<String, String> headers = <String, String>{};
    final String? etag = meta['etag']?.toString();
    final String? lastModified = meta['lastModified']?.toString();
    if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
    if (lastModified != null && lastModified.isNotEmpty) {
      headers['If-Modified-Since'] = lastModified;
    }
    return headers;
  } catch (_) {
    return <String, String>{};
  }
}

Future<void> _persistCacheHeaders(
    File localFile, dynamic headers) async {
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
