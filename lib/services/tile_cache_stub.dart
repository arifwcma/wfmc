import 'dart:typed_data';

/// Web stub — no tile caching (browser handles its own HTTP cache).
class TileCache {
  static void initialize(String basePath) {}

  static String keyFor(Uri url) => '';

  static dynamic getFile(String key) => null;

  static Future<void> putFile(String key, Uint8List bytes) async {}
}
