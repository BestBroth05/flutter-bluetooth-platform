import 'dart:math' as math;

import '../../../core/error/ble_failure.dart';
import '../../../core/utils/clock.dart';

/// Retries an asynchronous action with exponential backoff.
final class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.backoffFactor = 2.0,
    this.clock = const SystemClock(),
  });

  /// Total attempts including the first try.
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffFactor;
  final Clock clock;

  /// Delay applied after [failedAttempt] failures (1-based).
  Duration delayAfterFailure(int failedAttempt) {
    if (failedAttempt < 1) {
      return Duration.zero;
    }
    final multiplier = math.pow(backoffFactor, failedAttempt - 1).toDouble();
    final millis = (initialDelay.inMilliseconds * multiplier).round();
    return Duration(milliseconds: millis);
  }

  /// Executes [action] until success or [maxAttempts] is exhausted.
  Future<T> execute<T>(Future<T> Function() action) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        if (attempt >= maxAttempts) {
          break;
        }
        await clock.delay(delayAfterFailure(attempt));
      }
    }

    if (lastError is BleFailure) {
      throw lastError;
    }
    Error.throwWithStackTrace(
      UnexpectedBleFailure(lastError?.toString() ?? 'Retry exhausted.'),
      lastStack ?? StackTrace.current,
    );
  }
}
