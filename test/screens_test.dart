import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spingame/core/palette.dart';
import 'package:spingame/core/storage.dart';
import 'package:spingame/game/game_controller.dart';
import 'package:spingame/models/roles.dart';
import 'package:spingame/screens/collection_screen.dart';
import 'package:spingame/screens/game_screen.dart';
import 'package:spingame/screens/loading_screen.dart';
import 'package:spingame/screens/menu_screen.dart';
import 'package:spingame/screens/result_overlay.dart';
import 'package:spingame/screens/scene_select_screen.dart';
import 'package:spingame/screens/settings_screen.dart';
import 'package:spingame/screens/tasks_screen.dart';
import 'package:spingame/widgets/ornaments.dart';

/// Logical sizes of the smallest and largest devices the game ships on, in the
/// landscape orientation it locks to.
const _sizes = <String, Size>{
  'iPhone SE': Size(667, 375),
  'iPhone 16 Pro Max': Size(956, 440),
  'iPad 11"': Size(1194, 834),
};

Future<GameProgress> _newProgress({int level = 8}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'highestLevel': level,
    'tickets': 640,
    'bestScore': 18420,
  });
  return GameProgress(await SharedPreferences.getInstance());
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Size size, {
  GameProgress? progress,
  EdgeInsets padding = const EdgeInsets.only(left: 44, right: 44, bottom: 21),
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final store = progress ?? await _newProgress();
  await tester.pumpWidget(
    ChangeNotifierProvider<GameProgress>.value(
      value: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: Palette.velvetDeep),
        home: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: 3.0, padding: padding),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
}

void main() {
  final screens = <String, Widget Function()>{
    'menu': () => const MenuScreen(),
    'scenes': () => const SceneSelectScreen(),
    'collection': () => const CollectionScreen(),
    'tasks': () => const TasksScreen(),
    'settings': () => const SettingsScreen(),
    'game': () => const GameScreen(level: 8),
  };

  group('every screen lays out in landscape', () {
    for (final entry in screens.entries) {
      for (final device in _sizes.entries) {
        testWidgets('${entry.key} on ${device.key}', (tester) async {
          await _pump(tester, entry.value(), device.value);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('loading screen fits both orientations and starts empty', (tester) async {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await _pump(tester, const LoadingScreen(), size, padding: EdgeInsets.zero);
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('0%'), findsOneWidget, reason: 'the bar must start empty');
      expect(find.text('100%'), findsNothing);

      // Drop the screen before its boot sequence can navigate away.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }
  });

  testWidgets('game screen survives a played-out show', (tester) async {
    await _pump(tester, const GameScreen(level: 12), const Size(667, 375));

    // Countdown, then a stretch of play with spins and taps.
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);

    final spin = find.text('SPIN');
    expect(spin, findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(spin, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause overlay opens from the HUD', (tester) async {
    await _pump(tester, const GameScreen(level: 3), const Size(956, 440));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('INTERMISSION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result overlay renders every outcome', (tester) async {
    for (final outcome in ShowOutcome.values) {
      final game = GameController(
        level: 6,
        unlockedRoles: Roles.unlockedFor(6),
        skinIndex: 0,
      )..start();
      game
        ..score = 24500
        ..beats = 42
        ..scriptsCompleted = 7
        ..spins = 19
        ..bestCombo = 11
        ..outcome = outcome;

      await _pump(
        tester,
        Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              ResultOverlay(
                game: game,
                rewards: const ShowRewards(
                  stars: 3,
                  previousStars: 1,
                  ticketsEarned: 240,
                  unlockedNextLevel: true,
                  newRoles: 1,
                  newBest: true,
                ),
                onRetry: () {},
                onNext: () {},
                onMenu: () {},
              ),
            ],
          ),
        ),
        const Size(667, 375),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'outcome $outcome');
      game.dispose();
    }
  });

  testWidgets('menu navigates into the sub screens', (tester) async {
    await _pump(tester, const MenuScreen(), const Size(956, 440));

    // The backdrop sparkles never stop, so settle by hand.
    for (final label in ['SCENES', 'ROLES', 'TASKS', 'SETTINGS']) {
      await tester.tap(find.widgetWithText(GoldButton, label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: label);
      expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets, reason: label);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }
  });

  testWidgets('wardrobe purchase spends tickets', (tester) async {
    final progress = await _newProgress();
    await _pump(tester, const CollectionScreen(), const Size(956, 440), progress: progress);

    await tester.tap(find.text('JESTER WARDROBE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(progress.ownsSkin(1), isFalse);
    final before = progress.tickets;
    progress.buySkin(1);
    await tester.pump(const Duration(milliseconds: 400));

    expect(progress.ownsSkin(1), isTrue);
    expect(progress.tickets, lessThan(before));
    expect(tester.takeException(), isNull);
  });
}
