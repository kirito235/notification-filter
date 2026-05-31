import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/notif_item.dart';
import '../services/filter_store.dart';
import '../services/focus_service.dart';
import 'filtered_screen.dart';
import 'all_notifs_screen.dart';
import 'filter_screen.dart';
import 'focus_screen.dart';
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
    RegExp(r'^\d+ new Snaps?$'),
    RegExp(r'^You have \d+ new'),
    RegExp(r'you may have new notifications', caseSensitive: false),
    RegExp(r'^Updating messages'), // FIX 2
  ];

  static const _summaryTitles = {
    'WA Business',
    'WhatsApp',
    'Instagram',
    'Snapchat',
    'Updating messages',
    'Updating messages…',
  };

  // FIX 5: WhatsApp system notification titles
  static const _waSystemTitles = {
    'Checking for messages…',
    'Checking for messages',
    'Ongoing call',
    'Incoming call',
    'Ringing…',
    'Ringing',
    'Connected',
    'Video call',
    'Voice call',
    'WhatsApp Web',
    'End-to-end encrypted',
    'Tap to return to call',
  };

  // FIX 4: Merge WA + WA Business — treat both as same app
  static const _waPackages = {'com.whatsapp', 'com.whatsapp.w4b'};

  @override
  void initState() {
    super.initState();
    _init();
    FocusService.instance.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    FocusService.instance.removeListener(_onFocusChanged);
    super.dispose();
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
      String title = data['title'] ?? '';
      final text = data['text'] ?? '';

      if (!AppInfo.isSupported(pkg)) return;
      if (DateTime.now().isBefore(appStartTime)) return;
      if (_isSummary(pkg, title, text)) return;

      // FIX 5: skip WA system notifications
      if (_waPackages.contains(pkg) && _waSystemTitles.contains(title)) return;
      if (_waPackages.contains(pkg) && _isWaSystemText(text)) return;

      // FIX 3: normalize Instagram title
      title = _normalizeTitle(pkg, title);

      if (_isDuplicate(pkg, title, text)) return;

      final allowed = store.isAllowed(pkg, title);
      final item = NotifItem(
        packageName: pkg,
        title: title,
        text: text,
        time: DateTime.now(),
        isAllowed: allowed,
      );

      if (FocusService.instance.isRunning) {
        if (allowed)
          FocusService.instance.recordAllowed();
        else
          FocusService.instance.recordSuppressed();
      }

      setState(() {
        allNotifs.insert(0, item);
        if (allowed) filteredNotifs.insert(0, item);
      });
    });
  }

  // FIX 3: "justvaibhavv: William" → "William"
  String _normalizeTitle(String pkg, String title) {
    if (pkg == 'com.instagram.android' && title.contains(': ')) {
      return title.substring(title.indexOf(': ') + 2).trim();
    }
    return title;
  }

  // FIX 5: WhatsApp system text patterns
  bool _isWaSystemText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('checking for messages')) return true;
    if (lower.contains('end-to-end encrypted')) return true;
    if (lower.contains('tap to return to call')) return true;
    return false;
  }

  bool _isSummary(String pkg, String title, String text) {
    if (_summaryTitles.contains(title) && text.isEmpty) return true;
    if (_summaryPatterns.any((p) => p.hasMatch(text))) return true;
    if (_summaryPatterns.any((p) => p.hasMatch(title))) return true;
    // FIX 2: Snapchat "Updating messages" as title
    if (pkg == 'com.snapchat.android' && title.startsWith('Updating'))
      return true;
    return false;
  }

  bool _isDuplicate(String pkg, String title, String text) {
    if (allNotifs.isEmpty) return false;
    final now = DateTime.now();
    return allNotifs.take(5).any((item) {
      final diff = now.difference(item.time).inSeconds;
      return diff < 5 &&
          item.packageName == pkg &&
          item.title == title &&
          item.text == text;
    });
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
          child: CircularProgressIndicator(
            color: AppTheme.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final focusSvc = FocusService.instance;
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
      const FocusScreen(),
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
                icon: _NavBadge(
                  count: filteredNotifs.length,
                  child: const Icon(Icons.shield_outlined, size: 22),
                ),
                selectedIcon: _NavBadge(
                  count: filteredNotifs.length,
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 22,
                    color: AppTheme.accent,
                  ),
                ),
                label: 'Filtered',
              ),
              NavigationDestination(
                icon: _NavBadge(
                  count: allNotifs.length,
                  child: const Icon(Icons.notifications_outlined, size: 22),
                ),
                selectedIcon: _NavBadge(
                  count: allNotifs.length,
                  child: const Icon(
                    Icons.notifications_rounded,
                    size: 22,
                    color: AppTheme.accent,
                  ),
                ),
                label: 'All',
              ),
              const NavigationDestination(
                icon: Icon(Icons.tune_outlined, size: 22),
                selectedIcon: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: AppTheme.accent,
                ),
                label: 'Filter',
              ),
              NavigationDestination(
                icon: focusSvc.isRunning
                    ? const _PulsingIcon()
                    : const Icon(Icons.timer_outlined, size: 22),
                selectedIcon: const Icon(
                  Icons.timer_rounded,
                  size: 22,
                  color: AppTheme.accent,
                ),
                label: 'Focus',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined, size: 22),
                selectedIcon: Icon(
                  Icons.settings_rounded,
                  size: 22,
                  color: AppTheme.accent,
                ),
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
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: AppTheme.accent,
      child: child,
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.timer_outlined, size: 22),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  const Color(0xFF25D366),
                  const Color(0xFF25D366).withOpacity(0.4),
                  _anim.value,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
