import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../game/game_controller.dart';
import '../models/levels.dart';
import '../models/roles.dart';
import '../widgets/ornaments.dart';
import '../widgets/role_badge.dart';
import '../widgets/stage_arena.dart';
import 'result_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final int level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameController _game;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  bool _paused = false;
  bool _recorded = false;
  ShowRewards? _rewards;

  @override
  void initState() {
    super.initState();
    _startLevel(widget.level);
    _ticker = createTicker(_onTick)..start();
  }

  void _startLevel(int level) {
    final progress = context.read<GameProgress>();
    _game = GameController(
      level: level,
      unlockedRoles: Roles.unlockedFor(progress.highestLevelUnlocked),
      skinIndex: progress.selectedSkin,
    )..start();
    _game.addListener(_onGameChanged);
    _recorded = false;
    _rewards = null;
    _paused = false;
    _last = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    if (_paused) {
      _last = elapsed;
      return;
    }
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    // Guard against long frames after a background pause.
    _game.tick(dt.clamp(0.0, 0.05));
  }

  void _onGameChanged() {
    if (_game.phase == GamePhase.finished && !_recorded) {
      _recorded = true;
      final progress = context.read<GameProgress>();
      _rewards = progress.recordShow(
        level: _game.level,
        score: _game.score,
        beats: _game.beats,
        combos: _game.scriptsCompleted,
        spins: _game.spins,
        bestCombo: _game.bestCombo,
        ovation: _game.outcome == ShowOutcome.ovation,
        survived: _game.outcome != ShowOutcome.failure,
        flawless: _game.flawless,
      );
      if (mounted) setState(() {});
    }
  }

  void _restart(int level) {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    setState(() => _startLevel(level));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_paused && _game.phase != GamePhase.finished) {
          setState(() => _paused = true);
        }
      },
      child: Scaffold(
        backgroundColor: Palette.velvetDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _Backdrop(game: _game),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final sideWidth = (c.maxWidth * 0.2).clamp(126.0, 196.0);
                    return Column(
                      children: [
                        _Hud(
                          game: _game,
                          onPause: () {
                            AudioManager.instance.play(Sfx.popupOpen, volume: 0.7);
                            setState(() => _paused = true);
                          },
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: sideWidth, child: _AudiencePanel(game: _game)),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: StageArena(game: _game),
                                ),
                              ),
                              SizedBox(width: sideWidth, child: _ScriptPanel(game: _game)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _EventBanner(game: _game),
            if (_paused)
              _PauseOverlay(
                onResume: () => setState(() => _paused = false),
                onRestart: () => _restart(_game.level),
                onQuit: () => Navigator.of(context).pop(),
              ),
            if (_game.phase == GamePhase.finished && _rewards != null)
              ResultOverlay(
                game: _game,
                rewards: _rewards!,
                onRetry: () => _restart(_game.level),
                onNext: _game.level < Levels.count &&
                        _rewards!.unlockedNextLevel
                    ? () => _restart(_game.level + 1)
                    : null,
                onMenu: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.0,
            colors: [
              (game.madness ? Palette.plum : Palette.velvetLight)
                  .withValues(alpha: 0.85 + game.flashLevel * 0.15),
              Palette.velvetDeep,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ------------------------------------------------------------------ top HUD
class _Hud extends StatelessWidget {
  const _Hud({required this.game, required this.onPause});

  final GameController game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final best = context.select<GameProgress, int>(
      (p) => p.levelBest[game.level] ?? 0,
    );
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final seconds = game.timeLeft.ceil().clamp(0, 999);
        final urgent = seconds <= 10;
        return OrnatePanel(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          opacity: 0.82,
          child: Row(
            children: [
              RoundIconButton(icon: Icons.pause_rounded, size: 30, onTap: onPause),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('HYPE', style: AppText.label(8.5, color: Colors.white70)),
                        const Spacer(),
                        Text(
                          game.mood.label,
                          style: AppText.label(8.5, color: Palette.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    MeterBar(value: game.hype, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HudStat(label: 'SCORE', value: '${game.score}', color: Palette.goldPale, wide: true),
              _HudStat(
                label: 'COMBO',
                value: game.combo > 0 ? 'x${game.combo}' : '—',
                color: game.combo > 2 ? Palette.magenta : Colors.white70,
              ),
              _HudStat(label: 'SPINS', value: '${game.spins}', color: Colors.white70),
              _HudStat(label: 'BEST', value: '$best', color: Colors.white70),
              const Spacer(),
              if (game.madness)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MadnessChip(left: game.madnessLeft),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: urgent ? null : Palette.buttonVelvet,
                  color: urgent ? Palette.crimson : null,
                  border: Border.all(color: Palette.gold, width: 1.3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: urgent ? Palette.goldPale : Palette.gold,
                    ),
                    const SizedBox(width: 4),
                    Text('$seconds', style: AppText.numeric(16)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: wide ? 66 : 46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.label(8, color: Colors.white54)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.numeric(15, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MadnessChip extends StatelessWidget {
  const _MadnessChip({required this.left});

  final double left;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Palette.magenta.withValues(alpha: 0.28),
        border: Border.all(color: Palette.magenta, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 13, color: Palette.magenta),
          const SizedBox(width: 4),
          Text('MADNESS ${left.ceil()}s', style: AppText.label(9, color: Palette.goldPale)),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- side panels
class _AudiencePanel extends StatelessWidget {
  const _AudiencePanel({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final mood = game.mood;
        final excitement = game.hype;
        return OrnatePanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          opacity: 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('THE HOUSE', textAlign: TextAlign.center, style: AppText.title(12)),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final cell = math.min(c.maxWidth / 3, c.maxHeight / 3) - 2;
                    return GridView.count(
                      crossAxisCount: 3,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: List.generate(9, (i) {
                        final active = i / 9 < excitement;
                        return Transform.translate(
                          offset: Offset(
                            0,
                            active ? -math.sin(game.ringRotation * 2 + i) * cell * 0.08 : 0,
                          ),
                          child: Opacity(
                            opacity: active ? 1 : 0.32,
                            child: Image.asset(
                              Sprites.audience((i * 7 + game.level * 3) % Sprites.audienceCount),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              cacheWidth: 110,
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mood.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(11, color: Palette.gold),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'ACT', value: '${game.level}')),
                  Expanded(child: _MiniStat(label: 'BEATS', value: '${game.beats}')),
                  Expanded(child: _MiniStat(label: 'COMBOS', value: '${game.scriptsCompleted}')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(child: Text(value, style: AppText.numeric(12))),
        FittedBox(child: Text(label, style: AppText.label(7.5, color: Colors.white54))),
      ],
    );
  }
}

class _ScriptPanel extends StatelessWidget {
  const _ScriptPanel({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final demand = Roles.byIndex(game.currentDemand);
        final upcoming = game.upcoming;
        return OrnatePanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          opacity: 0.78,
          glowColor: demand.color,
          child: LayoutBuilder(
            builder: (context, c) {
              final badge = (c.maxWidth * 0.52).clamp(46.0, 82.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AUDIENCE WANTS', textAlign: TextAlign.center, style: AppText.title(11)),
                  const SizedBox(height: 6),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('${game.currentDemand}-${game.scriptIndex}'),
                      tween: Tween(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      builder: (context, v, child) => Transform.scale(scale: v, child: child),
                      child: RoleBadge(role: demand, size: badge, highlight: true),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    demand.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(14, color: demand.color),
                  ),
                  Text(
                    demand.tagline,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(9, color: Colors.white60),
                  ),
                  const Spacer(),
                  Text('NEXT BEATS', textAlign: TextAlign.center, style: AppText.label(8.5, color: Colors.white54)),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 30,
                    child: upcoming.isEmpty
                        ? Center(
                            child: Text(
                              'FINAL BEAT',
                              style: AppText.label(10, color: Palette.gold),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final r in upcoming.take(4))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: RoleBadge(
                                      role: Roles.byIndex(r),
                                      size: 26,
                                      dimmed: true,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  MeterBar(
                    value: game.script.isEmpty ? 0 : game.scriptIndex / game.script.length,
                    height: 9,
                    gradient: Palette.goldBar,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SCRIPT ${game.scriptIndex}/${game.script.length}',
                    textAlign: TextAlign.center,
                    style: AppText.label(8.5, color: Colors.white54),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- overlays
class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        final info = game.eventInfo;
        final showEvent = info != null && game.bannerLeft > 0;
        final showMadness = game.madness && game.bannerLeft > 0 && info == null;
        if (!showEvent && !showMadness) return const SizedBox.shrink();

        final title = showEvent ? info.title : 'JESTER MADNESS';
        final detail = showEvent ? info.detail : 'Objects take two roles at once — double score';
        final color = showEvent ? info.color : Palette.magenta;
        final icon = showEvent ? info.icon : Sprites.jester(Sprites.jesterCheer);
        final t = (game.bannerLeft / 2.6).clamp(0.0, 1.0);

        return IgnorePointer(
          child: Align(
            alignment: const Alignment(0, -0.52),
            child: Opacity(
              opacity: (t < 0.25 ? t / 0.25 : 1.0).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.92 + 0.08 * (1 - t),
                child: OrnatePanel(
                  radius: 14,
                  borderColor: color,
                  glowColor: color,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(icon, height: 34, fit: BoxFit.contain, filterQuality: FilterQuality.low),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppText.title(15, color: color)),
                          Text(detail, style: AppText.body(10, color: Colors.white70)),
                        ],
                      ),
                    ],
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

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Palette.ink.withValues(alpha: 0.78),
        child: Center(
          child: SizedBox(
            width: 320,
            child: OrnatePanel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    Sprites.jester(Sprites.jesterPoint),
                    height: 76,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 6),
                  Text('INTERMISSION', style: AppText.title(20)),
                  const SizedBox(height: 14),
                  GoldButton(
                    label: 'RESUME',
                    width: double.infinity,
                    height: 44,
                    sfx: Sfx.popupClose,
                    onTap: onResume,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GoldButton(
                          label: 'RESTART',
                          velvet: true,
                          height: 40,
                          fontSize: 13,
                          onTap: onRestart,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GoldButton(
                          label: 'QUIT',
                          velvet: true,
                          height: 40,
                          fontSize: 13,
                          sfx: Sfx.menuClose,
                          onTap: onQuit,
                        ),
                      ),
                    ],
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
