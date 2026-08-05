import 'package:flutter/material.dart';

import 'core/palette.dart';
import 'screens/loading_screen.dart';

class VelvetJesterApp extends StatelessWidget {
  const VelvetJesterApp({super.key});

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
      home: const LoadingScreen(),
    );
  }
}
