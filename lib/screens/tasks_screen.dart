import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../models/daily_tasks.dart';
import '../widgets/backdrop.dart';
import '../widgets/ornaments.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<GameProgress>();
    final tasks = progress.todayTasks;

    return VelvetPage(
      title: 'DAILY BILLING',
      floorIndex: 5,
      trailing: OrnatePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        radius: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_number_rounded, size: 15, color: Palette.gold),
            const SizedBox(width: 5),
            Text('${progress.tickets}', style: AppText.numeric(14)),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (final t in tasks) ...[
                  Expanded(child: _TaskCard(task: t, progress: progress)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 210, child: _CareerPanel(progress: progress)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.progress});

  final TaskTemplate task;
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.taskProgress(task);
    final done = progress.taskComplete(task);
    final claimed = progress.taskClaimed(task);

    return OrnatePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderColor: claimed
          ? Palette.goldDeep.withValues(alpha: 0.5)
          : (done ? Palette.gold : Palette.goldDeep),
      glowColor: done && !claimed ? Palette.gold : null,
      child: Row(
        children: [
          Image.asset(
            Sprites.celebration(Sprites.partyStars[task.id.hashCode.abs() % 4]),
            height: 34,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.low,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(13),
                ),
                Text(
                  task.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(10, color: Colors.white60),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: MeterBar(
                        value: value / task.target,
                        height: 8,
                        gradient: Palette.goldBar,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$value/${task.target}', style: AppText.numeric(11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: claimed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Palette.gold, size: 24),
                      Text('CLAIMED', style: AppText.label(8.5, color: Colors.white54)),
                    ],
                  )
                : GoldButton(
                    label: '+${task.reward}',
                    height: 38,
                    fontSize: 14,
                    icon: Icons.confirmation_number_rounded,
                    enabled: done,
                    velvet: !done,
                    sfx: Sfx.reward,
                    onTap: () => progress.claimTask(task),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CareerPanel extends StatelessWidget {
  const _CareerPanel({required this.progress});

  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CAREER', textAlign: TextAlign.center, style: AppText.title(14)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                _Row(label: 'Shows played', value: '${progress.totalShows}'),
                _Row(label: 'Transformations', value: '${progress.totalBeats}'),
                _Row(label: 'Velvet Combos', value: '${progress.totalCombos}'),
                _Row(label: 'Standing ovations', value: '${progress.totalOvations}'),
                _Row(label: 'Spins used', value: '${progress.totalSpins}'),
                _Row(label: 'Longest chain', value: 'x${progress.longestCombo}'),
                _Row(label: 'Best score', value: '${progress.bestScore}'),
                _Row(label: 'Stars earned', value: '${progress.totalStars}'),
                _Row(
                  label: 'Roles collected',
                  value: '${(progress.collectionPercent * 100).round()}%',
                ),
              ],
            ),
          ),
          Text(
            'Tasks refresh every day at midnight.',
            textAlign: TextAlign.center,
            style: AppText.body(9.5, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(10.5, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 6),
          Text(value, style: AppText.numeric(12)),
        ],
      ),
    );
  }
}
