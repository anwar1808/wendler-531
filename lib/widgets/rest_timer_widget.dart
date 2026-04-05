import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A display-only rest timer widget driven by an external [remaining] counter.
/// The actual countdown lives in AppProvider; this widget just renders the state.
class RestTimerWidget extends StatelessWidget {
  final int durationSeconds;
  final int remaining;
  final String liftName;
  final String? nextSetInfo;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  const RestTimerWidget({
    super.key,
    required this.durationSeconds,
    required this.remaining,
    required this.liftName,
    this.nextSetInfo,
    required this.onDone,
    required this.onSkip,
  });

  String get _timeDisplay {
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (durationSeconds == 0) return 0;
    return remaining / durationSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'REST',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            liftName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remaining <= 10 ? Colors.red : AppTheme.accent,
                    ),
                  ),
                ),
                Text(
                  _timeDisplay,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (nextSetInfo != null) ...[
            Text(
              'NEXT',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextSetInfo!,
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSkip,
              child: const Text('Skip Rest'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
