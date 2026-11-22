import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// What the user chose in [showNumberDialog].
sealed class NumberDialogResult<T> {
  const NumberDialogResult();
}

class NumberSaved<T> extends NumberDialogResult<T> {
  const NumberSaved(this.value);
  final T value;
}

class NumberRemoved<T> extends NumberDialogResult<T> {
  const NumberRemoved();
}

/// A small dialog with one number field, used for budgets and study minutes.
///
/// The dialog owns its text controller and disposes it itself, after its
/// closing animation (disposing it from the caller right after `pop` crashes
/// while the dialog is still animating out).
///
/// [parse] turns the text into a value, or null if it's invalid (then
/// [errorText] is shown). Returns null if cancelled.
Future<NumberDialogResult<T>?> showNumberDialog<T>(
  BuildContext context, {
  required String title,
  required String label,
  required T? Function(String text) parse,
  required String errorText,
  String initialText = '',
  String? prefixText,
  String? suffixText,
  bool allowDecimal = false,
  bool showRemove = false,
}) {
  return showDialog<NumberDialogResult<T>>(
    context: context,
    builder: (_) => _NumberDialog<T>(
      title: title,
      label: label,
      parse: parse,
      errorText: errorText,
      initialText: initialText,
      prefixText: prefixText,
      suffixText: suffixText,
      allowDecimal: allowDecimal,
      showRemove: showRemove,
    ),
  );
}

class _NumberDialog<T> extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.parse,
    required this.errorText,
    required this.initialText,
    required this.prefixText,
    required this.suffixText,
    required this.allowDecimal,
    required this.showRemove,
  });

  final String title;
  final String label;
  final T? Function(String) parse;
  final String errorText;
  final String initialText;
  final String? prefixText;
  final String? suffixText;
  final bool allowDecimal;
  final bool showRemove;

  @override
  State<_NumberDialog<T>> createState() => _NumberDialogState<T>();
}

class _NumberDialogState<T> extends State<_NumberDialog<T>> {
  late final _field = TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.parse(_field.text);
    if (value == null) {
      setState(() => _error = widget.errorText);
      return;
    }
    Navigator.of(context).pop(NumberSaved<T>(value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.allowDecimal,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(widget.allowDecimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefixText,
          suffixText: widget.suffixText,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        if (widget.showRemove)
          TextButton(
            onPressed: () => Navigator.of(context).pop(NumberRemoved<T>()),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
