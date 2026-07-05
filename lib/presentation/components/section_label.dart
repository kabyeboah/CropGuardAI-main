import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Uppercase muted section label — matches SectionLabel.kt
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const SectionLabel({
    super.key,
    required this.text,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.muted,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
