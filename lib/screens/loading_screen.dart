import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../models/roles.dart';
import 'menu_screen.dart';

/// Boot screen. Rotates freely (portrait art and landscape art are both
/// shipped) and drives a left-to-right progress bar that only reaches 100 %
/// on the very last frame before the game opens.
///
/// The fill uses an `AnimationController`-driven baseline (3.2 s ease-out to
/// 94 %) merged with precache-stage progress via `max()`. That guarantees a
/// continuously visible animation on any device — the previous Ticker-based
/// approach could sit still when precache was instant (warm cache) because
/// `_shown` only advanced on stage boundaries. A second controller runs
/// the final 94 → 100 % ease-out immediately before pushing MenuScreen.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  static const int _stageCount = 6;
  static const double _preLaunchCap = 0.94;
  static const Duration _baselineDuration = Duration(milliseconds: 3200);
  static const Duration _finalDuration = Duration(milliseconds: 560);

  late final AnimationController _baseline;
  late final AnimationController _final;
  double _stageProgress = 0.0;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    _baseline = AnimationController(vsync: this, duration: _baselineDuration);
    _final = AnimationController(vsync: this, duration: _finalDuration);
    // Kick both the baseline fill AND the precache loop on the first frame
    // after mount — this way the bar renders "0 %" on its very first paint
    // (matches the widget-test expectation and avoids a jarring jump from
    // some sub-percent value on mount).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _baseline.forward();
      _run();
    });
  }

  @override
  void dispose() {
    _baseline.dispose();
    _final.dispose();
    super.dispose();
  }

  /// Combined value shown on the bar. Ease-out baseline capped at 94 % +
  /// stage progress (whichever is higher) + a final ease-out that carries
  /// the last stretch to 100 %.
  double get _shown {
    // easeOutCubic on the baseline controller (goes 0 → 1 over 3.2 s).
    final t = _baseline.value;
    final baseline = (1 - math.pow(1 - t, 3).toDouble()) * _preLaunchCap;
    final belowFinal = math.max(baseline, _stageProgress).clamp(0.0, 1.0);
    if (!_final.isAnimating && _final.value == 0.0) return belowFinal;
    // Final controller (0 → 1 over 560 ms) carries [belowFinal] to 1.0.
    final finalEased = 1 - math.pow(1 - _final.value, 3).toDouble();
    return belowFinal + (1.0 - belowFinal) * finalEased;
  }

  Future<void> _run() async {
    final started = DateTime.now();
    for (var i = 0; i < _stageCount; i++) {
      if (!mounted) return;
      await _work(i);
      if (!mounted) return;
      final target = (i + 1) / _stageCount * _preLaunchCap;
      if (target > _stageProgress) {
        setState(() => _stageProgress = target);
      }
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final minimum = (i + 1) * 340;
      if (elapsed < minimum) {
        await Future<void>.delayed(Duration(milliseconds: minimum - elapsed));
      }
    }
    if (!mounted) return;
    AudioManager.instance.play(Sfx.sceneTransition, volume: 0.8);
    // Final leg — GUARANTEED to reach 100 % before navigating.
    await _final.forward(from: 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted || _launched) return;
    _launched = true;
    _enterGame();
  }

  Future<void> _work(int step) async {
    switch (step) {
      case 0:
        await _precacheAll([
          Sprites.gameName,
          ...Sprites.stageFloors.take(3),
        ]);
      case 1:
        await _precacheAll(Roles.all.map((r) => r.icon).toList());
      case 2:
        await _precacheAll([
          for (final i in Sprites.magicRings) Sprites.magic(i),
          for (final i in Sprites.magicBursts) Sprites.magic(i),
          for (final i in Sprites.magicSparks) Sprites.magic(i),
        ]);
      case 3:
        await _precacheAll([
          for (final i in Sprites.cardPool.take(10)) Sprites.card(i),
          for (final i in Sprites.spotlightPool.take(6)) Sprites.spotlight(i),
        ]);
      case 4:
        await _precacheAll([
          for (var i = 0; i < 16; i++) Sprites.audience(i),
          for (final i in Sprites.confettiPoppers) Sprites.celebration(i),
        ]);
      case 5:
        await _precacheAll([
          for (var i = 0; i < 10; i++) Sprites.jester(i),
          for (var i = 0; i < Sprites.jesterSkinCount; i++) Sprites.jesterSkin(i),
        ]);
    }
  }

  Future<void> _precacheAll(List<String> assets) async {
    if (!mounted) return;
    for (final path in assets) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {
        // A missing decorative slice must never block the boot sequence.
      }
    }
  }

  Future<void> _enterGame() async {
    await _lockLandscape();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(_fade(const MenuScreen()));
  }

  static Future<void> _lockLandscape() => SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

  static PageRouteBuilder<void> _fade(Widget child) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.velvetDeep,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final portrait = orientation == Orientation.portrait;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                portrait ? Sprites.loadingPortrait : Sprites.loadingLandscape,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
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
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: portrait ? 26 : 70,
                      right: portrait ? 26 : 70,
                      bottom: portrait ? 42 : 20,
                    ),
                    // Merge both controllers so the bar redraws every
                    // frame either is animating. Reading [_shown] inside
                    // the builder pulls the current merged value.
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
            ],
          );
        },
      ),
    );
  }
}

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
            Expanded(
              child: _LoadingCaption(size: compact ? 14 : 16),
            ),
            const SizedBox(width: 12),
            // Fixed-width slot so digits don't reflow the caption as they
            // grow from "0%" to "100%".
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

/// Opaque left-to-right fill bar. Explicit `LayoutBuilder + Container(width:)`
/// (instead of `FractionallySizedBox`) so the fill width is guaranteed to
/// track [value] on every rebuild, even inside an `AnimatedBuilder`.
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
