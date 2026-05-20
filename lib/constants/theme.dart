import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF13131A);
  static const surfaceElevated = Color(0xFF1C1C26);
  static const surfaceBorder = Color(0xFF2A2A38);
  static const textPrimary = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF8888A8);
  static const textMuted = Color(0xFF55556A);
  static const accent = Color(0xFF7C6AF0);
  static const accentSoft = Color(0xFF2D2850);
  static const accentGlow = Color(0x207C6AF0);

  static const whatsapp = Color(0xFF25D366);
  static const whatsappSoft = Color(0xFF0D2B1A);
  static const instagram = Color(0xFFE1306C);
  static const instagramSoft = Color(0xFF2B0D1A);
  static const snapchat = Color(0xFFFFE400);
  static const snapchatSoft = Color(0xFF2B2700);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
          onSurface: textPrimary,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: accentSoft,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: textSecondary),
        ),
        dividerColor: surfaceBorder,
      );
}

class Sp {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class Rd {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));
  static const xl = BorderRadius.all(Radius.circular(24));
}
