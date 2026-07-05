import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/device_layout.dart';

/// Text field matching CropGuardTextField.kt
class CropGuardTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String? label;
  final String? placeholder;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const CropGuardTextField({
    super.key,
    required this.value,
    required this.onChanged,
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
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant CropGuardTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
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
          controller: _controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
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
