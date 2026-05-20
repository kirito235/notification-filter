import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../constants/app_info.dart';
import '../services/whitelist_store.dart';
import '../widgets/app_chip.dart';
import '../widgets/empty_state.dart';

class WhitelistScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const WhitelistScreen({super.key, required this.onChanged});

  @override
  State<WhitelistScreen> createState() => _WhitelistScreenState();
}

class _WhitelistScreenState extends State<WhitelistScreen> {
  static const _contactsChannel = MethodChannel('contacts');
  String _selectedApp = 'com.whatsapp.w4b';
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  bool get _isWA =>
      _selectedApp == 'com.whatsapp.w4b' || _selectedApp == 'com.whatsapp';
  bool get _isInstaOrSnap =>
      _selectedApp == 'com.instagram.android' ||
      _selectedApp == 'com.snapchat.android';

  Future<void> _pickContact() async {
    try {
      final String? name =
          await _contactsChannel.invokeMethod('pickContact');
      if (name != null && name.isNotEmpty) {
        await WhitelistStore.instance.addContact(_selectedApp, name);
        widget.onChanged();
        setState(() {});
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not open contacts');
    }
  }

  Future<void> _addManual() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    await WhitelistStore.instance.addContact(_selectedApp, name);
    widget.onChanged();
    setState(() => _ctrl.clear());
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();
  }

  Future<void> _remove(String name) async {
    HapticFeedback.lightImpact();
    await WhitelistStore.instance.removeContact(_selectedApp, name);
    widget.onChanged();
    setState(() {});
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: Rd.md),
      margin: const EdgeInsets.all(Sp.md),
      content: Text(msg,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 13)),
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = WhitelistStore.instance;
    final contacts = store.whitelist[_selectedApp]?.toList() ?? [];
    final color = AppInfo.color(_selectedApp);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Whitelist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.surfaceBorder),
        ),
      ),
      body: Column(
        children: [
          // App selector
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(
                vertical: Sp.sm + 2, horizontal: Sp.md),
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

          // Input area
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              children: [
                // Text input row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: Rd.md,
                          border: Border.all(
                              color: AppTheme.surfaceBorder, width: 0.5),
                        ),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focusNode,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Type name manually...',
                            hintStyle: TextStyle(
                                color: AppTheme.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: Sp.md, vertical: Sp.sm + 2),
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
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

                // Contact picker — WhatsApp only
                if (_isWA) ...[
                  const SizedBox(height: Sp.sm),
                  GestureDetector(
                    onTap: _pickContact,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: Sp.sm + 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: Rd.md,
                        border: Border.all(
                            color: color.withOpacity(0.25), width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contacts_rounded,
                              color: color, size: 16),
                          const SizedBox(width: Sp.sm),
                          Text('Pick from contacts',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],

                // Hint for Insta/Snap
                if (_isInstaOrSnap) ...[
                  const SizedBox(height: Sp.sm),
                  Container(
                    padding: const EdgeInsets.all(Sp.sm + 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSoft,
                      borderRadius: Rd.md,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: AppTheme.accent, size: 14),
                        const SizedBox(width: Sp.sm),
                        const Expanded(
                          child: Text(
                            'Go to All tab → find a notification → tap "Add to whitelist"',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                                height: 1.4),
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
            child: contacts.isEmpty
                ? EmptyState(
                    icon: Icons.person_add_outlined,
                    title: 'No contacts yet',
                    subtitle: _isInstaOrSnap
                        ? 'Use the All tab to add contacts from your notification log.'
                        : 'Add names manually or pick from your contacts.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        Sp.md, Sp.md, Sp.md, Sp.xxl),
                    itemCount: contacts.length,
                    itemBuilder: (ctx, i) => _ContactTile(
                      name: contacts[i],
                      color: color,
                      onRemove: () => _remove(contacts[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onRemove;

  const _ContactTile({
    required this.name,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: Sp.md, vertical: Sp.sm + 2),
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
              color: color.withOpacity(0.12),
              borderRadius: Rd.sm,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
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
                  fontWeight: FontWeight.w500),
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
              child: const Icon(Icons.close_rounded,
                  color: AppTheme.textMuted, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
