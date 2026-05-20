import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import 'onboarding_screen.dart';
import 'root_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOutBack)));

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.easeOut)));

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOut)));

    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            seen ? const RootScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: Rd.xl,
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.4), width: 1),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: AppTheme.accent,
                    size: 44,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.lg),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  const Text(
                    'FilterNotif',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    'Your notifications, your rules.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
