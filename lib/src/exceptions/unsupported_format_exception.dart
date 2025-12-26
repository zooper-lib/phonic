import 'phonic_exception.dart';

/// Exception thrown when an unsupported audio file format is encountered.
///
/// This exception is raised when the Phonic library attempts to process an
/// audio file that is not supported by any of the available format strategies
/// or codecs. This can occur when:
///
/// - The file format is not recognized (e.g., unsupported audio codec)
/// - The container format is corrupted beyond recognition
/// - The file lacks the necessary headers or signatures for format detection
/// - A required codec or parser is not available for the detected format
///
/// ## Usage Examples
///
/// ### Basic Exception Creation
/// ```dart
/// throw UnsupportedFormatException(
///   'Unsupported audio format: WMA',
///   context: 'file: audio.wma'
/// );
/// ```
///
/// ### Exception Handling
/// ```dart
/// try {
///   final audioFile = await Phonic.fromFile('unknown.xyz');
/// } on UnsupportedFormatException catch (e) {
///   print('Unsupported format: ${e.message}');
///   // Provide user-friendly error message
///   showError('This audio format is not supported');
/// } on PhonicException catch (e) {
///   // Handle other Phonic exceptions
///   print('Other error: ${e.message}');
/// }
/// ```
///
/// ### Format Detection Error
/// ```dart
/// void handleFormatDetection(String filePath) {
///   try {
///     final format = detectAudioFormat(filePath);
///     // Process the file...
///   } on UnsupportedFormatException catch (e) {
///     logger.warning('Skipping unsupported file: $filePath - ${e.message}');
///     // Continue processing other files
///   }
/// }
/// ```
///
/// ## Error Recovery
///
/// When catching [UnsupportedFormatException], applications should:
/// 1. Inform users that the specific file format is not supported
/// 2. Provide a list of supported formats for reference
/// 3. Skip the problematic file and continue processing others
/// 4. Log the error for potential future format support planning
///
/// ## Supported Formats
///
/// The Phonic library currently supports:
/// - MP3 files with ID3v1, ID3v2.2, ID3v2.3, and ID3v2.4 tags
/// - FLAC files with Vorbis Comments
/// - OGG Vorbis files with Vorbis Comments
/// - Opus files with Vorbis Comments
/// - MP4/M4A files with iTunes-style atoms
///
/// ## Thread Safety
///
/// [UnsupportedFormatException] instances are immutable and thread-safe.
final class UnsupportedFormatException extends PhonicException {
  /// Creates a new [UnsupportedFormatException] with the specified [message] and optional [context].
  ///
  /// The [message] should describe what format was unsupported or why the format
  /// could not be processed. The [context] can provide additional information
  /// such as file paths, detected signatures, or attempted format strategies.
  ///
  /// Example:
  /// ```dart
  /// const UnsupportedFormatException(
  ///   'No format strategy available for detected format',
  ///   context: 'file: audio.wma, detected: Windows Media Audio'
  /// );
  /// ```
  const UnsupportedFormatException(super.message, {super.context});

  /// Returns a string representation of this exception.
  ///
  /// The format includes the specific exception type name:
  /// - With context: `"UnsupportedFormatException: message (Context: context)"`
  /// - Without context: `"UnsupportedFormatException: message"`
  ///
  /// Example output:
  /// ```
  /// UnsupportedFormatException: Unsupported audio format: WMA (Context: file: song.wma)
  /// ```
  @override
  String toString() => context != null ? 'UnsupportedFormatException: $message (Context: $context)' : 'UnsupportedFormatException: $message';
}
