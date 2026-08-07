import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL written by SceneDelegate.swift into
/// UserDefaults. The `flutter.` prefix on the native side bridges to the plain
/// key read here via SharedPreferences.
class ColdTapReader {
  static const String _dartKey = 'vjs_launch_route';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
