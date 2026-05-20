class NotifItem {
  final String packageName;
  final String title;
  final String text;
  final DateTime time;
  final bool isAllowed;

  const NotifItem({
    required this.packageName,
    required this.title,
    required this.text,
    required this.time,
    required this.isAllowed,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
