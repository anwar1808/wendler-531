import 'package:flutter/material.dart';
import '../models/lift_type.dart';
import '../theme/app_theme.dart';

class TmEditDialog extends StatefulWidget {
  final LiftType lift;
  final double currentValue;
  final ValueChanged<double> onSave;

  const TmEditDialog({
    super.key,
    required this.lift,
    required this.currentValue,
    required this.onSave,
  });

  @override
  State<TmEditDialog> createState() => _TmEditDialogState();
}

class _TmEditDialogState extends State<TmEditDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue <= 0 ? '' : widget.currentValue.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final val = double.tryParse(_controller.text);
    if (val == null || val < 20) {
      setState(() => _error = 'Minimum 20kg');
      return;
    }
    widget.onSave(val);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      title: Text(
        'Edit TM — ${widget.lift.displayName}',
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Training Max (kg)',
              errorText: _error,
              suffixText: 'kg',
            ),
            onSubmitted: (_) => _validate(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validate,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
