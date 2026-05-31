import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../models/app_filter_config.dart';
import '../services/filter_store.dart';
import '../widgets/app_chip.dart';
import '../widgets/empty_state.dart';

class FilterScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const FilterScreen({super.key, required this.onChanged});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen>
    with SingleTickerProviderStateMixin {
  static const _contactsChannel = MethodChannel('contacts');

  // FIX 4: Only 3 entries in UI (WA Business merged into WhatsApp)
  String _selectedApp = 'com.whatsapp';
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isWA => _selectedApp == 'com.whatsapp';
  bool get _isInstagram => _selectedApp == 'com.instagram.android';
  bool get _isSnapchat => _selectedApp == 'com.snapchat.android';

  Future<void> _pickContact() async {
    try {
      final String? name = await _contactsChannel.invokeMethod('pickContact');
      if (name != null && name.isNotEmpty) {
        final store = FilterStore.instance;
        final mode = store.modeFor(_selectedApp);
        if (mode == FilterMode.allowlist) {
          await store.addToAllowlist(_selectedApp, name);
        } else {
          await store.addToBlocklist(_selectedApp, name);
        }
        widget.onChanged();
        setState(() {});
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open contacts');
    }
  }

  Future<void> _addManual() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final store = FilterStore.instance;
    final mode = store.modeFor(_selectedApp);
    if (mode == FilterMode.allowlist) {
      await store.addToAllowlist(_selectedApp, name);
    } else {
      await store.addToBlocklist(_selectedApp, name);
    }
    widget.onChanged();
    setState(() => _ctrl.clear());
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();
  }

  Future<void> _remove(String name, FilterMode mode) async {
    HapticFeedback.lightImpact();
    if (mode == FilterMode.allowlist) {
      await FilterStore.instance.removeFromAllowlist(_selectedApp, name);
    } else {
      await FilterStore.instance.removeFromBlocklist(_selectedApp, name);
    }
    widget.onChanged();
    setState(() {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: Rd.md),
        margin: const EdgeInsets.all(Sp.md),
        content: Text(
          msg,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = FilterStore.instance;
    final config = store.configs[_selectedApp]!;
    final color = AppInfo.color(_selectedApp);
    final mode = config.mode;

    final activeList = mode == FilterMode.allowlist
        ? config.allowlist.toList()
        : config.blocklist.toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Filter Lists'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.surfaceBorder),
        ),
      ),
      body: Column(
        children: [
          // FIX 4: Only 3 app chips (WA covers both packages)
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(
              vertical: Sp.sm + 2,
              horizontal: Sp.md,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppInfo.names.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: Sp.sm),
                    child: AppChip(
                      label: e.value,
                      selected: _selectedApp == e.key,
                      selectedColor: AppInfo.color(e.key),
                      onTap: () => setState(() => _selectedApp = e.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(height: 0.5, color: AppTheme.surfaceBorder),

          // Mode toggle
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.sm),
            child: _ModeToggle(
              mode: mode,
              color: color,
              onChanged: (newMode) async {
                await store.setMode(_selectedApp, newMode);
                widget.onChanged();
                setState(() {});
              },
            ),
          ),

          // Mode description
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
            child: Container(
              padding: const EdgeInsets.all(Sp.sm + 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: Rd.md,
                border: Border.all(color: color.withOpacity(0.2), width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    mode == FilterMode.allowlist
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    color: color,
                    size: 14,
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      mode == FilterMode.allowlist
                          ? 'User will ONLY receive notifications from contacts in this list.'
                          : 'User will receive notifications from ALL contacts EXCEPT those in this list.',
                      style: TextStyle(color: color, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 0.5, color: AppTheme.surfaceBorder),

          // Input area
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: Rd.md,
                          border: Border.all(
                            color: AppTheme.surfaceBorder,
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: mode == FilterMode.allowlist
                                ? 'Add to allowlist...'
                                : 'Add to blocklist...',
                            hintStyle: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Sp.md,
                              vertical: Sp.sm + 2,
                            ),
                          ),
                          onSubmitted: (_) => _addManual(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    GestureDetector(
                      onTap: _addManual,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: Rd.md,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                // Contact picker for WhatsApp only
                if (_isWA) ...[
                  const SizedBox(height: Sp.sm),
                  GestureDetector(
                    onTap: _pickContact,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: Sp.sm + 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: Rd.md,
                        border: Border.all(
                          color: color.withOpacity(0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contacts_rounded, color: color, size: 16),
                          const SizedBox(width: Sp.sm),
                          Text(
                            'Pick from contacts',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // FIX 3: Instagram hint — mention display name not username
                if (_isInstagram) ...[
                  const SizedBox(height: Sp.sm),
                  Container(
                    padding: const EdgeInsets.all(Sp.sm + 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: Rd.md,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppTheme.accent,
                          size: 14,
                        ),
                        SizedBox(width: Sp.sm),
                        Expanded(
                          child: Text(
                            'Instagram shows the sender\'s display name (not username). '
                            'Go to All tab → tap a notification → "Add to list" to add to the current list automatically.',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Snapchat hint
                if (_isSnapchat) ...[
                  const SizedBox(height: Sp.sm),
                  Container(
                    padding: const EdgeInsets.all(Sp.sm + 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: Rd.md,
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppTheme.accent,
                          size: 14,
                        ),
                        SizedBox(width: Sp.sm),
                        Expanded(
                          child: Text(
                            'Go to All tab → tap a Snapchat notification → "Add to list" to add automatically.',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 0.5, color: AppTheme.surfaceBorder),

          // Contact list
          Expanded(
            child: activeList.isEmpty
                ? EmptyState(
                    icon: mode == FilterMode.allowlist
                        ? Icons.person_add_outlined
                        : Icons.block_outlined,
                    title: mode == FilterMode.allowlist
                        ? 'No allowlist contacts'
                        : 'No blocked contacts',
                    subtitle: mode == FilterMode.allowlist
                        ? 'Add people whose notifications you want to receive.'
                        : 'Add people whose notifications you want to silence.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.md,
                      Sp.md,
                      Sp.md,
                      Sp.xxl,
                    ),
                    itemCount: activeList.length,
                    itemBuilder: (ctx, i) => _ContactTile(
                      name: activeList[i],
                      color: color,
                      mode: mode,
                      onRemove: () => _remove(activeList[i], mode),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final FilterMode mode;
  final Color color;
  final ValueChanged<FilterMode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: Rd.lg,
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Allowlist',
            icon: Icons.check_circle_outline_rounded,
            isSelected: mode == FilterMode.allowlist,
            color: const Color(0xFF25D366),
            onTap: () => onChanged(FilterMode.allowlist),
          ),
          _Tab(
            label: 'Blocklist',
            icon: Icons.block_rounded,
            isSelected: mode == FilterMode.blocklist,
            color: Colors.redAccent,
            onTap: () => onChanged(FilterMode.blocklist),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: Rd.md,
            border: isSelected
                ? Border.all(color: color.withOpacity(0.4), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? color : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final Color color;
  final FilterMode mode;
  final VoidCallback onRemove;

  const _ContactTile({
    required this.name,
    required this.color,
    required this.mode,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isBlock = mode == FilterMode.blocklist;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Sp.md,
        vertical: Sp.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: Rd.md,
        border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isBlock
                  ? Colors.redAccent.withOpacity(0.12)
                  : color.withOpacity(0.12),
              borderRadius: Rd.sm,
            ),
            child: Center(
              child: isBlock
                  ? const Icon(
                      Icons.block_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    )
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: Sp.md - 2),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: Rd.sm,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppTheme.textMuted,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
