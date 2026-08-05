import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx {
  applause('Applause_Burst_asset.mp3'),
  bigCombo('Big_Combo_asset.mp3'),
  click('Button_Click_asset.mp3'),
  hover('Button_Hover_asset.mp3'),
  comboUp('Combo_Increase_asset.mp3'),
  tick('Countdown_Tick_asset.mp3'),
  failure('Failure_asset.mp3'),
  levelComplete('Level_Complete_asset.mp3'),
  transform('Magical_Transformation_asset.mp3'),
  menuClose('Menu_Close_asset.mp3'),
  menuOpen('Menu_Open_asset.mp3'),
  newObjective('New_Objective_asset.mp3'),
  notification('Notification_asset.mp3'),
  popupClose('Popup_Close_asset.mp3'),
  popupOpen('Popup_Open_asset.mp3'),
  reward('Reward_Collect_asset.mp3'),
  sceneTransition('Scene_Transition_asset.mp3'),
  spin('Spin_Activation_asset.mp3'),
  success('Success_asset.mp3'),
  unlock('Unlock_asset.mp3');

  const Sfx(this.file);

  final String file;

  String get path => 'Velvet_Jester_Spin_sounds_assets/$file';
}

/// Small round-robin pool of players so overlapping cues never cut each other.
class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  static const _poolSize = 6;
  final List<AudioPlayer> _pool = [];
  int _cursor = 0;
  bool _ready = false;

  bool soundEnabled = true;
  bool hapticsEnabled = true;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      for (var i = 0; i < _poolSize; i++) {
        final player = AudioPlayer(playerId: 'vjs_$i');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _pool.add(player);
      }
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  void play(Sfx sfx, {double volume = 1.0}) {
    if (!soundEnabled || _pool.isEmpty) return;
    final player = _pool[_cursor];
    _cursor = (_cursor + 1) % _pool.length;
    unawaited(_playOn(player, sfx, volume));
  }

  Future<void> _playOn(AudioPlayer player, Sfx sfx, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(sfx.path));
    } catch (e) {
      debugPrint('Audio play failed (${sfx.file}): $e');
    }
  }

  void tap() {
    play(Sfx.click, volume: 0.7);
    haptic(HapticKind.light);
  }

  void haptic(HapticKind kind) {
    if (!hapticsEnabled) return;
    switch (kind) {
      case HapticKind.light:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case HapticKind.select:
        HapticFeedback.selectionClick();
    }
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
    _pool.clear();
    _ready = false;
  }
}

enum HapticKind { light, medium, heavy, select }

void unawaited(Future<void> future) {
  future.catchError((Object e) => debugPrint('Unawaited audio error: $e'));
}
