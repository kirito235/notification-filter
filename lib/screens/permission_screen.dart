import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import 'root_screen.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});
  static const _platform = MethodChannel('notifications');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Sp.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF2B1F00),
                  borderRadius: Rd.xl,
                  border: Border.all(
                      color: const Color(0xFFFFB340).withOpacity(0.3)),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Color(0xFFFFB340), size: 44),
              ),
              const SizedBox(height: Sp.xl),
              const Text(
                'One permission needed',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.md),
              const Text(
                'FilterNotif needs Notification Access to read and silently remove notifications from people not on your whitelist.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Sp.lg),
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: Rd.lg,
                  border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: AppTheme.textMuted, size: 16),
                    const SizedBox(width: Sp.sm),
                    const Expanded(
                      child: Text(
                        'Your data never leaves your device.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('Open Notification Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    try {
                      await _platform.invokeMethod('openNotificationSettings');
                    } catch (_) {}
                  },
                ),
              ),
              const SizedBox(height: Sp.md),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RootScreen()),
                  ),
                  child: const Text(
                    'I already gave permission',
                    style: TextStyle(
                        color: AppTheme.textMuted, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
