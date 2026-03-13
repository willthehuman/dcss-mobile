// Web stub — dart:io is unavailable in browsers.
// All tile fetching on web goes through the in-memory path in tile_loader.dart.
// These stubs exist only so the conditional import resolves without errors.

Future<Never> tileCacheDirectory() {
  throw UnsupportedError('tileCacheDirectory not available on web');
}

Future<String> downloadTextWithCache({
  required dynamic dio,
  required String url,
  required String localFileName,
  required dynamic directory,
  required bool forceRefresh,
}) {
  throw UnsupportedError('downloadTextWithCache not available on web');
}

Future<String> downloadBinaryWithCache({
  required dynamic dio,
  required String url,
  required String localFileName,
  required dynamic directory,
  required bool forceRefresh,
}) {
  throw UnsupportedError('downloadBinaryWithCache not available on web');
}

Future<double> nativeCacheSizeInMb() async => 0.0;
Future<void> nativeClearCache() async {}
