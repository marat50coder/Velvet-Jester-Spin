import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/palette.dart';
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
///
/// The progress bar uses two `AnimationController`s (baseline + final) so
/// the fill is guaranteed to be visibly animated every frame — a Ticker
/// with manual setState was skipping paints on some devices, which read as
/// "static bar / no percent counter" in the field.
class StageBootScreen extends StatefulWidget {
  const StageBootScreen({super.key, this.director});

  final StageDirector? director;

  @override
  State<StageBootScreen> createState() => _StageBootScreenState();
}

class _StageBootScreenState extends State<StageBootScreen>
    with TickerProviderStateMixin {
  StageVerdict? _verdict;
  bool _started = false;
  bool _navigating = false;
  late final DateTime _startTime;
  Timer? _hardDeadline;
  static const Duration _minSplash = Duration(milliseconds: 1400);
  static const double _preLaunchCap = 0.94;
  // Wall-clock baseline duration. Longer than LoadingScreen because the
  // gray pipeline (attribution → config POST) can legitimately take up to
  // ~10 s. The bar visibly ease-outs to the cap over this time regardless
  // of when the pipeline milestones fire.
  static const Duration _baselineDuration = Duration(milliseconds: 10000);
  static const Duration _finalDuration = Duration(milliseconds: 560);

  late final AnimationController _baseline;
  late final AnimationController _final;
  double _pipelineTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _baseline = AnimationController(vsync: this, duration: _baselineDuration);
    _final = AnimationController(vsync: this, duration: _finalDuration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _baseline.forward();
    });
    _hardDeadline = Timer(const Duration(seconds: 46), () {
      if (mounted && !_navigating && _verdict == null) {
        _verdict = const GameVerdict();
        _maybeNavigate();
      }
    });
  }

  @override
  void dispose() {
    _baseline.dispose();
    _final.dispose();
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

  /// Combined value shown on the bar. Ease-out baseline capped at 94 % +
  /// pipeline target (whichever is higher) + a final ease-out that carries
  /// the last stretch to 100 %.
  double get _shown {
    final t = _baseline.value;
    final baseline = (1 - math.pow(1 - t, 3).toDouble()) * _preLaunchCap;
    final belowFinal = math.max(baseline, _pipelineTarget).clamp(0.0, 1.0);
    if (!_final.isAnimating && _final.value == 0.0) return belowFinal;
    final finalEased = 1 - math.pow(1 - _final.value, 3).toDouble();
    return belowFinal + (1.0 - belowFinal) * finalEased;
  }

  /// Monotonic — pipeline milestones can only push the target up.
  void _advanceTarget(double value) {
    if (!mounted) return;
    final capped = value.clamp(0.0, _preLaunchCap);
    if (capped <= _pipelineTarget) return;
    setState(() => _pipelineTarget = capped);
  }

  Future<void> _resolve() async {
    final director = widget.director;
    if (director == null) {
      _verdict = const GameVerdict();
      _maybeNavigate();
      return;
    }
    try {
      _verdict = await director.resolve(
        onProgress: (value) => _advanceTarget(value),
      );
    } catch (_) {
      _verdict = const GameVerdict();
    }
    _advanceTarget(_preLaunchCap);
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
    // Final leg — GUARANTEED to reach 100 % before we transition.
    await _final.forward(from: 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
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
    final barBlockWidth = portrait ? screenW * 0.72 : screenW * 0.46;

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
                child: SizedBox(
                  width: barBlockWidth,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_baseline, _final]),
                    builder: (context, _) => _ProgressBlock(
                      value: _shown,
                      compact: !portrait,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared caption + percent counter + fill bar. Kept private here (and
/// mirrored in `screens/loading_screen.dart`) — same visual across both
/// splash screens, so the hand-off from gray-boot to white-loading is
/// seamless.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.value, required this.compact});

  final double value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).clamp(0.0, 100.0).round();
    final barHeight = compact ? 16.0 : 22.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: _LoadingCaption(size: compact ? 14 : 16)),
            const SizedBox(width: 12),
            SizedBox(
              width: compact ? 58 : 68,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: const Color(0xFFF3D89A),
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  height: 1.0,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        _JesterBar(value: value, height: barHeight),
      ],
    );
  }
}

class _JesterBar extends StatelessWidget {
  const _JesterBar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height * 0.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fillWidth = math.max(0.0, maxWidth * clamped);
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF12030F),
            borderRadius: radius,
            border: Border.all(color: const Color(0xFF3A1230), width: 1.8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height * 0.42),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: fillWidth,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFF7C948),
                          Color(0xFFF2B036),
                          Color(0xFFE0A431),
                          Color(0xFFB8862F),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66F7C948),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.42,
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingCaption extends StatefulWidget {
  const _LoadingCaption({required this.size});

  final double size;

  @override
  State<_LoadingCaption> createState() => _LoadingCaptionState();
}

class _LoadingCaptionState extends State<_LoadingCaption>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _dots = 0;
  Duration _lastStep = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastStep < const Duration(milliseconds: 420)) return;
    _lastStep = elapsed;
    if (!mounted) return;
    setState(() => _dots = (_dots + 1) % 4);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Loading${'.' * _dots}',
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: AppText.label(widget.size),
    );
  }
}
