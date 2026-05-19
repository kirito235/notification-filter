import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime appStartTime = DateTime.now();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotifGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.deepPurpleAccent,
          surface: const Color(0xFF1A1A1A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

// ─── APP CONSTANTS ───────────────────────────────────────────────
class AppInfo {
  static const Map<String, String> names = {
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
    'android': 'Android System',
  };

  static const Map<String, Color> colors = {
    'com.whatsapp.w4b': Color(0xFF25D366),
    'com.whatsapp': Color(0xFF25D366),
    'com.instagram.android': Color(0xFFE1306C),
    'com.snapchat.android': Color(0xFFFFFC00),
    'android': Colors.grey,
  };

  static String name(String pkg) => names[pkg] ?? pkg;
  static Color color(String pkg) => colors[pkg] ?? Colors.blue;
}

// ─── NOTIFICATION MODEL ──────────────────────────────────────────
class NotifItem {
  final String packageName;
  final String title;
  final String text;
  final DateTime time;

  NotifItem({
    required this.packageName,
    required this.title,
    required this.text,
    required this.time,
  });
}

// ─── WHITELIST STORE ─────────────────────────────────────────────
class WhitelistStore {
  static Map<String, Set<String>> whitelist = {
    'com.whatsapp.w4b': {},
    'com.whatsapp': {},
    'com.instagram.android': {},
    'com.snapchat.android': {},
  };

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pkg in whitelist.keys) {
      final saved = prefs.getStringList(pkg);
      if (saved != null) whitelist[pkg] = saved.toSet();
    }
  }

  static Future<void> save(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(pkg, whitelist[pkg]!.toList());
  }

  static Future<void> syncToNative() async {
    const channel = MethodChannel('whitelist_sync');
    final Map<String, List<String>> data = {};
    for (final entry in whitelist.entries) {
      data[entry.key] = entry.value.toList();
    }
    try {
      await channel.invokeMethod('sync', data);
    } catch (e) {
      debugPrint('Whitelist sync error: $e');
    }
  }

  static Future<void> addContact(String pkg, String name) async {
    if (!whitelist.containsKey(pkg)) whitelist[pkg] = {};
    whitelist[pkg]!.add(name);
    await save(pkg);
    await syncToNative();
  }

  static Future<void> removeContact(String pkg, String name) async {
    whitelist[pkg]?.remove(name);
    await save(pkg);
    await syncToNative();
  }

  static bool isAllowed(String pkg, String title) {
    if (!whitelist.containsKey(pkg)) return false;
    final contacts = whitelist[pkg]!;
    if (contacts.isEmpty) return false;
    return contacts.any((name) =>
        title.toLowerCase().contains(name.toLowerCase()));
  }
}

// ─── SPLASH PAGE ─────────────────────────────────────────────────
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => seen ? const RootPage() : const OnboardingPage(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.deepPurple.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.shield,
                    color: Colors.deepPurple, size: 56),
              ),
              const SizedBox(height: 24),
              const Text('NotifGuard',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text('Your notifications, your rules.',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ONBOARDING PAGE ─────────────────────────────────────────────
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> pages = [
    {
      'icon': Icons.notifications_off,
      'color': Colors.redAccent,
      'title': 'Tired of notification spam?',
      'subtitle':
          'Group chats, promotional messages, and random notifications constantly interrupt your day.',
    },
    {
      'icon': Icons.shield,
      'color': Colors.deepPurple,
      'title': 'NotifGuard filters for you',
      'subtitle':
          'Only notifications from people you care about get through. Everything else is silently suppressed.',
    },
    {
      'icon': Icons.tune,
      'color': Colors.green,
      'title': 'You control the whitelist',
      'subtitle':
          'Add contacts from WhatsApp, Instagram, and Snapchat. One tap to whitelist anyone from the notification log.',
    },
    {
      'icon': Icons.lock,
      'color': Colors.orange,
      'title': 'Private & local',
      'subtitle':
          'Everything stays on your device. No servers, no accounts, no data collection. Ever.',
    },
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const PermissionPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: pages.length,
                itemBuilder: (ctx, i) {
                  final page = pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: (page['color'] as Color).withOpacity(0.4),
                                width: 2),
                          ),
                          child: Icon(page['icon'] as IconData,
                              color: page['color'] as Color, size: 60),
                        ),
                        const SizedBox(height: 40),
                        Text(page['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text(page['subtitle'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 15,
                                height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? Colors.deepPurple
                      : Colors.grey[700],
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: Text('Skip',
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < pages.length - 1) {
                        _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      } else {
                        _finish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentPage < pages.length - 1 ? 'Next' : 'Get Started',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── PERMISSION PAGE ─────────────────────────────────────────────
class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  static const platform = MethodChannel('notifications');

  Future<void> _openSettings(BuildContext context) async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.notifications_active,
                    color: Colors.orange, size: 52),
              ),
              const SizedBox(height: 32),
              const Text('One Permission Needed',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                'NotifGuard needs Notification Access to read and filter notifications from WhatsApp, Instagram, and Snapchat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[400], fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Your data never leaves your device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  label: const Text('Open Notification Settings',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _openSettings(context),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const RootPage())),
                  child: Text('I already gave permission',
                      style: TextStyle(color: Colors.grey[400])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ROOT PAGE ───────────────────────────────────────────────────
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const platform = MethodChannel('notifications');
  int _currentIndex = 0;
  bool _loaded = false;
  bool _filterEnabled = true;

  final List<NotifItem> allNotifs = [];
  final List<NotifItem> filteredNotifs = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await WhitelistStore.load();
    await WhitelistStore.syncToNative();
    setState(() => _loaded = true);

    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final data = Map<String, String>.from(call.arguments);
        final pkg = data['packageName'] ?? '';
        final title = data['title'] ?? '';
        final text = data['text'] ?? '';

        final now = DateTime.now();
        if (now.isBefore(appStartTime)) return;
        if (_isSummaryNotification(pkg, title, text)) return;
        if (_isDuplicate(pkg, title)) return;

        final item = NotifItem(
          packageName: pkg,
          title: title,
          text: text,
          time: now,
        );

        setState(() {
          allNotifs.insert(0, item);
          if (WhitelistStore.isAllowed(pkg, title)) {
            filteredNotifs.insert(0, item);
          }
        });
      }
    });
  }

  bool _isSummaryNotification(String pkg, String title, String text) {
    if (text.contains('messages from') && text.contains('chats')) return true;
    if (title == 'WA Business' || title == 'WhatsApp') return true;
    if (pkg == 'com.snapchat.android' && text.contains('new snap')) return true;
    if (pkg == 'com.instagram.android' && title == 'Instagram') return true;
    if (pkg == 'android') return true;
    return false;
  }

  bool _isDuplicate(String pkg, String title) {
    if (allNotifs.isEmpty) return false;
    final last = allNotifs.first;
    final diff = DateTime.now().difference(last.time).inSeconds;
    return last.packageName == pkg && last.title == title && diff < 2;
  }

  void _onWhitelistAdded() {
    setState(() {
      filteredNotifs.clear();
      for (final item in allNotifs) {
        if (WhitelistStore.isAllowed(item.packageName, item.title)) {
          filteredNotifs.add(item);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      FilteredPage(
        notifs: filteredNotifs,
        filterEnabled: _filterEnabled,
        onToggleFilter: (val) => setState(() => _filterEnabled = val),
        onClear: () => setState(() => filteredNotifs.clear()),
      ),
      AllNotifsPage(
        notifs: allNotifs,
        onWhitelistAdded: _onWhitelistAdded,
        onClear: () => setState(() => allNotifs.clear()),
      ),
      WhitelistPage(onChanged: _onWhitelistAdded),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1A1A),
        indicatorColor: Colors.deepPurple,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: filteredNotifs.isNotEmpty,
              label: Text('${filteredNotifs.length}'),
              child: const Icon(Icons.filter_alt_outlined, color: Colors.grey),
            ),
            selectedIcon: Badge(
              isLabelVisible: filteredNotifs.isNotEmpty,
              label: Text('${filteredNotifs.length}'),
              child: const Icon(Icons.filter_alt, color: Colors.white),
            ),
            label: 'Filtered',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: allNotifs.isNotEmpty,
              label: Text('${allNotifs.length}'),
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.grey),
            ),
            selectedIcon: Badge(
              isLabelVisible: allNotifs.isNotEmpty,
              label: Text('${allNotifs.length}'),
              child:
                  const Icon(Icons.notifications, color: Colors.white),
            ),
            label: 'All',
          ),
          const NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined, color: Colors.grey),
            selectedIcon:
                Icon(Icons.manage_accounts, color: Colors.white),
            label: 'Whitelist',
          ),
        ],
      ),
    );
  }
}

// ─── NOTIFICATION CARD ───────────────────────────────────────────
class NotifCard extends StatelessWidget {
  final NotifItem item;
  final VoidCallback? onWhitelist;

  const NotifCard({super.key, required this.item, this.onWhitelist});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = AppInfo.color(item.packageName);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(AppInfo.name(item.packageName),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                Text(_timeAgo(item.time),
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(item.text,
                style:
                    TextStyle(color: Colors.grey[400], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (onWhitelist != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onWhitelist,
                  icon: Icon(Icons.add_circle_outline,
                      color: color, size: 16),
                  label: Text('+ Whitelist',
                      style: TextStyle(color: color, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    backgroundColor: color.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ─── FILTERED PAGE ───────────────────────────────────────────────
class FilteredPage extends StatelessWidget {
  final List<NotifItem> notifs;
  final bool filterEnabled;
  final ValueChanged<bool> onToggleFilter;
  final VoidCallback onClear;

  const FilteredPage({
    super.key,
    required this.notifs,
    required this.filterEnabled,
    required this.onToggleFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('NotifGuard',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          Row(
            children: [
              Text(filterEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                      color: filterEnabled ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Switch(
                value: filterEnabled,
                onChanged: onToggleFilter,
                activeColor: Colors.deepPurple,
              ),
            ],
          ),
          if (notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.grey),
              onPressed: onClear,
            ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield,
                      color: Colors.deepPurple.withOpacity(0.4), size: 72),
                  const SizedBox(height: 16),
                  const Text('All quiet.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Whitelisted notifications\nwill appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: notifs.length,
              itemBuilder: (ctx, i) => NotifCard(item: notifs[i]),
            ),
    );
  }
}

// ─── ALL NOTIFICATIONS PAGE ──────────────────────────────────────
class AllNotifsPage extends StatefulWidget {
  final List<NotifItem> notifs;
  final VoidCallback onWhitelistAdded;
  final VoidCallback onClear;

  const AllNotifsPage({
    super.key,
    required this.notifs,
    required this.onWhitelistAdded,
    required this.onClear,
  });

  @override
  State<AllNotifsPage> createState() => _AllNotifsPageState();
}

class _AllNotifsPageState extends State<AllNotifsPage> {
  String _filter = 'all';

  final Map<String, String> filterOptions = {
    'all': 'All',
    'com.whatsapp.w4b': 'WA Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  Future<void> _whitelist(NotifItem item) async {
    final pkg = item.packageName;
    if (!WhitelistStore.whitelist.containsKey(pkg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This app is not supported for filtering.')),
      );
      return;
    }
    await WhitelistStore.addContact(pkg, item.title);
    widget.onWhitelistAdded();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppInfo.color(pkg),
        content: Text(
          '"${item.title}" added to ${AppInfo.name(pkg)} whitelist!',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<NotifItem> get _filtered {
    if (_filter == 'all') return widget.notifs;
    return widget.notifs
        .where((n) => n.packageName == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('All Notifications',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (widget.notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.grey),
              onPressed: widget.onClear,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: filterOptions.entries.map((entry) {
                  final isSelected = _filter == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 12)),
                      selected: isSelected,
                      selectedColor: Colors.deepPurple,
                      backgroundColor: const Color(0xFF2A2A2A),
                      onSelected: (_) =>
                          setState(() => _filter = entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('No notifications yet.',
                        style: TextStyle(color: Colors.grey[600])),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = _filtered[i];
                      final isSupported = WhitelistStore.whitelist
                          .containsKey(item.packageName);
                      return NotifCard(
                        item: item,
                        onWhitelist: isSupported
                            ? () => _whitelist(item)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── WHITELIST PAGE ──────────────────────────────────────────────
class WhitelistPage extends StatefulWidget {
  final VoidCallback onChanged;
  const WhitelistPage({super.key, required this.onChanged});
  @override
  State<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends State<WhitelistPage> {
  static const contactsChannel = MethodChannel('contacts');
  String selectedApp = 'com.whatsapp.w4b';
  final TextEditingController _controller = TextEditingController();

  final Map<String, String> appNames = {
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  Future<void> _pickContact() async {
    try {
      final String? name =
          await contactsChannel.invokeMethod('pickContact');
      if (name != null && name.isNotEmpty) {
        await WhitelistStore.addContact(selectedApp, name);
        widget.onChanged();
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open contacts: $e')),
      );
    }
  }

  Future<void> _addManual() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await WhitelistStore.addContact(selectedApp, name);
    widget.onChanged();
    setState(() => _controller.clear());
  }

  Future<void> _remove(String name) async {
    await WhitelistStore.removeContact(selectedApp, name);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contacts =
        WhitelistStore.whitelist[selectedApp]?.toList() ?? [];
    final color = AppInfo.color(selectedApp);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Whitelist',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: appNames.entries.map((entry) {
                  final isSelected = selectedApp == entry.key;
                  final c = AppInfo.color(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value,
                          style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 12)),
                      selected: isSelected,
                      selectedColor: c,
                      backgroundColor: const Color(0xFF2A2A2A),
                      onSelected: (_) =>
                          setState(() => selectedApp = entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type name manually...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: color.withOpacity(0.4))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color)),
                    ),
                    onSubmitted: (_) => _addManual(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  child: const Text('Add',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (selectedApp == 'com.whatsapp.w4b' ||
              selectedApp == 'com.whatsapp')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.contacts, color: color),
                  label: Text('Pick from Contacts',
                      style: TextStyle(color: color)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _pickContact,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              selectedApp == 'com.instagram.android' ||
                      selectedApp == 'com.snapchat.android'
                  ? '💡 Go to All tab → find a notification → tap "+ Whitelist"'
                  : 'Name must match how it appears in notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_outlined,
                            color: Colors.grey[700], size: 48),
                        const SizedBox(height: 12),
                        Text('No contacts added yet.',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: contacts.length,
                    itemBuilder: (ctx, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.person,
                            color: color, size: 20),
                        title: Text(contacts[i],
                            style: const TextStyle(
                                color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.red, size: 18),
                          onPressed: () => _remove(contacts[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}