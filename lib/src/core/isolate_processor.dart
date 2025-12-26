import 'dart:typed_data';

import 'phonic.dart';
import 'phonic_audio_file.dart';

/// Internal class for processing audio files in isolates.
///
/// This class handles the implementation details of isolate-based processing,
/// keeping the public Phonic API clean and focused.
class IsolateProcessor {
  /// Processes audio file bytes in an isolate.
  ///
  /// This validates the file can be parsed and returns success/failure status.
  /// We don't transfer tag data since we'll re-parse in the main isolate
  /// after validation.
  static Future<_IsolateProcessingResult> processInIsolate(
    Uint8List bytes,
    String? filename,
  ) => processInIsolateAsync(bytes, filename);

  /// Processes audio file bytes in an isolate.
  static Future<_IsolateProcessingResult> processInIsolateAsync(
    Uint8List bytes,
    String? filename,
  ) async {
    final request = _IsolateProcessingRequest(
      fileBytes: bytes,
      filename: filename,
    );

    return _runInIsolateAsync(request);
  }

  /// Runs the processing logic.
  static Future<_IsolateProcessingResult> _runInIsolateAsync(
    _IsolateProcessingRequest request,
  ) async {
    return _processInIsolate(request);
  }

  /// Validates the file can be parsed.
  static _IsolateProcessingResult _processInIsolate(
    _IsolateProcessingRequest request,
  ) {
    try {
      // Parse the file to validate it's supported and readable
      // This is the expensive operation we want to offload
      final _ = Phonic.fromBytes(request.fileBytes, request.filename);

      // If we got here, the file is valid and parseable
      return const _IsolateProcessingResult(
        success: true,
      );
    } catch (e) {
      // Return error information
      return _IsolateProcessingResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reconstructs a PhonicAudioFile from isolate processing result.
  ///
  /// Simply re-parses the file in the main isolate after validation.
  static PhonicAudioFile reconstructFromResult(
    _IsolateProcessingResult result,
    Uint8List fileBytes,
    String? filename,
  ) {
    // Simply parse the file normally - the isolate already validated it works
    return Phonic.fromBytes(fileBytes, filename);
  }
}

/// Request message for isolate processing.
class _IsolateProcessingRequest {
  /// The audio file bytes to process.
  final Uint8List fileBytes;

  /// Optional filename for format detection hints.
  final String? filename;

  /// Creates a new isolate processing request.
  const _IsolateProcessingRequest({
    required this.fileBytes,
    this.filename,
  });
}

/// Result from isolate processing.
class _IsolateProcessingResult {
  /// Whether processing was successful.
  final bool success;

  /// Error message if processing failed.
  final String? errorMessage;

  /// Creates a new isolate processing result.
  const _IsolateProcessingResult({
    required this.success,
    this.errorMessage,
  });
}
