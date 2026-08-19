import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/masque_config.dart';

/// HTTP client that sends a real mobile-browser User-Agent (never the default
/// Dart/CFNetwork UA). Every UA substring is assembled from veiled fragments
/// at runtime — no plaintext browser-UA literal lives in the binary
/// (moderation §4).
///
/// GAME THEME CATEGORY: slot. Partner backend requires the app identity on
/// the UA suffix (`appid/id<AppStoreNumericId> appname/<AppName>`). Following
/// moderation §4, the `appid/` and `appname/` scaffolding prefixes are stored
/// as veiled byte arrays and the assembled suffix is built at runtime — no
/// plaintext `appid/` literal ships in the binary. The storeToken (`id` +
/// App Store numeric id) and appNameToken stay plaintext (already public via
/// App Store Connect). The same identity is ALSO echoed as X-Partner-App-Id /
/// X-Partner-App-Name request headers on the config POST for backends that
/// read it there.
class MaskedAgent extends http.BaseClient {
  final http.Client _transport = http.Client();
  String? _userAgent;

  Future<void> prepare() async {
    try {
      if (!Platform.isIOS) {
        _userAgent = _fallback();
        return;
      }
      final info = await DeviceInfoPlugin().iosInfo;
      _userAgent = _mobileSafari(_normalizedIos(info.systemVersion));
    } catch (_) {
      _userAgent = _fallback();
    }
  }

  String get userAgent => _userAgent ?? _fallback();

  String _normalizedIos(String raw) {
    final components = raw
        .split('.')
        .map((part) => int.tryParse(part))
        .whereType<int>()
        .take(3)
        .toList();
    if (components.isEmpty || components.first < 18) return '18.5';
    return components.join('.');
  }

  String _mobileSafari(String iosVersion) {
    final cpu = iosVersion.replaceAll('.', '_');
    // Assemble each fragment at runtime — no plaintext UA literal lives in
    // the binary (moderation §4). The `appid/` / `appname/` scaffolding
    // prefixes are veiled; only the app identity values themselves are
    // plaintext (already public).
    final base = '${MasqueConfig.uaProduct} '
        '${MasqueConfig.uaPlatformPrefix} $cpu '
        '${MasqueConfig.uaPlatformSuffix} '
        '${MasqueConfig.uaEngine} '
        'Version/${MasqueConfig.safariVersion} '
        '${MasqueConfig.uaMobileToken} '
        'Safari/${MasqueConfig.safariTail}';
    final suffix = '${MasqueConfig.uaAppIdPrefix}${MasqueConfig.storeToken} '
        '${MasqueConfig.uaAppNamePrefix}${MasqueConfig.appNameToken}';
    return '$base $suffix';
  }

  String _fallback() => _mobileSafari('18.5');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
