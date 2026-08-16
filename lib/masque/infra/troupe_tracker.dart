import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/masque_config.dart';
import 'masked_agent.dart';

/// Asserts-wrapped logger: the closure AND its string literals are stripped
/// from release builds so no debug tag can ship as a static-analysis marker
/// (moderation §2). Never replace call sites with bare `debugPrint(...)`.
void veilTrace(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}

/// AppsFlyer attribution: warmup, conversion/deep-link capture, GCD recheck
/// for Organic false-positives, and the flat config-body composition.
class TroupeTracker {
  TroupeTracker(this._agent);

  final MaskedAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  final Completer<void> _installReady = Completer<void>();
  final Completer<void> _deepLinkReady = Completer<void>();

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (!MasqueConfig.grayCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: MasqueConfig.appsFlyerKey,
          appId: MasqueConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 5,
        ),
      );
      _sdk = sdk;
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((raw) => _reopen = _flat(raw));
      sdk.onDeepLinking((result) {
        final event = result.deepLink?.clickEvent;
        if (event != null) _deepLink = Map<String, dynamic>.from(event);
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      veilTrace(() => '[SPIN.TRACK] init failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    // ATT must be requested after the first frame (rotated delay, §7a).
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 480));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _acceptInstall(dynamic raw) async {
    try {
      final received = _flat(raw);
      final status = received['status']?.toString().toLowerCase();
      final failed = status == 'failure' ||
          (received['af_status'] == null && received.containsKey('status'));
      veilTrace(
        () => '[SPIN.TRACK] conversion status=$status '
            'af_status=${received['af_status']} keys=${received.keys.toList()}',
      );
      if (failed) {
        _install = <String, dynamic>{};
      } else if (received['af_status'] == 'Organic') {
        await Future<void>.delayed(
          const Duration(seconds: MasqueConfig.organicRecheckSeconds),
        );
        _install = await _fetchGcd() ?? received;
      } else {
        _install = received;
      }
    } catch (error) {
      veilTrace(() => '[SPIN.TRACK] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installReady.isCompleted) _installReady.complete();
    }
  }

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final payload = map['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : map;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD uses the numeric App Store id, not the bundle id.
      final base = MasqueConfig.gcdBase;
      final sep = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${sep}app_id=${MasqueConfig.iosStoreId}&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${MasqueConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = const Duration(seconds: 9),
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(installTimeout, onTimeout: () {}),
      _deepLinkReady.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      ),
    ]);
  }

  /// True once AppsFlyer's conversion callback has fired with a real,
  /// non-empty payload. False both before the callback runs and after an
  /// explicit failure (where `_install` is set to an empty map).
  bool get hasInstallSignal => _install != null && _install!.isNotEmpty;

  /// Waits for the AppsFlyer install callback for at most [timeout]. Safe to
  /// call multiple times; if the callback already fired, returns immediately.
  Future<void> awaitInstall(Duration timeout) async {
    await start();
    if (_installReady.isCompleted) return;
    await _installReady.future.timeout(timeout, onTimeout: () {});
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    // Merge order is a hard invariant (guide §Config Request Contract):
    // install writes as-is, reopen and deepLink only fill missing keys,
    // device-side fields overwrite last. Refactored to a single helper so
    // the graph shape differs from the classic `forEach(putIfAbsent)` pair.
    final body = <String, dynamic>{};
    _absorb(body, _install, override: true);
    _absorb(body, _reopen);
    _absorb(body, _deepLink);

    final resolvedAfId = (await appsFlyerId()) ?? body['af_id'] ?? '';
    final device = <String, dynamic>{
      'af_id': resolvedAfId,
      'bundle_id': MasqueConfig.bundleId,
      'os': 'iOS',
      'store_id': MasqueConfig.storeToken,
      'locale': locale,
    };
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        MasqueConfig.firebaseProjectNumber.isNotEmpty) {
      device['push_token'] = pushToken;
      device['firebase_project_id'] = MasqueConfig.firebaseProjectNumber;
    }
    body.addAll(device);

    final idfa = await _resolveIdfa();
    if (idfa != null) body['sub_id_10'] = idfa;

    veilTrace(() => '[SPIN.TRACK] payload ${jsonEncode(body)}');
    return body;
  }

  /// Copies keys from [source] into [target]. When [override] is true it
  /// clobbers existing keys (install source); otherwise it only fills gaps
  /// (reopen / deep-link sources).
  void _absorb(
    Map<String, dynamic> target,
    Map<String, dynamic>? source, {
    bool override = false,
  }) {
    if (source == null || source.isEmpty) return;
    if (override) {
      target.addAll(source);
      return;
    }
    source.forEach((key, value) => target.putIfAbsent(key, () => value));
  }

  Future<String?> _resolveIdfa() async {
    if (!Platform.isIOS) return null;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.authorized) return null;
      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (idfa.isEmpty || idfa.startsWith('00000000-')) return null;
      return idfa;
    } catch (_) {
      return null;
    }
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
