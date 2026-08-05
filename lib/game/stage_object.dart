import 'dart:math' as math;
import 'dart:ui';

import '../core/sprites.dart';

enum ObjectKind { card, spotlight, instrument, prop, animal }

extension ObjectKindInfo on ObjectKind {
  String get label => switch (this) {
        ObjectKind.card => 'Card',
        ObjectKind.spotlight => 'Spotlight',
        ObjectKind.instrument => 'Instrument',
        ObjectKind.prop => 'Prop',
        ObjectKind.animal => 'Animal',
      };

  /// Relative on-stage footprint; animals read as bigger than cards.
  double get scale => switch (this) {
        ObjectKind.card => 0.96,
        ObjectKind.spotlight => 1.0,
        ObjectKind.instrument => 1.0,
        ObjectKind.prop => 1.0,
        ObjectKind.animal => 1.12,
      };

  String spriteFor(int poolIndex) => switch (this) {
        ObjectKind.card => Sprites.card(Sprites.cardPool[poolIndex % Sprites.cardPool.length]),
        ObjectKind.spotlight =>
          Sprites.spotlight(Sprites.spotlightPool[poolIndex % Sprites.spotlightPool.length]),
        ObjectKind.instrument =>
          Sprites.instrument(Sprites.instrumentPool[poolIndex % Sprites.instrumentPool.length]),
        ObjectKind.prop => Sprites.prop(Sprites.propPool[poolIndex % Sprites.propPool.length]),
        ObjectKind.animal =>
          Sprites.animal(Sprites.animalPool[poolIndex % Sprites.animalPool.length]),
      };
}

/// One performer on the ring. Positions are polar and normalised to the arena
/// radius so the widget layer can map them to any screen size.
class StageObject {
  StageObject({
    required this.id,
    required this.kind,
    required this.sprite,
    required this.angle,
    required this.radius,
    required this.roleIndex,
    this.wild = false,
    this.temporary = false,
  });

  final int id;
  final ObjectKind kind;
  final String sprite;

  double angle;
  double radius;
  int roleIndex;
  int? secondRoleIndex;
  bool wild;
  bool temporary;

  /// 1.0 right after a transformation, decaying to 0 - drives the flash.
  double flash = 0;

  /// Non-zero while the object plays its "wrong pick" wobble.
  double shake = 0;

  /// Ramps 0 -> 1 when the object walks onto the stage.
  double entry = 0;

  double bobPhase = 0;

  bool matches(int role) => wild || roleIndex == role || secondRoleIndex == role;

  Offset unitPosition(double ringRotation) {
    final a = angle + ringRotation;
    return Offset(math.cos(a) * radius, math.sin(a) * radius);
  }
}
