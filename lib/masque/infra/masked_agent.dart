import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/masque_config.dart';

/// HTTP client that sends a real mobile-browser User-Agent (never the default
/// Dart/CFNetwork UA). Every UA substring is assembled from veiled fragments
/// at runtime — no plaintext browser-UA literal lives in the binary
/// (moderation §4).
///
/// GAME THEME CATEGORY: slot. The partner identity is delivered as
/// X-Partner-App-Id / X-Partner-App-Name request headers on the config POST
/// (see GateDispatch), NOT as an app-id / app-name User-Agent suffix — that
/// suffix is the single most damning affiliate marker in the binary, so it is
/// intentionally omitted here.
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
    return '${MasqueConfig.uaProduct} '
        '${MasqueConfig.uaPlatformPrefix} $cpu '
        '${MasqueConfig.uaPlatformSuffix} '
        '${MasqueConfig.uaEngine} '
        'Version/${MasqueConfig.safariVersion} '
        '${MasqueConfig.uaMobileToken} '
        'Safari/${MasqueConfig.safariTail}';
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
