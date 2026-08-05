import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sprites.dart';

/// A role is the "job" an object performs on stage. Every Spin reassigns them.
class Role {
  const Role({
    required this.index,
    required this.iconIndex,
    required this.name,
    required this.tagline,
    required this.description,
    required this.color,
    required this.unlockLevel,
  });

  /// Stable id used for persistence and ordering in the encyclopedia.
  final int index;

  /// Slice index inside the role-icon atlas.
  final int iconIndex;
  final String name;
  final String tagline;
  final String description;
  final Color color;
  final int unlockLevel;

  String get icon => Sprites.roleIcon(iconIndex);
}

class Roles {
  const Roles._();

  static const all = <Role>[
    Role(
      index: 0,
      iconIndex: 0,
      name: 'PERFORMER',
      tagline: 'Takes the centre ring',
      description:
          'The backbone of any act. A performer soaks up the spotlight and keeps the audience leaning forward.',
      color: Palette.gold,
      unlockLevel: 1,
    ),
    Role(
      index: 1,
      iconIndex: 14,
      name: 'SPOTLIGHT',
      tagline: 'Paints the stage in light',
      description:
          'Turns any object into a beam of theatre light. Light chains read beautifully to the crowd.',
      color: Color(0xFFFFB347),
      unlockLevel: 1,
    ),
    Role(
      index: 2,
      iconIndex: 1,
      name: 'MUSICIAN',
      tagline: 'Carries the melody',
      description: 'Gives the scene rhythm. Musicians pair naturally with orchestral finales.',
      color: Color(0xFFE05FD0),
      unlockLevel: 1,
    ),
    Role(
      index: 3,
      iconIndex: 9,
      name: 'APPLAUSE',
      tagline: 'Feeds the crowd back to itself',
      description: 'Objects clap along. Applause roles restore extra hype when chained late.',
      color: Color(0xFFFFD166),
      unlockLevel: 1,
    ),
    Role(
      index: 4,
      iconIndex: 13,
      name: 'DECOR',
      tagline: 'Dresses the scene',
      description: 'Quiet but essential. Decor keeps the stage rich while you set up bigger tricks.',
      color: Color(0xFFFF8FC7),
      unlockLevel: 1,
    ),
    Role(
      index: 5,
      iconIndex: 15,
      name: 'CONFETTI',
      tagline: 'Bursts of paper colour',
      description: 'A quick crowd-pleaser. Confetti roles are worth more during Jester Madness.',
      color: Color(0xFF7BE8A8),
      unlockLevel: 2,
    ),
    Role(
      index: 6,
      iconIndex: 2,
      name: 'MAGICIAN',
      tagline: 'Hat, cards, impossible things',
      description: 'Bends the rules of the act. Magicians open the door to illusion chains.',
      color: Color(0xFFB68CFF),
      unlockLevel: 3,
    ),
    Role(
      index: 7,
      iconIndex: 12,
      name: 'FIREWORKS',
      tagline: 'Sky-high punctuation',
      description: 'Best saved for the end of a script. Fireworks pay a bonus on the final beat.',
      color: Color(0xFFFF6B8A),
      unlockLevel: 4,
    ),
    Role(
      index: 8,
      iconIndex: 3,
      name: 'MIRROR',
      tagline: 'Reflects the act back',
      description: 'Copies the mood of the ring. Mirrors make long scripts easier to read.',
      color: Color(0xFF9AD9FF),
      unlockLevel: 5,
    ),
    Role(
      index: 9,
      iconIndex: 4,
      name: 'MAGNET',
      tagline: 'Pulls the show together',
      description: 'Draws attention across the ring, letting distant objects share a beat.',
      color: Color(0xFF5AD1E8),
      unlockLevel: 6,
    ),
    Role(
      index: 10,
      iconIndex: 5,
      name: 'ORCHESTRA',
      tagline: 'Every instrument at once',
      description: 'A grand upgrade of the musician. Orchestra beats score double in a full script.',
      color: Color(0xFFFFC98B),
      unlockLevel: 7,
    ),
    Role(
      index: 11,
      iconIndex: 11,
      name: 'CONDUCTOR',
      tagline: 'Sets the tempo',
      description: 'Holds the whole ring on a single baton. Conductor beats slow the hype decay.',
      color: Color(0xFFFF9FE8),
      unlockLevel: 8,
    ),
    Role(
      index: 12,
      iconIndex: 6,
      name: 'SHADOW',
      tagline: 'The act behind the act',
      description: 'Silent and strange. Shadows are hard to spot but pay a premium.',
      color: Color(0xFF9B7BD8),
      unlockLevel: 9,
    ),
    Role(
      index: 13,
      iconIndex: 7,
      name: 'TWIN',
      tagline: 'Two of everything',
      description: 'Duplicates a performer. Twin beats extend your combo window.',
      color: Color(0xFF7FC8FF),
      unlockLevel: 10,
    ),
    Role(
      index: 14,
      iconIndex: 8,
      name: 'TELEPORT',
      tagline: 'Here, then there',
      description: 'Objects vanish and reappear elsewhere on the ring after performing.',
      color: Color(0xFF6FD9FF),
      unlockLevel: 11,
    ),
    Role(
      index: 15,
      iconIndex: 10,
      name: 'CHARM',
      tagline: 'Golden wings over the crowd',
      description: 'The rarest role. Charm beats award a full hype refill when they end a script.',
      color: Color(0xFFFFE79A),
      unlockLevel: 12,
    ),
  ];

  static Role byIndex(int index) => all[index];

  static List<Role> unlockedFor(int highestLevelReached) =>
      all.where((r) => r.unlockLevel <= highestLevelReached).toList();

  static int unlockedCountFor(int highestLevelReached) =>
      all.where((r) => r.unlockLevel <= highestLevelReached).length;
}
