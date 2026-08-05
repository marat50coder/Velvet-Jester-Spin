import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sprites.dart';
import 'ornaments.dart';

/// Shared theatre backdrop: a blurred arena floor, hanging curtains and a
/// drifting sparkle layer.
class VelvetBackdrop extends StatelessWidget {
  const VelvetBackdrop({
    super.key,
    required this.child,
    this.floorIndex = 1,
    this.blur = 9,
    this.dim = 0.62,
    this.showCurtains = true,
  });

  final Widget child;
  final int floorIndex;
  final double blur;
  final double dim;
  final bool showCurtains;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Image.asset(
            Sprites.stageFloors[floorIndex % Sprites.stageFloors.length],
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [
                Palette.velvetDeep.withValues(alpha: dim * 0.6),
                Palette.velvetDeep.withValues(alpha: dim + 0.28),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        if (showCurtains) ...[
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 1.0,
              child: Image.asset(
                Sprites.decoration(0),
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Opacity(
              opacity: 0.75,
              child: Image.asset(
                Sprites.decoration(36),
                height: 150,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Opacity(
              opacity: 0.75,
              child: Transform.flip(
                flipX: true,
                child: Image.asset(
                  Sprites.decoration(36),
                  height: 150,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),
        ],
        const SparkleField(count: 30),
        child,
      ],
    );
  }
}

/// Standard landscape page shell: back button, title plaque and a body slot.
class VelvetPage extends StatelessWidget {
  const VelvetPage({
    super.key,
    required this.title,
    required this.child,
    this.floorIndex = 1,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget child;
  final int floorIndex;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.velvetDeep,
      body: VelvetBackdrop(
        floorIndex: floorIndex,
        showCurtains: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 38,
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(21),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
