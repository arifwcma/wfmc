import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Native (Android / iOS / desktop) — disables cert validation for dev.
http.Client createHttpClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (cert, host, port) => true;
  return IOClient(ioClient);
}
