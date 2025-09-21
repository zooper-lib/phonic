/// Represents the result of processing a single audio file in a streaming operation.
///
/// This class encapsulates the outcome of processing operations, including
/// success/failure status, error information, result data, and optional messages.
/// It provides factory constructors for creating success and failure results.
///
/// Example usage:
/// ```dart
/// // Success with data
/// final result = ProcessingResult.success(
///   data: {'tags_updated': 5},
///   message: 'Successfully updated metadata'
/// );
///
/// // Failure with error
/// final result = ProcessingResult.failure(
///   Exception('Invalid file format'),
///   message: 'Could not parse MP3 file'
/// );
/// ```
class ProcessingResult {
  /// Whether the audio file processing operation was successful.
  final bool success;

  /// Exception that occurred during processing, if any.
  ///
  /// This field is null for successful operations and contains
  /// the specific error information for failed operations.
  final Exception? error;

  /// Optional result data returned from the processing operation.
  ///
  /// This can contain any relevant data from the processing, such as
  /// metadata information, file statistics, or transformation results.
  final dynamic data;

  /// Optional descriptive message about the processing outcome.
  ///
  /// Provides human-readable information about what happened during
  /// processing, useful for logging or user feedback.
  final String? message;

  /// Creates a new processing result with the specified parameters.
  const ProcessingResult({
    required this.success,
    this.error,
    this.data,
    this.message,
  });

  /// Creates a successful processing result.
  ///
  /// Use this factory constructor when an operation completes successfully.
  /// Optionally include result [data] or a descriptive [message].
  factory ProcessingResult.success({dynamic data, String? message}) {
    return ProcessingResult(
      success: true,
      data: data,
      message: message,
    );
  }

  /// Creates a failed processing result with an error.
  ///
  /// Use this factory constructor when an operation fails.
  /// The [error] parameter is required, and an optional descriptive
  /// [message] can provide additional context.
  factory ProcessingResult.failure(Exception error, {String? message}) {
    return ProcessingResult(
      success: false,
      error: error,
      message: message,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ProcessingResult.success(${message ?? 'OK'})';
    } else {
      return 'ProcessingResult.failure(${error?.toString() ?? 'Unknown error'})';
    }
  }
}
