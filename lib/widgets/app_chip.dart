import 'package:flutter/material.dart';
import '../constants/theme.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm - 2),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppTheme.surfaceElevated,
          borderRadius: Rd.xl,
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : AppTheme.surfaceBorder,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
