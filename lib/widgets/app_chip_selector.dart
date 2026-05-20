import 'package:flutter/material.dart';
import '../constants/app_info.dart';
import '../constants/theme.dart';

class AppChipSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<String>? apps;

  const AppChipSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.apps,
  });

  @override
  Widget build(BuildContext context) {
    final list = apps ?? AppInfo.supportedApps;
    return Container(
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
        child: Row(
          children: [
            if (apps == null) ...[
              _Chip(
                label: 'All',
                isSelected: selected == 'all',
                color: AppTheme.accent,
                softColor: AppTheme.accentSoft,
                onTap: () => onSelected('all'),
              ),
              const SizedBox(width: Sp.sm),
            ],
            ...list.map((pkg) {
              return Padding(
                padding: const EdgeInsets.only(right: Sp.sm),
                child: _Chip(
                  label: AppInfo.name(pkg),
                  isSelected: selected == pkg,
                  color: AppInfo.color(pkg),
                  softColor: AppInfo.softColor(pkg),
                  icon: AppInfo.icon(pkg),
                  onTap: () => onSelected(pkg),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final Color softColor;
  final IconData? icon;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.softColor,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? softColor : AppTheme.surfaceElevated,
          borderRadius: Rd.md,
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : AppTheme.surfaceBorder,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? color : AppTheme.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
