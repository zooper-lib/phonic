/// A simple cancellation mechanism for stopping long-running audio processing operations.
///
/// This token provides a thread-safe way to signal cancellation to streaming operations.
/// Processing functions should check the [isCancelled] status periodically and stop
/// gracefully when cancellation is requested.
///
/// Example usage:
/// ```dart
/// final token = CancellationToken();
///
/// // In another thread or user interaction
/// token.cancel();
///
/// // In the processing loop
/// if (token.isCancelled) {
///   print('Operation cancelled by user');
///   break;
/// }
/// ```
class CancellationToken {
  bool _isCancelled = false;

  /// Whether the operation has been requested to cancel.
  ///
  /// Processing operations should check this flag periodically and
  /// stop execution gracefully when it returns true.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation of the current operation.
  ///
  /// This method is safe to call from any thread and will immediately
  /// set the [isCancelled] flag to true.
  void cancel() {
    _isCancelled = true;
  }

  /// Resets the cancellation state back to not-cancelled.
  ///
  /// This allows the token to be reused for subsequent operations.
  /// Should only be called when no operations are currently using this token.
  void reset() {
    _isCancelled = false;
  }
}
