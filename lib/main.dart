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
      title: 'Notification Filter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RootPage(),
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

  static bool isAllowed(String pkg, String title) {
    if (!whitelist.containsKey(pkg)) return false;
    final contacts = whitelist[pkg]!;
    if (contacts.isEmpty) return false;
    return contacts.any((name) =>
        title.toLowerCase().contains(name.toLowerCase()));
  }
}

// ─── ROOT PAGE (Bottom Nav) ──────────────────────────────────────
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const platform = MethodChannel('notifications');
  int _currentIndex = 0;
  bool _loaded = false;

  // Shared notification lists
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

        // Fix 1 — ignore notifications that arrived before app started
        final now = DateTime.now();
        if (now.isBefore(appStartTime)) return;

        // Fix 2 — ignore summary notifications
        if (_isSummaryNotification(pkg, title, text)) return;

        // Fix 2 — ignore duplicates (same pkg + title within 2 seconds)
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
    // WhatsApp summary: "X messages from Y chats"
    if (text.contains('messages from') && text.contains('chats')) return true;
    // WhatsApp summary title
    if (title == 'WA Business' || title == 'WhatsApp') return true;
    // Snapchat batch: "You have X new snaps"
    if (pkg == 'com.snapchat.android' && text.contains('new snap')) return true;
    // Instagram batch
    if (pkg == 'com.instagram.android' && title == 'Instagram') return true;
    // Android system notifications
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
    // Recheck all notifications against updated whitelist
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
              child: const Icon(Icons.notifications_outlined, color: Colors.grey),
            ),
            selectedIcon: Badge(
              isLabelVisible: allNotifs.isNotEmpty,
              label: Text('${allNotifs.length}'),
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            label: 'All',
          ),
          const NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined, color: Colors.grey),
            selectedIcon: Icon(Icons.manage_accounts, color: Colors.white),
            label: 'Whitelist',
          ),
        ],
      ),
    );
  }
}

// ─── NOTIFICATION CARD (reusable) ────────────────────────────────
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
            // Top row — app name + time
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
                  child: Text(
                    AppInfo.name(item.packageName),
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Text(_timeAgo(item.time),
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(item.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 4),
            // Text
            Text(item.text,
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            // Whitelist button
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
  final VoidCallback onClear;

  const FilteredPage(
      {super.key, required this.notifs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Filtered',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: onClear,
            ),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text('No filtered notifications yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    'Go to All tab → tap "+ Whitelist"\non any notification to add contacts.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey[700], fontSize: 13),
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
        const SnackBar(content: Text('This app is not supported for filtering.')),
      );
      return;
    }

    await WhitelistStore.addContact(pkg, item.title);
    widget.onWhitelistAdded();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppInfo.color(pkg),
        content: Text(
          '"${item.title}" added to ${AppInfo.name(pkg)} whitelist!',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
        backgroundColor: Colors.deepPurple,
        title: const Text('All Notifications',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (widget.notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: widget.onClear,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
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

          // Notification list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No notifications yet.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
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
                        onWhitelist:
                            isSupported ? () => _whitelist(item) : null,
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
        backgroundColor: Colors.deepPurple,
        title: const Text('Whitelist',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // App selector
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

          // Manual input
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
                          borderSide:
                              BorderSide(color: color.withOpacity(0.4))),
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

          // Contact picker (WhatsApp only)
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

          // Hint
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              selectedApp == 'com.instagram.android' ||
                      selectedApp == 'com.snapchat.android'
                  ? 'Tip: Go to All tab, find a notification and tap "+ Whitelist" to add automatically.'
                  : 'Add the name as it appears in notifications, or pick from contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          // Contact list
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text('No contacts added yet.',
                        style: TextStyle(color: Colors.grey[600])),
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
                        leading:
                            Icon(Icons.person, color: color, size: 20),
                        title: Text(contacts[i],
                            style:
                                const TextStyle(color: Colors.white)),
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