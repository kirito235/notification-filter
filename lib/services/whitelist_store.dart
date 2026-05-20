import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhitelistStore extends ChangeNotifier {
  static const _syncChannel = MethodChannel('whitelist_sync');

  static final WhitelistStore _instance = WhitelistStore._();
  static WhitelistStore get instance => _instance;
  WhitelistStore._();

  Map<String, Set<String>> whitelist = {
    'com.whatsapp.w4b': {},
    'com.whatsapp': {},
    'com.instagram.android': {},
    'com.snapchat.android': {},
  };

  Map<String, bool> appEnabled = {
    'com.whatsapp.w4b': true,
    'com.whatsapp': true,
    'com.instagram.android': true,
    'com.snapchat.android': true,
  };

  bool globalEnabled = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pkg in whitelist.keys) {
      final saved = prefs.getStringList(pkg);
      if (saved != null) whitelist[pkg] = saved.toSet();
      appEnabled[pkg] = prefs.getBool('${pkg}_enabled') ?? true;
    }
    globalEnabled = prefs.getBool('global_enabled') ?? true;
    notifyListeners();
  }

  Future<void> _savePkg(String pkg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(pkg, whitelist[pkg]!.toList());
  }

  Future<void> syncToNative() async {
    final Map<String, List<String>> data = {};
    for (final e in whitelist.entries) {
      data[e.key] = e.value.toList();
    }
    try {
      await _syncChannel.invokeMethod('sync', data);
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

  Future<void> addContact(String pkg, String name) async {
    if (!whitelist.containsKey(pkg)) whitelist[pkg] = {};
    whitelist[pkg]!.add(name);
    await _savePkg(pkg);
    await syncToNative();
    notifyListeners();
  }

  Future<void> removeContact(String pkg, String name) async {
    whitelist[pkg]?.remove(name);
    await _savePkg(pkg);
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
    appEnabled[pkg] = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${pkg}_enabled', val);
    await syncToNative();
    notifyListeners();
  }

  bool isAllowed(String pkg, String title) {
    if (!globalEnabled) return true;
    if (appEnabled[pkg] == false) return true;
    if (!whitelist.containsKey(pkg)) return false;
    final contacts = whitelist[pkg]!;
    if (contacts.isEmpty) return false;
    return contacts.any(
        (name) => title.toLowerCase().contains(name.toLowerCase()));
  }

  bool isSupported(String pkg) => whitelist.containsKey(pkg);
}
