import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore(this.prefs);

  final SharedPreferences prefs;

  static const _baseEndpointKey = 'settings.baseEndpoint.v2';
  static const _mapPathKey = 'settings.mapPath.v2';

  static const defaultBaseEndpoint = 'https://pozi.wcma.work/ows/';
  static const defaultMapPath = '/var/www/qgis_projects/pozi_base/pozi_base.qgs';

  String get baseEndpoint => prefs.getString(_baseEndpointKey) ?? defaultBaseEndpoint;
  String get mapPath => prefs.getString(_mapPathKey) ?? defaultMapPath;

  Future<void> setBaseEndpoint(String value) async {
    await prefs.setString(_baseEndpointKey, value);
  }

  Future<void> setMapPath(String value) async {
    await prefs.setString(_mapPathKey, value);
  }
}
