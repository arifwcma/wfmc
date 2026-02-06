import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'services/wms_tile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Initialise on-disk tile cache for offline fallback.
  final cacheDir = await getTemporaryDirectory();
  TileCache.initialize('${cacheDir.path}/wms_tiles');

  runApp(WfmcApp(prefs: prefs));
}

class WfmcApp extends StatelessWidget {
  const WfmcApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFMC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FFF)),
        useMaterial3: true,
      ),
      home: HomeScreen(prefs: prefs),
    );
  }
}
