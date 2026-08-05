import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../game/game_controller.dart';
import '../models/roles.dart';
import '../widgets/ornaments.dart';
import '../widgets/role_badge.dart';

class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.game,
    required this.rewards,
    required this.onRetry,
    required this.onMenu,
    this.onNext,
  });

  final GameController game;
  final ShowRewards rewards;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final failed = game.outcome == ShowOutcome.failure;
    final title = switch (game.outcome) {
      ShowOutcome.ovation => 'STANDING OVATION',
      ShowOutcome.applause => 'CURTAIN CALL',
      ShowOutcome.failure => 'THE HOUSE WENT COLD',
    };
    final jester = switch (game.outcome) {
      ShowOutcome.ovation => Sprites.jesterCheer,
      ShowOutcome.applause => Sprites.jesterReady,
      ShowOutcome.failure => Sprites.jesterShock,
    };
    final accent = failed ? Palette.crimsonLight : Palette.gold;

    return Positioned.fill(
      child: ColoredBox(
        color: Palette.ink.withValues(alpha: 0.82),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.86, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: SizedBox(
                width: math.min(620, c.maxWidth - 24),
                child: OrnatePanel(
                  borderColor: accent,
                  glowColor: accent,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            Sprites.jester(jester),
                            height: 92,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.title(21, color: accent),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Act ${game.level} · ${game.config.title}',
                                  style: AppText.body(11, color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    for (var i = 0; i < 3; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 3),
                                        child: Icon(
                                          i < rewards.stars
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          size: 26,
                                          color: i < rewards.stars ? Palette.gold : Colors.white24,
                                        ),
                                      ),
                                    const Spacer(),
                                    if (rewards.newBest)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: Palette.buttonGold,
                                        ),
                                        child: Text(
                                          'NEW BEST',
                                          style: AppText.label(9, color: Palette.ink),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('SHOW SCORE', style: AppText.label(9, color: Colors.white54)),
                              Text('${game.score}', style: AppText.numeric(32, color: accent)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.confirmation_number_rounded,
                                    size: 14,
                                    color: Palette.gold,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${rewards.ticketsEarned}',
                                    style: AppText.numeric(14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ResultStat(label: 'TRANSFORMS', value: '${game.beats}'),
                          _ResultStat(label: 'VELVET COMBOS', value: '${game.scriptsCompleted}'),
                          _ResultStat(label: 'LONGEST CHAIN', value: 'x${game.bestCombo}'),
                          _ResultStat(label: 'SPINS', value: '${game.spins}'),
                          _ResultStat(label: 'MISSES', value: '${game.misses}'),
                        ],
                      ),
                      if (rewards.newRoles > 0) ...[
                        const SizedBox(height: 10),
                        _NewRolesStrip(count: rewards.newRoles, unlockedTo: game.level + 1),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GoldButton(
                              label: 'MENU',
                              velvet: true,
                              height: 44,
                              fontSize: 14,
                              sfx: Sfx.menuClose,
                              onTap: onMenu,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GoldButton(
                              label: 'REPLAY',
                              velvet: true,
                              height: 44,
                              fontSize: 14,
                              onTap: onRetry,
                            ),
                          ),
                          if (onNext != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: GoldButton(
                                label: 'NEXT ACT',
                                height: 44,
                                fontSize: 16,
                                icon: Icons.play_arrow_rounded,
                                onTap: onNext!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Palette.goldDeep.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppText.numeric(16)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(7.5, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewRolesStrip extends StatelessWidget {
  const _NewRolesStrip({required this.count, required this.unlockedTo});

  final int count;
  final int unlockedTo;

  @override
  Widget build(BuildContext context) {
    final roles = Roles.all.where((r) => r.unlockLevel == unlockedTo).take(count).toList();
    if (roles.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Palette.plum.withValues(alpha: 0.7),
            Palette.velvetDeep.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(color: Palette.magenta.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, size: 18, color: Palette.gold),
          const SizedBox(width: 8),
          Text('NEW ROLE UNLOCKED', style: AppText.label(11, color: Palette.gold)),
          const SizedBox(width: 12),
          for (final r in roles) ...[
            RoleBadge(role: r, size: 30, highlight: true),
            const SizedBox(width: 6),
            Text(r.name, style: AppText.label(11, color: r.color)),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}
