import 'package:http/http.dart' as http;

/// Web fallback — plain HTTP client (no cert overrides needed in browser).
http.Client createHttpClient() => http.Client();
