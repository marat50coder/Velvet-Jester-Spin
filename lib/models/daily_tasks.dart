/// Metrics a daily task can track. Names are persisted, so keep them stable.
enum TaskMetric { shows, beats, combos, ovations, spins, bestCombo, perfectShow }

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.metric,
    required this.title,
    required this.detail,
    required this.target,
    required this.reward,
  });

  final String id;
  final TaskMetric metric;
  final String title;
  final String detail;
  final int target;
  final int reward;
}

class DailyTasks {
  const DailyTasks._();

  static const pool = <TaskTemplate>[
    TaskTemplate(
      id: 'shows5',
      metric: TaskMetric.shows,
      title: 'Full House',
      detail: 'Finish 5 performances',
      target: 5,
      reward: 40,
    ),
    TaskTemplate(
      id: 'beats20',
      metric: TaskMetric.beats,
      title: 'Quick Change',
      detail: 'Perform 20 transformations',
      target: 20,
      reward: 35,
    ),
    TaskTemplate(
      id: 'combos10',
      metric: TaskMetric.combos,
      title: 'Velvet Streak',
      detail: 'Complete 10 Velvet Combos',
      target: 10,
      reward: 50,
    ),
    TaskTemplate(
      id: 'ovations5',
      metric: TaskMetric.ovations,
      title: 'On Their Feet',
      detail: 'Earn 5 standing ovations',
      target: 5,
      reward: 60,
    ),
    TaskTemplate(
      id: 'spins30',
      metric: TaskMetric.spins,
      title: 'Turn the Ring',
      detail: 'Use the Spin 30 times',
      target: 30,
      reward: 30,
    ),
    TaskTemplate(
      id: 'combo8',
      metric: TaskMetric.bestCombo,
      title: 'Chain Master',
      detail: 'Reach a combo of 8',
      target: 8,
      reward: 45,
    ),
    TaskTemplate(
      id: 'perfect1',
      metric: TaskMetric.perfectShow,
      title: 'Flawless Act',
      detail: 'Finish a show without a single miss',
      target: 1,
      reward: 70,
    ),
  ];

  static TaskTemplate byId(String id) => pool.firstWhere(
        (t) => t.id == id,
        orElse: () => pool.first,
      );

  /// Deterministic daily rotation so the set is stable for the whole day.
  static List<TaskTemplate> forDay(int dayKey) {
    final indices = <int>[];
    var seed = dayKey * 2654435761 % 2147483647;
    while (indices.length < 3) {
      seed = (seed * 1103515245 + 12345) % 2147483647;
      final i = seed % pool.length;
      if (!indices.contains(i)) indices.add(i);
    }
    return indices.map((i) => pool[i]).toList();
  }
}
