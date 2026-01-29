import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore(this.prefs);

  final SharedPreferences prefs;

  static const _baseEndpointKey = 'settings.baseEndpoint';
  static const _mapPathKey = 'settings.mapPath';

  static const defaultBaseEndpoint = 'https://wimmera.xyz/qgis/';
  static const defaultMapPath = '/var/www/qgis/wfma/wfma.qgs';

  String get baseEndpoint => prefs.getString(_baseEndpointKey) ?? defaultBaseEndpoint;
  String get mapPath => prefs.getString(_mapPathKey) ?? defaultMapPath;

  Future<void> setBaseEndpoint(String value) async {
    await prefs.setString(_baseEndpointKey, value);
  }

  Future<void> setMapPath(String value) async {
    await prefs.setString(_mapPathKey, value);
  }
}
