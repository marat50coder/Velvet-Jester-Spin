import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/masque_config.dart';
import '../core/stage_models.dart';

/// Persists the routing decision, cached/pending URLs and push-invite state.
class StageVault {
  static const String _routeKey = 'vjs.masque.route';
  static const String _expiryKey = 'vjs.masque.expiry';
  static const String _inviteKey = 'vjs.masque.invite.after';
  static const String _permissionKey = 'vjs.masque.push.allowed';
  static const String _osDeniedKey = 'vjs.masque.push.os_denied';
  static const String _savedUrlKey = 'vjs.masque.secure.destination';
  static const String _pendingUrlKey = 'vjs.masque.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  StageRoute get route => StageRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(StageRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      // A URL from an old server response must not live forever. If the
      // backend gives no explicit expiry, fall back to savedUrlExpiryDays.
      final effective = expiresAt ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              MasqueConfig.savedUrlExpiryDays * 86400;
      await _preferences.setInt(_expiryKey, effective);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final expiry = _preferences.getInt(_expiryKey);
    return expiry == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() => _preferences.setBool(_osDeniedKey, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);
}
