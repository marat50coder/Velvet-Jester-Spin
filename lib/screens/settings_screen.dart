import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../widgets/backdrop.dart';
import '../widgets/ornaments.dart';
import 'web_page_screen.dart';

const _privacyPolicyUrl = 'https://velvetjesterspin.com/privacy-policy.html';
const _supportUrl = 'https://velvetjesterspin.com/support.html';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<GameProgress>();

    return VelvetPage(
      title: 'BACKSTAGE',
      floorIndex: 6,
      child: LayoutBuilder(
        builder: (context, c) {
          final infoWidth = (c.maxWidth * 0.38).clamp(190.0, 300.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: OrnatePanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('PREFERENCES', style: AppText.title(14)),
                      const SizedBox(height: 12),
                      _ToggleRow(
                        icon: Icons.volume_up_rounded,
                        label: 'Sound effects',
                        detail: 'Applause, spins and transformations',
                        value: progress.soundEnabled,
                        onChanged: (v) {
                          progress.setSound(v);
                          if (v) AudioManager.instance.play(Sfx.success, volume: 0.6);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        icon: Icons.vibration_rounded,
                        label: 'Haptics',
                        detail: 'Feel every beat of the show',
                        value: progress.hapticsEnabled,
                        onChanged: (v) {
                          progress.setHaptics(v);
                          if (v) AudioManager.instance.haptic(HapticKind.medium);
                        },
                      ),
                      const Spacer(),
                      GoldButton(
                        label: 'RESET ALL PROGRESS',
                        velvet: true,
                        height: 42,
                        fontSize: 13,
                        icon: Icons.restart_alt_rounded,
                        sfx: Sfx.popupOpen,
                        onTap: () => _confirmReset(context, progress),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: infoWidth,
                child: OrnatePanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          Sprites.jester(Sprites.jesterWand),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'VELVET JESTER SPIN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(15),
                      ),
                      Text('Version 1.0.0', style: AppText.body(11, color: Colors.white54)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GoldButton(
                              label: 'PRIVACY',
                              velvet: true,
                              height: 38,
                              fontSize: 11,
                              icon: Icons.lock_outline_rounded,
                              sfx: Sfx.menuOpen,
                              onTap: () => _openWebPage(
                                context,
                                title: 'PRIVACY POLICY',
                                url: _privacyPolicyUrl,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GoldButton(
                              label: 'SUPPORT',
                              velvet: true,
                              height: 38,
                              fontSize: 11,
                              icon: Icons.help_outline_rounded,
                              sfx: Sfx.menuOpen,
                              onTap: () => _openWebPage(
                                context,
                                title: 'SUPPORT',
                                url: _supportUrl,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openWebPage(BuildContext context, {required String title, required String url}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebPageScreen(title: title, url: url),
      ),
    );
  }

  void _confirmReset(BuildContext context, GameProgress progress) {
    showDialog<void>(
      context: context,
      barrierColor: Palette.ink.withValues(alpha: 0.8),
      builder: (dialogContext) => Center(
        child: SizedBox(
          width: 340,
          child: OrnatePanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            borderColor: Palette.crimsonLight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CLOSE THE SHOW?', style: AppText.title(17, color: Palette.crimsonLight)),
                const SizedBox(height: 8),
                Text(
                  'Every act, role, costume and ticket will be lost. '
                  'The Jester starts from opening night again.',
                  textAlign: TextAlign.center,
                  style: AppText.body(11),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GoldButton(
                        label: 'KEEP',
                        height: 40,
                        fontSize: 13,
                        sfx: Sfx.popupClose,
                        onTap: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GoldButton(
                        label: 'RESET',
                        velvet: true,
                        height: 40,
                        fontSize: 13,
                        sfx: Sfx.failure,
                        onTap: () {
                          progress.resetAll();
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.28),
          border: Border.all(color: Palette.goldDeep.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: value ? Palette.gold : Colors.white38, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(13),
                  ),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(10, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Palette.ink,
              activeTrackColor: Palette.gold,
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Palette.velvetDeep,
            ),
          ],
        ),
      ),
    );
  }
}
