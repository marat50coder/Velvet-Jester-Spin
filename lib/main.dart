import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/audio.dart';
import 'core/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The loading screen is allowed to rotate (portrait and landscape art both
  // ship); the game itself locks to landscape once the menu appears.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final prefs = await SharedPreferences.getInstance();
  await AudioManager.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProgress(prefs),
      child: const VelvetJesterApp(),
    ),
  );
}
