import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../models/roles.dart';
import '../widgets/ornaments.dart';
import 'menu_screen.dart';

/// Boot screen. Rotates freely (portrait art and landscape art are both
/// shipped) and drives a left-to-right progress bar that only reaches 100%
/// on the very last frame before the game opens.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  static const _steps = <String>[
    'Rolling out the velvet…',
    'Tuning the orchestra…',
    'Lighting the ring…',
    'Shuffling the deck…',
    'Seating the audience…',
    'Waking the Jester…',
  ];

  double _progress = 0;
  int _step = 0;
  bool _launched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final started = DateTime.now();

    for (var i = 0; i < _steps.length; i++) {
      if (!mounted) return;
      setState(() => _step = i);
      await _work(i);
      if (!mounted) return;
      // Cap the bar below 100% until every stage has genuinely finished.
      setState(() => _progress = (i + 1) / _steps.length * 0.9);
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final minimum = (i + 1) * 330;
      if (elapsed < minimum) {
        await Future<void>.delayed(Duration(milliseconds: minimum - elapsed));
      }
    }

    if (!mounted) return;
    setState(() => _progress = 1.0);
    AudioManager.instance.play(Sfx.sceneTransition, volume: 0.8);
    await Future<void>.delayed(const Duration(milliseconds: 620));
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
                    child: _ProgressBlock(
                      progress: _progress,
                      caption: _progress >= 1.0 ? 'Curtain up!' : _steps[_step],
                      compact: !portrait,
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
  const _ProgressBlock({required this.progress, required this.caption, required this.compact});

  final double progress;
  final String caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(compact ? 12 : 14),
              ),
            ),
            const SizedBox(width: 12),
            Text('$percent%', style: AppText.numeric(compact ? 13 : 15)),
          ],
        ),
        SizedBox(height: compact ? 6 : 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => MeterBar(
            value: value,
            height: compact ? 13 : 18,
            gradient: Palette.goldBar,
            radiusFactor: 0.42,
          ),
        ),
      ],
    );
  }
}
