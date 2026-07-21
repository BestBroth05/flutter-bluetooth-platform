import 'package:bluetooth_platform/ble/domain/policies/reconnection_policy.dart';
import 'package:bluetooth_platform/ble/domain/policies/retry_policy.dart';
import 'package:bluetooth_platform/core/error/ble_failure.dart';
import 'package:bluetooth_platform/core/utils/cancellation_token.dart';
import 'package:bluetooth_platform/core/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReconnectionPolicy', () {
    test('reconnects successfully after transient failures', () async {
      final clock = FakeClock();
      final policy = ReconnectionPolicy(
        retryPolicy: RetryPolicy(
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 5),
          clock: clock,
        ),
        clock: clock,
      );
      var attempts = 0;

      await policy.reconnect(
        connect: () async {
          attempts += 1;
          if (attempts < 2) {
            throw const ConnectionFailure('transient');
          }
        },
      );

      expect(attempts, 2);
    });

    test('cancels reconnection between attempts', () async {
      final clock = FakeClock();
      final token = CancellationToken();
      final policy = ReconnectionPolicy(
        retryPolicy: RetryPolicy(
          maxAttempts: 5,
          initialDelay: const Duration(milliseconds: 5),
          clock: clock,
        ),
        clock: clock,
      );
      var attempts = 0;

      await expectLater(
        policy.reconnect(
          cancellationToken: token,
          connect: () async {
            attempts += 1;
            if (attempts == 1) {
              token.cancel();
              throw const ConnectionFailure('first failure');
            }
          },
        ),
        throwsA(isA<CancelledFailure>()),
      );

      expect(attempts, 1);
    });
  });
}
