import 'dart:math';
import 'package:flutter/material.dart';

class CursorOverlay extends StatefulWidget {
  final bool isVisible;
  final double targetX;
  final double targetY;
  final bool isClicking;

  const CursorOverlay({
    super.key,
    this.isVisible = false,
    this.targetX = 0,
    this.targetY = 0,
    this.isClicking = false,
  });

  @override
  State<CursorOverlay> createState() => _CursorOverlayState();
}

class _CursorOverlayState extends State<CursorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _clickScaleAnim;
  late Animation<double> _clickOpacityAnim;

  Offset _currentPos = const Offset(100, 100);
  final List<Offset> _trail = [];
  static const int maxTrailLength = 15;

  Offset _startPos = const Offset(100, 100);
  Offset _endPos = const Offset(100, 100);
  Offset _controlPoint1 = const Offset(100, 100);
  Offset _controlPoint2 = const Offset(100, 100);
  final Random _rng = Random();

  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _clickScaleAnim = Tween<double>(begin: 1.0, end: 0.65).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );

    _clickOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    _animController.addListener(_onAnimTick);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.reverse();
      }
    });
  }

  void _onAnimTick() {
    if (_isMoving) {
      final t = _animController.value;
      final pos = _cubicBezier(t, _startPos, _controlPoint1, _controlPoint2, _endPos);
      final jitter = Offset(
        (_rng.nextDouble() - 0.5) * 1.5,
        (_rng.nextDouble() - 0.5) * 1.5,
      );
      setState(() {
        _currentPos = pos + jitter;
        if (_trail.length > maxTrailLength) _trail.removeAt(0);
        _trail.add(_currentPos);
      });
    } else {
      setState(() {});
    }
  }

  Offset _cubicBezier(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final u = 1 - t;
    final u3 = u * u * u;
    final u2t = 3.0 * u * u * t;
    final ut2 = 3.0 * u * t * t;
    final t3 = t * t * t;
    return Offset(
      u3 * p0.dx + u2t * p1.dx + ut2 * p2.dx + t3 * p3.dx,
      u3 * p0.dy + u2t * p1.dy + ut2 * p2.dy + t3 * p3.dy,
    );
  }

  void _moveTo(double x, double y) {
    _startPos = _currentPos;
    _endPos = Offset(x, y);

    final dx = _endPos.dx - _startPos.dx;
    final dy = _endPos.dy - _startPos.dy;
    final dist = sqrt(dx * dx + dy * dy);

    final wobbleX = (_rng.nextDouble() - 0.5) * dist * 0.15;
    final wobbleY = (_rng.nextDouble() - 0.5) * dist * 0.15;

    _controlPoint1 = Offset(
      _startPos.dx + dx * 0.3 + wobbleX,
      _startPos.dy + dy * 0.3 + wobbleY,
    );
    _controlPoint2 = Offset(
      _startPos.dx + dx * 0.7 - wobbleX * 0.5,
      _startPos.dy + dy * 0.7 - wobbleY * 0.5,
    );

    final speed = (dist / 400).clamp(0.15, 0.35);
    _animController.duration = Duration(milliseconds: (speed * 1000).toInt());

    _isMoving = true;
    _animController.forward(from: 0).then((_) {
      _isMoving = false;
      _trail.clear();
    });
  }

  void _performClick() {
    _isMoving = false;
    _animController.duration = const Duration(milliseconds: 250);
    _animController.forward(from: 0);
  }

  @override
  void didUpdateWidget(CursorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.targetX != oldWidget.targetX || widget.targetY != oldWidget.targetY) {
      _moveTo(widget.targetX, widget.targetY);
    }

    if (widget.isClicking && !oldWidget.isClicking) {
      _performClick();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        painter: _CursorPainter(
          position: _currentPos,
          trail: List.from(_trail),
          clickScale: _clickScaleAnim.value,
          clickOpacity: _clickOpacityAnim.value,
          isClicking: widget.isClicking && _animController.isAnimating && !_isMoving,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final Offset position;
  final List<Offset> trail;
  final double clickScale;
  final double clickOpacity;
  final bool isClicking;

  _CursorPainter({
    required this.position,
    required this.trail,
    required this.clickScale,
    required this.clickOpacity,
    required this.isClicking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawTrail(canvas);
    _drawClickRipple(canvas);
    _drawCursor(canvas);
  }

  void _drawTrail(Canvas canvas) {
    if (trail.length < 2) return;
    for (int i = 0; i < trail.length - 1; i++) {
      final opacity = (i / trail.length) * 0.35;
      final paint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: opacity)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(trail[i], trail[i + 1], paint);
    }
  }

  void _drawClickRipple(Canvas canvas) {
    if (!isClicking) return;

    final ripplePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.25 * clickOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 28.0 * clickScale, ripplePaint);

    final ringPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.5 * clickOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(position, 38.0 * clickScale, ringPaint);
  }

  void _drawCursor(Canvas canvas) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    final scale = isClicking ? clickScale : 1.0;
    canvas.scale(scale);

    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, 22);
    path.lineTo(6, 17);
    path.lineTo(12, 26);
    path.lineTo(16, 24);
    path.lineTo(10, 15);
    path.lineTo(17, 13);
    path.close();

    canvas.drawPath(path, cursorPaint);
    canvas.drawPath(path, borderPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.clickScale != clickScale ||
        oldDelegate.clickOpacity != clickOpacity ||
        oldDelegate.isClicking != isClicking;
  }
}
