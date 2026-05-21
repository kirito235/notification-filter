import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_session.dart';

class FocusService extends ChangeNotifier {
  static const _syncChannel = MethodChannel('whitelist_sync');

  static final FocusService _instance = FocusService._();
  static FocusService get instance => _instance;
  FocusService._();

  FocusSession _session = FocusSession(
    duration: const Duration(minutes: 25),
    startTime: DateTime.now(),
    status: FocusStatus.idle,
  );

  Timer? _ticker;

  // Summary stats for when session ends
  int suppressedDuringFocus = 0;
  int allowedDuringFocus = 0;

  FocusSession get session => _session;
  bool get isActive => _session.status == FocusStatus.running ||
      _session.status == FocusStatus.paused;
  bool get isRunning => _session.status == FocusStatus.running;

  // ── Start ─────────────────────────────────────────────────────

  Future<void> start(Duration duration) async {
    _session = FocusSession(
      duration: duration,
      startTime: DateTime.now(),
      status: FocusStatus.running,
    );
    suppressedDuringFocus = 0;
    allowedDuringFocus = 0;
    _startTicker();
    await _syncFocusMode(true);
    notifyListeners();
  }

  // ── Pause / Resume ────────────────────────────────────────────

  void pause() {
    if (_session.status != FocusStatus.running) return;
    final elapsed = _session.elapsed + DateTime.now().difference(_session.startTime);
    _session = _session.copyWith(
      status: FocusStatus.paused,
      elapsed: elapsed,
    );
    _ticker?.cancel();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_session.status != FocusStatus.paused) return;
    _session = _session.copyWith(
      status: FocusStatus.running,
      startTime: DateTime.now(),
    );
    _startTicker();
    notifyListeners();
  }

  // ── Stop ──────────────────────────────────────────────────────

  Future<void> stop() async {
    _ticker?.cancel();
    _session = FocusSession(
      duration: _session.duration,
      startTime: DateTime.now(),
      status: FocusStatus.idle,
    );
    await _syncFocusMode(false);
    notifyListeners();
  }

  // ── Internal tick ─────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session.isComplete) {
        _onComplete();
      } else {
        notifyListeners();
      }
    });
  }

  void _onComplete() {
    _ticker?.cancel();
    _session = _session.copyWith(status: FocusStatus.completed);
    _syncFocusMode(false);
    notifyListeners();
  }

  void acknowledgeComplete() {
    _session = FocusSession(
      duration: _session.duration,
      startTime: DateTime.now(),
      status: FocusStatus.idle,
    );
    notifyListeners();
  }

  // ── Native sync ───────────────────────────────────────────────

  Future<void> _syncFocusMode(bool active) async {
    try {
      await _syncChannel.invokeMethod('setFocusMode', active);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('focus_mode_active', active);
    } catch (e) {
      debugPrint('Focus sync error: $e');
    }
  }

  // ── Stats tracking ────────────────────────────────────────────

  void recordSuppressed() => suppressedDuringFocus++;
  void recordAllowed() => allowedDuringFocus++;
}
