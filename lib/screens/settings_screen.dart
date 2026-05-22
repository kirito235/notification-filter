import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/app_filter_config.dart';
import '../services/filter_store.dart';
import '../services/focus_service.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const SettingsScreen({super.key, required this.onChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _platform = MethodChannel('notifications');

  @override
  Widget build(BuildContext context) {
    final store = FilterStore.instance;
    final focusSvc = FocusService.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.surfaceBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Sp.xxl),
        children: [
          // Focus status card
          ListenableBuilder(
            listenable: focusSvc,
            builder: (_, __) {
              if (!focusSvc.isActive) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 0),
                child: Container(
                  padding: const EdgeInsets.all(Sp.md),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: Rd.lg,
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.4), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_rounded,
                          color: AppTheme.accent, size: 18),
                      const SizedBox(width: Sp.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Focus session active',
                                style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              '${focusSvc.session.remainingFormatted} remaining · allowlist mode enforced',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Master switch
          SettingsGroup(
            header: 'Filtering',
            tiles: [
              SettingsTile(
                icon: Icons.shield_rounded,
                iconColor: AppTheme.accent,
                title: 'Enable filtering',
                subtitle: 'Master switch — pauses all notification filtering',
                trailing: Switch(
                  value: store.globalEnabled,
                  activeColor: AppTheme.accent,
                  onChanged: (val) async {
                    HapticFeedback.selectionClick();
                    await store.setGlobalEnabled(val);
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          // FIX 4: Per-app using AppInfo.names (3 entries, not 4)
          SettingsGroup(
            header: 'Per-App Filtering',
            tiles: AppInfo.names.entries.map((e) {
              final color = AppInfo.color(e.key);
              final config = store.configs[e.key];
              final mode = config?.mode ?? FilterMode.allowlist;
              final count = mode == FilterMode.allowlist
                  ? config?.allowlist.length ?? 0
                  : config?.blocklist.length ?? 0;
              final modeLabel =
                  mode == FilterMode.allowlist ? 'Allowlist' : 'Blocklist';

              return SettingsTile(
                icon: AppInfo.icon(e.key),
                iconColor: color,
                title: e.value,
                subtitle: '$count contacts · $modeLabel mode',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mode == FilterMode.allowlist
                            ? const Color(0xFF25D366).withOpacity(0.12)
                            : Colors.redAccent.withOpacity(0.12),
                        borderRadius: Rd.sm,
                      ),
                      child: Text(
                        modeLabel,
                        style: TextStyle(
                          color: mode == FilterMode.allowlist
                              ? const Color(0xFF25D366)
                              : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Switch(
                      value: store.appEnabled[e.key] ?? true,
                      activeColor: color,
                      onChanged: (val) async {
                        HapticFeedback.selectionClick();
                        await store.setAppEnabled(e.key, val);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Permissions
          SettingsGroup(
            header: 'Permissions',
            tiles: [
              SettingsTile(
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.orange,
                title: 'Notification access',
                subtitle: 'Required for filtering to work',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textMuted, size: 14),
                onTap: () async {
                  try {
                    await _platform.invokeMethod('openNotificationSettings');
                  } catch (_) {}
                },
              ),
              SettingsTile(
                icon: Icons.battery_saver_rounded,
                iconColor: const Color(0xFF4ADE80),
                title: 'Battery optimization',
                subtitle: 'Disable to keep filtering active in background',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textMuted, size: 14),
                onTap: () async {
                  try {
                    await _platform.invokeMethod('openBatterySettings');
                  } catch (_) {}
                },
              ),
            ],
          ),

          // About
          SettingsGroup(
            header: 'About',
            tiles: [
              SettingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.textMuted,
                title: 'FilterNotif',
                subtitle: 'Version 1.0.0',
                trailing: null,
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppTheme.textMuted,
                title: 'Privacy policy',
                subtitle: 'All data stays on your device. No tracking.',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textMuted, size: 14),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
