/// Configurable timeouts for scan, connect, and command operations.
final class TimeoutPolicy {
  const TimeoutPolicy({
    this.scanTimeout = const Duration(seconds: 2),
    this.connectionTimeout = const Duration(seconds: 3),
    this.commandTimeout = const Duration(seconds: 3),
  });

  final Duration scanTimeout;
  final Duration connectionTimeout;
  final Duration commandTimeout;
}
