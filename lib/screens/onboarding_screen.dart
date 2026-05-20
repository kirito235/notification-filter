import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import 'permission_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      icon: Icons.notifications_off_rounded,
      color: Color(0xFFE1306C),
      softColor: Color(0xFF2B0D1A),
      title: 'Tired of notification spam?',
      subtitle: 'Group chats, promos, and random pings interrupt your focus every few minutes.',
    ),
    _OnboardPage(
      icon: Icons.shield_rounded,
      color: AppTheme.accent,
      softColor: AppTheme.accentSoft,
      title: 'FilterNotif filters for you',
      subtitle: 'Only hear from people you care about. Everyone else is silently blocked.',
    ),
    _OnboardPage(
      icon: Icons.touch_app_rounded,
      color: Color(0xFF25D366),
      softColor: Color(0xFF0D2B1A),
      title: 'One tap to whitelist',
      subtitle: 'See a notification in your log, tap to whitelist that person. Done.',
    ),
    _OnboardPage(
      icon: Icons.lock_rounded,
      color: Color(0xFFFFB340),
      softColor: Color(0xFF2B2200),
      title: '100% private, always',
      subtitle: 'Everything lives on your device. No servers, no tracking, no accounts.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PermissionScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 14)),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, Sp.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _page == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? AppTheme.accent
                              : AppTheme.surfaceBorder,
                          borderRadius: Rd.sm,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: Sp.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_page < _pages.length - 1) {
                          _pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic);
                        } else {
                          _finish();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: Rd.lg),
                        elevation: 0,
                      ),
                      child: Text(
                        _page < _pages.length - 1 ? 'Continue' : 'Get Started',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
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

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color softColor;
  final String title;
  final String subtitle;

  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: Rd.xl,
              border: Border.all(
                  color: color.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: Sp.xl),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Sp.md),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
