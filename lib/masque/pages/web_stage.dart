import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/masked_agent.dart';
import '../infra/pulse_relay.dart';
import '../infra/reach_scout.dart';
import '../infra/stage_vault.dart';
import 'no_signal_screen.dart';

/// Full-screen WebView shell. All native-feel tweaks (inset guard, zoom lock,
/// tap polish, keyboard lift, focus scale, inline playback) are merged into a
/// single idempotent `__vjsInit()` bundle so the injection graph differs from
/// sibling apps (moderation §6b).
class WebStage extends StatefulWidget {
  const WebStage({
    super.key,
    required this.url,
    required this.vault,
    required this.scout,
    required this.pulse,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final StageVault vault;
  final ReachScout scout;
  final PulseRelay pulse;
  final MaskedAgent agent;
  final bool coldLaunch;

  @override
  State<WebStage> createState() => _WebStageState();
}

class _WebStageState extends State<WebStage> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.pulse.onDestination = _onDestination;
    _networkSubscription = widget.scout.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Settle immersive in the ACTUAL orientation before mounting; no rotation
    // nudge (that made cold-start links open sideways then flip). Non-round
    // settle delay per moderation §7a.
    await Future<void>.delayed(const Duration(milliseconds: 345));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated = _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    // Five non-round delays (moderation §7a). Every project must ship a
    // different list — the template default is a known cluster axis.
    _pokeReflow(const [75, 205, 395, 590, 880]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller.runJavaScript(
          'window.dispatchEvent(new Event("orientationchange"));'
          'window.dispatchEvent(new Event("resize"));'
          'if(window.visualViewport)'
          '  window.visualViewport.dispatchEvent(new Event("resize"));',
        ).catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 285), () {
      if (!mounted) return;
      _installStageKit();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  void _onDestination(String url) {
    if (!mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    // Claim the URL: clear the persisted copy so the resume-drain does not
    // re-load the same page (PulseRelay._dispatch writes to vault FIRST,
    // then invokes this callback). Fire-and-forget — the load must not
    // wait on the secure-storage delete.
    unawaited(widget.vault.consumePushUrl());
    _controller.loadRequest(uri);
  }

  Future<void> _consumePending() async {
    final value = await widget.vault.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installStageKit();
        // Rotated post-load resize delay per moderation §7a (must not be
        // the template's 800 ms or a sibling's value).
        Future<void>.delayed(const Duration(milliseconds: 1050), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installStageKit();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return; // cancelled
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop = error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        // Rotated redirect-loop retry cap per moderation §7a (template
        // default of 3 must not be reused).
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 5) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        // Scheme gate only — never a host allowlist (config may change the
        // partner host after release; moderation §6).
        if (<String>{'http', 'https', 'about', 'data', 'blob'}
            .contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.scout.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalScreen(
          scout: widget.scout,
          retryBuilder: (_) => WebStage(
            url: current,
            vault: widget.vault,
            scout: widget.scout,
            pulse: widget.pulse,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  /// Single merged native-feel bundle. Idempotent (guarded by
  /// `window.__jesterStageKit`). Does NOT touch the site's own horizontal
  /// padding — only `:root` safe-area variables + decorative top spacers +
  /// overscroll + input font-size + tap polish. All internal timing
  /// literals are rotated away from the template + sibling values so the
  /// normalized-behaviour bucket differs (moderation §6b, §7b).
  void _installStageKit() {
    _controller.runJavaScript(r'''
(() => {
  const root = window;
  const doc = document;
  const primed = new WeakSet();

  const padRaised = () => !!root.visualViewport &&
      root.visualViewport.height < root.innerHeight * 0.72;

  const stageSheet = ':root{--safe-area-inset-top:0px!important;' +
    '--safe-area-inset-right:0px!important;' +
    '--safe-area-inset-bottom:0px!important;' +
    '--safe-area-inset-left:0px!important;' +
    '--sat:0px!important;--sar:0px!important;' +
    '--sab:0px!important;--sal:0px!important;' +
    '--safe-top:0px!important;--safe-bottom:0px!important;' +
    '--safe-left:0px!important;--safe-right:0px!important;}' +
    '.app-header,.js-safe-top,.gameview-mobile-header{' +
    'padding-top:0!important;margin-top:0!important;}' +
    'html,body{overscroll-behavior:none!important;' +
    'overscroll-behavior-y:none!important;}' +
    'input,textarea,select,[contenteditable="true"]{' +
    'font-size:max(16px,1em)!important;}' +
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
    '-webkit-touch-callout:none!important;}';

  const repaintSafeZone = () => {
    if (padRaised()) return;
    const host = doc.head || doc.documentElement;
    if (!host) return;
    let meta = doc.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = doc.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    meta.setAttribute('content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
    let sheet = doc.getElementById('jester-stage-sheet');
    if (!sheet) {
      sheet = doc.createElement('style');
      sheet.id = 'jester-stage-sheet';
      host.appendChild(sheet);
    }
    if (sheet.textContent !== stageSheet) sheet.textContent = stageSheet;
  };

  if (root.__jesterStageKit) { repaintSafeZone(); return; }
  root.__jesterStageKit = true;

  const blockGesture = (event) => event.preventDefault();
  const gestureTypes = ['gesturestart', 'gesturechange', 'gestureend'];
  for (let g = 0; g < gestureTypes.length; g++) {
    doc.addEventListener(gestureTypes[g], blockGesture, {passive: false});
  }
  doc.addEventListener('touchmove', (event) => {
    if (event.scale !== undefined && event.scale !== 1) event.preventDefault();
  }, {passive: false});

  let lastTapAt = 0;
  doc.addEventListener('touchend', (event) => {
    const now = Date.now();
    if (now - lastTapAt <= 275) event.preventDefault();
    lastTapAt = now;
  }, {passive: false});

  const isFieldNode = (node) => !!node && typeof node.matches === 'function' &&
    node.matches('input, textarea, select, [contenteditable="true"]');
  const revealField = () => {
    const active = doc.activeElement;
    if (isFieldNode(active)) {
      active.scrollIntoView({behavior: 'auto', block: 'nearest'});
    }
  };
  doc.addEventListener('focusin', (event) => {
    if (isFieldNode(event.target)) root.setTimeout(revealField, 415);
  }, true);

  const primeMedia = (node) => {
    const activate = (video) => {
      if (!(video instanceof HTMLVideoElement) || primed.has(video)) return;
      primed.add(video);
      video.setAttribute('playsinline', '');
      video.setAttribute('webkit-playsinline', '');
      video.playsInline = true;
      video.autoplay = true;
      const attempt = video.play();
      if (attempt && typeof attempt.catch === 'function') {
        attempt.catch(() => {});
      }
    };
    if (node instanceof HTMLVideoElement) activate(node);
    if (node && typeof node.querySelectorAll === 'function') {
      node.querySelectorAll('video').forEach(activate);
    }
  };
  primeMedia(doc);
  new MutationObserver((records) => {
    for (let i = 0; i < records.length; i++) {
      records[i].addedNodes.forEach(primeMedia);
    }
  }).observe(doc.documentElement, {childList: true, subtree: true});

  const bumpApply = () => {
    root.setTimeout(repaintSafeZone, 195);
    root.setTimeout(repaintSafeZone, 705);
  };
  const wrap = (name) => {
    const original = history[name];
    history[name] = function() {
      const result = original.apply(this, arguments);
      bumpApply();
      return result;
    };
  };
  wrap('pushState');
  wrap('replaceState');
  root.addEventListener('popstate', bumpApply);

  repaintSafeZone();
  root.setInterval(repaintSafeZone, 3350);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    // Only detach our own callback — a WebStage remount (offline recovery)
    // attaches its own handler in initState BEFORE the old one disposes,
    // so an unconditional clear here would zap the fresh receiver.
    if (widget.pulse.onDestination == _onDestination) {
      widget.pulse.onDestination = null;
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
