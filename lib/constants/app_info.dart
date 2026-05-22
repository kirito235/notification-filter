import 'package:flutter/material.dart';
import 'theme.dart';

class AppInfo {
  // FIX 4: Only show one WhatsApp entry in UI (handles both packages)
  static const Map<String, String> names = {
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  // Display names including WA Business for notification cards
  static const Map<String, String> displayNames = {
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  static const Map<String, Color> colors = {
    'com.whatsapp.w4b': AppTheme.whatsapp,
    'com.whatsapp': AppTheme.whatsapp,
    'com.instagram.android': AppTheme.instagram,
    'com.snapchat.android': AppTheme.snapchat,
  };

  static const Map<String, Color> softColors = {
    'com.whatsapp.w4b': AppTheme.whatsappSoft,
    'com.whatsapp': AppTheme.whatsappSoft,
    'com.instagram.android': AppTheme.instagramSoft,
    'com.snapchat.android': AppTheme.snapchatSoft,
  };

  static const Map<String, IconData> icons = {
    'com.whatsapp.w4b': Icons.chat_bubble_rounded,
    'com.whatsapp': Icons.chat_bubble_rounded,
    'com.instagram.android': Icons.camera_alt_rounded,
    'com.snapchat.android': Icons.crop_square_rounded,
  };

  // FIX 4: Both WA packages are supported
  static const List<String> supportedApps = [
    'com.whatsapp.w4b',
    'com.whatsapp',
    'com.instagram.android',
    'com.snapchat.android',
  ];

  static String name(String pkg) => displayNames[pkg] ?? pkg;
  static Color color(String pkg) => colors[pkg] ?? AppTheme.textSecondary;
  static Color softColor(String pkg) =>
      softColors[pkg] ?? AppTheme.surfaceElevated;
  static IconData icon(String pkg) =>
      icons[pkg] ?? Icons.notifications_rounded;
  static bool isSupported(String pkg) => supportedApps.contains(pkg);
}
