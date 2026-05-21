import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_filter_config.dart';

class FilterStore extends ChangeNotifier {
  static const _syncChannel = MethodChannel('whitelist_sync');

  static final FilterStore _instance = FilterStore._();
  static FilterStore get instance => _instance;
  FilterStore._();

  // Per-app config
  Map<String, AppFilterConfig> configs = {
    'com.whatsapp.w4b': const AppFilterConfig(),
    'com.whatsapp': const AppFilterConfig(),
    'com.instagram.android': const AppFilterConfig(),
    'com.snapchat.android': const AppFilterConfig(),
  };

  // Per-app enabled toggle
  Map<String, bool> appEnabled = {
    'com.whatsapp.w4b': true,
    'com.whatsapp': true,
    'com.instagram.android': true,
    'com.snapchat.android': true,
  };

  bool globalEnabled = true;

  // ── Persistence ───────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pkg in configs.keys) {
      final modeStr = prefs.getString('${pkg}_mode') ?? 'allowlist';
      final allowlist = prefs.getStringList('${pkg}_allowlist')?.toSet() ?? {};
      final blocklist = prefs.getStringList('${pkg}_blocklist')?.toSet() ?? {};
      configs[pkg] = AppFilterConfig(
        mode: modeStr == 'blocklist' ? FilterMode.blocklist : FilterMode.allowlist,
        allowlist: allowlist,
        blocklist: blocklist,
      );
      appEnabled[pkg] = prefs.getBool('${pkg}_enabled') ?? true;
    }
    globalEnabled = prefs.getBool('global_enabled') ?? true;
    notifyListeners();
  }

  Future<void> _savePkg(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    final config = configs[pkg]!;
    await prefs.setString('${pkg}_mode',
        config.mode == FilterMode.blocklist ? 'blocklist' : 'allowlist');
    await prefs.setStringList('${pkg}_allowlist', config.allowlist.toList());
    await prefs.setStringList('${pkg}_blocklist', config.blocklist.toList());
  }

  // ── Native sync ───────────────────────────────────────────────

  Future<void> syncToNative() async {
    try {
      // Sync allowlists (legacy key for backward compat)
      final Map<String, List<String>> allowData = {};
      final Map<String, List<String>> blockData = {};
      final Map<String, String> modeData = {};

      for (final e in configs.entries) {
        allowData[e.key] = e.value.allowlist.toList();
        blockData[e.key] = e.value.blocklist.toList();
        modeData[e.key] =
            e.value.mode == FilterMode.blocklist ? 'blocklist' : 'allowlist';
      }

      await _syncChannel.invokeMethod('sync', allowData);
      await _syncChannel.invokeMethod('syncBlocklist', blockData);
      await _syncChannel.invokeMethod('syncModes', modeData);
      await _syncChannel.invokeMethod('setGlobalEnabled', globalEnabled);

      for (final e in appEnabled.entries) {
        await _syncChannel.invokeMethod('setAppEnabled', {
          'pkg': e.key,
          'enabled': e.value,
        });
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  // ── Allowlist operations ──────────────────────────────────────

  Future<void> addToAllowlist(String pkg, String name) async {
    configs[pkg] = configs[pkg]!.copyWith(
      allowlist: {...configs[pkg]!.allowlist, name},
    );
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  Future<void> removeFromAllowlist(String pkg, String name) async {
    final updated = Set<String>.from(configs[pkg]!.allowlist)..remove(name);
    configs[pkg] = configs[pkg]!.copyWith(allowlist: updated);
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  // ── Blocklist operations ──────────────────────────────────────

  Future<void> addToBlocklist(String pkg, String name) async {
    configs[pkg] = configs[pkg]!.copyWith(
      blocklist: {...configs[pkg]!.blocklist, name},
    );
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  Future<void> removeFromBlocklist(String pkg, String name) async {
    final updated = Set<String>.from(configs[pkg]!.blocklist)..remove(name);
    configs[pkg] = configs[pkg]!.copyWith(blocklist: updated);
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  // ── Mode operations ───────────────────────────────────────────

  Future<void> setMode(String pkg, FilterMode mode) async {
    configs[pkg] = configs[pkg]!.copyWith(mode: mode);
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  // ── Global / per-app toggles ──────────────────────────────────

  Future<void> setGlobalEnabled(bool val) async {
    globalEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('global_enabled', val);
    await syncToNative();
    notifyListeners();
  }

  Future<void> setAppEnabled(String pkg, bool val) async {
    appEnabled[pkg] = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${pkg}_enabled', val);
    await syncToNative();
    notifyListeners();
  }

  // ── Filter logic ──────────────────────────────────────────────

  bool isAllowed(String pkg, String title) {
    if (!globalEnabled) return true;
    if (appEnabled[pkg] == false) return true;
    final config = configs[pkg];
    if (config == null) return false;
    return config.isAllowed(title);
  }

  bool isSupported(String pkg) => configs.containsKey(pkg);

  FilterMode modeFor(String pkg) =>
      configs[pkg]?.mode ?? FilterMode.allowlist;

  // Legacy accessors for screens that still need them
  Set<String> allowlistFor(String pkg) => configs[pkg]?.allowlist ?? {};
  Set<String> blocklistFor(String pkg) => configs[pkg]?.blocklist ?? {};
}
