import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/arcade_stage.dart';
import '../app/play_kit.dart';
import '../app/services/audio.dart';
import '../core/arcade.dart';
import 'fighter_engine.dart';

/// Stick-figure fighters drawn from a pose (no sprites needed).
Paint _p(int c) => Paint()..color = Color(c);

void _bar(Canvas c, Rect r, double f, int color, {bool rtl = false}) {
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), _p(0x99000000));
  final w = r.width * f.clamp(0.0, 1.0);
  final fill = rtl ? Rect.fromLTWH(r.right - w, r.top, w, r.height) : Rect.fromLTWH(r.left, r.top, w, r.height);
  c.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(10)), _p(color));
}

void _stick(Canvas c, Fighter f, int color, double t, {bool ninja = false, double scale = 1}) {
  final s = scale;
  final base = Offset(f.x, kGround - f.y);
  final paint = Paint()
    ..color = f.hitFlash > 0 ? Colors.white : Color(color)
    ..strokeWidth = 14 * s
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final face = f.face.toDouble();
  final walking = f.vx.abs() > 0.5 && f.y < 1;
  final swingA = walking ? math.sin(t * 14 + f.x * 0.01) * 0.6 : 0.0;
  final crouch = f.state == fsBlock ? 18.0 : 0.0;
  final hip = base.translate(0, -90 * s + crouch);
  final neck = hip.translate(f.state == fsHurt ? -face * 18 : face * 4, -80 * s);
  final head = neck.translate(0, -30 * s);
  // legs
  final airborne = f.y > 1;
  final kneeL = airborne ? hip.translate(-20 * s, 30 * s) : hip.translate(math.sin(swingA) * 40 * s, 45 * s);
  final kneeR = airborne ? hip.translate(24 * s, 24 * s) : hip.translate(-math.sin(swingA) * 40 * s, 45 * s);
  c.drawLine(hip, kneeL, paint);
  c.drawLine(kneeL, airborne ? kneeL.translate(-10 * s, 30 * s) : base.translate(math.sin(swingA) * 50 * s, 0), paint);
  final kicking = f.state == fsActive && f.combo == 2;
  c.drawLine(hip, kicking ? hip.translate(face * 120 * s, -20 * s) : kneeR, paint);
  if (!kicking)
    c.drawLine(
      kneeR,
      airborne ? kneeR.translate(14 * s, 30 * s) : base.translate(-math.sin(swingA) * 50 * s, 0),
      paint,
    );
  // body
  c.drawLine(hip, neck, paint);
  // arms by state
  final shoulder = neck.translate(0, 12 * s);
  late Offset handF, handB;
  switch (f.state) {
    case fsWindup:
      handF = shoulder.translate(-face * 40 * s, 10 * s);
      handB = shoulder.translate(-face * 30 * s, 40 * s);
      c.drawCircle(handF, 22 * s, Paint()..color = const Color(0x66FFD166));
    case fsActive:
      handF = shoulder.translate(face * 115 * s, 0);
      handB = shoulder.translate(-face * 30 * s, 40 * s);
    case fsBlock:
      handF = shoulder.translate(face * 40 * s, -20 * s);
      handB = shoulder.translate(face * 34 * s, 10 * s);
    case fsSpecial:
      handF = shoulder.translate(face * 90 * s, -10 * s);
      handB = shoulder.translate(face * 80 * s, 10 * s);
    case fsHurt:
      handF = shoulder.translate(-face * 40 * s, -40 * s);
      handB = shoulder.translate(-face * 50 * s, 20 * s);
    default:
      handF = shoulder.translate(face * 40 * s + math.sin(swingA) * 10, 50 * s);
      handB = shoulder.translate(-face * 20 * s - math.sin(swingA) * 10, 55 * s);
  }
  c.drawLine(shoulder, Offset.lerp(shoulder, handF, 0.5)!.translate(0, 10 * s), paint);
  c.drawLine(Offset.lerp(shoulder, handF, 0.5)!.translate(0, 10 * s), handF, paint);
  c.drawLine(shoulder, handB, paint);
  c.drawCircle(head, 28 * s, Paint()..color = paint.color);
  if (ninja) {
    c.drawRect(Rect.fromCenter(center: head.translate(face * 6, -2), width: 52 * s, height: 12 * s), _p(0xFFE63946));
    c.drawLine(
      head.translate(-face * 26 * s, -2),
      head.translate(-face * (60 + math.sin(t * 12) * 8) * s, 10 * s),
      Paint()
        ..color = const Color(0xFFE63946)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  } else {
    c.drawCircle(head.translate(face * 10 * s, -4), 5 * s, _p(0xFF000000));
  }
  if (f.state == fsBlock) {
    c.drawArc(
      Rect.fromCircle(center: shoulder.translate(face * 50 * s, 0), radius: 60 * s),
      -math.pi / 2 - face * 0.0 - 1,
      2,
      false,
      Paint()
        ..color = const Color(0x8848CAE4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
  }
  if (f.state == fsSpecial) {
    c.drawArc(
      Rect.fromCircle(center: shoulder, radius: 240),
      face > 0 ? -0.8 : math.pi - 0.8,
      1.6,
      false,
      Paint()
        ..color = Color.fromARGB((f.timer * 7).clamp(0, 200).toInt(), 255, 214, 10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30,
    );
  }
}

int _styleColor(int style, bool shadow) {
  if (shadow) return style == stBoss ? 0xFF3C096C : 0xFF212529;
  return switch (style) {
    stRusher => 0xFFE63946,
    stDefender => 0xFF457B9D,
    stJumper => 0xFF2A9D8F,
    stHeavy => 0xFF6D597A,
    stBoss => 0xFFF77F00,
    stGrunt => 0xFF495057,
    _ => 0xFFF4A261,
  };
}

void paintFight(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as FightSim;
  final shadow = s.level.kind == FightKind.brawl;
  // backdrop
  final sky = switch (s.level.arena) {
    0 => [0xFF0B132B, 0xFF3A506B],
    1 => [0xFF6A040F, 0xFFE85D04],
    2 => [0xFF240046, 0xFF7B2CBF],
    _ => [0xFF003049, 0xFF669BBC],
  };
  c.drawRect(
    const Rect.fromLTWH(0, 0, kWorldW, kWorldH),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(sky[0]), Color(sky[1])],
      ).createShader(const Rect.fromLTWH(0, 0, kWorldW, kGround)),
  );
  c.drawCircle(const Offset(780, 360), 120, _p(shadow ? 0xFFF1FAEE : 0x66FFFFFF));
  // silhouettes: temples / city
  for (var i = 0; i < 6; i++) {
    final x = i * 190.0 - 40;
    final h = 220.0 + (i * 97) % 180;
    c.drawRect(Rect.fromLTWH(x, kGround - h, 150, h), _p(0x55000000));
    if (shadow) {
      c.drawPath(
        Path()
          ..moveTo(x - 20, kGround - h)
          ..lineTo(x + 75, kGround - h - 60)
          ..lineTo(x + 170, kGround - h)
          ..close(),
        _p(0x55000000),
      );
    }
  }
  c.drawRect(const Rect.fromLTWH(0, kGround, kWorldW, kWorldH - kGround), _p(shadow ? 0xFF161A1D : 0xFF3D405B));
  c.drawLine(
    const Offset(0, kGround),
    const Offset(kWorldW, kGround),
    Paint()
      ..color = Colors.white24
      ..strokeWidth = 6,
  );
  // fighters
  for (final f in s.foes) {
    c.drawOval(Rect.fromCenter(center: Offset(f.x, kGround + 6), width: 110, height: 18), _p(0x55000000));
    _stick(
      c,
      f,
      _styleColor(f.style, shadow),
      t,
      ninja: shadow,
      scale: f.style == stBoss ? 1.35 : (f.style == stHeavy ? 1.15 : 1),
    );
    if (f.state == fsWindup) paintText(c, '!', Offset(f.x, kGround - f.y - 290), 60, const Color(0xFFFFD166));
    if (shadow || s.foes.length > 1) {
      final w = f.style == stBoss ? 160.0 : 90.0;
      _bar(
        c,
        Rect.fromCenter(center: Offset(f.x, kGround - f.y - 250 * (f.style == stBoss ? 1.3 : 1)), width: w, height: 12),
        f.hp / f.maxHp,
        0xFFFF4D6D,
      );
    }
  }
  final pl = s.p;
  final blink = s.shield > 0 && (s.ticks ~/ 5).isOdd;
  c.drawOval(Rect.fromCenter(center: Offset(pl.x, kGround + 6), width: 110, height: 18), _p(0x55000000));
  if (!blink) _stick(c, pl, shadow ? 0xFF0D1B2A : p.piece(0).toARGB32(), t, ninja: shadow);
  for (final (x, y, life) in s.sparks) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + life;
      c.drawLine(
        Offset(x, y),
        Offset(x, y) + Offset(math.cos(a), math.sin(a)) * (14.0 - life) * 6,
        Paint()
          ..color = const Color(0xFFFFD166)
          ..strokeWidth = 6,
      );
    }
  }
  // HUD bars
  _bar(c, const Rect.fromLTWH(40, 120, 420, 34), pl.hp / pl.maxHp, 0xFF52B788);
  if (!shadow && s.foes.isNotEmpty) {
    final f = s.foes.first;
    _bar(c, const Rect.fromLTWH(540, 120, 420, 34), f.hp / f.maxHp, 0xFFE63946, rtl: true);
  }
  _bar(c, const Rect.fromLTWH(40, 170, 300, 20), s.meter / 100, s.meter >= 100 ? 0xFFFFD60A : 0xFF4CC9F0);
  if (s.meter >= 100) paintText(c, '⬇ ★', const Offset(390, 180), 32, const Color(0xFFFFD60A));
  if (s.gap > 0) paintText(c, s.level.kind == FightKind.duel ? 'K.O.' : '⚑', const Offset(500, 650), 140, Colors.white);
  // touch zones hint
  final hint = Paint()..color = Colors.white10;
  c.drawRect(const Rect.fromLTWH(0, 1300, 300, 300), hint);
  c.drawRect(const Rect.fromLTWH(700, 1300, 300, 300), hint);
  paintText(c, '◀', const Offset(150, 1450), 70, Colors.white30);
  paintText(c, '▶', const Offset(850, 1450), 70, Colors.white30);
  paintText(c, '✊', const Offset(500, 1450), 70, Colors.white30);
}

Sfx? fightSound(ArcadeSim sim) => switch ((sim as FightSim).lastEvent) {
  1 => Sfx.tap,
  2 => Sfx.clear,
  3 => Sfx.place,
  4 => Sfx.error,
  5 => Sfx.combo,
  _ => null,
};
