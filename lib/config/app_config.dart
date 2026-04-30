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

  static const studyNameSuffix = ' Flood Depths';
  static const baseLayersGroupName = 'Base Layers';
  static const hiddenBaseLayerNames = <String>{
    'Wimmera CMA Boundary',
    'Parcels',
    'Historic River Gauges',
  };
  static const defaultLayerSubstring100yr = '1% (1 in 100';
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

  int get maxNativeZoom {
    switch (this) {
      case BasemapType.cartographic:
        return 19;
      case BasemapType.satellite:
        return 22;
    }
  }
}

class MapZoom {
  MapZoom._();

  static const int wmsMaxNativeZoom = 22;
  static const double mapMaxZoom = 22;
}
