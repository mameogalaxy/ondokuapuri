import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';

/// ペットの気分。アニメーションを切り替えます。
enum PetMood {
  idle, // ふつう（ゆらゆら）
  reading, // 音読中（応援・ぴょんぴょん）
  happy, // よろこんでいる
}

/// ペット表示ウィジェット。
///
/// MVPでは外部アセット（Lottie/Rive）を使わず、CustomPainter と
/// AnimatedBuilder で簡易アニメーションを実装しています。
/// たまごは揺れ、音読すると目を開けたり跳ねたりします。
class PetView extends StatefulWidget {
  final PetStage stage;
  final PetMood mood;
  final double size;

  const PetView({
    super.key,
    required this.stage,
    this.mood = PetMood.idle,
    this.size = 200,
  });

  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // 気分ごとに動きの強さ・速さを変える。
        double bounce;
        double sway;
        switch (widget.mood) {
          case PetMood.idle:
            bounce = math.sin(t * 2 * math.pi) * 3;
            sway = math.sin(t * 2 * math.pi) * 0.04;
            break;
          case PetMood.reading:
            bounce = (math.sin(t * 4 * math.pi)).abs() * -14;
            sway = math.sin(t * 4 * math.pi) * 0.06;
            break;
          case PetMood.happy:
            bounce = (math.sin(t * 6 * math.pi)).abs() * -20;
            sway = math.sin(t * 6 * math.pi) * 0.10;
            break;
        }

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Transform.rotate(
            angle: sway,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _PetPainter(
                stage: widget.stage,
                mood: widget.mood,
                t: t,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PetPainter extends CustomPainter {
  final PetStage stage;
  final PetMood mood;
  final double t;

  _PetPainter({required this.stage, required this.mood, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (stage) {
      case PetStage.egg:
        _drawEgg(canvas, size, center);
        break;
      case PetStage.chick:
        _drawCreature(canvas, size, center,
            bodyColor: const Color(0xFFFFD23F), earType: _Ear.none);
        break;
      case PetStage.child:
        _drawCreature(canvas, size, center,
            bodyColor: const Color(0xFF8FD694), earType: _Ear.round);
        break;
      case PetStage.evolved:
        _drawCreature(canvas, size, center,
            bodyColor: const Color(0xFF6FB7FF), earType: _Ear.pointy);
        break;
      case PetStage.rare:
        _drawCreature(canvas, size, center,
            bodyColor: const Color(0xFFC79BFF),
            earType: _Ear.pointy,
            sparkle: true);
        break;
    }
  }

  void _drawEgg(Canvas canvas, Size size, Offset center) {
    final w = size.width * 0.55;
    final h = size.height * 0.7;
    final rect = Rect.fromCenter(center: center, width: w, height: h);

    final shellPaint = Paint()..color = const Color(0xFFFFF3D6);
    canvas.drawOval(rect, shellPaint);

    // 模様
    final patternPaint = Paint()
      ..color = const Color(0xFFFFC861)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final y = center.dy - h * 0.15 + i * h * 0.22;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(center.dx, y), width: w * 0.5, height: 8),
        patternPaint,
      );
    }

    // 目（音読中は開く）
    final eyeOpen = mood != PetMood.idle || (t > 0.5);
    _drawEyes(canvas, center.translate(0, -h * 0.05), w * 0.10, eyeOpen);

    // 輪郭
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFFE8B860)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawCreature(
    Canvas canvas,
    Size size,
    Offset center, {
    required Color bodyColor,
    required _Ear earType,
    bool sparkle = false,
  }) {
    final r = size.width * 0.30;

    // 耳
    final earPaint = Paint()..color = bodyColor;
    if (earType == _Ear.round) {
      canvas.drawCircle(center.translate(-r * 0.8, -r * 0.8), r * 0.35, earPaint);
      canvas.drawCircle(center.translate(r * 0.8, -r * 0.8), r * 0.35, earPaint);
    } else if (earType == _Ear.pointy) {
      _triangle(canvas, center.translate(-r * 0.7, -r * 0.9), r * 0.5, earPaint);
      _triangle(canvas, center.translate(r * 0.7, -r * 0.9), r * 0.5, earPaint);
    }

    // 体（まる）
    canvas.drawCircle(center, r, Paint()..color = bodyColor);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // ほっぺ
    final cheek = Paint()..color = const Color(0x55FF7B7B);
    canvas.drawCircle(center.translate(-r * 0.55, r * 0.25), r * 0.18, cheek);
    canvas.drawCircle(center.translate(r * 0.55, r * 0.25), r * 0.18, cheek);

    // 目
    final eyeOpen = mood != PetMood.idle || (t > 0.45);
    _drawEyes(canvas, center.translate(0, -r * 0.1), r * 0.16, eyeOpen);

    // 口（よろこんでいると大きく）
    final mouthPaint = Paint()
      ..color = const Color(0xFF6B4A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: center.translate(0, r * 0.35),
      width: r * (mood == PetMood.happy ? 0.7 : 0.4),
      height: r * (mood == PetMood.happy ? 0.5 : 0.25),
    );
    canvas.drawArc(mouthRect, 0.1, math.pi - 0.2, false, mouthPaint);

    if (sparkle) {
      _drawSparkles(canvas, center, r);
    }
  }

  void _drawEyes(Canvas canvas, Offset eyeCenter, double eyeR, bool open) {
    final spacing = eyeR * 2.6;
    final eyePaint = Paint()..color = const Color(0xFF3A2A1A);
    if (open) {
      canvas.drawCircle(eyeCenter.translate(-spacing / 2, 0), eyeR, eyePaint);
      canvas.drawCircle(eyeCenter.translate(spacing / 2, 0), eyeR, eyePaint);
      // ハイライト
      final hl = Paint()..color = Colors.white;
      canvas.drawCircle(
          eyeCenter.translate(-spacing / 2 + eyeR * 0.3, -eyeR * 0.3),
          eyeR * 0.3,
          hl);
      canvas.drawCircle(
          eyeCenter.translate(spacing / 2 + eyeR * 0.3, -eyeR * 0.3),
          eyeR * 0.3,
          hl);
    } else {
      // 閉じた目（にっこりライン）
      final p = Paint()
        ..color = const Color(0xFF3A2A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final dx in [-spacing / 2, spacing / 2]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: eyeCenter.translate(dx, 0),
              width: eyeR * 2,
              height: eyeR * 2),
          math.pi,
          math.pi,
          false,
          p,
        );
      }
    }
  }

  void _triangle(Canvas canvas, Offset apexBase, double s, Paint paint) {
    final path = Path()
      ..moveTo(apexBase.dx, apexBase.dy - s)
      ..lineTo(apexBase.dx - s * 0.5, apexBase.dy + s * 0.3)
      ..lineTo(apexBase.dx + s * 0.5, apexBase.dy + s * 0.3)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkles(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = const Color(0xFFFFE873);
    final positions = [
      center.translate(-r * 1.3, -r * 0.6),
      center.translate(r * 1.3, -r * 0.3),
      center.translate(r * 1.1, r * 0.9),
    ];
    for (var i = 0; i < positions.length; i++) {
      final scale = 0.6 + 0.4 * math.sin((t + i * 0.3) * 2 * math.pi).abs();
      _star(canvas, positions[i], r * 0.18 * scale, paint);
    }
  }

  void _star(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final radius = i.isEven ? s : s * 0.4;
      final p = Offset(c.dx + radius * math.cos(angle),
          c.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PetPainter old) =>
      old.t != t || old.mood != mood || old.stage != stage;
}

enum _Ear { none, round, pointy }
