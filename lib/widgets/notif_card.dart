import 'package:flutter/material.dart';
import '../models/notif_item.dart';
import '../constants/app_info.dart';
import '../constants/theme.dart';

class NotifCard extends StatefulWidget {
  final NotifItem item;
  final VoidCallback? onWhitelist;
  final String whitelistLabel;
  final int index;

  const NotifCard({
    super.key,
    required this.item,
    required this.index,
    this.onWhitelist,
    this.whitelistLabel = 'Add to whitelist',
  });

  @override
  State<NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<NotifCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppInfo.color(widget.item.packageName);
    final softColor = AppInfo.softColor(widget.item.packageName);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: Sp.sm + 2),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: Rd.lg,
            border: Border.all(color: AppTheme.surfaceBorder, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: Rd.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 2, color: color.withOpacity(0.6)),
                Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: softColor, borderRadius: Rd.sm),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppInfo.icon(widget.item.packageName),
                                    size: 11, color: color),
                                const SizedBox(width: 4),
                                Text(AppInfo.name(widget.item.packageName),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(widget.item.timeAgo,
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: Sp.sm + 2),
                      Text(widget.item.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(widget.item.text,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (widget.onWhitelist != null) ...[
                        const SizedBox(height: Sp.sm + 2),
                        const Divider(height: 1, color: AppTheme.surfaceBorder),
                        const SizedBox(height: Sp.sm),
                        GestureDetector(
                          onTap: widget.onWhitelist,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  size: 14, color: color),
                              const SizedBox(width: 5),
                              Text(widget.whitelistLabel,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
