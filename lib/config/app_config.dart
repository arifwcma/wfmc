class AppConfig {
  AppConfig._();

  static const orgName = 'Wimmera Catchment Management Authority';
  static const orgShortName = 'Wimmera CMA';
  static const orgWebsite = 'https://wcma.vic.gov.au';
  static const orgPhone = '(03) 5382 1544';
  static const orgPhoneUri = 'tel:+61353821544';
  static const contactEmail = 'software@wcma.vic.gov.au';
  static const contactDisplayName = 'Software App Developer';
  static const feedbackSubject = 'Wimmera Flood Maps Feedback';

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
    'UW_E01_100y_052_D_Max_g007_50',
    'WaBr15Dep100',
    'l_100y_existing_flood_depths',
  };
}

enum BasemapType {
  cartographic,
  satellite,
}

extension BasemapTypeExtension on BasemapType {
  String get label {
    switch (this) {
      case BasemapType.cartographic:
        return 'Cartographic';
      case BasemapType.satellite:
        return 'Satellite';
    }
  }

  String get urlTemplate {
    switch (this) {
      case BasemapType.cartographic:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case BasemapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }
}
