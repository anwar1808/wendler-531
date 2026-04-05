import 'package:flutter/material.dart';
import '../models/set_log_model.dart';
import '../services/wendler_calculator.dart';
import '../services/plate_calculator.dart';
import '../theme/app_theme.dart';

class SetTile extends StatelessWidget {
  final SetLogModel setLog;
  final ValueChanged<bool?> onChecked;
  final ValueChanged<int>? onAmrapRepsChanged;

  const SetTile({
    super.key,
    required this.setLog,
    required this.onChecked,
    this.onAmrapRepsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final weightStr = WendlerCalculator.formatWeight(setLog.prescribedWeight);
    final repsLabel = setLog.repsLabel;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: setLog.isComplete
            ? AppTheme.success.withValues(alpha: 0.15)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: setLog.isComplete ? AppTheme.success.withValues(alpha: 0.4) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            'Set ${setLog.setNumber}',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      weightStr,
                      style: TextStyle(
                        color: setLog.isComplete ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: setLog.isComplete ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '× $repsLabel',
                      style: TextStyle(
                        color: setLog.isAmrap ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: setLog.isAmrap ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                _PlatesLine(weight: setLog.prescribedWeight),
              ],
            ),
          ),
          if (setLog.isAmrap && setLog.isComplete && onAmrapRepsChanged != null) ...[
            const SizedBox(width: 8),
            _AmrapInput(
              initialValue: setLog.actualReps,
              onChanged: onAmrapRepsChanged!,
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: setLog.isComplete,
              onChanged: onChecked,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatesLine extends StatelessWidget {
  final double weight;
  const _PlatesLine({required this.weight});

  @override
  Widget build(BuildContext context) {
    final text = PlateCalculator.formatPlates(weight);
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
      ),
    );
  }
}

class _AmrapInput extends StatefulWidget {
  final int? initialValue;
  final ValueChanged<int> onChanged;

  const _AmrapInput({this.initialValue, required this.onChanged});

  @override
  State<_AmrapInput> createState() => _AmrapInputState();
}

class _AmrapInputState extends State<_AmrapInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue != null ? '${widget.initialValue}' : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 36,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'reps',
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          isDense: true,
        ),
        onChanged: (val) {
          final n = int.tryParse(val);
          if (n != null && n > 0) widget.onChanged(n);
        },
      ),
    );
  }
}
