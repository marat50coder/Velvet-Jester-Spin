import 'dart:async';
import 'dart:io';

import 'config/masque_config.dart';
import 'core/stage_models.dart';
import 'infra/cold_tap_reader.dart';
import 'infra/gate_dispatch.dart';
import 'infra/masked_agent.dart';
import 'infra/pulse_relay.dart';
import 'infra/reach_scout.dart';
import 'infra/stage_vault.dart';
import 'infra/troupe_tracker.dart';

/// The whole routing brain. Runs the attribution → config pipeline once per
/// boot and returns a [StageVerdict]. Cold-start push taps win over
/// everything; a first-launch network failure never commits to the game.
class StageDirector {
  StageDirector({
    required this.vault,
    required this.scout,
    required this.tracker,
    required this.dispatch,
    required this.pulse,
    required this.agent,
    required this.runtimeEnabled,
  });

  final StageVault vault;
  final ReachScout scout;
  final TroupeTracker tracker;
  final GateDispatch dispatch;
  final PulseRelay pulse;
  final MaskedAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && MasqueConfig.grayCredentialsReady;

  Future<StageVerdict>? _resolveFuture;

  /// De-duplicates only *concurrent* calls (the boot screen can build twice at
  /// startup). The cache clears once the pipeline finishes, so a later Retry
  /// re-runs the whole pipeline instead of replaying a cached OfflineVerdict.
  Future<StageVerdict> resolve({
    required void Function(double value) onProgress,
  }) =>
      _resolveFuture ??=
          _resolve(onProgress: onProgress).whenComplete(() => _resolveFuture = null);

  Future<StageVerdict> _resolve({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      onProgress(1);
      return const GameVerdict();
    }

    pulse.onTokenChanged = _refreshForToken;

    // Firebase `getInitialMessage` MUST resolve before we sample the
    // cold-tap URL — with `FirebaseAppDelegateProxyEnabled=true` (default)
    // Firebase swizzles the AppDelegate proxy and eats the notification
    // response, so `SceneDelegate` never fires and `ColdTapReader.consume`
    // alone returns null on the terminated-tap path. `PulseRelay._boot`
    // writes any initial-message URL into the vault via
    // `_vault.stashPushUrl`, which the drain below picks up. Skipping
    // this await produced the "2nd push opens the previous session's
    // URL" bug (a stale `savedUrl` won in `_returningPortal`).
    try {
      await pulse.boot();
    } catch (_) {}

    // Drain BOTH sources — SceneDelegate (a) fires when Firebase's proxy
    // is off or the OS routed the tap to Scene first, and vault (b) is
    // Firebase's `getInitialMessage` path. Consume both so a stale
    // vault entry never fires on the next `AppLifecycleState.resumed`.
    final tapUrl = await ColdTapReader.consume();
    final vaultUrl = await vault.consumePushUrl();
    final coldUrl = tapUrl ?? vaultUrl;
    if (coldUrl != null && coldUrl.isNotEmpty) {
      await vault.saveRoute(StageRoute.portal);
      unawaited(_backgroundDispatch());
      onProgress(1);
      return WebVerdict(coldUrl, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      StageRoute.undecided => _firstDecision(onProgress),
      StageRoute.portal => _returningPortal(onProgress),
      StageRoute.native => _returningNative(onProgress),
    };
  }

  Future<StageVerdict> _firstDecision(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      return const OfflineVerdict(returnToGame: false);
    }
    progress(0.28);
    try {
      await pulse.boot();
    } catch (_) {}
    if (!await scout.canReachNetwork()) {
      return const OfflineVerdict(returnToGame: false);
    }
    progress(0.48);
    await tracker.awaitSignals();
    progress(0.72);
    var reply = await _requestConfig();
    // First-launch attribution race: if AppsFlyer's install callback hadn't
    // fired by the first `awaitSignals` deadline, the server correctly
    // answers "No data" for our empty payload. Wait a bit longer for the
    // install signal and retry ONCE — this is safe here because the route is
    // still `undecided`; we are not flipping a returning user's decision (§6).
    if (!reply.hasDestination && !tracker.hasInstallSignal) {
      await tracker.awaitInstall(const Duration(seconds: 14));
      if (tracker.hasInstallSignal) {
        reply = await _requestConfig();
      }
    }
    progress(1);
    if (reply.hasDestination) {
      await vault.saveRoute(StageRoute.portal);
      return WebVerdict(reply.url!);
    }
    await vault.saveRoute(StageRoute.native);
    return const GameVerdict();
  }

  Future<StageVerdict> _returningPortal(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      return const OfflineVerdict(returnToGame: false);
    }
    final pending = await vault.consumePushUrl();
    if (pending != null && pending.isNotEmpty) {
      progress(1);
      return WebVerdict(pending);
    }
    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return WebVerdict(cached);
    }

    await Future.wait<void>(<Future<void>>[pulse.boot(), tracker.start()]);
    if (!await scout.canReachNetwork()) {
      return const OfflineVerdict(returnToGame: false);
    }
    progress(0.62);
    await tracker.awaitSignals(installTimeout: const Duration(seconds: 7));
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return WebVerdict(reply.url!);
    if (cached != null) return WebVerdict(cached);
    return const OfflineVerdict(returnToGame: false);
  }

  Future<StageVerdict> _returningNative(void Function(double) progress) async {
    if (!await scout.hasInterface()) {
      progress(1);
      return const GameVerdict();
    }
    await Future.wait<void>(<Future<void>>[pulse.boot(), tracker.start()]);
    if (!await scout.canReachNetwork()) {
      progress(1);
      return const GameVerdict();
    }
    progress(0.55);
    await tracker.awaitSignals();
    final reply = await _requestConfig();
    progress(1);
    if (!reply.hasDestination) return const GameVerdict();
    await vault.saveRoute(StageRoute.portal);
    return WebVerdict(reply.url!);
  }

  Future<GateReply> _requestConfig({String? token}) async {
    final body = await tracker.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? pulse.token,
    );
    return dispatch.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        pulse.boot(),
        tracker.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
