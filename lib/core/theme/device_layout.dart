import 'package:flutter/material.dart';

/// Responsive layout tokens.
///
/// Static constants are fixed design-system values (touch targets, radii, icon
/// sizes) that never change with screen size.  Use the [DeviceLayoutContext]
/// extension on [BuildContext] for values that adapt to the actual viewport
/// width at runtime.
class DeviceLayout {
  DeviceLayout._();

  // ── Breakpoints ──────────────────────────────────────────────────────────

  /// Viewport width at which phone layouts switch to tablet layouts (dp).
  static const double tabletBreakpoint = 600;

  /// Viewport width for large tablets — reserved for future two-pane layouts.
  static const double largeTabletBreakpoint = 840;

  /// Maximum width of scrollable content on tablets.  Keeps line lengths
  /// readable and prevents full-bleed stretching on wide screens.
  static const double tabletContentMaxWidth = 640;

  // ── Spacing tokens ────────────────────────────────────────────────────────

  static const double screenPaddingHorizontal = 16;
  static const double screenPaddingVertical = 24;
  static const double sectionSpacing = 16;

  // ── Component sizes ───────────────────────────────────────────────────────

  static const double primaryButtonHeight = 52;
  static const double secondaryButtonHeight = 48;
  static const double socialButtonHeight = 48;
  static const double textFieldMinHeight = 56;
  static const double textFieldPaddingH = 16;
  static const double textFieldPaddingV = 16;
  static const double minTouchTarget = 48;
  static const double bottomNavHeight = 80;
  static const double cornerRadius = 12;
  static const double buttonCornerRadius = 12;
  static const double iconSize = 24;

  // ── Static EdgeInsets (context-adaptive versions live in the extension) ───

  static EdgeInsets get textFieldContentPadding => const EdgeInsets.symmetric(
        horizontal: textFieldPaddingH,
        vertical: textFieldPaddingV,
      );
}

extension DeviceLayoutContext on BuildContext {
  double get _viewportWidth => MediaQuery.sizeOf(this).width;

  /// True when the viewport is wide enough to warrant a tablet layout.
  bool get isTablet => _viewportWidth >= DeviceLayout.tabletBreakpoint;

  /// Horizontal screen padding — wider on tablets to avoid over-stretched lines.
  double get screenPaddingH =>
      isTablet ? 24.0 : DeviceLayout.screenPaddingHorizontal;

  /// Primary button height — constant across breakpoints; meets the 48 dp
  /// minimum touch-target requirement on all supported devices.
  double get primaryButtonHeight => DeviceLayout.primaryButtonHeight;

  /// Padding for non-scrolling full-screen content.
  EdgeInsets get screenContentPadding => isTablet
      ? const EdgeInsets.symmetric(horizontal: 24, vertical: 32)
      : const EdgeInsets.symmetric(
          horizontal: DeviceLayout.screenPaddingHorizontal,
          vertical: DeviceLayout.screenPaddingVertical,
        );

  /// Padding for scrolling content (extra bottom room so FABs / nav bars
  /// do not clip the last item).
  EdgeInsets get scrollContentPadding => isTablet
      ? const EdgeInsets.fromLTRB(24, 32, 24,
          DeviceLayout.sectionSpacing + 32)
      : const EdgeInsets.fromLTRB(
          DeviceLayout.screenPaddingHorizontal,
          DeviceLayout.screenPaddingVertical,
          DeviceLayout.screenPaddingHorizontal,
          DeviceLayout.screenPaddingVertical + DeviceLayout.sectionSpacing,
        );

  /// On tablets, centers [child] and caps its width at
  /// [DeviceLayout.tabletContentMaxWidth].  Returns [child] unchanged on phones.
  Widget constrainToContentWidth(Widget child) {
    if (!isTablet) return child;
    return Align(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DeviceLayout.tabletContentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
