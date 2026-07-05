import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Circular animated health ring — matches FarmHealthRing.kt
class FarmHealthRing extends StatefulWidget {
  final double percentage; // 0.0 – 1.0
  final double size;
  final double strokeWidth;
  final bool showStartPrompt;

  const FarmHealthRing({
    super.key,
    required this.percentage,
    this.size = 100,
    this.strokeWidth = 10,
    this.showStartPrompt = false,
  });

  @override
  State<FarmHealthRing> createState() => _FarmHealthRingState();
}

class _FarmHealthRingState extends State<FarmHealthRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: widget.percentage).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FarmHealthRing old) {
    super.didUpdateWidget(old);
    if (old.percentage != widget.percentage) {
      _animation =
          Tween<double>(begin: _animation.value, end: widget.percentage)
              .animate(CurvedAnimation(
                  parent: _controller, curve: Curves.fastOutSlowIn));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final value = _animation.value;
        final ringColor = value >= 0.8
            ? colors.healthy
            : value >= 0.5
                ? colors.lowConfidence
                : colors.diseaseRed;

        return Semantics(
          label: context.l10n.farmHealth,
          value: '${(value * 100).toInt()}%',
          excludeSemantics: true,
          child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: value,
                  color: ringColor,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              // Show the scan-prompt immediately (before the animation
              // value updates) so there is never a "0%" flash on first run.
              widget.showStartPrompt
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: colors.primary, size: 22),
                        const SizedBox(height: 4),
                        Text(context.l10n.scan,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.muted)),
                      ],
                    )
                  : Text(
                      '${(value * 100).toInt()}%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: colors.onBackground,
                          ),
                    ),
            ],
          ),
        ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _RingPainter(
      {required this.progress,
      required this.color,
      required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
