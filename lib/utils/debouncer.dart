import 'dart:async';

import 'package:flutter/foundation.dart';

class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  final Duration duration;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
