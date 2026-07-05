import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/device_layout.dart';

/// Primary green button — matches PrimaryButton.kt
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = DeviceLayout.primaryButtonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final buttonHeight = height == DeviceLayout.primaryButtonHeight
        ? context.primaryButtonHeight
        : height;
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          ),
          minimumSize: Size(double.infinity, buttonHeight),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(text,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )),
                ],
              ),
      ),
    );
  }
}

/// Secondary outlined button — matches SecondaryButton.kt
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.height = DeviceLayout.secondaryButtonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          ),
          minimumSize: Size(double.infinity, height),
        ),
        child: Text(text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.primary,
                )),
      ),
    );
  }
}

/// Lime gradient button — matches LimeButton composable
class LimeButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const LimeButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: context.primaryButtonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [colors.accent, colors.limeDark]),
            borderRadius: BorderRadius.circular(DeviceLayout.buttonCornerRadius),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.background,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
