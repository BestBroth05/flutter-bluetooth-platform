import 'package:bluetooth_platform/ble/domain/policies/retry_policy.dart';
import 'package:bluetooth_platform/core/error/ble_failure.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy', () {
    test('calculates exponential backoff delays', () {
      final policy = RetryPolicy(
        initialDelay: const Duration(milliseconds: 100),
        backoffFactor: 2,
        clock: FakeClock(),
      );

      expect(policy.delayAfterFailure(1), const Duration(milliseconds: 100));
      expect(policy.delayAfterFailure(2), const Duration(milliseconds: 200));
      expect(policy.delayAfterFailure(3), const Duration(milliseconds: 400));
    });

    test('stops after maxAttempts and rethrows the last failure', () async {
      final clock = FakeClock();
      final policy = RetryPolicy(
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 10),
        clock: clock,
      );
      var attempts = 0;

      await expectLater(
        policy.execute(() async {
          attempts += 1;
          throw const ConnectionFailure('simulated');
        }),
        throwsA(isA<ConnectionFailure>()),
      );

      expect(attempts, 3);
      expect(clock.delayedDurations, hasLength(2));
      expect(clock.delayedDurations[0], const Duration(milliseconds: 10));
      expect(clock.delayedDurations[1], const Duration(milliseconds: 20));
    });

    test('returns on first success without retrying', () async {
      final clock = FakeClock();
      final policy = RetryPolicy(maxAttempts: 3, clock: clock);
      var attempts = 0;

      final value = await policy.execute(() async {
        attempts += 1;
        return 42;
      });

      expect(value, 42);
      expect(attempts, 1);
      expect(clock.delayedDurations, isEmpty);
    });
  });
}
