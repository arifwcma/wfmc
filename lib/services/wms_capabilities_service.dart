import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/wms_models.dart';

class WmsCapabilitiesService {
  WmsCapabilitiesService({
    required this.httpClient,
    required this.prefs,
  });

  final http.Client httpClient;
  final SharedPreferences prefs;

  static const _prefsCapabilitiesXmlKey = 'wms.capabilitiesXml';
  static const _prefsCapabilitiesFetchedAtKey = 'wms.capabilitiesFetchedAtEpochMs';

  int? get cachedFetchedAtEpochMs => prefs.getInt(_prefsCapabilitiesFetchedAtKey);

  Future<WmsCapabilities> load({
    required Uri capabilitiesUri,
    bool forceRefresh = false,
  }) async {
    final cachedXml = prefs.getString(_prefsCapabilitiesXmlKey);
    if (!forceRefresh && cachedXml != null && cachedXml.trim().isNotEmpty) {
      return parse(cachedXml);
    }

    final res = await httpClient.get(capabilitiesUri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (cachedXml != null && cachedXml.trim().isNotEmpty) {
        return parse(cachedXml);
      }
      throw Exception('GetCapabilities failed: HTTP ${res.statusCode}');
    }

    final body = res.body;
    prefs.setString(_prefsCapabilitiesXmlKey, body);
    prefs.setInt(_prefsCapabilitiesFetchedAtKey, DateTime.now().millisecondsSinceEpoch);
    return parse(body);
  }

  WmsCapabilities parse(String xmlString) {
    final doc = XmlDocument.parse(xmlString);

    String serviceTitle = 'WMS';
    final serviceEl = doc
        .findAllElements('Service')
        .cast<XmlElement?>()
        .firstWhere((e) => e != null, orElse: () => null);
    final serviceTitleText = serviceEl?.getElement('Title')?.innerText.trim();
    if (serviceTitleText != null && serviceTitleText.isNotEmpty) {
      serviceTitle = serviceTitleText;
    }

    final capabilityLayer = doc
        .findAllElements('Capability')
        .expand((c) => c.findElements('Layer'))
        .cast<XmlElement?>()
        .firstWhere((e) => e != null, orElse: () => null);
    if (capabilityLayer == null) {
      throw Exception('Invalid capabilities: missing Capability/Layer');
    }

    final root = _parseLayer(capabilityLayer);
    return WmsCapabilities(serviceTitle: serviceTitle, rootLayer: root);
  }

  WmsLayer _parseLayer(XmlElement el) {
    final nameText = el.getElement('Name')?.innerText.trim();
    final titleText = el.getElement('Title')?.innerText.trim();
    final name = (nameText != null && nameText.isNotEmpty) ? nameText : null;
    final title = (titleText != null && titleText.isNotEmpty)
        ? titleText
        : (name ?? 'Layer');

    final queryableAttr = el.getAttribute('queryable');
    final queryable = queryableAttr == '1' || queryableAttr?.toLowerCase() == 'true';

    WmsBBox? bbox3857;
    for (final bboxEl in el.findElements('BoundingBox')) {
      final crs = bboxEl.getAttribute('CRS') ?? bboxEl.getAttribute('SRS');
      if (crs == 'EPSG:3857') {
        final minx = double.tryParse(bboxEl.getAttribute('minx') ?? '');
        final miny = double.tryParse(bboxEl.getAttribute('miny') ?? '');
        final maxx = double.tryParse(bboxEl.getAttribute('maxx') ?? '');
        final maxy = double.tryParse(bboxEl.getAttribute('maxy') ?? '');
        if (minx != null && miny != null && maxx != null && maxy != null) {
          bbox3857 = WmsBBox(minx: minx, miny: miny, maxx: maxx, maxy: maxy);
        }
        break;
      }
    }

    final children = <WmsLayer>[];
    for (final child in el.findElements('Layer')) {
      children.add(_parseLayer(child));
    }

    return WmsLayer(
      name: name,
      title: title.isNotEmpty ? title : (name ?? 'Layer'),
      children: children,
      queryable: queryable,
      bbox3857: bbox3857,
    );
  }

  static Uri buildCapabilitiesUri({
    required Uri baseEndpoint,
    required String mapPath,
  }) {
    final params = <String, String>{
      'MAP': mapPath,
      'SERVICE': 'WMS',
      'REQUEST': 'GetCapabilities',
    };
    return baseEndpoint.replace(queryParameters: params);
  }

  static Uri buildLegendUri({
    required Uri baseEndpoint,
    required String mapPath,
    required String layerName,
    String style = 'default',
  }) {
    final params = <String, String>{
      'MAP': mapPath,
      'SERVICE': 'WMS',
      'VERSION': '1.3.0',
      'REQUEST': 'GetLegendGraphic',
      'LAYER': layerName,
      'FORMAT': 'image/png',
      'STYLE': style,
      'SLD_VERSION': '1.1.0',
    };
    return baseEndpoint.replace(queryParameters: params);
  }

  static String prettyPrintXml(String xmlString) {
    try {
      final doc = XmlDocument.parse(xmlString);
      return doc.toXmlString(pretty: true, indent: '  ');
    } catch (_) {
      return xmlString;
    }
  }

  static String toPrettyJson(Object? jsonObj) {
    return const JsonEncoder.withIndent('  ').convert(jsonObj);
  }
}
