import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/notif_item.dart';
import '../models/app_filter_config.dart';
import '../services/filter_store.dart';
import '../widgets/notif_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/empty_state.dart';

class AllNotifsScreen extends StatefulWidget {
  final List<NotifItem> notifs;
  final VoidCallback onFilterChanged;
  final VoidCallback onClear;

  const AllNotifsScreen({
    super.key,
    required this.notifs,
    required this.onFilterChanged,
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

  // Adds to allowlist OR blocklist depending on current mode for that app
  Future<void> _addToList(NotifItem item, FilterMode targetMode) async {
    HapticFeedback.mediumImpact();
    final store = FilterStore.instance;
    final pkg = item.packageName;

    if (targetMode == FilterMode.allowlist) {
      await store.addToAllowlist(pkg, item.title);
    } else {
      await store.addToBlocklist(pkg, item.title);
    }
    widget.onFilterChanged();
    if (!mounted) return;

    final color = AppInfo.color(pkg);
    final label = targetMode == FilterMode.allowlist ? 'allowlist' : 'blocklist';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: Rd.md),
      margin: const EdgeInsets.all(Sp.md),
      content: Row(
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text('"${item.title}" added to $label',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    ));
  }

  void _showAddOptions(BuildContext context, NotifItem item) {
    final store = FilterStore.instance;
    final currentMode = store.modeFor(item.packageName);
    final color = AppInfo.color(item.packageName);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.surfaceBorder, borderRadius: Rd.sm)),
            ),
            const SizedBox(height: Sp.md),
            Text(item.title,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w600)),
            Text(AppInfo.name(item.packageName),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: Sp.lg),
            // Add to allowlist
            _SheetOption(
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF25D366),
              title: 'Add to Allowlist',
              subtitle: 'Always receive notifications from this contact',
              isHighlighted: currentMode == FilterMode.allowlist,
              onTap: () {
                Navigator.pop(context);
                _addToList(item, FilterMode.allowlist);
              },
            ),
            const SizedBox(height: Sp.sm),
            // Add to blocklist
            _SheetOption(
              icon: Icons.block_rounded,
              color: Colors.redAccent,
              title: 'Add to Blocklist',
              subtitle: 'Never receive notifications from this contact',
              isHighlighted: currentMode == FilterMode.blocklist,
              onTap: () {
                Navigator.pop(context);
                _addToList(item, FilterMode.blocklist);
              },
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
          Expanded(
            child: _filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    subtitle:
                        'Notifications from WhatsApp, Instagram and Snapchat will appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Sp.md, Sp.md, Sp.md, Sp.xxl),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = _filtered[i];
                      final isSupported =
                          FilterStore.instance.isSupported(item.packageName);
                      return NotifCard(
                        item: item,
                        index: i,
                        onWhitelist: isSupported
                            ? () => _showAddOptions(context, item)
                            : null,
                        whitelistLabel: 'Add to list',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: isHighlighted ? color.withOpacity(0.08) : AppTheme.surfaceElevated,
          borderRadius: Rd.lg,
          border: Border.all(
            color: isHighlighted ? color.withOpacity(0.4) : AppTheme.surfaceBorder,
            width: isHighlighted ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), borderRadius: Rd.sm),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isHighlighted ? color : AppTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isHighlighted)
              Icon(Icons.check_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
