import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';

class BookmarkService {
  BookmarkService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'bookmarks';

  List<Bookmark> getAll() {
    final str = _prefs.getString(_key);
    if (str == null || str.isEmpty) return [];
    return Bookmark.decodeList(str);
  }

  Future<void> save(Bookmark bookmark) async {
    final list = getAll()..add(bookmark);
    await _prefs.setString(_key, Bookmark.encodeList(list));
  }

  Future<void> delete(String id) async {
    final list = getAll()..removeWhere((b) => b.id == id);
    await _prefs.setString(_key, Bookmark.encodeList(list));
  }
}
