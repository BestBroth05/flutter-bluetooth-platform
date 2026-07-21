/// Abstract clock used by policies so unit tests can control time.
abstract class Clock {
  const Clock();

  DateTime now();

  Future<void> delay(Duration duration);
}

/// Real wall-clock implementation used at runtime.
final class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);
}

/// Controllable clock for deterministic tests.
final class FakeClock extends Clock {
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime(2026, 1, 1);

  DateTime _now;
  final List<Duration> delayedDurations = <Duration>[];

  @override
  DateTime now() => _now;

  @override
  Future<void> delay(Duration duration) async {
    delayedDurations.add(duration);
    _now = _now.add(duration);
  }

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
