import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/palette.dart';

/// Velvet panel with a double gold rule - the game's default container.
class OrnatePanel extends StatelessWidget {
  const OrnatePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.tint,
    this.borderColor = Palette.gold,
    this.glowColor,
    this.opacity = 0.92,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final Color borderColor;
  final Color? glowColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tint ?? Palette.velvetLight).withValues(alpha: opacity),
            (tint ?? Palette.velvetDeep).withValues(alpha: opacity),
          ],
        ),
        border: Border.all(color: borderColor.withValues(alpha: 0.85), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? Colors.black).withValues(alpha: glowColor == null ? 0.45 : 0.35),
            blurRadius: glowColor == null ? 14 : 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(2.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - 4),
            border: Border.all(color: borderColor.withValues(alpha: 0.32), width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Primary call-to-action styled as an embossed gold plaque.
class GoldButton extends StatefulWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 52,
    this.width,
    this.fontSize = 18,
    this.enabled = true,
    this.velvet = false,
    this.sfx,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double height;
  final double? width;
  final double fontSize;
  final bool enabled;
  final bool velvet;
  final Sfx? sfx;

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              AudioManager.instance.play(widget.sfx ?? Sfx.click, volume: 0.75);
              AudioManager.instance.haptic(HapticKind.light);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.955 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: EdgeInsets.symmetric(horizontal: widget.height * 0.42),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height * 0.32),
              gradient: widget.velvet ? Palette.buttonVelvet : Palette.buttonGold,
              border: Border.all(
                color: widget.velvet ? Palette.gold : Palette.goldDeep,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.velvet ? Palette.plum : Palette.gold).withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.fontSize * 1.15,
                    color: widget.velvet ? Palette.goldPale : Palette.ink,
                  ),
                  SizedBox(width: widget.fontSize * 0.45),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: widget.fontSize * 0.08,
                      color: widget.velvet ? Palette.goldPale : Palette.ink,
                      shadows: widget.velvet
                          ? const [Shadow(color: Colors.black87, blurRadius: 4)]
                          : const [Shadow(color: Color(0x55FFFFFF), blurRadius: 1)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact circular button used for back / settings / pause.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.color = Palette.gold,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color color;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioManager.instance.tap();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Palette.buttonVelvet,
              border: Border.all(color: color, width: 1.6),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: Icon(icon, size: size * 0.52, color: color),
          ),
          if (badge)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  color: Palette.crimsonLight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal meter with a gold frame; used for hype, loading and progress.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.height = 14,
    this.gradient = Palette.hypeBar,
    this.background = const Color(0xAA1B0620),
    this.showSheen = true,
    this.radiusFactor = 0.5,
  });

  final double value;
  final double height;
  final Gradient gradient;
  final Color background;
  final bool showSheen;
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * radiusFactor);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border.all(color: Palette.goldDeep.withValues(alpha: 0.9), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
                child: showSheen
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.42,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slowly drifting sparkles behind menu content.
class SparkleField extends StatefulWidget {
  const SparkleField({super.key, this.count = 26, this.color = Palette.gold});

  final int count;
  final Color color;

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _sparks = List.generate(
      widget.count,
      (i) => _Spark(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.2 + rng.nextDouble() * 2.8,
        phase: rng.nextDouble(),
        speed: 0.25 + rng.nextDouble() * 0.6,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _SparkPainter(_sparks, _c.value, widget.color), size: Size.infinite),
      ),
    );
  }
}

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks, this.t, this.color);

  final List<_Spark> sparks;
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final s in sparks) {
      final progress = (t * s.speed + s.phase) % 1.0;
      final y = (s.y - progress * 0.35) % 1.0;
      final alpha = (math.sin(progress * math.pi * 2) * 0.5 + 0.5) * 0.7;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(s.x * size.width, y * size.height), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.t != t;
}
