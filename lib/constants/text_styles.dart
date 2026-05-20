import 'package:flutter/material.dart';
import 'colors.dart';

class AppText {
  static const heading1 = TextStyle(
    color: AppColors.textPrimary, fontSize: 28,
    fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.2,
  );
  static const heading2 = TextStyle(
    color: AppColors.textPrimary, fontSize: 22,
    fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.3,
  );
  static const heading3 = TextStyle(
    color: AppColors.textPrimary, fontSize: 17,
    fontWeight: FontWeight.w600, letterSpacing: -0.3,
  );
  static const body = TextStyle(
    color: AppColors.textSecondary, fontSize: 15, height: 1.6,
  );
  static const bodySmall = TextStyle(
    color: AppColors.textSecondary, fontSize: 13, height: 1.5,
  );
  static const caption = TextStyle(
    color: AppColors.textMuted, fontSize: 12,
  );
  static const label = TextStyle(
    color: AppColors.textMuted, fontSize: 11,
    fontWeight: FontWeight.w600, letterSpacing: 1.2,
  );
  static const cardTitle = TextStyle(
    color: AppColors.textPrimary, fontSize: 14,
    fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.3,
  );
  static const cardBody = TextStyle(
    color: AppColors.textSecondary, fontSize: 13, height: 1.4,
  );
}
