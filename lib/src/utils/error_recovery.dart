import 'dart:typed_data';

import '../core/container_locator.dart';
import '../core/metadata_tag.dart';
import '../core/tag_codec.dart';
import '../exceptions/corrupted_container_exception.dart';
import '../exceptions/phonic_exception.dart';
import '../exceptions/unsupported_format_exception.dart';

/// Utilities for graceful error recovery during audio file parsing.
///
/// This module provides comprehensive error recovery mechanisms that allow
/// the Phonic library to continue processing audio files even when individual
/// containers are corrupted or malformed. The recovery system focuses on:
///
/// - **Graceful Degradation**: Continue processing when containers fail
/// - **Detailed Logging**: Capture error context with byte offsets
/// - **Container Isolation**: Skip corrupted containers while preserving others
/// - **Context Preservation**: Maintain debugging information for analysis
/// - **Recovery Strategies**: Multiple approaches for different error types
///
/// ## Key Features
///
/// - **Container Skip Logic**: Automatically skip corrupted containers
/// - **Error Context Tracking**: Detailed error information with byte offsets
/// - **Recovery Policies**: Configurable strategies for different error types
/// - **Logging Integration**: Structured error logging for debugging
/// - **Partial Success**: Extract what data is possible from damaged files
/// - **Memory Safety**: Prevent crashes from malformed data
///
/// ## Usage Examples
///
/// ### Basic Error Recovery
/// ```dart
/// final recovery = ErrorRecoveryManager();
///
/// final result = await recovery.recoverFromContainers(
///   fileBytes: audioFileBytes,
///   locators: [id3v2Locator, id3v1Locator],
///   codecs: [id3v24Codec, id3v1Codec],
///   onError: (error) => print('Recovery error: $error'),
/// );
///
/// if (result.hasPartialSuccess) {
///   print('Recovered ${result.tags.length} tags');
///   print('Errors: ${result.errors.length}');
/// }
/// ```
///
/// ### Custom Recovery Policy
/// ```dart
/// final policy = ErrorRecoveryPolicy(
///   skipCorruptedContainers: true,
///   preservePartialData: true,
///   maxErrorsPerContainer: 3,
///   continueAfterCriticalError: false,
/// );
///
/// final recovery = ErrorRecoveryManager(policy: policy);
/// ```
///
/// ### Error Analysis
/// ```dart
/// final result = await recovery.recoverFromContainers(...);
///
/// for (final error in result.errors) {
///   print('Error at byte ${error.byteOffset}: ${error.message}');
///   print('Context: ${error.context}');
///   print('Recovery action: ${error.recoveryAction}');
/// }
/// ```

/// Configuration for error recovery behavior.
class ErrorRecoveryPolicy {
  /// Whether to skip corrupted containers and continue with others.
  final bool skipCorruptedContainers;

  /// Whether to preserve partial data from containers that partially parse.
  final bool preservePartialData;

  /// Maximum number of errors to tolerate per container before skipping.
  final int maxErrorsPerContainer;

  /// Whether to continue processing after critical errors.
  final bool continueAfterCriticalError;

  /// Whether to enable detailed error logging.
  final bool enableDetailedLogging;

  /// Whether to attempt container repair for common corruption patterns.
  final bool attemptContainerRepair;

  /// Maximum byte offset to scan when looking for recovery points.
  final int maxRecoveryScanBytes;

  const ErrorRecoveryPolicy({
    this.skipCorruptedContainers = true,
    this.preservePartialData = true,
    this.maxErrorsPerContainer = 5,
    this.continueAfterCriticalError = false,
    this.enableDetailedLogging = true,
    this.attemptContainerRepair = false,
    this.maxRecoveryScanBytes = 8192,
  });

  /// Creates a policy optimized for maximum data recovery.
  factory ErrorRecoveryPolicy.aggressive() {
    return const ErrorRecoveryPolicy(
      skipCorruptedContainers: true,
      preservePartialData: true,
      maxErrorsPerContainer: 10,
      continueAfterCriticalError: true,
      enableDetailedLogging: true,
      attemptContainerRepair: true,
      maxRecoveryScanBytes: 16384,
    );
  }

  /// Creates a policy optimized for stability and performance.
  factory ErrorRecoveryPolicy.conservative() {
    return const ErrorRecoveryPolicy(
      skipCorruptedContainers: true,
      preservePartialData: false,
      maxErrorsPerContainer: 2,
      continueAfterCriticalError: false,
      enableDetailedLogging: false,
      attemptContainerRepair: false,
      maxRecoveryScanBytes: 4096,
    );
  }
}

/// Detailed information about an error that occurred during parsing.
class ErrorContext {
  /// The exception that occurred.
  final PhonicException exception;

  /// Byte offset where the error occurred (if known).
  final int? byteOffset;

  /// Container type being parsed when error occurred.
  final String? containerType;

  /// Container version being parsed when error occurred.
  final String? containerVersion;

  /// Operation being performed when error occurred.
  final String? operation;

  /// Additional context information.
  final Map<String, dynamic> additionalContext;

  /// Recovery action that was taken.
  final RecoveryAction recoveryAction;

  /// Timestamp when the error occurred.
  final DateTime timestamp;

  ErrorContext({
    required this.exception,
    this.byteOffset,
    this.containerType,
    this.containerVersion,
    this.operation,
    this.additionalContext = const {},
    required this.recoveryAction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates an error context from a corrupted container exception.
  factory ErrorContext.fromCorruptedContainer(
    CorruptedContainerException exception, {
    String? containerType,
    String? containerVersion,
    String? operation,
    Map<String, dynamic>? additionalContext,
    RecoveryAction recoveryAction = RecoveryAction.skipContainer,
  }) {
    return ErrorContext(
      exception: exception,
      byteOffset: exception.byteOffset,
      containerType: containerType,
      containerVersion: containerVersion,
      operation: operation,
      additionalContext: additionalContext ?? {},
      recoveryAction: recoveryAction,
    );
  }

  /// Creates an error context from a generic exception.
  factory ErrorContext.fromException(
    Exception exception, {
    int? byteOffset,
    String? containerType,
    String? containerVersion,
    String? operation,
    Map<String, dynamic>? additionalContext,
    RecoveryAction recoveryAction = RecoveryAction.skipContainer,
  }) {
    final phonicException = exception is PhonicException
        ? exception
        : CorruptedContainerException(
            exception.toString(),
            context: 'Wrapped exception: ${exception.runtimeType}',
          );

    return ErrorContext(
      exception: phonicException,
      byteOffset: byteOffset,
      containerType: containerType,
      containerVersion: containerVersion,
      operation: operation,
      additionalContext: additionalContext ?? {},
      recoveryAction: recoveryAction,
    );
  }

  /// Returns a formatted string representation of the error context.
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('Error Context:');
    buffer.writeln('  Exception: ${exception.runtimeType}');
    buffer.writeln('  Message: ${exception.message}');

    if (byteOffset != null) {
      buffer.writeln('  Byte Offset: $byteOffset (0x${byteOffset!.toRadixString(16).padLeft(8, '0')})');
    }

    if (containerType != null) {
      buffer.write('  Container: $containerType');
      if (containerVersion != null) {
        buffer.write(' v$containerVersion');
      }
      buffer.writeln();
    }

    if (operation != null) {
      buffer.writeln('  Operation: $operation');
    }

    if (exception.context != null) {
      buffer.writeln('  Exception Context: ${exception.context}');
    }

    buffer.writeln('  Recovery Action: ${recoveryAction.name}');
    buffer.writeln('  Timestamp: ${timestamp.toIso8601String()}');

    if (additionalContext.isNotEmpty) {
      buffer.writeln('  Additional Context:');
      for (final entry in additionalContext.entries) {
        buffer.writeln('    ${entry.key}: ${entry.value}');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() {
    final parts = <String>[
      exception.message,
    ];

    if (byteOffset != null) {
      parts.add('at byte $byteOffset');
    }

    if (containerType != null) {
      parts.add('in $containerType');
    }

    if (operation != null) {
      parts.add('during $operation');
    }

    return 'ErrorContext(${parts.join(', ')})';
  }
}

/// Actions that can be taken when recovering from errors.
enum RecoveryAction {
  /// Skip the entire container and continue with others.
  skipContainer,

  /// Skip the current frame/atom and continue parsing the container.
  skipFrame,

  /// Attempt to repair the container and retry parsing.
  repairAndRetry,

  /// Use partial data that was successfully parsed.
  usePartialData,

  /// Stop processing entirely.
  stopProcessing,

  /// Continue with default/fallback values.
  useDefaults,
}

/// Result of an error recovery operation.
class RecoveryResult {
  /// Tags that were successfully recovered.
  final List<MetadataTag> tags;

  /// Errors that occurred during recovery.
  final List<ErrorContext> errors;

  /// Whether any data was successfully recovered.
  final bool hasPartialSuccess;

  /// Whether recovery completed without critical errors.
  final bool isFullSuccess;

  /// Total number of containers processed.
  final int containersProcessed;

  /// Number of containers that were skipped due to errors.
  final int containersSkipped;

  /// Memory usage statistics during recovery.
  final Map<String, dynamic> statistics;

  const RecoveryResult({
    required this.tags,
    required this.errors,
    required this.hasPartialSuccess,
    required this.isFullSuccess,
    required this.containersProcessed,
    required this.containersSkipped,
    this.statistics = const {},
  });

  /// Creates a successful recovery result.
  factory RecoveryResult.success(
    List<MetadataTag> tags, {
    List<ErrorContext> errors = const [],
    int containersProcessed = 1,
    Map<String, dynamic>? statistics,
  }) {
    return RecoveryResult(
      tags: tags,
      errors: errors,
      hasPartialSuccess: tags.isNotEmpty,
      isFullSuccess: errors.isEmpty,
      containersProcessed: containersProcessed,
      containersSkipped: 0,
      statistics: statistics ?? {},
    );
  }

  /// Creates a failed recovery result.
  factory RecoveryResult.failure(
    List<ErrorContext> errors, {
    List<MetadataTag> partialTags = const [],
    int containersProcessed = 0,
    int containersSkipped = 0,
    Map<String, dynamic>? statistics,
  }) {
    return RecoveryResult(
      tags: partialTags,
      errors: errors,
      hasPartialSuccess: partialTags.isNotEmpty,
      isFullSuccess: false,
      containersProcessed: containersProcessed,
      containersSkipped: containersSkipped,
      statistics: statistics ?? {},
    );
  }

  /// Gets a summary of the recovery operation.
  String getSummary() {
    final buffer = StringBuffer();
    buffer.write('Recovery Result: ');

    if (isFullSuccess) {
      buffer.write('Full Success');
    } else if (hasPartialSuccess) {
      buffer.write('Partial Success');
    } else {
      buffer.write('Failed');
    }

    buffer.write(' (${tags.length} tags recovered');

    if (errors.isNotEmpty) {
      buffer.write(', ${errors.length} errors');
    }

    if (containersSkipped > 0) {
      buffer.write(', $containersSkipped containers skipped');
    }

    buffer.write(')');

    return buffer.toString();
  }

  @override
  String toString() => getSummary();
}

/// Callback function type for error notifications.
typedef ErrorCallback = void Function(ErrorContext error);

/// Main class for managing error recovery during audio file parsing.
///
/// This class coordinates the recovery process when containers are corrupted
/// or parsing fails, implementing various strategies to extract as much
/// metadata as possible while maintaining system stability.
class ErrorRecoveryManager {
  final ErrorRecoveryPolicy _policy;
  final ErrorCallback? _errorCallback;

  /// Creates a new error recovery manager.
  const ErrorRecoveryManager({
    ErrorRecoveryPolicy? policy,
    ErrorCallback? onError,
  }) : _policy = policy ?? const ErrorRecoveryPolicy(),
       _errorCallback = onError;

  /// Attempts to recover metadata from containers with error handling.
  ///
  /// This method processes multiple containers and attempts to extract
  /// metadata from each one, gracefully handling errors and continuing
  /// with other containers when possible.
  ///
  /// Parameters:
  /// - [fileBytes]: The complete audio file bytes
  /// - [locators]: Container locators to try
  /// - [codecs]: Codecs for parsing containers
  /// - [onProgress]: Optional progress callback
  ///
  /// Returns a [RecoveryResult] with recovered tags and error information.
  Future<RecoveryResult> recoverFromContainers({
    required Uint8List fileBytes,
    required List<ContainerLocator> locators,
    required List<TagCodec> codecs,
    void Function(int processed, int total)? onProgress,
  }) async {
    final recoveredTags = <MetadataTag>[];
    final errors = <ErrorContext>[];
    var containersProcessed = 0;
    var containersSkipped = 0;

    final startTime = DateTime.now();
    final statistics = <String, dynamic>{
      'startTime': startTime,
      'fileSize': fileBytes.length,
    };

    try {
      // Process each locator/codec combination
      for (int i = 0; i < locators.length; i++) {
        final locator = locators[i];
        onProgress?.call(i, locators.length);

        try {
          // Check if this locator can handle the file
          if (!locator.fileMatches(fileBytes)) {
            continue;
          }

          // Find matching codec
          final codec = codecs.firstWhere(
            (c) => c.containerKind == locator.containerKind,
            orElse: () => throw UnsupportedFormatException(
              'No codec available for container kind: ${locator.containerKind}',
              context: 'locator: ${locator.runtimeType}',
            ),
          );

          // Attempt to extract and parse container
          final containerResult = await _processContainer(
            fileBytes: fileBytes,
            locator: locator,
            codec: codec,
            containerIndex: i,
          );

          recoveredTags.addAll(containerResult.tags);
          errors.addAll(containerResult.errors);

          if (containerResult.wasProcessed) {
            containersProcessed++;
          } else {
            containersSkipped++;
          }

          // Check if we should stop processing
          if (!_policy.continueAfterCriticalError && containerResult.errors.any((e) => _isCriticalError(e.exception))) {
            break;
          }
        } catch (e) {
          final error = ErrorContext.fromException(
            e is Exception ? e : Exception(e.toString()),
            containerType: locator.containerKind.name,
            operation: 'container_processing',
            additionalContext: {'locator_index': i},
            recoveryAction: RecoveryAction.skipContainer,
          );

          errors.add(error);
          containersSkipped++;

          _notifyError(error);

          if (!_policy.skipCorruptedContainers) {
            break;
          }
        }
      }

      onProgress?.call(locators.length, locators.length);
    } finally {
      statistics['endTime'] = DateTime.now();
      statistics['processingDuration'] = DateTime.now().difference(startTime);
      statistics['containersProcessed'] = containersProcessed;
      statistics['containersSkipped'] = containersSkipped;
      statistics['tagsRecovered'] = recoveredTags.length;
      statistics['errorsEncountered'] = errors.length;
    }

    return RecoveryResult(
      tags: recoveredTags,
      errors: errors,
      hasPartialSuccess: recoveredTags.isNotEmpty,
      isFullSuccess: errors.isEmpty,
      containersProcessed: containersProcessed,
      containersSkipped: containersSkipped,
      statistics: statistics,
    );
  }

  /// Processes a single container with error recovery.
  Future<_ContainerResult> _processContainer({
    required Uint8List fileBytes,
    required ContainerLocator locator,
    required TagCodec codec,
    required int containerIndex,
  }) async {
    final tags = <MetadataTag>[];
    final errors = <ErrorContext>[];
    var wasProcessed = false;
    var errorCount = 0;

    try {
      // Extract container bytes
      final containerBytes = locator.extract(fileBytes);
      if (containerBytes?.isEmpty ?? true) {
        throw CorruptedContainerException(
          'Container extraction returned empty bytes',
          context: 'locator: ${locator.runtimeType}, file_size: ${fileBytes.length}',
        );
      }

      wasProcessed = true;

      // Parse container with error recovery
      final parseResult = await _parseContainerWithRecovery(
        containerBytes: containerBytes!,
        codec: codec,
        containerType: locator.containerKind.name,
        containerVersion: codec.containerVersion,
      );

      tags.addAll(parseResult.tags);
      errors.addAll(parseResult.errors);
      errorCount = parseResult.errors.length;
    } catch (e) {
      final error = ErrorContext.fromException(
        e is Exception ? e : Exception(e.toString()),
        containerType: locator.containerKind.name,
        containerVersion: codec.containerVersion,
        operation: 'container_extraction',
        additionalContext: {
          'container_index': containerIndex,
          'file_size': fileBytes.length,
        },
        recoveryAction: RecoveryAction.skipContainer,
      );

      errors.add(error);
      errorCount++;

      _notifyError(error);
    }

    return _ContainerResult(
      tags: tags,
      errors: errors,
      wasProcessed: wasProcessed,
      errorCount: errorCount,
    );
  }

  /// Parses container bytes with error recovery strategies.
  Future<_ParseResult> _parseContainerWithRecovery({
    required Uint8List containerBytes,
    required TagCodec codec,
    required String containerType,
    required String containerVersion,
  }) async {
    final tags = <MetadataTag>[];
    final errors = <ErrorContext>[];

    try {
      // Attempt normal parsing first
      final parsedTags = codec.readFromContainer(containerBytes);
      tags.addAll(parsedTags);
    } catch (e) {
      final error = ErrorContext.fromException(
        e is Exception ? e : Exception(e.toString()),
        containerType: containerType,
        containerVersion: containerVersion,
        operation: 'container_parsing',
        recoveryAction: _policy.preservePartialData ? RecoveryAction.usePartialData : RecoveryAction.skipContainer,
      );

      errors.add(error);
      _notifyError(error);

      // Attempt recovery if enabled
      if (_policy.preservePartialData || _policy.attemptContainerRepair) {
        final recoveryResult = await _attemptContainerRecovery(
          containerBytes: containerBytes,
          codec: codec,
          containerType: containerType,
          containerVersion: containerVersion,
          originalError: error,
        );

        tags.addAll(recoveryResult.tags);
        errors.addAll(recoveryResult.errors);
      }
    }

    return _ParseResult(tags: tags, errors: errors);
  }

  /// Attempts various recovery strategies for corrupted containers.
  Future<_ParseResult> _attemptContainerRecovery({
    required Uint8List containerBytes,
    required TagCodec codec,
    required String containerType,
    required String containerVersion,
    required ErrorContext originalError,
  }) async {
    final tags = <MetadataTag>[];
    final errors = <ErrorContext>[];

    // Strategy 1: Try to parse partial container data
    if (_policy.preservePartialData) {
      final partialResult = await _tryPartialParsing(
        containerBytes: containerBytes,
        codec: codec,
        containerType: containerType,
        containerVersion: containerVersion,
      );

      tags.addAll(partialResult.tags);
      errors.addAll(partialResult.errors);
    }

    // Strategy 2: Attempt container repair
    if (_policy.attemptContainerRepair && tags.isEmpty) {
      final repairResult = await _tryContainerRepair(
        containerBytes: containerBytes,
        codec: codec,
        containerType: containerType,
        containerVersion: containerVersion,
      );

      tags.addAll(repairResult.tags);
      errors.addAll(repairResult.errors);
    }

    // If no recovery was successful, preserve the original error
    if (tags.isEmpty && errors.isEmpty) {
      errors.add(originalError);
    }

    return _ParseResult(tags: tags, errors: errors);
  }

  /// Attempts to parse partial container data by scanning for valid structures.
  Future<_ParseResult> _tryPartialParsing({
    required Uint8List containerBytes,
    required TagCodec codec,
    required String containerType,
    required String containerVersion,
  }) async {
    final tags = <MetadataTag>[];
    final errors = <ErrorContext>[];

    // This is a simplified implementation - in practice, you'd implement
    // format-specific partial parsing strategies
    try {
      // Try parsing smaller chunks of the container
      final chunkSize = (containerBytes.length / 4).round();
      for (int offset = 0; offset < containerBytes.length; offset += chunkSize) {
        final endOffset = (offset + chunkSize).clamp(0, containerBytes.length);
        final chunk = containerBytes.sublist(offset, endOffset);

        try {
          final chunkTags = codec.readFromContainer(chunk);
          tags.addAll(chunkTags);
        } catch (e) {
          // Continue with next chunk
          continue;
        }
      }
    } catch (e) {
      final error = ErrorContext.fromException(
        e is Exception ? e : Exception(e.toString()),
        containerType: containerType,
        containerVersion: containerVersion,
        operation: 'partial_parsing',
        recoveryAction: RecoveryAction.usePartialData,
      );

      errors.add(error);
    }

    return _ParseResult(tags: tags, errors: errors);
  }

  /// Attempts to repair common container corruption patterns.
  Future<_ParseResult> _tryContainerRepair({
    required Uint8List containerBytes,
    required TagCodec codec,
    required String containerType,
    required String containerVersion,
  }) async {
    final tags = <MetadataTag>[];
    final errors = <ErrorContext>[];

    // This is a placeholder for container-specific repair logic
    // In practice, you'd implement format-specific repair strategies
    try {
      // Example repair strategy: try to fix common header corruption
      final repairedBytes = _attemptHeaderRepair(containerBytes, containerType);
      if (repairedBytes != null) {
        final repairedTags = codec.readFromContainer(repairedBytes);
        tags.addAll(repairedTags);
      }
    } catch (e) {
      final error = ErrorContext.fromException(
        e is Exception ? e : Exception(e.toString()),
        containerType: containerType,
        containerVersion: containerVersion,
        operation: 'container_repair',
        recoveryAction: RecoveryAction.repairAndRetry,
      );

      errors.add(error);
    }

    return _ParseResult(tags: tags, errors: errors);
  }

  /// Attempts to repair common header corruption patterns.
  Uint8List? _attemptHeaderRepair(Uint8List containerBytes, String containerType) {
    // This is a simplified example - real implementations would be format-specific
    if (containerBytes.length < 10) {
      return null;
    }

    // Example: Try to fix ID3v2 header corruption
    if (containerType.toLowerCase().contains('id3v2')) {
      final repaired = Uint8List.fromList(containerBytes);

      // Check if header starts with "ID3" - if not, try to find it
      if (repaired.length >= 3 && (repaired[0] != 0x49 || repaired[1] != 0x44 || repaired[2] != 0x33)) {
        // Scan for ID3 signature within first few bytes
        for (int i = 0; i < 10 && i < repaired.length - 3; i++) {
          if (repaired[i] == 0x49 && repaired[i + 1] == 0x44 && repaired[i + 2] == 0x33) {
            // Found ID3 signature, create new buffer starting from here
            return repaired.sublist(i);
          }
        }
      }
    }

    return null;
  }

  /// Determines if an exception represents a critical error.
  bool _isCriticalError(PhonicException exception) {
    // Critical errors are those that indicate fundamental problems
    // that are unlikely to be recoverable
    return exception is UnsupportedFormatException ||
        (exception is CorruptedContainerException && exception.byteOffset != null && exception.byteOffset! < 100); // Early corruption is often critical
  }

  /// Notifies about an error if callback is configured.
  void _notifyError(ErrorContext error) {
    _errorCallback?.call(error);
  }
}

/// Internal result class for container processing.
class _ContainerResult {
  final List<MetadataTag> tags;
  final List<ErrorContext> errors;
  final bool wasProcessed;
  final int errorCount;

  const _ContainerResult({
    required this.tags,
    required this.errors,
    required this.wasProcessed,
    required this.errorCount,
  });
}

/// Internal result class for parsing operations.
class _ParseResult {
  final List<MetadataTag> tags;
  final List<ErrorContext> errors;

  const _ParseResult({
    required this.tags,
    required this.errors,
  });
}

/// Utility functions for error recovery operations.
class ErrorRecoveryUtils {
  /// Scans bytes for potential recovery points (frame/atom boundaries).
  static List<int> findRecoveryPoints(
    Uint8List bytes,
    String containerType, {
    int maxScanBytes = 8192,
  }) {
    final recoveryPoints = <int>[];
    final scanLimit = (maxScanBytes).clamp(0, bytes.length);

    switch (containerType.toLowerCase()) {
      case 'id3v2':
        // Look for frame ID patterns (4 uppercase letters/digits)
        for (int i = 0; i < scanLimit - 4; i++) {
          if (_looksLikeId3v2FrameId(bytes, i)) {
            recoveryPoints.add(i);
          }
        }
        break;

      case 'mp4':
        // Look for atom headers (4-byte size + 4-byte type)
        for (int i = 0; i <= scanLimit - 8; i++) {
          if (_looksLikeMp4Atom(bytes, i)) {
            recoveryPoints.add(i);
          }
        }
        break;

      case 'vorbis':
        // Look for Vorbis comment patterns
        for (int i = 0; i < scanLimit - 8; i++) {
          if (_looksLikeVorbisComment(bytes, i)) {
            recoveryPoints.add(i);
          }
        }
        break;
    }

    return recoveryPoints;
  }

  /// Checks if bytes at offset look like an ID3v2 frame ID.
  static bool _looksLikeId3v2FrameId(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return false;

    for (int i = 0; i < 4; i++) {
      final byte = bytes[offset + i];
      // Frame IDs should be uppercase letters (A-Z) or digits (0-9)
      if (!((byte >= 0x41 && byte <= 0x5A) || (byte >= 0x30 && byte <= 0x39))) {
        return false;
      }
    }

    return true;
  }

  /// Checks if bytes at offset look like an MP4 atom header.
  static bool _looksLikeMp4Atom(Uint8List bytes, int offset) {
    if (offset + 8 > bytes.length) return false;

    // Check if the atom type (bytes 4-7) contains printable ASCII
    for (int i = 4; i < 8; i++) {
      final byte = bytes[offset + i];
      if (byte < 0x20 || byte > 0x7E) {
        return false;
      }
    }

    return true;
  }

  /// Checks if bytes at offset look like a Vorbis comment.
  static bool _looksLikeVorbisComment(Uint8List bytes, int offset) {
    if (offset + 8 > bytes.length) return false;

    // Look for common Vorbis comment field names
    final commonFields = ['TITLE=', 'ARTIST=', 'ALBUM=', 'GENRE='];

    for (final field in commonFields) {
      if (offset + field.length <= bytes.length) {
        final fieldBytes = bytes.sublist(offset, offset + field.length);
        final fieldString = String.fromCharCodes(fieldBytes);
        if (fieldString.toUpperCase() == field) {
          return true;
        }
      }
    }

    return false;
  }

  /// Creates a detailed error report from a list of error contexts.
  static String generateErrorReport(List<ErrorContext> errors) {
    if (errors.isEmpty) {
      return 'No errors occurred during processing.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Error Recovery Report');
    buffer.writeln('===================');
    buffer.writeln('Total Errors: ${errors.length}');
    buffer.writeln();

    // Group errors by type
    final errorsByType = <String, List<ErrorContext>>{};
    for (final error in errors) {
      final type = error.exception.runtimeType.toString();
      errorsByType.putIfAbsent(type, () => []).add(error);
    }

    for (final entry in errorsByType.entries) {
      buffer.writeln('${entry.key}: ${entry.value.length} occurrences');

      for (int i = 0; i < entry.value.length && i < 3; i++) {
        final error = entry.value[i];
        buffer.writeln('  ${i + 1}. ${error.exception.message}');
        if (error.byteOffset != null) {
          buffer.writeln('     At byte: ${error.byteOffset}');
        }
        if (error.containerType != null) {
          buffer.writeln('     Container: ${error.containerType}');
        }
      }

      if (entry.value.length > 3) {
        buffer.writeln('  ... and ${entry.value.length - 3} more');
      }

      buffer.writeln();
    }

    return buffer.toString();
  }
}
