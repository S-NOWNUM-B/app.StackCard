import 'package:flutter/material.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';

class StackCardInput extends StatelessWidget {
  const StackCardInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
    this.prefixIconWidget,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.showLabel = true,
    this.helperText,
    this.errorText,
    this.focusNode,
  }) : assert(prefixIcon == null || prefixIconWidget == null);

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? prefixIconWidget;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;

  /// Поиск скрывает внешний label, сохраняя доступное имя поля.
  final bool showLabel;
  final String? helperText;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final multiline =
        !obscureText && ((maxLines ?? 2) > 1 || (minLines ?? 1) > 1);
    return Semantics(
      label: showLabel ? null : label,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        validator: validator,
        errorBuilder: (_, message) => Text(message),
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        obscureText: obscureText,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        autocorrect: !obscureText,
        enableSuggestions: !obscureText,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: showLabel ? label : null,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: hint ?? (showLabel ? null : label),
          helper: switch (helperText) {
            final message? => Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.colors.textMeta),
            ),
            null => null,
          },
          error: switch (errorText) {
            final message? => Text(message),
            null => null,
          },
          prefixIcon: prefixIconWidget != null
              ? Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: SizedBox.square(
                    dimension: 20,
                    child: prefixIconWidget,
                  ),
                )
              : prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 20),
          constraints: BoxConstraints(
            minHeight: multiline ? 120 : StackCardSize.inputHeight,
          ),
        ),
      ),
    );
  }
}
