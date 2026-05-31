import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../constants/theme.dart';
import '../models/focus_session.dart';
import '../services/focus_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _selectedPreset = 1; // 25 min default
  Duration _customDuration = const Duration(minutes: 25);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Listen for completion
    FocusService.instance.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (FocusService.instance.session.status == FocusStatus.completed) {
      _showCompletionSheet();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    FocusService.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    await FocusService.instance.start(_customDuration);
  }

  Future<void> _stop() async {
    HapticFeedback.lightImpact();
    final confirmed = await _showStopDialog();
    if (confirmed == true) await FocusService.instance.stop();
  }

  Future<bool?> _showStopDialog() => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: Rd.xl),
      title: const Text(
        'End focus session?',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
      ),
      content: const Text(
        'Your progress will be lost and notifications will return to normal.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Keep going',
            style: TextStyle(color: AppTheme.accent),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'End session',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );

  void _showCompletionSheet() {
    final svc = FocusService.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: Rd.xl,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: Sp.lg),
            const Text(
              'Focus complete!',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sp.sm),
            Text(
              'Great work. You stayed focused.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: Sp.xl),
            // Stats row
            Row(
              children: [
                _StatCard(
                  label: 'Suppressed',
                  value: '${svc.suppressedDuringFocus}',
                  icon: Icons.block_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: Sp.md),
                _StatCard(
                  label: 'Allowed through',
                  value: '${svc.allowedDuringFocus}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF25D366),
                ),
              ],
            ),
            const SizedBox(height: Sp.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  FocusService.instance.acknowledgeComplete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = FocusService.instance;
    final session = svc.session;
    final isActive = svc.isActive;
    final isRunning = svc.isRunning;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Focus Session'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.surfaceBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          children: [
            const SizedBox(height: Sp.lg),

            // ── Circular timer ────────────────────────────────
            ListenableBuilder(
              listenable: svc,
              builder: (_, __) => _CircularTimer(
                progress: isActive ? session.progress : 0,
                timeText: isActive
                    ? session.remainingFormatted
                    : _formatDuration(_customDuration),
                isRunning: isRunning,
                pulseAnim: _pulseCtrl,
              ),
            ),

            const SizedBox(height: Sp.xxl),

            // ── Preset selector (only when idle) ─────────────
            if (!isActive) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Duration',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: Sp.sm),
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: FocusSession.presets.asMap().entries.map((e) {
                  final isSelected = _selectedPreset == e.key;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedPreset = e.key;
                        _customDuration = e.value.duration;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentSoft
                            : AppTheme.surfaceElevated,
                        borderRadius: Rd.lg,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accent.withOpacity(0.5)
                              : AppTheme.surfaceBorder,
                          width: isSelected ? 1 : 0.5,
                        ),
                      ),
                      child: Text(
                        e.value.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Sp.xl),
            ],

            // ── Session info banner (when active) ─────────────
            if (isActive) ...[
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: Rd.lg,
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: AppTheme.accent,
                      size: 16,
                    ),
                    const SizedBox(width: Sp.sm),
                    const Expanded(
                      child: Text(
                        'Allowlist mode active — only contacts on the allowlist can reach you.',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.xl),
            ],

            // ── Action buttons ────────────────────────────────
            if (!isActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Start Focus',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                    elevation: 0,
                  ),
                  onPressed: _start,
                ),
              ),

            if (isRunning)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.pause_rounded,
                        color: AppTheme.accent,
                      ),
                      label: const Text(
                        'Pause',
                        style: TextStyle(color: AppTheme.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: AppTheme.accent,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        FocusService.instance.pause();
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.stop_rounded,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Stop',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                      ),
                      onPressed: _stop,
                    ),
                  ),
                ],
              ),

            if (session.status == FocusStatus.paused)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Resume',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        FocusService.instance.resume();
                      },
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.stop_rounded,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Stop',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 0.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: Rd.lg),
                      ),
                      onPressed: _stop,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: Sp.xl),

            // ── How it works info ─────────────────────────────
            if (!isActive)
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: Rd.lg,
                  border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How focus sessions work',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Sp.sm),
                    _InfoRow(
                      icon: Icons.shield_rounded,
                      text:
                          'Forces allowlist mode on all apps during the session',
                    ),
                    _InfoRow(
                      icon: Icons.notifications_off_rounded,
                      text:
                          'Contacts not on the allowlist are silently suppressed',
                    ),
                    _InfoRow(
                      icon: Icons.bar_chart_rounded,
                      text:
                          'Shows a summary of suppressed notifications when done',
                    ),
                    _InfoRow(
                      icon: Icons.settings_backup_restore_rounded,
                      text:
                          'Your normal filter settings are restored automatically',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m}:00' : '$m:00';
  }
}

// ── Circular Timer ────────────────────────────────────────────────

class _CircularTimer extends StatelessWidget {
  final double progress;
  final String timeText;
  final bool isRunning;
  final Animation<double> pulseAnim;

  const _CircularTimer({
    required this.progress,
    required this.timeText,
    required this.isRunning,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        final glow = isRunning ? pulseAnim.value * 0.3 : 0.0;
        return Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isRunning
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.15 + glow),
                      blurRadius: 40 + glow * 20,
                      spreadRadius: 5 + glow * 5,
                    ),
                  ]
                : [],
          ),
          child: CustomPaint(
            painter: _TimerPainter(progress: progress),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRunning ? 'remaining' : 'duration',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;
  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.surfaceElevated
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppTheme.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerPainter old) => old.progress != progress;
}

// ── Helper widgets ────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: Rd.lg,
          border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: Sp.xs),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Sp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 14),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
