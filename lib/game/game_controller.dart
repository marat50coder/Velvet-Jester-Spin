import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/audio.dart';
import '../core/sprites.dart';
import '../models/levels.dart';
import '../models/roles.dart';
import 'stage_events.dart';
import 'stage_object.dart';

enum GamePhase { countdown, playing, finished }

enum ShowOutcome { ovation, applause, failure }

/// Audience mood ladder driven by the hype meter.
enum AudienceMood { restless, curious, amused, delighted, thrilled, ecstatic }

extension AudienceMoodInfo on AudienceMood {
  String get label => switch (this) {
        AudienceMood.restless => 'RESTLESS',
        AudienceMood.curious => 'CURIOUS',
        AudienceMood.amused => 'AMUSED',
        AudienceMood.delighted => 'DELIGHTED',
        AudienceMood.thrilled => 'THRILLED',
        AudienceMood.ecstatic => 'STANDING OVATION',
      };
}

class GameController extends ChangeNotifier {
  GameController({required this.level, required this.unlockedRoles, required this.skinIndex})
      : config = Levels.byNumber(level);

  final int level;
  final LevelConfig config;

  /// Roles the player has earned so far; the level draws its pool from these.
  final List<Role> unlockedRoles;
  final int skinIndex;

  final math.Random _rng = math.Random();

  // ------------------------------------------------------------------ state
  GamePhase phase = GamePhase.countdown;
  ShowOutcome outcome = ShowOutcome.applause;

  double countdown = 3.2;
  double timeLeft = 0;
  double hype = 0.62;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int beats = 0;
  int scriptsCompleted = 0;
  int spins = 0;
  int misses = 0;

  final List<StageObject> objects = [];
  final List<int> rolePool = [];
  final List<int> script = [];
  int scriptIndex = 0;

  final List<VisualEffect> effects = [];
  final List<FloatingLabel> labels = [];
  final List<Particle> particles = [];

  double ringRotation = 0;
  double _ringSpin = 0;
  double spinCooldown = 0;
  double madnessLeft = 0;
  double _madnessCooldown = 0;
  double screenShake = 0;
  double flashLevel = 0;

  StageEventKind? activeEvent;
  double eventLeft = 0;
  double _eventTimer = 0;
  double _illusionTimer = 0;
  double _bannerLeft = 0;

  int _nextObjectId = 0;
  int _failedSpins = 0;
  int _lastTickSecond = 99;
  double _spinFlourish = 0;

  bool get madness => madnessLeft > 0;

  bool get rolesHidden => activeEvent == StageEventKind.lightsOut;

  bool get doubleScore => activeEvent == StageEventKind.kingArrives;

  double get spinFlourish => _spinFlourish;

  double get bannerLeft => _bannerLeft;

  int get currentDemand => script.isEmpty ? 0 : script[scriptIndex];

  List<int> get upcoming => script.sublist(math.min(scriptIndex + 1, script.length));

  double get scriptProgress => script.isEmpty ? 0 : scriptIndex / script.length;

  bool get flawless => misses == 0;

  int get scoreMultiplier => (madness ? 2 : 1) * (doubleScore ? 2 : 1);

  String get jesterSkin => Sprites.jesterSkin(skinIndex);

  AudienceMood get mood {
    if (hype >= 0.92) return AudienceMood.ecstatic;
    if (hype >= 0.75) return AudienceMood.thrilled;
    if (hype >= 0.58) return AudienceMood.delighted;
    if (hype >= 0.40) return AudienceMood.amused;
    if (hype >= 0.22) return AudienceMood.curious;
    return AudienceMood.restless;
  }

  StageEventInfo? get eventInfo =>
      activeEvent == null ? null : StageEventInfo.of(activeEvent!);

  // ------------------------------------------------------------------ setup
  void start() {
    timeLeft = config.duration.toDouble();
    _buildRolePool();
    _buildObjects();
    _rollScript(initial: true);
    _eventTimer = config.eventInterval * 0.7;
    notifyListeners();
  }

  void _buildRolePool() {
    rolePool.clear();
    final available = List<Role>.from(unlockedRoles);
    final take = math.min(config.rolePoolSize, available.length);
    // Keep the newest roles in play so unlocks feel immediate.
    available.sort((a, b) => b.unlockLevel.compareTo(a.unlockLevel));
    final chosen = available.take(take).map((r) => r.index).toList();
    if (chosen.length < 3) {
      for (final r in Roles.all.take(3)) {
        if (!chosen.contains(r.index)) chosen.add(r.index);
      }
    }
    rolePool.addAll(chosen);
  }

  void _buildObjects() {
    objects.clear();
    final kinds = ObjectKind.values;
    for (var i = 0; i < config.objectCount; i++) {
      objects.add(_makeObject(kinds[i % kinds.length]));
    }
    _layoutRing();
  }

  StageObject _makeObject(ObjectKind kind) {
    final obj = StageObject(
      id: _nextObjectId++,
      kind: kind,
      sprite: kind.spriteFor(_rng.nextInt(64)),
      angle: 0,
      radius: 0.78,
      roleIndex: _randomRole(),
    );
    obj.bobPhase = _rng.nextDouble() * math.pi * 2;
    return obj;
  }

  /// Spreads objects over the ring, alternating radius so nothing overlaps.
  void _layoutRing() {
    final n = objects.length;
    for (var i = 0; i < n; i++) {
      final o = objects[i];
      o.angle = (i / n) * math.pi * 2;
      o.radius = n > 10 ? (i.isEven ? 0.82 : 0.58) : 0.76;
    }
  }

  int _randomRole() => rolePool[_rng.nextInt(rolePool.length)];

  void _rollScript({bool initial = false}) {
    script.clear();
    scriptIndex = 0;
    final length = config.scriptLength;
    var previous = -1;
    for (var i = 0; i < length; i++) {
      var role = _randomRole();
      var guard = 0;
      while (role == previous && rolePool.length > 1 && guard++ < 8) {
        role = _randomRole();
      }
      previous = role;
      script.add(role);
    }
    if (!initial) AudioManager.instance.play(Sfx.newObjective, volume: 0.55);
    _ensureSolvableAfterMisses(force: initial);
  }

  /// The board must never be a dead end forever: after two fruitless spins we
  /// quietly hand one object the demanded role.
  void _ensureSolvableAfterMisses({bool force = false}) {
    if (script.isEmpty) return;
    final demand = currentDemand;
    if (objects.any((o) => o.matches(demand))) {
      _failedSpins = 0;
      return;
    }
    if (force || _failedSpins >= 2) {
      final target = objects[_rng.nextInt(objects.length)];
      target.roleIndex = demand;
      target.flash = 1;
      _failedSpins = 0;
    }
  }

  // ------------------------------------------------------------------- loop
  void tick(double dt) {
    if (phase == GamePhase.finished) {
      _advanceVisuals(dt);
      notifyListeners();
      return;
    }

    if (phase == GamePhase.countdown) {
      countdown -= dt;
      final second = countdown.ceil();
      if (second != _lastTickSecond && second >= 1 && second <= 3) {
        _lastTickSecond = second;
        AudioManager.instance.play(Sfx.tick, volume: 0.6);
      }
      if (countdown <= 0) {
        phase = GamePhase.playing;
        _lastTickSecond = 99;
        AudioManager.instance.play(Sfx.sceneTransition, volume: 0.7);
      }
      _advanceVisuals(dt);
      notifyListeners();
      return;
    }

    timeLeft -= dt;

    var decay = config.hypeDecayPerSecond;
    if (madness) decay *= 0.55;
    hype -= decay * dt;

    if (activeEvent == StageEventKind.hiddenStage) {
      _ringSpin = 0.32;
    }
    ringRotation += _ringSpin * dt;
    _ringSpin *= math.pow(0.02, dt).toDouble();

    if (spinCooldown > 0) spinCooldown = math.max(0, spinCooldown - dt);
    if (madnessLeft > 0) {
      madnessLeft -= dt;
      if (madnessLeft <= 0) _endMadness();
    }
    if (_madnessCooldown > 0) _madnessCooldown -= dt;
    if (_bannerLeft > 0) _bannerLeft -= dt;
    if (_spinFlourish > 0) _spinFlourish = math.max(0, _spinFlourish - dt * 1.6);

    _tickEvents(dt);
    _advanceVisuals(dt);

    final second = timeLeft.ceil();
    if (second <= 5 && second >= 1 && second != _lastTickSecond) {
      _lastTickSecond = second;
      AudioManager.instance.play(Sfx.tick, volume: 0.75);
    }

    if (hype <= 0) {
      hype = 0;
      _finish(ShowOutcome.failure);
    } else if (timeLeft <= 0) {
      timeLeft = 0;
      _finish(hype >= 0.75 ? ShowOutcome.ovation : ShowOutcome.applause);
    }

    notifyListeners();
  }

  void _advanceVisuals(double dt) {
    hype = hype.clamp(0.0, 1.0);
    screenShake = math.max(0, screenShake - dt * 3.2);
    flashLevel = math.max(0, flashLevel - dt * 2.4);

    for (final o in objects) {
      o.flash = math.max(0, o.flash - dt * 2.2);
      o.shake = math.max(0, o.shake - dt * 3.0);
      o.entry = math.min(1, o.entry + dt * 2.6);
      o.bobPhase += dt * 1.4;
    }

    for (final e in effects) {
      e.age += dt;
    }
    effects.removeWhere((e) => e.dead);

    for (final l in labels) {
      l.age += dt;
    }
    labels.removeWhere((l) => l.dead);

    for (final p in particles) {
      p.age += dt;
      p.velocity = Offset(p.velocity.dx * 0.99, p.velocity.dy + 0.9 * dt);
      p.position += p.velocity * dt;
      p.rotation += p.rotationSpeed * dt;
    }
    particles.removeWhere((p) => p.dead);
  }

  // ----------------------------------------------------------------- events
  void _tickEvents(double dt) {
    if (activeEvent != null) {
      eventLeft -= dt;
      if (activeEvent == StageEventKind.magicIllusion) {
        _illusionTimer -= dt;
        if (_illusionTimer <= 0) {
          _illusionTimer = 2.6;
          _rerollAll(announce: true);
        }
      }
      if (eventLeft <= 0) _endEvent();
      return;
    }

    _eventTimer -= dt;
    if (_eventTimer <= 0 && timeLeft > 8) {
      _startEvent();
      _eventTimer = config.eventInterval;
    }
  }

  void _startEvent() {
    final pool = <StageEventKind>[
      StageEventKind.lightsOut,
      StageEventKind.lionAppears,
      StageEventKind.kingArrives,
      StageEventKind.confettiRain,
      StageEventKind.extraSpotlights,
      StageEventKind.hiddenStage,
      StageEventKind.magicIllusion,
    ];
    if (level < 3) {
      pool.removeWhere((e) => e == StageEventKind.lightsOut || e == StageEventKind.magicIllusion);
    }
    final kind = pool[_rng.nextInt(pool.length)];
    final info = StageEventInfo.of(kind);
    activeEvent = kind;
    eventLeft = info.duration;
    _bannerLeft = 2.6;
    AudioManager.instance.play(Sfx.notification, volume: 0.7);

    switch (kind) {
      case StageEventKind.lionAppears:
        _spawnWild();
      case StageEventKind.confettiRain:
        final bonus = 240 * scoreMultiplier;
        score += bonus;
        hype = (hype + 0.16).clamp(0.0, 1.0);
        _burstConfetti(60);
        _pushLabel('+$bonus', Offset.zero, const Color(0xFF7BE8A8), size: 30);
      case StageEventKind.extraSpotlights:
        _spawnExtras(2);
      case StageEventKind.hiddenStage:
        _ringSpin = 0.5;
      case StageEventKind.magicIllusion:
        _illusionTimer = 1.2;
      case StageEventKind.lightsOut:
        flashLevel = 0.6;
      case StageEventKind.kingArrives:
        flashLevel = 0.5;
    }
    notifyListeners();
  }

  void _endEvent() {
    final finished = activeEvent;
    activeEvent = null;
    eventLeft = 0;
    if (finished == StageEventKind.lionAppears) {
      objects.removeWhere((o) => o.wild);
      _layoutRing();
    }
    if (finished == StageEventKind.hiddenStage) {
      _ringSpin = 0;
    }
  }

  void _spawnWild() {
    final wild = StageObject(
      id: _nextObjectId++,
      kind: ObjectKind.animal,
      sprite: Sprites.animal(Sprites.animalPool[_rng.nextInt(2)]),
      angle: 0,
      radius: 0.42,
      roleIndex: currentDemand,
      wild: true,
      temporary: true,
    );
    objects.add(wild);
    _layoutRing();
    // Keep the wild act near the middle so it reads as special.
    wild.radius = 0.34;
    wild.angle = _rng.nextDouble() * math.pi * 2;
  }

  void _spawnExtras(int count) {
    if (objects.length >= 16) return;
    for (var i = 0; i < count; i++) {
      final kind = ObjectKind.values[_rng.nextInt(ObjectKind.values.length)];
      objects.add(_makeObject(kind));
    }
    _layoutRing();
    AudioManager.instance.play(Sfx.unlock, volume: 0.5);
  }

  // ------------------------------------------------------------------ input
  void spin() {
    if (phase != GamePhase.playing || spinCooldown > 0) return;
    spins += 1;
    spinCooldown = 0.42;
    _spinFlourish = 1;
    _ringSpin = 2.6 + _rng.nextDouble() * 1.4;
    hype = (hype - 0.022).clamp(0.0, 1.0);
    screenShake = 0.45;

    final hadMatch = objects.any((o) => o.matches(currentDemand));
    _rerollAll();
    final hasMatch = objects.any((o) => o.matches(currentDemand));
    if (!hasMatch) {
      _failedSpins++;
      _ensureSolvableAfterMisses();
    } else if (!hadMatch) {
      _failedSpins = 0;
    }

    AudioManager.instance.play(Sfx.spin);
    AudioManager.instance.haptic(HapticKind.medium);
    _spawnEffect(
      Sprites.magic(Sprites.magicRings[_rng.nextInt(Sprites.magicRings.length)]),
      Offset.zero,
      0.95,
      life: 0.7,
      startScale: 0.3,
      endScale: 1.8,
      spin: 1.4,
    );
    notifyListeners();
  }

  void _rerollAll({bool announce = false}) {
    for (final o in objects) {
      if (o.wild) continue;
      o.roleIndex = _randomRole();
      o.secondRoleIndex = null;
      o.flash = 1;
    }
    if (madness) {
      final dualCount = (objects.length * 0.4).round();
      final shuffled = List<StageObject>.from(objects)..shuffle(_rng);
      for (final o in shuffled.take(dualCount)) {
        if (o.wild) continue;
        var second = _randomRole();
        var guard = 0;
        while (second == o.roleIndex && rolePool.length > 1 && guard++ < 8) {
          second = _randomRole();
        }
        o.secondRoleIndex = second;
      }
    }
    // A player-driven spin has its own sound; automatic re-rolls need one.
    if (announce) AudioManager.instance.play(Sfx.transform, volume: 0.45);
  }

  void tapObject(StageObject object) {
    if (phase != GamePhase.playing) return;
    final demand = currentDemand;
    if (object.matches(demand)) {
      _hit(object);
    } else {
      _miss(object);
    }
    notifyListeners();
  }

  void _hit(StageObject object) {
    combo += 1;
    beats += 1;
    if (combo > bestCombo) bestCombo = combo;

    final role = Roles.byIndex(currentDemand);
    final base = 90 + combo * 14;
    final gained = (base * scoreMultiplier * (object.wild ? 1.5 : 1.0)).round();
    score += gained;
    hype = (hype + 0.032 + combo * 0.002).clamp(0.0, 1.0);

    final pos = object.unitPosition(ringRotation);
    _spawnEffect(
      Sprites.magic(Sprites.magicBursts[_rng.nextInt(Sprites.magicBursts.length)]),
      pos,
      0.34,
      life: 0.5,
      tint: role.color,
    );
    _spawnEffect(
      Sprites.magic(Sprites.magicSparks[_rng.nextInt(Sprites.magicSparks.length)]),
      pos,
      0.26,
      life: 0.6,
      spin: 2.2,
    );
    _pushLabel('+$gained', pos, role.color);

    object.flash = 1;
    object.roleIndex = _randomRole();
    object.secondRoleIndex = null;
    if (object.wild) {
      objects.remove(object);
      _layoutRing();
    }

    AudioManager.instance.play(combo > 3 ? Sfx.comboUp : Sfx.success, volume: 0.8);
    AudioManager.instance.haptic(HapticKind.light);

    scriptIndex += 1;
    if (scriptIndex >= script.length) {
      _completeScript();
    } else {
      _ensureSolvableAfterMisses();
    }

    if (combo >= 6 && !madness && _madnessCooldown <= 0) _startMadness();
  }

  void _completeScript() {
    scriptsCompleted += 1;
    final bonus = (260 * script.length * (1 + combo * 0.08) * scoreMultiplier).round();
    score += bonus;
    hype = (hype + 0.15).clamp(0.0, 1.0);
    screenShake = 0.7;
    flashLevel = 0.75;

    _pushLabel('VELVET COMBO  +$bonus', const Offset(0, -0.28), const Color(0xFFF4C542), size: 26);
    _burstConfetti(46);
    for (var i = 0; i < 3; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      _spawnEffect(
        Sprites.celebration(Sprites.confettiPoppers[_rng.nextInt(Sprites.confettiPoppers.length)]),
        Offset(math.cos(a) * 0.55, math.sin(a) * 0.55),
        0.34,
        life: 0.85,
        drift: Offset(math.cos(a) * 0.25, math.sin(a) * 0.25),
      );
    }
    AudioManager.instance.play(Sfx.bigCombo);
    AudioManager.instance.play(Sfx.applause, volume: 0.55);
    AudioManager.instance.haptic(HapticKind.heavy);

    _rollScript();
  }

  void _miss(StageObject object) {
    combo = 0;
    misses += 1;
    hype = (hype - 0.085).clamp(0.0, 1.0);
    object.shake = 1;
    screenShake = 0.5;
    final pos = object.unitPosition(ringRotation);
    _pushLabel('MISS', pos, const Color(0xFFFF6B8A), size: 18);
    _spawnEffect(
      Sprites.magic(Sprites.magicPortals[_rng.nextInt(Sprites.magicPortals.length)]),
      pos,
      0.28,
      life: 0.45,
      startScale: 1.0,
      endScale: 0.4,
    );
    AudioManager.instance.play(Sfx.failure, volume: 0.45);
    AudioManager.instance.haptic(HapticKind.medium);
  }

  // ---------------------------------------------------------------- madness
  void _startMadness() {
    madnessLeft = 9;
    flashLevel = 0.85;
    screenShake = 0.6;
    _bannerLeft = 2.2;
    final dualCount = (objects.length * 0.4).round();
    final shuffled = List<StageObject>.from(objects)..shuffle(_rng);
    for (final o in shuffled.take(dualCount)) {
      if (o.wild) continue;
      var second = _randomRole();
      var guard = 0;
      while (second == o.roleIndex && rolePool.length > 1 && guard++ < 8) {
        second = _randomRole();
      }
      o.secondRoleIndex = second;
      o.flash = 1;
    }
    AudioManager.instance.play(Sfx.unlock);
    AudioManager.instance.haptic(HapticKind.heavy);
  }

  void _endMadness() {
    madnessLeft = 0;
    _madnessCooldown = 12;
    for (final o in objects) {
      o.secondRoleIndex = null;
    }
  }

  // ---------------------------------------------------------------- effects
  void _spawnEffect(
    String sprite,
    Offset position,
    double size, {
    double life = 0.6,
    double spin = 0,
    Offset drift = Offset.zero,
    double startScale = 0.4,
    double endScale = 1.4,
    Color? tint,
  }) {
    effects.add(
      VisualEffect(
        sprite: sprite,
        position: position,
        size: size,
        life: life,
        spin: spin,
        drift: drift,
        startScale: startScale,
        endScale: endScale,
        tint: tint,
      ),
    );
  }

  void _pushLabel(String text, Offset position, Color color, {double size = 20}) {
    labels.add(FloatingLabel(text: text, position: position, color: color, size: size));
  }

  void _burstConfetti(int count) {
    const palette = [
      Color(0xFFF4C542),
      Color(0xFFE04FCF),
      Color(0xFF56D8F5),
      Color(0xFF7BE8A8),
      Color(0xFFFF6B8A),
      Color(0xFFFFE9A8),
    ];
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 0.5 + _rng.nextDouble() * 1.1;
      particles.add(
        Particle(
          position: Offset(
            (_rng.nextDouble() - 0.5) * 0.4,
            (_rng.nextDouble() - 0.5) * 0.4,
          ),
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed - 0.5),
          color: palette[_rng.nextInt(palette.length)],
          size: 0.012 + _rng.nextDouble() * 0.016,
          life: 1.1 + _rng.nextDouble() * 0.9,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 12,
        ),
      );
    }
  }

  // ----------------------------------------------------------------- finish
  void _finish(ShowOutcome result) {
    if (phase == GamePhase.finished) return;
    phase = GamePhase.finished;
    outcome = result;
    _endMadness();
    activeEvent = null;
    if (result == ShowOutcome.failure) {
      AudioManager.instance.play(Sfx.failure);
    } else {
      AudioManager.instance.play(Sfx.levelComplete);
      AudioManager.instance.play(Sfx.applause, volume: 0.8);
      _burstConfetti(110);
    }
  }

  void abandon() {
    phase = GamePhase.finished;
    outcome = ShowOutcome.failure;
  }
}
