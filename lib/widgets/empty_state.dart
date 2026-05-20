import 'package:flutter/material.dart';
import '../constants/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: Rd.xl,
                border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
              ),
              child: Icon(icon, color: AppTheme.textMuted, size: 32),
            ),
            const SizedBox(height: Sp.lg),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.sm),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Sp.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
