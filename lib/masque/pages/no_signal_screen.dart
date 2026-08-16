import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/reach_scout.dart';

/// Offline screen. Retry re-runs the whole pipeline by pushing a fresh
/// [retryBuilder] widget using THIS page's own (mounted) context — never a
/// captured parent context, which would be defunct after pushReplacement.
class NoSignalScreen extends StatefulWidget {
  const NoSignalScreen({
    super.key,
    required this.scout,
    required this.retryBuilder,
  });

  final ReachScout scout;
  final WidgetBuilder retryBuilder;

  @override
  State<NoSignalScreen> createState() => _NoSignalScreenState();
}

class _NoSignalScreenState extends State<NoSignalScreen> {
  bool _checking = false;
  bool _stillOffline = false;
  bool _navigated = false;
  StreamSubscription<List<ConnectivityResult>>? _watch;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Allow rotation — the boot splash locks portrait right before routing.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Auto-recover: the moment iOS reports any live interface, retry
    // without waiting for the user to spam the button.
    _watch = widget.scout.changes.listen((states) {
      if (_navigated || _checking) return;
      final live = states.any((s) => s != ConnectivityResult.none);
      if (live) unawaited(_retry(auto: true));
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  Future<void> _retry({bool auto = false}) async {
    if (_checking || _navigated) return;
    if (!auto) HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    // Fast path: trust connectivity_plus (instant, iOS SCNetworkReachability
    // under the hood). If ANY interface is up we hand off to the retry
    // builder — WebStage will re-attempt the actual load and will bounce
    // back here if it truly fails. DNS-probing here would block for up to
    // ~7s right after WiFi returns because iOS hasn't refreshed its DNS
    // cache yet — that's the "nothing happens on first tap" bug.
    bool live = false;
    try {
      live = await widget.scout.hasInterface();
    } catch (_) {
      live = false;
    }
    if (!mounted) return;
    if (live) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final background = landscape
        ? 'assets/Velvet_Jester_Spin_additional_assets/Horizontal_Nowifi_Screen.webp'
        : 'assets/Velvet_Jester_Spin_additional_assets/Vertical_Nowifi_Screen.webp';
    final width = landscape
        ? (media.size.width * 0.40).clamp(300.0, 520.0)
        : (media.size.width * 0.66).clamp(260.0, 420.0);
    final height = landscape ? 70.0 : 74.0;
    // Landscape: no safe-area, centred horizontally (avoids the notch offset
    // that shifts the horizontal centre). Portrait keeps a little bottom room.
    final align = landscape ? const Alignment(0, 0.82) : const Alignment(0, 0.80);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            background,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Align(
            alignment: align,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _RetryButton(
                  width: width,
                  height: height,
                  busy: _checking,
                  onTap: () => _retry(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _stillOffline
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No connection yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black, blurRadius: 5),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF7C948), Color(0xFFB8862F)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF3A1230), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(34),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF3A1230),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.refresh_rounded,
                            color: Color(0xFF3A1230), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Color(0xFF3A1230),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
