import 'dart:async';

/// Gives an ad controller a single, cancellable retry timer so a pending
/// retry never fires after the controller has been disposed.
mixin AdRetryScheduler {
  Timer? _retryTimer;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Schedules [action] to run after [delay], replacing any pending retry.
  void scheduleRetry(Duration delay, void Function() action) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_disposed) action();
    });
  }

  void cancelRetry() => _retryTimer?.cancel();

  /// Call from the controller's `dispose()`.
  void disposeRetryScheduler() {
    _disposed = true;
    _retryTimer?.cancel();
  }
}
