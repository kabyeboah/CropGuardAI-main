import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/device_layout.dart';

/// Text field matching CropGuardTextField.kt
class CropGuardTextField extends StatefulWidget {
  /// If [controller] is supplied the widget operates in "controlled" mode:
  /// the caller owns the controller lifecycle and [value] / [onChanged] are
  /// ignored.  Passing a controller avoids putting transient text-field content
  /// inside a ChangeNotifier provider.
  final TextEditingController? controller;
  final String value;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? label;
  final String? placeholder;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const CropGuardTextField({
    super.key,
    this.controller,
    this.value = '',
    this.onChanged,
    this.focusNode,
    this.label,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  State<CropGuardTextField> createState() => _CropGuardTextFieldState();
}

class _CropGuardTextFieldState extends State<CropGuardTextField> {
  // Non-null only when the caller did NOT supply their own controller.
  TextEditingController? _ownedController;

  TextEditingController get _effectiveController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant CropGuardTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync the internal controller; external controllers are caller-owned.
    if (widget.controller == null) {
      if (widget.value != _effectiveController.text) {
        _effectiveController.text = widget.value;
        _effectiveController.selection = TextSelection.fromPosition(
          TextPosition(offset: _effectiveController.text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose(); // only dispose what we created
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.label!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.muted,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
        TextFormField(
          controller: _effectiveController,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged ?? (_) {},
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onBackground,
                fontSize: 16,
              ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(color: colors.muted, fontSize: 15),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: colors.surface,
            contentPadding: DeviceLayout.textFieldContentPadding,
            constraints: const BoxConstraints(
              minHeight: DeviceLayout.textFieldMinHeight,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DeviceLayout.cornerRadius),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
