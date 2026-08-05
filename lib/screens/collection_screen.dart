import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/audio.dart';
import '../core/palette.dart';
import '../core/sprites.dart';
import '../core/storage.dart';
import '../models/roles.dart';
import '../widgets/backdrop.dart';
import '../widgets/ornaments.dart';
import '../widgets/role_badge.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int _tab = 0;
  int _selectedRole = 0;
  int _selectedSkin = 0;

  @override
  void initState() {
    super.initState();
    _selectedSkin = context.read<GameProgress>().selectedSkin;
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<GameProgress>();

    return VelvetPage(
      title: 'THE COLLECTION',
      floorIndex: 4,
      trailing: _TicketChip(tickets: progress.tickets),
      child: Column(
        children: [
          _Segmented(
            index: _tab,
            labels: const ['ROLE ENCYCLOPEDIA', 'JESTER WARDROBE'],
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tab == 0
                ? _RolesTab(
                    progress: progress,
                    selected: _selectedRole,
                    onSelect: (i) => setState(() => _selectedRole = i),
                  )
                : _WardrobeTab(
                    progress: progress,
                    selected: _selectedSkin,
                    onSelect: (i) => setState(() => _selectedSkin = i),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.labels, required this.onChanged});

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Palette.velvetDeep.withValues(alpha: 0.8),
          border: Border.all(color: Palette.goldDeep, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: () {
                  AudioManager.instance.tap();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: i == index ? Palette.buttonGold : null,
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.label(
                      11,
                      color: i == index ? Palette.ink : Palette.goldPale.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketChip extends StatelessWidget {
  const _TicketChip({required this.tickets});

  final int tickets;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      radius: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.confirmation_number_rounded, size: 15, color: Palette.gold),
          const SizedBox(width: 5),
          Text('$tickets', style: AppText.numeric(14)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- roles
class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.progress, required this.selected, required this.onSelect});

  final GameProgress progress;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final role = Roles.byIndex(selected);
    final unlocked = role.unlockLevel <= progress.highestLevelUnlocked;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: OrnatePanel(
            padding: const EdgeInsets.all(10),
            opacity: 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('DISCOVERED', style: AppText.label(10, color: Colors.white60)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MeterBar(
                        value: progress.collectionPercent,
                        height: 9,
                        gradient: Palette.goldBar,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.collectedRoles}/${Roles.all.length}',
                      style: AppText.numeric(12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 74,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: Roles.all.length,
                    itemBuilder: (context, i) {
                      final r = Roles.all[i];
                      final open = r.unlockLevel <= progress.highestLevelUnlocked;
                      return GestureDetector(
                        onTap: () {
                          AudioManager.instance.play(
                            open ? Sfx.hover : Sfx.popupClose,
                            volume: 0.6,
                          );
                          onSelect(i);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: i == selected
                                ? Palette.plum.withValues(alpha: 0.55)
                                : Colors.black.withValues(alpha: 0.24),
                            border: Border.all(
                              color: i == selected ? Palette.gold : Colors.white12,
                              width: i == selected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: RoleBadge(
                                  role: r,
                                  size: 44,
                                  locked: !open,
                                  dimmed: !open,
                                ),
                              ),
                              Text(
                                open ? r.name : 'ACT ${r.unlockLevel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.label(
                                  7.5,
                                  color: open ? Palette.goldPale : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 250,
          child: OrnatePanel(
            padding: const EdgeInsets.all(12),
            borderColor: unlocked ? role.color : Palette.goldDeep,
            glowColor: unlocked ? role.color : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RoleBadge(role: role, size: 84, locked: !unlocked, highlight: unlocked),
                const SizedBox(height: 8),
                Text(
                  unlocked ? role.name : 'LOCKED ROLE',
                  textAlign: TextAlign.center,
                  style: AppText.title(17, color: unlocked ? role.color : Colors.white54),
                ),
                Text(
                  unlocked ? role.tagline : 'Reach Act ${role.unlockLevel} to reveal',
                  textAlign: TextAlign.center,
                  style: AppText.body(11, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      unlocked
                          ? role.description
                          : 'The Jester keeps this one behind the curtain until the crowd is ready.',
                      textAlign: TextAlign.center,
                      style: AppText.body(11),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: Palette.goldDeep.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    'UNLOCKS AT ACT ${role.unlockLevel}',
                    style: AppText.label(9.5, color: Palette.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- wardrobe
class _WardrobeTab extends StatelessWidget {
  const _WardrobeTab({required this.progress, required this.selected, required this.onSelect});

  final GameProgress progress;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final owned = progress.ownsSkin(selected);
    final price = kSkinPrices[selected];
    final equipped = progress.selectedSkin == selected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: OrnatePanel(
            padding: const EdgeInsets.all(10),
            opacity: 0.8,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 92,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.78,
              ),
              itemCount: Sprites.jesterSkinCount,
              itemBuilder: (context, i) {
                final isOwned = progress.ownsSkin(i);
                return GestureDetector(
                  onTap: () {
                    AudioManager.instance.play(Sfx.hover, volume: 0.6);
                    onSelect(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: i == selected
                          ? Palette.plum.withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.24),
                      border: Border.all(
                        color: i == selected ? Palette.gold : Colors.white12,
                        width: i == selected ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Opacity(
                            opacity: isOwned ? 1 : 0.55,
                            child: Image.asset(
                              Sprites.jesterSkin(i),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: 180,
                            ),
                          ),
                        ),
                        if (progress.selectedSkin == i)
                          Text('EQUIPPED', style: AppText.label(7.5, color: Palette.gold))
                        else if (isOwned)
                          Text('OWNED', style: AppText.label(7.5, color: Colors.white54))
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.confirmation_number_rounded,
                                size: 10,
                                color: Palette.gold,
                              ),
                              const SizedBox(width: 3),
                              Text('${kSkinPrices[i]}', style: AppText.label(8)),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 250,
          child: OrnatePanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: Image.asset(
                    Sprites.jesterSkin(selected),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kSkinNames[selected].toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(15),
                ),
                Text(
                  'Costume ${selected + 1} of ${Sprites.jesterSkinCount}',
                  style: AppText.body(10, color: Colors.white54),
                ),
                const SizedBox(height: 10),
                if (equipped)
                  GoldButton(
                    label: 'ON STAGE',
                    width: double.infinity,
                    height: 42,
                    fontSize: 14,
                    enabled: false,
                    onTap: () {},
                  )
                else if (owned)
                  GoldButton(
                    label: 'WEAR THIS',
                    width: double.infinity,
                    height: 42,
                    fontSize: 14,
                    sfx: Sfx.reward,
                    onTap: () => progress.selectSkin(selected),
                  )
                else
                  GoldButton(
                    label: 'BUY  ·  $price',
                    width: double.infinity,
                    height: 42,
                    fontSize: 14,
                    icon: Icons.confirmation_number_rounded,
                    enabled: progress.tickets >= price,
                    sfx: Sfx.unlock,
                    onTap: () {
                      if (progress.buySkin(selected)) {
                        AudioManager.instance.play(Sfx.reward);
                      }
                    },
                  ),
                if (!owned && progress.tickets < price) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Earn ${price - progress.tickets} more tickets',
                    style: AppText.body(10, color: Palette.crimsonLight),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
