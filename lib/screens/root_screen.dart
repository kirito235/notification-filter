import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/notif_item.dart';
import '../services/filter_store.dart';
import 'filtered_screen.dart';
import 'all_notifs_screen.dart';
import 'filter_screen.dart';
import 'settings_screen.dart';

final DateTime appStartTime = DateTime.now();

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  static const _platform = MethodChannel('notifications');
  int _tab = 0;
  bool _loaded = false;

  final List<NotifItem> allNotifs = [];
  final List<NotifItem> filteredNotifs = [];

  static final _summaryPatterns = [
    RegExp(r'\d+ messages from \d+ chats'),
    RegExp(r'\d+ new messages'),
  ];
  static const _summaryTitles = {'WA Business', 'WhatsApp', 'Instagram', 'Snapchat'};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final store = FilterStore.instance;
    await store.load();
    await store.syncToNative();
    setState(() => _loaded = true);

    _platform.setMethodCallHandler((call) async {
      if (call.method != 'onNotification') return;
      final data = Map<String, String>.from(call.arguments);
      final pkg = data['packageName'] ?? '';
      final title = data['title'] ?? '';
      final text = data['text'] ?? '';

      if (!AppInfo.isSupported(pkg)) return;
      if (DateTime.now().isBefore(appStartTime)) return;
      if (_isSummary(title, text)) return;
      if (_isDuplicate(pkg, title)) return;

      final allowed = store.isAllowed(pkg, title);
      final item = NotifItem(
        packageName: pkg,
        title: title,
        text: text,
        time: DateTime.now(),
        isAllowed: allowed,
      );

      setState(() {
        allNotifs.insert(0, item);
        if (allowed) filteredNotifs.insert(0, item);
      });
    });
  }

  bool _isSummary(String title, String text) {
    if (_summaryTitles.contains(title) && text.isEmpty) return true;
    return _summaryPatterns.any((p) => p.hasMatch(text));
  }

  bool _isDuplicate(String pkg, String title) {
    if (allNotifs.isEmpty) return false;
    final last = allNotifs.first;
    final diff = DateTime.now().difference(last.time).inSeconds;
    return last.packageName == pkg && last.title == title && diff < 2;
  }

  void _onFilterChanged() {
    final store = FilterStore.instance;
    setState(() {
      filteredNotifs.clear();
      for (final item in allNotifs) {
        if (store.isAllowed(item.packageName, item.title)) {
          filteredNotifs.add(item);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
        ),
      );
    }

    final pages = [
      FilteredScreen(
        notifs: filteredNotifs,
        onClear: () => setState(() => filteredNotifs.clear()),
        onFilterChanged: _onFilterChanged,
      ),
      AllNotifsScreen(
        notifs: allNotifs,
        onFilterChanged: _onFilterChanged,
        onClear: () => setState(() => allNotifs.clear()),
      ),
      FilterScreen(onChanged: _onFilterChanged),
      SettingsScreen(onChanged: _onFilterChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 0.5, color: AppTheme.surfaceBorder),
          NavigationBar(
            backgroundColor: AppTheme.surface,
            indicatorColor: AppTheme.accentSoft,
            selectedIndex: _tab,
            height: 64,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _tab = i);
            },
            destinations: [
              NavigationDestination(
                icon: _NavBadge(count: filteredNotifs.length,
                    child: const Icon(Icons.shield_outlined, size: 22)),
                selectedIcon: _NavBadge(count: filteredNotifs.length,
                    child: const Icon(Icons.shield_rounded, size: 22, color: AppTheme.accent)),
                label: 'Filtered',
              ),
              NavigationDestination(
                icon: _NavBadge(count: allNotifs.length,
                    child: const Icon(Icons.notifications_outlined, size: 22)),
                selectedIcon: _NavBadge(count: allNotifs.length,
                    child: const Icon(Icons.notifications_rounded, size: 22, color: AppTheme.accent)),
                label: 'All',
              ),
              const NavigationDestination(
                icon: Icon(Icons.tune_outlined, size: 22),
                selectedIcon: Icon(Icons.tune_rounded, size: 22, color: AppTheme.accent),
                label: 'Filter',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined, size: 22),
                selectedIcon: Icon(Icons.settings_rounded, size: 22, color: AppTheme.accent),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const _NavBadge({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10)),
      backgroundColor: AppTheme.accent,
      child: child,
    );
  }
}
