import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/notif_item.dart';
import '../services/whitelist_store.dart';
import '../widgets/notif_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/empty_state.dart';

class AllNotifsScreen extends StatefulWidget {
  final List<NotifItem> notifs;
  final VoidCallback onWhitelistAdded;
  final VoidCallback onClear;

  const AllNotifsScreen({
    super.key,
    required this.notifs,
    required this.onWhitelistAdded,
    required this.onClear,
  });

  @override
  State<AllNotifsScreen> createState() => _AllNotifsScreenState();
}

class _AllNotifsScreenState extends State<AllNotifsScreen> {
  String _filter = 'all';

  static const _filterOptions = {
    'all': 'All',
    'com.whatsapp.w4b': 'WA Business',
    'com.whatsapp': 'WhatsApp',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
  };

  List<NotifItem> get _filtered {
    if (_filter == 'all') return widget.notifs;
    return widget.notifs.where((n) => n.packageName == _filter).toList();
  }

  Future<void> _whitelist(NotifItem item) async {
    HapticFeedback.mediumImpact();
    await WhitelistStore.instance.addContact(item.packageName, item.title);
    widget.onWhitelistAdded();
    if (!mounted) return;
    final color = AppInfo.color(item.packageName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: Rd.md),
        margin: const EdgeInsets.all(Sp.md),
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                '"${item.title}" added to whitelist',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('All Notifications'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.surfaceBorder),
        ),
        actions: [
          if (widget.notifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onClear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(
                vertical: Sp.sm + 2, horizontal: Sp.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: Sp.sm),
                    child: AppChip(
                      label: e.value,
                      selected: _filter == e.key,
                      selectedColor: e.key == 'all'
                          ? AppTheme.accent
                          : AppInfo.color(e.key),
                      onTap: () => setState(() => _filter = e.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(height: 0.5, color: AppTheme.surfaceBorder),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    subtitle:
                        'Notifications from WhatsApp, Instagram, and Snapchat will appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Sp.md, Sp.md, Sp.md, Sp.xxl),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = _filtered[i];
                      return NotifCard(
                        item: item,
                        index: i,
                        onWhitelist:
                            WhitelistStore.instance.isSupported(item.packageName)
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
