import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/roles.dart';

/// Circular medallion showing a role icon. Used on stage, in the script strip
/// and inside the encyclopedia.
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    required this.size,
    this.hidden = false,
    this.dimmed = false,
    this.highlight = false,
    this.locked = false,
  });

  final Role role;
  final double size;
  final bool hidden;
  final bool dimmed;
  final bool highlight;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: highlight
            ? [BoxShadow(color: role.color.withValues(alpha: 0.75), blurRadius: size * 0.35)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: size * 0.12)],
      ),
      child: hidden
          ? _HiddenFace(size: size)
          : ColorFiltered(
              colorFilter: locked
                  ? const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Opacity(
                opacity: dimmed ? 0.45 : 1,
                child: Image.asset(
                  role.icon,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 3).round(),
                ),
              ),
            ),
    );
  }
}

class _HiddenFace extends StatelessWidget {
  const _HiddenFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Palette.velvetLight, Palette.velvetDeep]),
        border: Border.all(color: Palette.goldDeep, width: size * 0.06),
      ),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: Palette.gold.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
