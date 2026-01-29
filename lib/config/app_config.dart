class AppConfig {
  AppConfig._();

  static const depthGroupName = 'Depth';

  static const defaultEnabledStudies = <String>{
    'Concongella_2015',
    'Dunmunkle_2017',
    'HallsGap_2017',
    'HorshamWartook_2017',
    'MountWilliam_2014',
    'Natimuk_2013',
    'Stawell_2024',
    'UpperWimmera_2014',
    'WarracknabealBrim_2016',
    'WimmeraRiverYarriambiackCreek_2010',
  };

  static const defaultEnabledLayers = <String>{
    'Concongella_100y_d_Max',
    'Dunm17RvDepthARI100',
    'HGAP17RvDepthARI100',
    'Hors19RvDepthARI100',
    'MTW_E01_100Y_050_D_MAX',
    'dep_100y',
    'Stawell24RvDepthARI100',
    'StawellG24RvDepthARI100',
    'UW_E01_100y_052_D_Max_g007.50',
    'WaBr15Dep100',
    '100y_existing_flood_depths',
  };
}

enum BasemapType {
  cartographic,
  topographic,
  satellite,
}

extension BasemapTypeExtension on BasemapType {
  String get label {
    switch (this) {
      case BasemapType.cartographic:
        return 'Cartographic';
      case BasemapType.topographic:
        return 'Topographic';
      case BasemapType.satellite:
        return 'Satellite';
    }
  }

  String get urlTemplate {
    switch (this) {
      case BasemapType.cartographic:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case BasemapType.topographic:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case BasemapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String>? get subdomains {
    switch (this) {
      case BasemapType.topographic:
        return ['a', 'b', 'c'];
      default:
        return null;
    }
  }
}
