/// Base exception class for all Phonic library errors.
///
/// This abstract class provides a consistent error handling interface across
/// the Phonic library. All library-specific exceptions extend this class to
/// provide structured error information with optional context.
///
/// The exception includes a human-readable [message] and optional [context]
/// information that can help with debugging and error reporting.
///
/// ## Usage Examples
///
/// ### Basic Exception Creation
/// ```dart
/// // Custom exception extending PhonicException
/// class MyCustomException extends PhonicException {
///   const MyCustomException(String message, {String? context})
///       : super(message, context: context);
/// }
///
/// // Throwing an exception with context
/// throw MyCustomException(
///   'Failed to parse audio file',
///   context: 'file: /path/to/audio.mp3, offset: 1024'
/// );
/// ```
///
/// ### Exception Handling
/// ```dart
/// try {
///   // Some Phonic library operation
///   final audioFile = await Phonic.fromFileAsync('audio.mp3');
/// } on PhonicException catch (e) {
///   print('Phonic error: ${e.message}');
///   if (e.context != null) {
///     print('Context: ${e.context}');
///   }
/// }
/// ```
///
/// ### Error Logging
/// ```dart
/// void logPhonicError(PhonicException e) {
///   final logMessage = e.context != null
///       ? '${e.message} (Context: ${e.context})'
///       : e.message;
///   logger.error('Phonic Exception: $logMessage');
/// }
/// ```
///
/// ## Error Recovery
///
/// When catching [PhonicException], applications should:
/// 1. Log the error with full context information
/// 2. Determine if the operation can be retried or if graceful degradation is possible
/// 3. Provide meaningful feedback to users when appropriate
/// 4. Use the [context] field for debugging and support purposes
///
/// ## Thread Safety
///
/// [PhonicException] instances are immutable and thread-safe. They can be
/// safely passed between isolates and stored for later analysis.
abstract class PhonicException implements Exception {
  /// Human-readable error message describing what went wrong.
  ///
  /// This message should be clear and actionable, providing enough information
  /// for developers to understand the nature of the error without being
  /// overly technical for end users.
  final String message;

  /// Optional context information providing additional details about the error.
  ///
  /// This field typically contains debugging information such as:
  /// - File paths and names
  /// - Byte offsets in binary data
  /// - Container format details
  /// - Operation parameters
  /// - Stack trace information
  ///
  /// The context is primarily intended for debugging and logging purposes.
  final String? context;

  /// Creates a new [PhonicException] with the specified [message] and optional [context].
  ///
  /// The [message] parameter is required and should provide a clear description
  /// of the error. The [context] parameter is optional and can provide additional
  /// debugging information.
  ///
  /// Example:
  /// ```dart
  /// const PhonicException(
  ///   'Invalid tag format detected',
  ///   context: 'file: audio.mp3, container: ID3v2.4, frame: TIT2'
  /// );
  /// ```
  const PhonicException(this.message, {this.context});

  /// Returns a string representation of this exception.
  ///
  /// The format includes the exception type, message, and context (if available):
  /// - With context: `"PhonicException: message (Context: context)"`
  /// - Without context: `"PhonicException: message"`
  ///
  /// This method is automatically called when the exception is printed or
  /// converted to a string for logging purposes.
  ///
  /// Example output:
  /// ```
  /// PhonicException: Failed to parse ID3v2 header (Context: file: song.mp3, offset: 0)
  /// ```
  @override
  String toString() => context != null ? 'PhonicException: $message (Context: $context)' : 'PhonicException: $message';
}
