import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sprites.dart';

enum StageEventKind {
  lightsOut,
  lionAppears,
  kingArrives,
  confettiRain,
  extraSpotlights,
  hiddenStage,
  magicIllusion,
}

class StageEventInfo {
  const StageEventInfo({
    required this.kind,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.duration,
  });

  final StageEventKind kind;
  final String title;
  final String detail;
  final String icon;
  final Color color;
  final double duration;

  static const catalog = <StageEventKind, StageEventInfo>{
    StageEventKind.lightsOut: StageEventInfo(
      kind: StageEventKind.lightsOut,
      title: 'LIGHTS OUT',
      detail: 'Roles are hidden - trust your memory',
      icon: 'assets/sprites/magic_effects/68.png',
      color: Color(0xFF9B7BD8),
      duration: 5,
    ),
    StageEventKind.lionAppears: StageEventInfo(
      kind: StageEventKind.lionAppears,
      title: 'THE LION!',
      detail: 'A wild act joins - it fits any beat',
      icon: 'assets/sprites/circus_animals/00.png',
      color: Color(0xFFFFB347),
      duration: 10,
    ),
    StageEventKind.kingArrives: StageEventInfo(
      kind: StageEventKind.kingArrives,
      title: 'THE KING ARRIVES',
      detail: 'Double score while he watches',
      icon: 'assets/sprites/celebration_effects/58.png',
      color: Palette.gold,
      duration: 9,
    ),
    StageEventKind.confettiRain: StageEventInfo(
      kind: StageEventKind.confettiRain,
      title: 'CONFETTI RAIN',
      detail: 'The house showers the ring',
      icon: 'assets/sprites/celebration_effects/17.png',
      color: Color(0xFF7BE8A8),
      duration: 4,
    ),
    StageEventKind.extraSpotlights: StageEventInfo(
      kind: StageEventKind.extraSpotlights,
      title: 'EXTRA SPOTLIGHTS',
      detail: 'Two more objects take the ring',
      icon: 'assets/sprites/spotlights/03.png',
      color: Color(0xFFE04FCF),
      duration: 4,
    ),
    StageEventKind.hiddenStage: StageEventInfo(
      kind: StageEventKind.hiddenStage,
      title: 'HIDDEN STAGE',
      detail: 'The ring turns beneath the act',
      icon: 'assets/sprites/magic_effects/00.png',
      color: Color(0xFF56D8F5),
      duration: 11,
    ),
    StageEventKind.magicIllusion: StageEventInfo(
      kind: StageEventKind.magicIllusion,
      title: 'MAGIC ILLUSION',
      detail: 'Roles reshuffle on their own',
      icon: 'assets/sprites/magic_effects/02.png',
      color: Color(0xFFB68CFF),
      duration: 9,
    ),
  };

  static StageEventInfo of(StageEventKind kind) => catalog[kind]!;
}

/// Transient sprite burst rendered above the ring.
class VisualEffect {
  VisualEffect({
    required this.sprite,
    required this.position,
    required this.size,
    required this.life,
    this.spin = 0,
    this.drift = Offset.zero,
    this.startScale = 0.4,
    this.endScale = 1.4,
    this.tint,
  });

  final String sprite;
  final Offset position;
  final double size;
  final double life;
  final double spin;
  final Offset drift;
  final double startScale;
  final double endScale;
  final Color? tint;

  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);

  bool get dead => age >= life;
}

class FloatingLabel {
  FloatingLabel({
    required this.text,
    required this.position,
    required this.color,
    this.life = 1.1,
    this.size = 20,
  });

  final String text;
  final Offset position;
  final Color color;
  final double life;
  final double size;

  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);

  bool get dead => age >= life;
}

/// Confetti/streamer particle used for the celebration overlay.
class Particle {
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    required this.rotationSpeed,
  });

  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double life;
  final double rotationSpeed;

  double age = 0;
  double rotation = 0;

  bool get dead => age >= life;
}

const kCelebrationSprites = <int>[
  Sprites.crown,
  Sprites.topHat,
  Sprites.carnivalMask,
];
