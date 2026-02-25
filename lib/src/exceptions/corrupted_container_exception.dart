import 'phonic_exception.dart';

/// Exception thrown when a corrupted or malformed audio container is encountered.
///
/// This exception is raised when the Phonic library detects corruption or
/// structural problems in an audio file's metadata container that prevent
/// proper parsing or processing. This can occur when:
///
/// - Container headers are malformed or contain invalid data
/// - Frame or atom structures are corrupted or truncated
/// - Required container elements are missing or in unexpected locations
/// - Byte sequences don't match expected container format specifications
/// - File truncation has damaged the container structure
///
/// The exception includes a [byteOffset] field that indicates the approximate
/// location in the file where the corruption was detected, which is valuable
/// for debugging and data recovery efforts.
///
/// ## Usage Examples
///
/// ### Basic Exception Creation
/// ```dart
/// throw CorruptedContainerException(
///   'Invalid ID3v2 frame header detected',
///   byteOffset: 1024,
///   context: 'file: corrupted.mp3, frame: TIT2'
/// );
/// ```
///
/// ### Exception Handling with Offset Information
/// ```dart
/// try {
///   final audioFile = await Phonic.fromFileAsync('damaged.mp3');
/// } on CorruptedContainerException catch (e) {
///   print('Container corruption at byte ${e.byteOffset}: ${e.message}');
///   // Attempt recovery or skip to next container
///   if (e.byteOffset != null && e.byteOffset! < 1000) {
///     // Corruption is early in file, try alternative parsing
///     tryAlternativeParser();
///   }
/// } on PhonicException catch (e) {
///   // Handle other Phonic exceptions
///   print('Other error: ${e.message}');
/// }
/// ```
///
/// ### Logging Corruption Details
/// ```dart
/// void logCorruption(CorruptedContainerException e) {
///   final offset = e.byteOffset != null ? ' at offset ${e.byteOffset}' : '';
///   logger.error('Container corruption detected$offset: ${e.message}');
///   if (e.context != null) {
///     logger.debug('Corruption context: ${e.context}');
///   }
/// }
/// ```
///
/// ### Recovery Strategy
/// ```dart
/// Future<PhonicAudioFile?> parseWithRecovery(String filePath) async {
///   try {
///     return await Phonic.fromFileAsync(filePath);
///   } on CorruptedContainerException catch (e) {
///     // Try to skip corrupted container and parse others
///     if (e.byteOffset != null) {
///       return await parseFromOffset(filePath, e.byteOffset! + 1);
///     }
///     return null; // Unable to recover
///   }
/// }
/// ```
///
/// ## Error Recovery
///
/// When catching [CorruptedContainerException], applications should:
/// 1. Log the corruption details including byte offset for debugging
/// 2. Attempt to parse other containers in the same file if possible
/// 3. Consider partial data recovery from uncorrupted sections
/// 4. Provide user feedback about the file's condition
/// 5. Use the byte offset information for targeted repair attempts
///
/// ## Corruption Types
///
/// Common corruption scenarios that trigger this exception:
/// - **Header Corruption**: Invalid magic bytes or version information
/// - **Size Mismatch**: Declared sizes don't match actual data lengths
/// - **Frame Corruption**: Invalid frame IDs, flags, or data structures
/// - **Encoding Issues**: Text encoding problems or invalid character sequences
/// - **Truncation**: File ends unexpectedly during container parsing
/// - **Synchronization Loss**: Unable to find expected frame or atom boundaries
///
/// ## Thread Safety
///
/// [CorruptedContainerException] instances are immutable and thread-safe.
final class CorruptedContainerException extends PhonicException {
  /// The approximate byte offset in the file where the corruption was detected.
  ///
  /// This field provides valuable debugging information by indicating where
  /// in the file the parser encountered the corruption. The offset may be:
  /// - The exact byte where invalid data was found
  /// - The start of a corrupted frame or atom
  /// - The position where expected data was missing
  /// - `null` if the corruption location cannot be determined
  ///
  /// The offset is particularly useful for:
  /// - Manual file inspection and repair
  /// - Implementing recovery strategies that skip corrupted sections
  /// - Logging detailed error information for support purposes
  /// - Data forensics and corruption analysis
  final int? byteOffset;

  /// Creates a new [CorruptedContainerException] with the specified [message],
  /// optional [byteOffset], and optional [context].
  ///
  /// The [message] should describe the nature of the corruption detected.
  /// The [byteOffset] should indicate where in the file the corruption was
  /// found, if known. The [context] can provide additional information such
  /// as file paths, container types, or parsing state.
  ///
  /// Example:
  /// ```dart
  /// const CorruptedContainerException(
  ///   'ID3v2 frame size exceeds remaining container data',
  ///   byteOffset: 2048,
  ///   context: 'file: song.mp3, container: ID3v2.4, frame: APIC'
  /// );
  /// ```
  const CorruptedContainerException(super.message, {this.byteOffset, super.context});

  /// Returns a string representation of this exception.
  ///
  /// The format includes the specific exception type name and byte offset:
  /// - With offset and context: `"CorruptedContainerException: message at byte offset (Context: context)"`
  /// - With offset only: `"CorruptedContainerException: message at byte offset"`
  /// - Without offset: `"CorruptedContainerException: message"`
  ///
  /// Example output:
  /// ```
  /// CorruptedContainerException: Invalid frame header at byte 1024 (Context: file: song.mp3)
  /// ```
  @override
  String toString() {
    final offsetInfo = byteOffset != null ? ' at byte $byteOffset' : '';
    final contextInfo = context != null ? ' (Context: $context)' : '';
    return 'CorruptedContainerException: $message$offsetInfo$contextInfo';
  }
}
