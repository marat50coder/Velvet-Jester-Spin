# Velvet Jester Spin

A landscape iOS arcade puzzler built with Flutter. You are the Jester of a circus
theatre: one tap on the central **Spin** hands every object on stage a brand new
role, and your job is to perform the audience script before the hype runs dry.

- Bundle id: `com.velvetjester.spingame`
- Orientation: the game is landscape-only; the loading screen also renders in
  portrait.
- Language: English.
- Fully offline: no network, notification or other runtime permissions.

## Gameplay

The arena is a circular ring of performers — cards, spotlights, instruments,
props and animals. Each one wears a role badge.

- **The script.** The audience asks for a chain of roles. Tap the object wearing
  the demanded role to land a beat; the object then re-rolls into a new role.
- **Spin.** The signature move. Every object is reassigned at once for a small
  hype cost and a short cooldown. Two fruitless spins in a row are quietly
  rescued so the board is never a dead end.
- **Velvet Combo.** Finishing a whole script pays a large bonus, a hype refill
  and a burst of confetti, then a fresh script begins.
- **Jester Madness.** A six beat combo gives part of the ring two roles at once
  and doubles the score for nine seconds.
- **Stage events.** Lights out, a loose lion, the king's visit, confetti rain,
  extra spotlights, a rotating hidden stage and a magic illusion that re-rolls
  the ring on its own.
- **Failure.** The show ends early if hype reaches zero; otherwise it closes with
  a curtain call, or a standing ovation above 75% hype.

14 acts across 7 scenes, 16 roles that unlock as you climb, 16 buyable jester
costumes, daily tasks paying Gold Tickets, and a role encyclopedia.

## Project layout

```
lib/
  core/      palette, sprite index, audio pool, persisted progress
  models/    roles, level table, daily task templates
  game/      stage objects, stage events, the game controller (pure logic)
  widgets/   backdrop, ornaments, role badge, the arena
  screens/   loading, menu, scenes, game, result, collection, tasks, settings
assets/
  sprites/   individual PNGs sliced from the source atlases
```

The controller in `lib/game/game_controller.dart` holds all rules and drives a
`Ticker` from the game screen; every widget layer only reads normalised
positions from it, so the arena scales to any screen size.

## Assets

The source art ships as large transparent atlases in
`assets/Velvet_Jester_Spin_gameplay_assets`. They were sliced once into
individual sprites under `assets/sprites/<atlas>/NN.png` via connected-component
labelling on the alpha channel; only the sliced output is bundled. Sound effects
play through a six-player pool so overlapping cues never cut each other.

## Running

```bash
flutter pub get
flutter run                       # attach a device or simulator
flutter build ios --release       # signed device build
```

App icons are generated from `assets/app_icon/icon_1024.png`:

```bash
dart run flutter_launcher_icons
```

## Tests

`flutter test` covers the two things a device run would otherwise catch by eye:

- `test/screens_test.dart` renders every screen at iPhone SE, iPhone 16 Pro Max
  and iPad sizes in landscape and fails on any overflow or render exception. It
  also drives navigation, the pause and result overlays and a wardrobe purchase.
- `test/game_controller_test.dart` plays whole shows headlessly: scoring, misses,
  spin cooldown, the anti-deadlock guard, velvet combos, madness and both end
  conditions.
