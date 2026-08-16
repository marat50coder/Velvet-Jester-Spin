import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'stage_vault.dart';

@pragma('vm:entry-point')
Future<void> masqueBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging + APNs plumbing: token warmup, permission prompt, and
/// push-URL extraction (foreground / backgrounded taps; cold-start taps are
/// handled by SceneDelegate → ColdTapReader).
class PulseRelay {
  PulseRelay(this._vault, {required this.enabled});

  final StageVault _vault;
  final bool enabled;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Attach listeners FIRST — before any await — so a tap that arrives
    // while `getInitialMessage` is still resolving is never dropped on a
    // broadcast stream with no subscribers. Mirrors Bolt-of-Aether
    // `BoltPulse.init` and matches the reference sibling reliability.
    try {
      FirebaseMessaging.onBackgroundMessage(masqueBackgroundMessage);
    } catch (_) {}
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = _extract(message.data);
      if (url != null) _dispatch(url);
    });

    // Foreground presentation options. Must be set before the first
    // foreground push arrives or iOS suppresses the banner.
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // Terminated-tap fallback. Primary cold-start path is SceneDelegate →
    // ColdTapReader; this handles the case where Firebase's swizzled
    // AppDelegate ate the response before Scene saw it.
    try {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(milliseconds: 4200),
        onTimeout: () => null,
      );
      if (initial != null) {
        final initialUrl = _extract(initial.data);
        if (initialUrl != null) await _vault.stashPushUrl(initialUrl);
      }
    } catch (_) {}

    await _waitForApns();
    _token = await messaging.getToken();
  }

  /// Persist FIRST, then call the live callback. Covers the race where a
  /// background-tap resumes the app after the current WebView has been
  /// torn down (route flip, offline recovery) but before a new WebView has
  /// attached `onDestination`. The WebView clears the vault on successful
  /// claim (see `WebStage._onDestination`), so a subsequent resume-drain
  /// does not re-fire the same URL.
  Future<void> _dispatch(String url) async {
    if (url.isEmpty) return;
    try {
      await _vault.stashPushUrl(url);
    } catch (_) {}
    final callback = onDestination;
    if (callback != null) {
      try {
        callback(url);
      } catch (_) {}
    }
  }

  // Rotated key priority: order + set MUST differ from siblings (moderation
  // §1). The backend is documented to send the URL under any of these; a
  // reordered scan is functionally identical because it still returns the
  // first non-empty value.
  static const List<String> _urlKeys = <String>[
    'target',
    'url',
    'deep_link',
    'link',
    'deeplink',
    'destination',
  ];
  static const List<String> _urlContainers = <String>['data', 'payload'];

  String? _extract(Map<String, dynamic> payload) {
    for (final key in _urlKeys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in _urlContainers) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  // Rotated poll counts / steps (moderation §7a).
  Future<void> _waitForApns({int attempts = 7}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 620));
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 12);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
