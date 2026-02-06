import 'dart:io';
import 'dart:typed_data';

/// Native tile cache — stores WMS tiles on disk for offline fallback.
class TileCache {
  static String? _basePath;

  static void initialize(String basePath) {
    _basePath = basePath;
    Directory(basePath).createSync(recursive: true);
  }

  /// Deterministic hash key for a URL (FNV-1a 32-bit).
  static String keyFor(Uri url) {
    final input = url.toString();
    int hash = 0x811c9dc5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static File? getFile(String key) {
    if (_basePath == null) return null;
    final file = File('$_basePath/$key.png');
    return file.existsSync() ? file : null;
  }

  static Future<void> putFile(String key, Uint8List bytes) async {
    if (_basePath == null) return;
    await File('$_basePath/$key.png').writeAsBytes(bytes);
  }
}
