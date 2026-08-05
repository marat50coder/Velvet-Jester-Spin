import 'package:flutter_test/flutter_test.dart';
import 'package:spingame/game/game_controller.dart';
import 'package:spingame/models/levels.dart';
import 'package:spingame/models/roles.dart';

GameController _controller({int level = 5}) => GameController(
      level: level,
      unlockedRoles: Roles.unlockedFor(level),
      skinIndex: 0,
    );

/// Runs the countdown out so the controller is in [GamePhase.playing].
void _beginShow(GameController game) {
  game.start();
  while (game.phase == GamePhase.countdown) {
    game.tick(0.1);
  }
}

void main() {
  // The controller fires haptics, which needs a binding even off-screen.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh show starts solvable', () {
    for (var level = 1; level <= Levels.count; level++) {
      final game = _controller(level: level);
      _beginShow(game);

      expect(game.objects, hasLength(game.config.objectCount));
      expect(game.script, hasLength(game.config.scriptLength));
      expect(
        game.objects.any((o) => o.matches(game.currentDemand)),
        isTrue,
        reason: 'act $level opens on a dead board',
      );
      game.dispose();
    }
  });

  test('a matching tap scores and advances the script', () {
    final game = _controller();
    _beginShow(game);

    final target = game.objects.firstWhere((o) => o.matches(game.currentDemand));
    game.tapObject(target);

    expect(game.beats, 1);
    expect(game.combo, 1);
    expect(game.score, greaterThan(0));
    expect(game.scriptIndex, 1);
    game.dispose();
  });

  test('a wrong tap costs hype and breaks the combo', () {
    final game = _controller();
    _beginShow(game);

    game.tapObject(game.objects.firstWhere((o) => o.matches(game.currentDemand)));
    final hypeBefore = game.hype;
    final wrong = game.objects.firstWhere((o) => !o.matches(game.currentDemand));
    game.tapObject(wrong);

    expect(game.combo, 0);
    expect(game.misses, 1);
    expect(game.hype, lessThan(hypeBefore));
    game.dispose();
  });

  test('spin re-rolls the stage and respects its cooldown', () {
    final game = _controller(level: 9);
    _beginShow(game);

    final before = game.objects.map((o) => o.roleIndex).toList();
    game.spin();
    expect(game.spins, 1);
    expect(
      game.objects.map((o) => o.roleIndex).toList(),
      isNot(equals(before)),
      reason: 'a spin must change the board',
    );

    game.spin();
    expect(game.spins, 1, reason: 'the cooldown blocks a second spin');

    game.tick(0.5);
    game.spin();
    expect(game.spins, 2);
    game.dispose();
  });

  test('spinning never leaves the player stuck', () {
    final game = _controller(level: 14);
    _beginShow(game);

    // The board can miss on a single unlucky spin, but the anti-deadlock guard
    // hands out the demanded role within two consecutive fruitless spins, so a
    // player is never stuck for more than one extra spin.
    for (var round = 0; round < 40; round++) {
      game.hype = 0.8; // keep the show alive across the whole run
      game.spin();
      game.tick(0.5);
      if (game.objects.any((o) => o.matches(game.currentDemand))) continue;

      // No match this spin: one more must rescue the board.
      game.hype = 0.8;
      game.spin();
      game.tick(0.5);
      expect(
        game.objects.any((o) => o.matches(game.currentDemand)),
        isTrue,
        reason: 'two spins in a row left no playable object',
      );
    }
    game.dispose();
  });

  test('finishing a script pays a velvet combo bonus', () {
    final game = _controller();
    _beginShow(game);

    final scriptLength = game.script.length;
    var guard = 0;
    while (game.scriptsCompleted == 0 && guard++ < 200) {
      final match = game.objects.where((o) => o.matches(game.currentDemand));
      if (match.isEmpty) {
        game.tick(0.5);
        game.spin();
        continue;
      }
      game.tapObject(match.first);
    }

    expect(game.scriptsCompleted, 1);
    expect(game.beats, greaterThanOrEqualTo(scriptLength));
    expect(game.script, isNotEmpty, reason: 'a new script follows the combo');
    expect(game.scriptIndex, 0);
    game.dispose();
  });

  test('an empty hype meter ends the show as a failure', () {
    final game = _controller();
    _beginShow(game);

    game.hype = 0.01;
    game.tick(1.0);

    expect(game.phase, GamePhase.finished);
    expect(game.outcome, ShowOutcome.failure);
    game.dispose();
  });

  test('surviving to the final beat ends in applause or an ovation', () {
    final game = _controller();
    _beginShow(game);

    while (game.phase == GamePhase.playing) {
      game.hype = 0.8;
      game.tick(0.25);
    }

    expect(game.phase, GamePhase.finished);
    expect(game.outcome, ShowOutcome.ovation);
    expect(game.timeLeft, 0);
    game.dispose();
  });

  test('a long run of play stays stable', () {
    final game = _controller(level: 11);
    _beginShow(game);

    var taps = 0;
    while (game.phase == GamePhase.playing) {
      game.hype = 0.7;
      game.tick(1 / 60);
      final match = game.objects.where((o) => o.matches(game.currentDemand));
      if (match.isNotEmpty && taps % 3 == 0) {
        game.tapObject(match.first);
      } else if (match.isEmpty) {
        game.spin();
      }
      taps++;
    }

    expect(game.score, greaterThan(0));
    expect(game.objects, isNotEmpty);
    expect(game.effects.length, lessThan(400), reason: 'effects must be reaped');
    expect(game.particles.length, lessThan(600));
    game.dispose();
  });

  test('madness grants second roles and expires', () {
    final game = _controller(level: 10);
    _beginShow(game);

    var guard = 0;
    while (!game.madness && guard++ < 400) {
      final match = game.objects.where((o) => o.matches(game.currentDemand));
      if (match.isEmpty) {
        game.tick(0.5);
        game.spin();
        continue;
      }
      game.tapObject(match.first);
      game.tick(1 / 60);
    }

    expect(game.madness, isTrue, reason: 'a six beat combo must trigger madness');
    expect(game.objects.any((o) => o.secondRoleIndex != null), isTrue);
    expect(game.scoreMultiplier, greaterThanOrEqualTo(2));

    game.hype = 1;
    for (var i = 0; i < 700; i++) {
      game.hype = 1;
      game.tick(1 / 60);
    }
    expect(game.madness, isFalse);
    expect(game.objects.every((o) => o.secondRoleIndex == null), isTrue);
    game.dispose();
  });

  test('roles unlock steadily across the acts', () {
    expect(Roles.unlockedFor(1).length, greaterThanOrEqualTo(5));
    expect(
      Roles.unlockedFor(Levels.count).length,
      greaterThan(Roles.unlockedFor(1).length),
    );
    expect(Roles.unlockedFor(Levels.count).length, Roles.all.length);
  });
}
