/// Simple cancellation primitive for long-running reconnect loops.
final class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const CancelledException();
    }
  }
}

final class CancelledException implements Exception {
  const CancelledException([this.message = 'Operation cancelled.']);

  final String message;

  @override
  String toString() => 'CancelledException: $message';
}
