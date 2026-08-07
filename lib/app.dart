import 'package:flutter/material.dart';

import 'core/palette.dart';
import 'masque/pages/stage_boot.dart';
import 'masque/stage_director.dart';

class VelvetJesterApp extends StatelessWidget {
  const VelvetJesterApp({super.key, this.director});

  final StageDirector? director;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velvet Jester Spin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.velvetDeep,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.plum,
          brightness: Brightness.dark,
          surface: Palette.velvet,
        ),
        fontFamily: 'Helvetica Neue',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) {
        return MediaQuery.withNoTextScaling(
          child: child ?? const SizedBox.shrink(),
        );
      },
      // The boot splash runs the attribution pipeline, then routes to the
      // white game (organic) or the WebView (attributed).
      home: StageBootScreen(director: director),
    );
  }
}
