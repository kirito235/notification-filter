import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../services/whitelist_store.dart';
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
    final store = WhitelistStore.instance;

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

          // Per-app toggles
          SettingsGroup(
            header: 'Per-App Filtering',
            tiles: AppInfo.names.entries.map((e) {
              final color = AppInfo.color(e.key);
              return SettingsTile(
                icon: AppInfo.icon(e.key),
                iconColor: color,
                title: e.value,
                subtitle:
                    '${store.whitelist[e.key]?.length ?? 0} contacts whitelisted',
                trailing: Switch(
                  value: store.appEnabled[e.key] ?? true,
                  activeColor: color,
                  onChanged: (val) async {
                    HapticFeedback.selectionClick();
                    await store.setAppEnabled(e.key, val);
                    widget.onChanged();
                    setState(() {});
                  },
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
                subtitle: 'Open system notification access settings',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textMuted, size: 14),
                onTap: () async {
                  try {
                    await _platform
                        .invokeMethod('openNotificationSettings');
                  } catch (_) {}
                },
              ),
            ],
          ),

          // Battery
          SettingsGroup(
            header: 'Battery',
            tiles: [
              SettingsTile(
                icon: Icons.battery_saver_rounded,
                iconColor: const Color(0xFF4ADE80),
                title: 'Battery optimization',
                subtitle:
                    'Disable battery optimization to keep filtering active',
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.textMuted, size: 14),
                onTap: () async {
                  try {
                    await _platform
                        .invokeMethod('openBatterySettings');
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
