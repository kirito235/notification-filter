import 'package:flutter/material.dart';
import '../models/notif_item.dart';
import '../services/filter_store.dart';
import '../services/focus_service.dart';
import '../models/focus_session.dart';
import '../constants/theme.dart';
import '../widgets/notif_card.dart';
import '../widgets/empty_state.dart';

class FilteredScreen extends StatelessWidget {
  final List<NotifItem> notifs;
  final VoidCallback onClear;
  final VoidCallback onFilterChanged;

  const FilteredScreen({
    super.key,
    required this.notifs,
    required this.onClear,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final store = FilterStore.instance;
    final focusSvc = FocusService.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: AppTheme.accentSoft, borderRadius: Rd.sm),
              child: const Icon(Icons.shield_rounded,
                  color: AppTheme.accent, size: 16),
            ),
            const SizedBox(width: Sp.sm),
            const Text('FilterNotif'),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => GestureDetector(
              onTap: () async {
                await store.setGlobalEnabled(!store.globalEnabled);
                onFilterChanged();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: Sp.sm),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: store.globalEnabled
                      ? AppTheme.accentSoft
                      : AppTheme.surfaceElevated,
                  borderRadius: Rd.md,
                  border: Border.all(
                    color: store.globalEnabled
                        ? AppTheme.accent.withOpacity(0.5)
                        : AppTheme.surfaceBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: store.globalEnabled
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      store.globalEnabled ? 'Active' : 'Paused',
                      style: TextStyle(
                        color: store.globalEnabled
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              onPressed: onClear,
            ),
        ],
      ),
      body: Column(
        children: [
          // Focus session banner
          ListenableBuilder(
            listenable: focusSvc,
            builder: (_, __) {
              if (!focusSvc.isActive) return const SizedBox.shrink();
              final session = focusSvc.session;
              final isPaused = session.status == FocusStatus.paused;
              return Container(
                margin: const EdgeInsets.fromLTRB(
                    Sp.md, Sp.md, Sp.md, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: Sp.md, vertical: Sp.sm + 2),
                decoration: BoxDecoration(
                  color: isPaused
                      ? AppTheme.surfaceElevated
                      : AppTheme.accentSoft,
                  borderRadius: Rd.lg,
                  border: Border.all(
                    color: isPaused
                        ? AppTheme.surfaceBorder
                        : AppTheme.accent.withOpacity(0.4),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPaused
                          ? Icons.pause_circle_outline_rounded
                          : Icons.timer_rounded,
                      color: isPaused
                          ? AppTheme.textMuted
                          : AppTheme.accent,
                      size: 16,
                    ),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Text(
                        isPaused
                            ? 'Focus paused · ${session.remainingFormatted} remaining'
                            : 'Focus active · ${session.remainingFormatted} remaining',
                        style: TextStyle(
                          color: isPaused
                              ? AppTheme.textSecondary
                              : AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Notification list
          Expanded(
            child: notifs.isEmpty
                ? EmptyState(
                    icon: Icons.shield_rounded,
                    title: 'All quiet',
                    subtitle: store.configs.values
                            .every((c) =>
                                c.allowlist.isEmpty && c.blocklist.isEmpty)
                        ? 'Add contacts to your filter lists\nto start filtering.'
                        : 'No filtered notifications yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Sp.md, Sp.md, Sp.md, Sp.xxl),
                    itemCount: notifs.length,
                    itemBuilder: (ctx, i) =>
                        NotifCard(item: notifs[i], index: i),
                  ),
          ),
        ],
      ),
    );
  }
}
