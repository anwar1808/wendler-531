import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// A compact timer bar shown at the bottom of the main nav when a rest timer
/// is active but the user is not on the session/workout screen.
class PersistentTimerBar extends StatelessWidget {
  final AppProvider provider;

  const PersistentTimerBar({super.key, required this.provider});

  String get _timeDisplay {
    final r = provider.timerRemaining;
    final mins = r ~/ 60;
    final secs = r % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = provider.timerRemaining <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(
          top: BorderSide(
            color: isUrgent ? Colors.red : AppTheme.accent,
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: isUrgent ? Colors.red : AppTheme.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'REST',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeDisplay,
            style: TextStyle(
              color: isUrgent ? Colors.red : AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (provider.timerNextSet != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Next: ${provider.timerNextSet}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          TextButton(
            onPressed: provider.stopRestTimer,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Skip', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
