import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_tasks.dart';
import '../models/levels.dart';
import '../models/roles.dart';
import 'audio.dart';

/// Prices for the jester wardrobe. Index 0 is the starting costume.
const kSkinPrices = <int>[0, 60, 80, 100, 120, 140, 160, 190, 220, 250, 280, 320, 360, 420, 480, 560];

const kSkinNames = <String>[
  'Crimson Herald',
  'Royal Ivory',
  'Amethyst Veil',
  'Sapphire Facet',
  'Emerald Court',
  'Ruby Baron',
  'Frostbound',
  'Ember Grin',
  'Prism Dancer',
  'Bronze Automaton',
  'Pearl Regalia',
  'Obsidian Duke',
  'Golden Sovereign',
  'Peacock Masque',
  'Midnight Star',
  'Carnival King',
];

class GameProgress extends ChangeNotifier {
  GameProgress(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  int highestLevelUnlocked = 1;
  int tickets = 0;
  Map<int, int> levelStars = {};
  Map<int, int> levelBest = {};
  int bestScore = 0;
  int longestCombo = 0;
  int totalShows = 0;
  int totalBeats = 0;
  int totalCombos = 0;
  int totalOvations = 0;
  int totalSpins = 0;
  Set<int> ownedSkins = {0};
  int selectedSkin = 0;
  bool soundEnabled = true;
  bool hapticsEnabled = true;

  int _taskDay = 0;
  Map<String, int> _taskProgress = {};
  Set<String> _taskClaimed = {};

  // ------------------------------------------------------------------ load
  void _load() {
    highestLevelUnlocked = _prefs.getInt('highestLevel') ?? 1;
    tickets = _prefs.getInt('tickets') ?? 0;
    bestScore = _prefs.getInt('bestScore') ?? 0;
    longestCombo = _prefs.getInt('longestCombo') ?? 0;
    totalShows = _prefs.getInt('totalShows') ?? 0;
    totalBeats = _prefs.getInt('totalBeats') ?? 0;
    totalCombos = _prefs.getInt('totalCombos') ?? 0;
    totalOvations = _prefs.getInt('totalOvations') ?? 0;
    totalSpins = _prefs.getInt('totalSpins') ?? 0;
    selectedSkin = _prefs.getInt('selectedSkin') ?? 0;
    soundEnabled = _prefs.getBool('soundEnabled') ?? true;
    hapticsEnabled = _prefs.getBool('hapticsEnabled') ?? true;
    levelStars = _decodeIntMap(_prefs.getString('levelStars'));
    levelBest = _decodeIntMap(_prefs.getString('levelBest'));
    ownedSkins = (_prefs.getStringList('ownedSkins') ?? ['0'])
        .map(int.parse)
        .toSet()
      ..add(0);
    _taskDay = _prefs.getInt('taskDay') ?? 0;
    _taskProgress = _decodeStringMap(_prefs.getString('taskProgress'));
    _taskClaimed = (_prefs.getStringList('taskClaimed') ?? const <String>[]).toSet();

    AudioManager.instance.soundEnabled = soundEnabled;
    AudioManager.instance.hapticsEnabled = hapticsEnabled;
    _rolloverTasksIfNeeded();
  }

  Map<int, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }

  Map<String, int> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ----------------------------------------------------------------- tasks
  static int todayKey() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  void _rolloverTasksIfNeeded() {
    final today = todayKey();
    if (_taskDay != today) {
      _taskDay = today;
      _taskProgress = {};
      _taskClaimed = {};
      _prefs.setInt('taskDay', _taskDay);
      _prefs.setString('taskProgress', jsonEncode(_taskProgress));
      _prefs.setStringList('taskClaimed', const []);
    }
  }

  List<TaskTemplate> get todayTasks => DailyTasks.forDay(_taskDay);

  int taskProgress(TaskTemplate t) => (_taskProgress[t.id] ?? 0).clamp(0, t.target);

  bool taskComplete(TaskTemplate t) => taskProgress(t) >= t.target;

  bool taskClaimed(TaskTemplate t) => _taskClaimed.contains(t.id);

  bool get hasClaimableTask =>
      todayTasks.any((t) => taskComplete(t) && !taskClaimed(t));

  void claimTask(TaskTemplate t) {
    if (!taskComplete(t) || taskClaimed(t)) return;
    _taskClaimed.add(t.id);
    tickets += t.reward;
    _prefs.setStringList('taskClaimed', _taskClaimed.toList());
    _prefs.setInt('tickets', tickets);
    notifyListeners();
  }

  void _bumpTask(TaskMetric metric, int amount, {bool absolute = false}) {
    for (final t in todayTasks) {
      if (t.metric != metric) continue;
      final current = _taskProgress[t.id] ?? 0;
      _taskProgress[t.id] = absolute ? (amount > current ? amount : current) : current + amount;
    }
  }

  // --------------------------------------------------------------- results
  /// Records the outcome of a finished performance and returns what changed.
  ShowRewards recordShow({
    required int level,
    required int score,
    required int beats,
    required int combos,
    required int spins,
    required int bestCombo,
    required bool ovation,
    required bool survived,
    required bool flawless,
  }) {
    _rolloverTasksIfNeeded();

    totalShows += 1;
    totalBeats += beats;
    totalCombos += combos;
    totalSpins += spins;
    if (ovation) totalOvations += 1;
    if (bestCombo > longestCombo) longestCombo = bestCombo;
    if (score > bestScore) bestScore = score;

    final previousBest = levelBest[level] ?? 0;
    if (score > previousBest) levelBest[level] = score;

    final config = Levels.byNumber(level);
    var stars = 0;
    if (survived) {
      for (final target in config.starTargets) {
        if (score >= target) stars++;
      }
      if (stars == 0) stars = 1;
    }
    final previousStars = levelStars[level] ?? 0;
    final improved = stars > previousStars;
    if (improved) levelStars[level] = stars;

    final rolesBefore = Roles.unlockedCountFor(highestLevelUnlocked);
    var unlockedLevel = false;
    if (survived && level == highestLevelUnlocked && level < Levels.count) {
      highestLevelUnlocked = level + 1;
      unlockedLevel = true;
    }
    final newRoles = Roles.unlockedCountFor(highestLevelUnlocked) - rolesBefore;

    final earned = survived ? (10 + score ~/ 120 + stars * 12) : (score ~/ 260);
    tickets += earned;

    _bumpTask(TaskMetric.shows, 1);
    _bumpTask(TaskMetric.beats, beats);
    _bumpTask(TaskMetric.combos, combos);
    _bumpTask(TaskMetric.spins, spins);
    if (ovation) _bumpTask(TaskMetric.ovations, 1);
    if (flawless && survived) _bumpTask(TaskMetric.perfectShow, 1);
    _bumpTask(TaskMetric.bestCombo, bestCombo, absolute: true);

    _persist();
    notifyListeners();

    return ShowRewards(
      stars: stars,
      previousStars: previousStars,
      ticketsEarned: earned,
      unlockedNextLevel: unlockedLevel,
      newRoles: newRoles,
      newBest: score > previousBest,
    );
  }

  // ---------------------------------------------------------------- skins
  bool ownsSkin(int index) => ownedSkins.contains(index);

  bool buySkin(int index) {
    if (ownsSkin(index)) return false;
    final price = kSkinPrices[index];
    if (tickets < price) return false;
    tickets -= price;
    ownedSkins.add(index);
    selectedSkin = index;
    _persist();
    notifyListeners();
    return true;
  }

  void selectSkin(int index) {
    if (!ownsSkin(index)) return;
    selectedSkin = index;
    _prefs.setInt('selectedSkin', index);
    notifyListeners();
  }

  // -------------------------------------------------------------- settings
  void setSound(bool value) {
    soundEnabled = value;
    AudioManager.instance.soundEnabled = value;
    _prefs.setBool('soundEnabled', value);
    notifyListeners();
  }

  void setHaptics(bool value) {
    hapticsEnabled = value;
    AudioManager.instance.hapticsEnabled = value;
    _prefs.setBool('hapticsEnabled', value);
    notifyListeners();
  }

  void resetAll() {
    highestLevelUnlocked = 1;
    tickets = 0;
    levelStars = {};
    levelBest = {};
    bestScore = 0;
    longestCombo = 0;
    totalShows = 0;
    totalBeats = 0;
    totalCombos = 0;
    totalOvations = 0;
    totalSpins = 0;
    ownedSkins = {0};
    selectedSkin = 0;
    _taskProgress = {};
    _taskClaimed = {};
    _persist();
    _prefs.setStringList('taskClaimed', const []);
    notifyListeners();
  }

  int get collectedRoles => Roles.unlockedCountFor(highestLevelUnlocked);

  double get collectionPercent => collectedRoles / Roles.all.length;

  int get totalStars => levelStars.values.fold(0, (a, b) => a + b);

  void _persist() {
    _prefs
      ..setInt('highestLevel', highestLevelUnlocked)
      ..setInt('tickets', tickets)
      ..setInt('bestScore', bestScore)
      ..setInt('longestCombo', longestCombo)
      ..setInt('totalShows', totalShows)
      ..setInt('totalBeats', totalBeats)
      ..setInt('totalCombos', totalCombos)
      ..setInt('totalOvations', totalOvations)
      ..setInt('totalSpins', totalSpins)
      ..setInt('selectedSkin', selectedSkin)
      ..setString('levelStars', jsonEncode(levelStars.map((k, v) => MapEntry('$k', v))))
      ..setString('levelBest', jsonEncode(levelBest.map((k, v) => MapEntry('$k', v))))
      ..setStringList('ownedSkins', ownedSkins.map((e) => '$e').toList())
      ..setString('taskProgress', jsonEncode(_taskProgress));
  }
}

class ShowRewards {
  const ShowRewards({
    required this.stars,
    required this.previousStars,
    required this.ticketsEarned,
    required this.unlockedNextLevel,
    required this.newRoles,
    required this.newBest,
  });

  final int stars;
  final int previousStars;
  final int ticketsEarned;
  final bool unlockedNextLevel;
  final int newRoles;
  final bool newBest;
}
