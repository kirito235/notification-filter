class AppFilterConfig {
  final FilterMode mode;
  final Set<String> allowlist;
  final Set<String> blocklist;

  const AppFilterConfig({
    this.mode = FilterMode.allowlist,
    Set<String>? allowlist,
    Set<String>? blocklist,
  })  : allowlist = allowlist ?? const {},
        blocklist = blocklist ?? const {};

  AppFilterConfig copyWith({
    FilterMode? mode,
    Set<String>? allowlist,
    Set<String>? blocklist,
  }) {
    return AppFilterConfig(
      mode: mode ?? this.mode,
      allowlist: allowlist ?? this.allowlist,
      blocklist: blocklist ?? this.blocklist,
    );
  }

  bool isAllowed(String title) {
    if (mode == FilterMode.allowlist) {
      // FIX 1: empty allowlist = block everything, not allow everything
      if (allowlist.isEmpty) return false;
      return allowlist.any(
          (name) => title.toLowerCase().contains(name.toLowerCase()));
    } else {
      if (blocklist.isEmpty) return true;
      return !blocklist.any(
          (name) => title.toLowerCase().contains(name.toLowerCase()));
    }
  }

  int get totalContacts => allowlist.length + blocklist.length;
}

enum FilterMode { allowlist, blocklist }
