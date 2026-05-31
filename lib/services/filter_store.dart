import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_filter_config.dart';
import 'focus_service.dart';

class FilterStore extends ChangeNotifier {
  static const _syncChannel = MethodChannel('whitelist_sync');

  static final FilterStore _instance = FilterStore._();
  static FilterStore get instance => _instance;
  FilterStore._();

  // FIX 4: WA Business and WA share ONE config under 'com.whatsapp' key
  // We keep both package keys but they mirror the same data
  Map<String, AppFilterConfig> configs = {
    'com.whatsapp': const AppFilterConfig(),
    'com.instagram.android': const AppFilterConfig(),
    'com.snapchat.android': const AppFilterConfig(),
  };

  Map<String, bool> appEnabled = {
    'com.whatsapp': true,
    'com.instagram.android': true,
    'com.snapchat.android': true,
  };

  bool globalEnabled = true;

  // FIX 4: resolve WA Business to WA key
  String _resolveKey(String pkg) {
    if (pkg == 'com.whatsapp.w4b') return 'com.whatsapp';
    return pkg;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pkg in configs.keys) {
      final modeStr = prefs.getString('${pkg}_mode') ?? 'allowlist';
      final allowlist = prefs.getStringList('${pkg}_allowlist')?.toSet() ?? {};
      final blocklist = prefs.getStringList('${pkg}_blocklist')?.toSet() ?? {};
      configs[pkg] = AppFilterConfig(
        mode: modeStr == 'blocklist'
            ? FilterMode.blocklist
            : FilterMode.allowlist,
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
    await prefs.setString(
      '${pkg}_mode',
      config.mode == FilterMode.blocklist ? 'blocklist' : 'allowlist',
    );
    await prefs.setStringList('${pkg}_allowlist', config.allowlist.toList());
    await prefs.setStringList('${pkg}_blocklist', config.blocklist.toList());
  }

  Future<void> syncToNative() async {
    try {
      // Prefer a single atomic sync call when supported by native side.
      final Map<String, List<String>> allowData = {};
      final Map<String, List<String>> blockData = {};
      final Map<String, String> modeData = {};
      final Map<String, bool> appEnabledData = {};

      for (final e in configs.entries) {
        allowData[e.key] = e.value.allowlist.toList();
        blockData[e.key] = e.value.blocklist.toList();
        modeData[e.key] = e.value.mode == FilterMode.blocklist
            ? 'blocklist'
            : 'allowlist';
        // Mirror WhatsApp Business alongside WhatsApp
        if (e.key == 'com.whatsapp') {
          allowData['com.whatsapp.w4b'] = e.value.allowlist.toList();
          blockData['com.whatsapp.w4b'] = e.value.blocklist.toList();
          modeData['com.whatsapp.w4b'] = modeData[e.key]!;
        }
      }

      for (final e in appEnabled.entries) {
        appEnabledData[e.key] = e.value;
        if (e.key == 'com.whatsapp') {
          appEnabledData['com.whatsapp.w4b'] = e.value;
        }
      }

      final payload = {
        'allow': allowData,
        'block': blockData,
        'modes': modeData,
        'globalEnabled': globalEnabled,
        'apps': appEnabledData,
      };

      try {
        await _syncChannel.invokeMethod('syncAll', payload);
        return;
      } catch (_) {
        // Native side may not support the batched method; fall back to legacy calls.
      }

      // Legacy fallback: keep existing per-channel calls for compatibility.
      await _syncChannel.invokeMethod('sync', allowData);
      await _syncChannel.invokeMethod('syncBlocklist', blockData);
      await _syncChannel.invokeMethod('syncModes', modeData);
      await _syncChannel.invokeMethod('setGlobalEnabled', globalEnabled);

      for (final e in appEnabled.entries) {
        await _syncChannel.invokeMethod('setAppEnabled', {
          'pkg': e.key,
          'enabled': e.value,
        });
        if (e.key == 'com.whatsapp') {
          await _syncChannel.invokeMethod('setAppEnabled', {
            'pkg': 'com.whatsapp.w4b',
            'enabled': e.value,
          });
        }
      }
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  Future<void> addToAllowlist(String pkg, String name) async {
    final key = _resolveKey(pkg);
    configs[key] = configs[key]!.copyWith(
      allowlist: {...configs[key]!.allowlist, name},
    );
    await _savePkg(key);
    await syncToNative();
    notifyListeners();
  }

  Future<void> removeFromAllowlist(String pkg, String name) async {
    final key = _resolveKey(pkg);
    final updated = Set<String>.from(configs[key]!.allowlist)..remove(name);
    configs[key] = configs[key]!.copyWith(allowlist: updated);
    await _savePkg(key);
    await syncToNative();
    notifyListeners();
  }

  Future<void> addToBlocklist(String pkg, String name) async {
    final key = _resolveKey(pkg);
    configs[key] = configs[key]!.copyWith(
      blocklist: {...configs[key]!.blocklist, name},
    );
    await _savePkg(key);
    await syncToNative();
    notifyListeners();
  }

  Future<void> removeFromBlocklist(String pkg, String name) async {
    final key = _resolveKey(pkg);
    final updated = Set<String>.from(configs[key]!.blocklist)..remove(name);
    configs[key] = configs[key]!.copyWith(blocklist: updated);
    await _savePkg(key);
    await syncToNative();
    notifyListeners();
  }

  Future<void> setMode(String pkg, FilterMode mode) async {
    final key = _resolveKey(pkg);
    configs[key] = configs[key]!.copyWith(mode: mode);
    await _savePkg(key);
    await syncToNative();
    notifyListeners();
  }

  Future<void> setGlobalEnabled(bool val) async {
    globalEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('global_enabled', val);
    await syncToNative();
    notifyListeners();
  }

  Future<void> setAppEnabled(String pkg, bool val) async {
    final key = _resolveKey(pkg);
    appEnabled[key] = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${key}_enabled', val);
    await syncToNative();
    notifyListeners();
  }

  bool isAllowed(String pkg, String title) {
    if (!globalEnabled) return true;
    final key = _resolveKey(pkg);
    if (appEnabled[key] == false) return true;
    final config = configs[key];
    if (config == null) return false;

    // Focus mode forces allowlist logic
    if (FocusService.instance.isRunning) {
      final allowlist = config.allowlist;
      if (allowlist.isEmpty) return false;
      return allowlist.any(
        (name) => title.toLowerCase().contains(name.toLowerCase()),
      );
    }

    return config.isAllowed(title);
  }

  bool isSupported(String pkg) {
    return configs.containsKey(_resolveKey(pkg));
  }

  FilterMode modeFor(String pkg) =>
      configs[_resolveKey(pkg)]?.mode ?? FilterMode.allowlist;

  Set<String> allowlistFor(String pkg) =>
      configs[_resolveKey(pkg)]?.allowlist ?? {};

  Set<String> blocklistFor(String pkg) =>
      configs[_resolveKey(pkg)]?.blocklist ?? {};
}
