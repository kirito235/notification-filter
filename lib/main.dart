import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Filter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ─── WHITELIST STORE (global simple state) ───────────────────────
class WhitelistStore {
  static final Map<String, Set<String>> whitelist = {
    'com.whatsapp.w4b': {},
    'com.whatsapp': {},
    'com.instagram.android': {},
    'com.snapchat.android': {},
  };

  static bool isAllowed(String packageName, String title) {
    if (!whitelist.containsKey(packageName)) return false;
    final contacts = whitelist[packageName]!;
    if (contacts.isEmpty) return false;
    return contacts.any((name) =>
        title.toLowerCase().contains(name.toLowerCase()));
  }
}

// ─── HOME PAGE ───────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const platform = MethodChannel('notifications');
  List<Map<String, String>> logs = [];

  final Map<String, String> appNames = {
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
    'android': 'Android System',
  };

  final Map<String, Color> appColors = {
    'com.whatsapp.w4b': const Color(0xFF25D366),
    'com.whatsapp': const Color(0xFF25D366),
    'com.instagram.android': const Color(0xFFE1306C),
    'com.snapchat.android': const Color(0xFFFFFC00),
    'android': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotification') {
        final data = Map<String, String>.from(call.arguments);
        final pkg = data['packageName'] ?? '';
        final title = data['title'] ?? '';

        // Only show if whitelisted
        if (WhitelistStore.isAllowed(pkg, title)) {
          setState(() => logs.insert(0, data));
        }
      }
    });
  }

  String _friendlyApp(String pkg) => appNames[pkg] ?? pkg;
  Color _appColor(String pkg) => appColors[pkg] ?? Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Notification Filter',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Manage Whitelist',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const WhitelistPage())),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: () => setState(() => logs.clear()),
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off,
                      color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text('No whitelisted notifications yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.tune, color: Colors.deepPurple),
                    label: const Text('Add contacts to whitelist',
                        style: TextStyle(color: Colors.deepPurple)),
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WhitelistPage())),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                final log = logs[i];
                final pkg = log['packageName'] ?? '';
                final color = _appColor(pkg);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(
                        _friendlyApp(pkg)[0],
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(log['title'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(log['text'] ?? '',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(_friendlyApp(pkg),
                        style: TextStyle(color: color, fontSize: 10)),
                  ),
                );
              },
            ),
    );
  }
}

// ─── WHITELIST PAGE ──────────────────────────────────────────────
class WhitelistPage extends StatefulWidget {
  const WhitelistPage({super.key});
  @override
  State<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends State<WhitelistPage> {
  final Map<String, String> appNames = {
    'com.whatsapp.w4b': 'WhatsApp Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  final Map<String, Color> appColors = {
    'com.whatsapp.w4b': const Color(0xFF25D366),
    'com.whatsapp': const Color(0xFF25D366),
    'com.instagram.android': const Color(0xFFE1306C),
    'com.snapchat.android': const Color(0xFFFFFC00),
  };

  String selectedApp = 'com.whatsapp.w4b';
  final TextEditingController _controller = TextEditingController();

  void _addContact() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      WhitelistStore.whitelist[selectedApp]!.add(name);
      _controller.clear();
    });
  }

  void _removeContact(String name) {
    setState(() => WhitelistStore.whitelist[selectedApp]!.remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final contacts = WhitelistStore.whitelist[selectedApp]!.toList();
    final color = appColors[selectedApp]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Manage Whitelist',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  final c = appColors[entry.key]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value,
                          style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
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

          // Add contact input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter contact name or group...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: color),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: color.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: color),
                      ),
                    ),
                    onSubmitted: (_) => _addContact(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: const Text('Add',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Hint text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Add the exact name as it appears in the notification title.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          const SizedBox(height: 8),

          // Contact list
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Text(
                      'No contacts added yet.\nAdd a name above to start filtering.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
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
                        border:
                            Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        leading:
                            Icon(Icons.person, color: color, size: 20),
                        title: Text(contacts[i],
                            style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.red, size: 18),
                          onPressed: () => _removeContact(contacts[i]),
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