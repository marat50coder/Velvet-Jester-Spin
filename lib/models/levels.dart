import '../core/sprites.dart';

class StageScene {
  const StageScene({required this.name, required this.subtitle, required this.floorIndex});

  final String name;
  final String subtitle;
  final int floorIndex;

  String get floor => Sprites.stageFloors[floorIndex];
}

class LevelConfig {
  const LevelConfig({
    required this.number,
    required this.scene,
    required this.title,
    required this.duration,
    required this.objectCount,
    required this.rolePoolSize,
    required this.scriptLength,
    required this.hypeDecayPerSecond,
    required this.eventInterval,
    required this.starTargets,
  });

  final int number;
  final StageScene scene;
  final String title;

  /// Length of one performance, in seconds (design target: 40-90s).
  final int duration;
  final int objectCount;

  /// How many different roles can appear this level.
  final int rolePoolSize;

  /// Beats in one audience script (a completed script is a Velvet Combo).
  final int scriptLength;
  final double hypeDecayPerSecond;
  final double eventInterval;

  /// Score needed for 1, 2 and 3 stars.
  final List<int> starTargets;
}

class Levels {
  const Levels._();

  static const scenes = <StageScene>[
    StageScene(name: 'Velvet Hall', subtitle: 'Where the season opens', floorIndex: 0),
    StageScene(name: 'Crimson Rotunda', subtitle: 'Gilded ribs, red velvet', floorIndex: 1),
    StageScene(name: 'Clockwork Ring', subtitle: 'Gears beneath the boards', floorIndex: 2),
    StageScene(name: 'Cathedral of Glass', subtitle: 'Light through coloured panes', floorIndex: 3),
    StageScene(name: 'Nebula Parlour', subtitle: 'A stage stitched from stars', floorIndex: 4),
    StageScene(name: 'Frost Mirror', subtitle: 'Cold, bright, unforgiving', floorIndex: 5),
    StageScene(name: 'Cloud Ovation', subtitle: 'The final act, above the world', floorIndex: 6),
  ];

  static final List<LevelConfig> all = _build();

  static List<LevelConfig> _build() {
    const titles = [
      'Opening Night',
      'The Warm Crowd',
      'Ribbons and Brass',
      'A Louder House',
      'Gears in Motion',
      'The Ticking Act',
      'Stained Light',
      'Prism Finale',
      'Starfall Revue',
      'The Comet Encore',
      'Silver Reflection',
      'Mirror Maze',
      'Above the Clouds',
      'The Grand Ovation',
    ];

    return List<LevelConfig>.generate(14, (i) {
      final n = i + 1;
      final scene = scenes[i ~/ 2];
      final objects = (7 + n * 0.55).round().clamp(7, 14);
      final rolePool = (4 + n * 0.85).round().clamp(4, 12);
      final script = (2 + n * 0.28).round().clamp(2, 6);
      final duration = (44 + n * 3).clamp(44, 90);
      final decay = 0.021 + n * 0.0028;
      final events = (17.0 - n * 0.55).clamp(9.0, 17.0);
      final base = 900 + n * 520;
      return LevelConfig(
        number: n,
        scene: scene,
        title: titles[i],
        duration: duration,
        objectCount: objects,
        rolePoolSize: rolePool,
        scriptLength: script,
        hypeDecayPerSecond: decay,
        eventInterval: events,
        starTargets: [base, (base * 1.55).round(), (base * 2.2).round()],
      );
    });
  }

  static LevelConfig byNumber(int number) => all[(number - 1).clamp(0, all.length - 1)];

  static int get count => all.length;
}
