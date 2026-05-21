enum FocusStatus { idle, running, paused, completed }

class FocusSession {
  final Duration duration;
  final DateTime startTime;
  final FocusStatus status;
  final Duration elapsed;

  const FocusSession({
    required this.duration,
    required this.startTime,
    required this.status,
    this.elapsed = Duration.zero,
  });

  Duration get remaining {
    if (status == FocusStatus.idle || status == FocusStatus.completed) {
      return duration;
    }
    if (status == FocusStatus.paused) {
      return duration - elapsed;
    }
    final liveElapsed = elapsed + DateTime.now().difference(startTime);
    final remaining = duration - liveElapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get progress {
    final rem = remaining;
    if (duration.inSeconds == 0) return 0;
    return 1.0 - (rem.inSeconds / duration.inSeconds);
  }

  bool get isComplete => remaining == Duration.zero && status == FocusStatus.running;

  FocusSession copyWith({
    Duration? duration,
    DateTime? startTime,
    FocusStatus? status,
    Duration? elapsed,
  }) {
    return FocusSession(
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  String get remainingFormatted {
    final r = remaining;
    final h = r.inHours;
    final m = r.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = r.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static const List<FocusPreset> presets = [
    FocusPreset(label: '15 min', duration: Duration(minutes: 15)),
    FocusPreset(label: '25 min', duration: Duration(minutes: 25)),
    FocusPreset(label: '45 min', duration: Duration(minutes: 45)),
    FocusPreset(label: '1 hour', duration: Duration(hours: 1)),
    FocusPreset(label: '2 hours', duration: Duration(hours: 2)),
  ];
}

class FocusPreset {
  final String label;
  final Duration duration;
  const FocusPreset({required this.label, required this.duration});
}
