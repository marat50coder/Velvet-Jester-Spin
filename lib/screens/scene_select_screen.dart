import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/storage.dart';
import '../models/levels.dart';
import '../widgets/backdrop.dart';
import '../widgets/ornaments.dart';
import 'game_screen.dart';

class SceneSelectScreen extends StatelessWidget {
  const SceneSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<GameProgress>();

    return VelvetPage(
      title: 'THEATRE SCENES',
      floorIndex: 3,
      trailing: OrnatePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        radius: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 15, color: Palette.gold),
            const SizedBox(width: 5),
            Text(
              '${progress.totalStars} / ${Levels.count * 3}',
              style: AppText.numeric(14),
            ),
          ],
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        itemCount: Levels.scenes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final scene = Levels.scenes[index];
          final levels = Levels.all.where((l) => l.scene == scene).toList();
          return _SceneCard(scene: scene, levels: levels, progress: progress);
        },
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.levels, required this.progress});

  final StageScene scene;
  final List<LevelConfig> levels;
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = levels.first.number <= progress.highestLevelUnlocked;
    return SizedBox(
      width: 240,
      child: OrnatePanel(
        padding: const EdgeInsets.all(10),
        borderColor: unlocked ? Palette.gold : Palette.goldDeep.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: ColorFiltered(
                      colorFilter: unlocked
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0, //
                              0.2126, 0.7152, 0.0722, 0, 0, //
                              0.2126, 0.7152, 0.0722, 0, 0, //
                              0, 0, 0, 1, 0,
                            ]),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          scene.floor,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          cacheWidth: 320,
                        ),
                      ),
                    ),
                  ),
                  if (!unlocked)
                    const Icon(Icons.lock_rounded, size: 34, color: Palette.goldPale),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scene.name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(15),
            ),
            Text(
              scene.subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(10.5, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            for (final level in levels) ...[
              _LevelRow(level: level, progress: progress),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level, required this.progress});

  final LevelConfig level;
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = level.number <= progress.highestLevelUnlocked;
    final stars = progress.levelStars[level.number] ?? 0;
    final best = progress.levelBest[level.number] ?? 0;

    return GestureDetector(
      onTap: unlocked
          ? () {
              AudioManager.instance.play(Sfx.menuOpen, volume: 0.75);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => GameScreen(level: level.number)),
              );
            }
          : () => AudioManager.instance.play(Sfx.popupClose, volume: 0.4),
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: unlocked ? Palette.buttonVelvet : null,
            color: unlocked ? null : Colors.black26,
            border: Border.all(
              color: unlocked ? Palette.gold.withValues(alpha: 0.75) : Colors.white24,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Palette.buttonGold,
                ),
                child: Text(
                  '${level.number}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(11.5),
                    ),
                    Text(
                      best > 0 ? 'Best $best' : '${level.duration}s · ${level.objectCount} acts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(9.5, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 13,
                    color: i < stars ? Palette.gold : Colors.white30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
