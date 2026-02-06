import 'dart:convert';

class Bookmark {
  const Bookmark({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double zoom;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'zoom': zoom,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        zoom: (json['zoom'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static String encodeList(List<Bookmark> bookmarks) =>
      json.encode(bookmarks.map((b) => b.toJson()).toList());

  static List<Bookmark> decodeList(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return list
        .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
