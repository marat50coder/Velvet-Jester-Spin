import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sprites.dart';
import '../../screens/loading_screen.dart';
import '../core/stage_models.dart';
import '../stage_director.dart';
import 'no_signal_screen.dart';
import 'push_invite.dart';
import 'web_stage.dart';

/// Boot splash AND the gray/white routing point. Plays the loading art (same
/// asset as the white game's own loading screen, so the hand-off is seamless)
/// while [StageDirector.resolve] runs the attribution → config pipeline, then
/// routes to the WebView (gray), the offline screen, or the white game.
class StageBootScreen extends StatefulWidget {
  const StageBootScreen({super.key, this.director});

  final StageDirector? director;

  @override
  State<StageBootScreen> createState() => _StageBootScreenState();
}

class _StageBootScreenState extends State<StageBootScreen> {
  double _progress = 0;
  StageVerdict? _verdict;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startTime;
  Timer? _hardDeadline;
  static const Duration _minSplash = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _hardDeadline = Timer(const Duration(seconds: 8), () {
      if (mounted && !_navigating) {
        _verdict ??= const GameVerdict();
        _maybeNavigate();
      }
    });
  }

  @override
  void dispose() {
    _hardDeadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final director = widget.director;
    if (director == null) {
      _verdict = const GameVerdict();
      setState(() => _progress = 1);
      _maybeNavigate();
      return;
    }
    try {
      _verdict = await director.resolve(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value.clamp(0.0, 1.0));
        },
      );
    } catch (_) {
      _verdict = const GameVerdict();
    }
    if (mounted) setState(() => _progress = 1);
    _hardDeadline?.cancel();
    _maybeNavigate();
  }

  Future<void> _maybeNavigate() async {
    if (_navigating || _verdict == null) return;
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }
    if (!mounted || _navigating) return;
    _navigating = true;
    await _openVerdict(_verdict!);
  }

  Future<void> _openVerdict(StageVerdict verdict) async {
    final director = widget.director;

    if (verdict is GameVerdict || director == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoadingScreen()),
      );
      return;
    }

    if (verdict is OfflineVerdict) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NoSignalScreen(
            scout: director.scout,
            retryBuilder: (_) => StageBootScreen(director: director),
          ),
        ),
      );
      return;
    }

    if (verdict is WebVerdict) {
      Widget webBuilder(BuildContext _) => WebStage(
        url: verdict.url,
        coldLaunch: verdict.coldLaunch,
        vault: director.vault,
        scout: director.scout,
        pulse: director.pulse,
        agent: director.agent,
      );

      if (director.vault.shouldShowPushInvite &&
          await director.pulse.canOfferPermission()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PushInvite(
              vault: director.vault,
              pulse: director.pulse,
              nextBuilder: webBuilder,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: webBuilder),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final portrait = orientation == Orientation.portrait;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF12030F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            portrait ? Sprites.loadingPortrait : Sprites.loadingLandscape,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF12030F)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC12030F)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: portrait ? 46 : 22),
                child: _BootBar(
                  progress: _progress,
                  width: portrait ? screenW * 0.66 : screenW * 0.42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootBar extends StatelessWidget {
  const _BootBar({required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A1230), width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              builder: (context, value, _) => FractionallySizedBox(
                widthFactor: value <= 0 ? 0.001 : value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7C948), Color(0xFFB8862F)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
