import 'package:flutter/material.dart';

import '../../core/theme/device_layout.dart';

/// Scrollable screen body with responsive padding and tablet centering.
///
/// On phones: full-width column with standard padding.
/// On tablets (≥600 dp): content is capped at [DeviceLayout.tabletContentMaxWidth]
/// and centered, preventing over-stretched single-column layouts.
class ScreenContent extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final bool scrollable;

  const ScreenContent({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final padding = context.screenContentPadding;
    final column = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
    final constrained = context.constrainToContentWidth(column);

    if (!scrollable) {
      return Padding(padding: padding, child: constrained);
    }

    return SingleChildScrollView(
      padding: padding,
      child: constrained,
    );
  }
}
