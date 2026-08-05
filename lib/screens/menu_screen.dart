import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../models/levels.dart';
import '../models/roles.dart';
import '../widgets/backdrop.dart';
import '../widgets/ornaments.dart';
import 'collection_screen.dart';
import 'game_screen.dart';
import 'scene_select_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<GameProgress>();
    final level = Levels.byNumber(progress.highestLevelUnlocked);

    return Scaffold(
      backgroundColor: Palette.velvetDeep,
      body: VelvetBackdrop(
        floorIndex: 1,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(flex: 5, child: _Hero(progress: progress)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopStats(progress: progress),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GoldButton(
                              label: 'PLAY  ·  ACT ${progress.highestLevelUnlocked}',
                              height: 58,
                              fontSize: 19,
                              icon: Icons.play_arrow_rounded,
                              sfx: Sfx.menuOpen,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      GameScreen(level: progress.highestLevelUnlocked),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${level.scene.name} — ${level.title}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(12, color: Palette.goldPale),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GoldButton(
                                    label: 'SCENES',
                                    velvet: true,
                                    height: 46,
                                    fontSize: 14,
                                    icon: Icons.theater_comedy_rounded,
                                    sfx: Sfx.menuOpen,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const SceneSelectScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GoldButton(
                                    label: 'ROLES',
                                    velvet: true,
                                    height: 46,
                                    fontSize: 14,
                                    icon: Icons.auto_awesome_rounded,
                                    sfx: Sfx.menuOpen,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const CollectionScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    fit: StackFit.passthrough,
                                    children: [
                                      GoldButton(
                                        label: 'TASKS',
                                        velvet: true,
                                        height: 46,
                                        fontSize: 14,
                                        icon: Icons.checklist_rounded,
                                        sfx: Sfx.menuOpen,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const TasksScreen(),
                                          ),
                                        ),
                                      ),
                                      if (progress.hasClaimableTask)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Palette.crimsonLight,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Palette.goldPale,
                                                width: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GoldButton(
                                    label: 'SETTINGS',
                                    velvet: true,
                                    height: 46,
                                    fontSize: 14,
                                    icon: Icons.tune_rounded,
                                    sfx: Sfx.menuOpen,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.progress});

  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final logoHeight = (c.maxHeight * 0.62).clamp(90.0, 210.0);
        return Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Image.asset(
                Sprites.jester(Sprites.jesterLeap),
                height: (c.maxHeight * 0.52).clamp(80.0, 180.0),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Sprites.gameName,
                  height: logoHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.progress});

  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      radius: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(
            icon: Icons.confirmation_number_rounded,
            value: '${progress.tickets}',
            label: 'TICKETS',
            color: Palette.gold,
          ),
          _Stat(
            icon: Icons.emoji_events_rounded,
            value: '${progress.bestScore}',
            label: 'BEST',
            color: Palette.goldPale,
          ),
          _Stat(
            icon: Icons.auto_awesome_rounded,
            value: '${progress.collectedRoles}/${Roles.all.length}',
            label: 'ROLES',
            color: Palette.magenta,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value, style: AppText.numeric(15, color: color)),
          ],
        ),
        Text(label, style: AppText.label(8.5, color: Colors.white70)),
      ],
    );
  }
}
