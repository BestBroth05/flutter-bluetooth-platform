import '../../../core/error/ble_failure.dart';
import '../../../core/utils/cancellation_token.dart';
import '../../../core/utils/clock.dart';
import 'retry_policy.dart';

/// Orchestrates reconnection attempts with retry and cancellation support.
final class ReconnectionPolicy {
  const ReconnectionPolicy({
    required this.retryPolicy,
    this.clock = const SystemClock(),
  });

  final RetryPolicy retryPolicy;
  final Clock clock;

  /// Invokes [connect] until it succeeds, retries are exhausted, or
  /// [cancellationToken] is cancelled.
  Future<void> reconnect({
    required Future<void> Function() connect,
    CancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? CancellationToken();
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      try {
        token.throwIfCancelled();
        await connect();
        token.throwIfCancelled();
        return;
      } on CancelledException {
        throw const CancelledFailure();
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        if (attempt >= retryPolicy.maxAttempts) {
          break;
        }
        try {
          token.throwIfCancelled();
        } on CancelledException {
          throw const CancelledFailure();
        }
        await clock.delay(retryPolicy.delayAfterFailure(attempt));
      }
    }

    if (lastError is BleFailure) {
      throw lastError;
    }
    Error.throwWithStackTrace(
      UnexpectedBleFailure(lastError?.toString() ?? 'Reconnection exhausted.'),
      lastStack ?? StackTrace.current,
    );
  }
}
