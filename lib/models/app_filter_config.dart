/// Represents the filtering configuration for a single app.
/// Each app has a mode (allowlist/blocklist) and two separate contact lists.
class AppFilterConfig {
  final FilterMode mode;
  final Set<String> allowlist; // shown/allowed through
  final Set<String> blocklist; // suppressed/blocked

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

  /// Returns true if this notification title should be shown to the user.
  bool isAllowed(String title) {
    if (mode == FilterMode.allowlist) {
      if (allowlist.isEmpty) return false; // no whitelist = block all
      return allowlist.any(
          (name) => title.toLowerCase().contains(name.toLowerCase()));
    } else {
      // blocklist mode — allow all except explicitly blocked
      if (blocklist.isEmpty) return true; // no blocklist = allow all
      return !blocklist.any(
          (name) => title.toLowerCase().contains(name.toLowerCase()));
    }
  }

  int get totalContacts => allowlist.length + blocklist.length;
}

enum FilterMode { allowlist, blocklist }
