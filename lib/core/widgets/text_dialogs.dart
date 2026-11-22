import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/petal_palette.dart';

/// A dialog with one or more text fields. Returns the values in order, or
/// null if cancelled. Owns (and safely disposes) its controllers.
Future<List<String>?> showTextFieldsDialog(
  BuildContext context, {
  required String title,
  required List<({String label, String initial, String? hint})> fields,
  String saveLabel = 'Save',
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) =>
        _TextFieldsDialog(title: title, fields: fields, saveLabel: saveLabel),
  );
}

class _TextFieldsDialog extends StatefulWidget {
  const _TextFieldsDialog({
    required this.title,
    required this.fields,
    required this.saveLabel,
  });

  final String title;
  final List<({String label, String initial, String? hint})> fields;
  final String saveLabel;

  @override
  State<_TextFieldsDialog> createState() => _TextFieldsDialogState();
}

class _TextFieldsDialogState extends State<_TextFieldsDialog> {
  late final _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() =>
      Navigator.of(context).pop([for (final c in _controllers) c.text.trim()]);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, f) in widget.fields.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              TextField(
                controller: _controllers[i],
                autofocus: i == 0,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: i == widget.fields.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                decoration: InputDecoration(
                  labelText: f.label,
                  hintText: f.hint,
                ),
                onSubmitted: (_) {
                  if (i == widget.fields.length - 1) _save();
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: Text(widget.saveLabel)),
      ],
    );
  }
}

/// Pick one of [options]; the current one shows a check. Returns the picked
/// value or null if dismissed.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T current,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (value, label) in options)
          Semantics(
            selected: value == current,
            button: true,
            child: SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(value),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (value == current)
                    Icon(LucideIcons.check, color: context.palette.deep),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
