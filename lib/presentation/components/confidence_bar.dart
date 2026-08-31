import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale_formatter.dart';

/// Animated confidence bar — matches ConfidenceBar.kt
class ConfidenceBar extends StatefulWidget {
  final double confidence; // 0.0 – 1.0
  final Color? color;
  final bool showLabel;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.color,
    this.showLabel = true,
  });

  @override
  State<ConfidenceBar> createState() => _ConfidenceBarState();
}

class _ConfidenceBarState extends State<ConfidenceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: widget.confidence).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ConfidenceBar old) {
    super.didUpdateWidget(old);
    if (old.confidence != widget.confidence) {
      _animation = Tween<double>(
              begin: _animation.value, end: widget.confidence)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
    final barColor = widget.color ?? colors.primary;
    final pct = (widget.confidence * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.aiConfidence,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: colors.onBackgroundSecondary)),
                Text('${LocaleFormatter.formatNumber(context, pct)}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: barColor)),
              ],
            ),
          ),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 6,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                semanticsLabel: context.l10n.aiConfidence,
                semanticsValue:
                    '${LocaleFormatter.formatNumber(context, pct)}%',
              ),
            );
          },
        ),
      ],
    );
  }
}
