import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sprites.dart';
import '../game/game_controller.dart';
import '../game/stage_events.dart';
import '../game/stage_object.dart';
import '../models/roles.dart';
import 'role_badge.dart';

/// The circular circus ring: floor, performers, the Spin pedestal and all the
/// transient effect layers.
class StageArena extends StatelessWidget {
  const StageArena({super.key, required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final r = size / 2;
        final ringRadius = r * 0.78;
        final objectSize = size * 0.155;
        final pedestal = size * 0.26;

        return AnimatedBuilder(
          animation: game,
          builder: (context, _) {
            final shake = game.screenShake;
            final dx = shake == 0 ? 0.0 : (math.Random().nextDouble() - 0.5) * shake * 10;
            final dy = shake == 0 ? 0.0 : (math.Random().nextDouble() - 0.5) * shake * 10;

            // Center keeps the arena a true square: without it the SizedBox
            // inherits the wide, tight constraints of the Expanded column and
            // stretches, pushing the ring of objects (laid out from the
            // top-left corner) off the centred floor and Spin pedestal.
            return Center(
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _Floor(game: game, size: size),
                      _Particles(game: game, size: size),
                      ...game.objects.map(
                        (o) => _StageObjectView(
                          key: ValueKey(o.id),
                          game: game,
                          object: o,
                          center: r,
                          ringRadius: ringRadius,
                          baseSize: objectSize,
                        ),
                      ),
                      _SpinPedestal(game: game, size: pedestal),
                      ..._effects(r),
                      ..._labels(r),
                      if (game.phase == GamePhase.countdown) _Countdown(game: game, size: size),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _effects(double r) {
    return game.effects.map((e) {
      final t = e.t;
      final scale = e.startScale + (e.endScale - e.startScale) * Curves.easeOutCubic.transform(t);
      final opacity = t < 0.25 ? t / 0.25 : (1 - (t - 0.25) / 0.75).clamp(0.0, 1.0);
      final pos = e.position + e.drift * t;
      final side = e.size * r * 2;
      return Positioned(
        left: r + pos.dx * r - side / 2,
        top: r + pos.dy * r - side / 2,
        width: side,
        height: side,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: e.spin * t * math.pi,
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  e.sprite,
                  fit: BoxFit.contain,
                  color: e.tint?.withValues(alpha: 0.35),
                  colorBlendMode: e.tint == null ? null : BlendMode.plus,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _labels(double r) {
    return game.labels.map((l) {
      final t = l.t;
      final rise = 34.0 * Curves.easeOutCubic.transform(t);
      return Positioned(
        left: r + l.position.dx * r - 110,
        top: r + l.position.dy * r - 14 - rise,
        width: 220,
        child: IgnorePointer(
          child: Opacity(
            opacity: (1 - t * t).clamp(0.0, 1.0),
            child: Text(
              l.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: l.size,
                fontWeight: FontWeight.w900,
                color: l.color,
                letterSpacing: 1,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _Floor extends StatelessWidget {
  const _Floor({required this.game, required this.size});

  final GameController game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final madness = game.madness;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (madness ? Palette.magenta : Palette.gold).withValues(alpha: 0.35),
                  blurRadius: size * 0.09,
                  spreadRadius: size * 0.005,
                ),
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: size * 0.06),
              ],
            ),
          ),
          ClipOval(
            child: Transform.rotate(
              angle: game.ringRotation * 0.35,
              child: SizedBox(
                width: size,
                height: size,
                child: Image.asset(
                  game.config.scene.floor,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 2).round(),
                ),
              ),
            ),
          ),
          // Vignette keeps the performers readable against busy floors.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          if (game.rolesHidden)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.velvetDeep.withValues(alpha: 0.55),
              ),
            ),
          if (madness)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Palette.magenta.withValues(alpha: 0.0),
                    Palette.magenta.withValues(alpha: 0.28),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          if (game.flashLevel > 0)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: game.flashLevel * 0.35),
              ),
            ),
          // Gold rim.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Palette.gold.withValues(alpha: 0.9), width: size * 0.012),
            ),
          ),
          Container(
            width: size * 0.965,
            height: size * 0.965,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Palette.goldPale.withValues(alpha: 0.35), width: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageObjectView extends StatelessWidget {
  const _StageObjectView({
    super.key,
    required this.game,
    required this.object,
    required this.center,
    required this.ringRadius,
    required this.baseSize,
  });

  final GameController game;
  final StageObject object;
  final double center;
  final double ringRadius;
  final double baseSize;

  @override
  Widget build(BuildContext context) {
    final unit = object.unitPosition(game.ringRotation);
    final bob = math.sin(object.bobPhase) * baseSize * 0.035;
    final shakeOffset = object.shake == 0
        ? 0.0
        : math.sin(object.shake * 34) * baseSize * 0.12 * object.shake;
    final size = baseSize * object.kind.scale;
    final entry = Curves.easeOutBack.transform(object.entry.clamp(0.0, 1.0));
    final role = Roles.byIndex(object.roleIndex);
    final isDemand = object.matches(game.currentDemand) && !game.rolesHidden;
    final badgeSize = size * 0.44;

    return Positioned(
      left: center + unit.dx * ringRadius - size / 2 + shakeOffset,
      top: center + unit.dy * ringRadius - size / 2 + bob,
      width: size,
      height: size,
      child: Transform.scale(
        scale: entry * (1 + object.flash * 0.14),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => game.tapObject(object),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isDemand)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: role.color.withValues(alpha: 0.55),
                        blurRadius: size * 0.3,
                        spreadRadius: size * 0.02,
                      ),
                    ],
                  ),
                ),
              if (object.wild)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Palette.gold.withValues(alpha: 0.8),
                        blurRadius: size * 0.4,
                        spreadRadius: size * 0.04,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(bottom: size * 0.1),
                child: Image.asset(
                  object.sprite,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 2.4).round(),
                ),
              ),
              if (object.flash > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: object.flash * 0.85,
                    child: Image.asset(
                      Sprites.magic(Sprites.magicRings[object.id % Sprites.magicRings.length]),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              Positioned(
                bottom: -badgeSize * 0.12,
                child: object.wild
                    ? _WildBadge(size: badgeSize)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RoleBadge(
                            role: role,
                            size: badgeSize,
                            hidden: game.rolesHidden,
                            highlight: isDemand,
                          ),
                          if (object.secondRoleIndex != null) ...[
                            SizedBox(width: badgeSize * 0.08),
                            RoleBadge(
                              role: Roles.byIndex(object.secondRoleIndex!),
                              size: badgeSize * 0.86,
                              hidden: game.rolesHidden,
                              highlight: object.secondRoleIndex == game.currentDemand,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WildBadge extends StatelessWidget {
  const _WildBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.9,
      height: size * 0.62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        gradient: Palette.buttonGold,
        border: Border.all(color: Palette.goldDeep, width: 1.2),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'WILD',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Palette.ink,
              fontSize: size * 0.42,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpinPedestal extends StatelessWidget {
  const _SpinPedestal({required this.game, required this.size});

  final GameController game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ready = game.spinCooldown <= 0 && game.phase == GamePhase.playing;
    final flourish = game.spinFlourish;
    return GestureDetector(
      onTap: game.spin,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: game.ringRotation * 1.6,
              child: Opacity(
                opacity: 0.55 + flourish * 0.45,
                child: Image.asset(
                  Sprites.magic(game.madness ? 2 : 0),
                  width: size * 1.28,
                  height: size * 1.28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Palette.velvetLight, Palette.velvetDeep],
                ),
                border: Border.all(
                  color: ready ? Palette.gold : Palette.goldDeep.withValues(alpha: 0.6),
                  width: size * 0.035,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (game.madness ? Palette.magenta : Palette.gold)
                        .withValues(alpha: ready ? 0.55 : 0.2),
                    blurRadius: size * 0.25,
                  ),
                ],
              ),
            ),
            Image.asset(
              game.jesterSkin,
              width: size * 0.62,
              height: size * 0.62,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: (size * 2).round(),
            ),
            Positioned(
              bottom: size * 0.06,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: size * 0.14, vertical: size * 0.035),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: Palette.buttonGold,
                  border: Border.all(color: Palette.goldDeep, width: 1.2),
                ),
                child: Text(
                  'SPIN',
                  style: TextStyle(
                    fontSize: size * 0.145,
                    fontWeight: FontWeight.w900,
                    letterSpacing: size * 0.012,
                    color: Palette.ink,
                  ),
                ),
              ),
            ),
            if (!ready)
              SizedBox(
                width: size * 0.94,
                height: size * 0.94,
                child: CircularProgressIndicator(
                  value: 1 - (game.spinCooldown / 0.42).clamp(0.0, 1.0),
                  strokeWidth: size * 0.035,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(Palette.gold.withValues(alpha: 0.55)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Particles extends StatelessWidget {
  const _Particles({required this.game, required this.size});

  final GameController game;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(size, size),
        painter: _ParticlePainter(game.particles, size),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles, this.side);

  final List<Particle> particles;
  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final paint = Paint();
    for (final p in particles) {
      final life = (1 - p.age / p.life).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: life);
      final center = Offset(r + p.position.dx * r, r + p.position.dy * r);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(p.rotation);
      final w = p.size * side;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.7),
          Radius.circular(w * 0.25),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.game, required this.size});

  final GameController game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = game.countdown;
    final label = value > 3 ? 'GET READY' : (value.ceil() > 0 ? '${value.ceil()}' : 'SHOWTIME');
    final phase = value - value.floorToDouble();
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.velvetDeep.withValues(alpha: 0.55),
        ),
        child: Transform.scale(
          scale: 0.85 + phase * 0.35,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * (label.length > 2 ? 0.11 : 0.24),
              fontWeight: FontWeight.w900,
              color: Palette.goldPale,
              letterSpacing: 3,
              shadows: const [
                Shadow(color: Palette.crimson, blurRadius: 0, offset: Offset(0, 3)),
                Shadow(color: Colors.black, blurRadius: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
