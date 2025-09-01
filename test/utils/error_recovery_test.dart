import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/container_locator.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/exceptions/phonic_exception.dart';
import 'package:phonic/src/exceptions/unsupported_format_exception.dart';
import 'package:phonic/src/utils/error_recovery.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('ErrorRecoveryPolicy', () {
    test('creates default policy with expected values', () {
      const policy = ErrorRecoveryPolicy();

      expect(policy.skipCorruptedContainers, isTrue);
      expect(policy.preservePartialData, isTrue);
      expect(policy.maxErrorsPerContainer, equals(5));
      expect(policy.continueAfterCriticalError, isFalse);
      expect(policy.enableDetailedLogging, isTrue);
      expect(policy.attemptContainerRepair, isFalse);
      expect(policy.maxRecoveryScanBytes, equals(8192));
    });

    test('creates aggressive policy with maximum recovery settings', () {
      final policy = ErrorRecoveryPolicy.aggressive();

      expect(policy.skipCorruptedContainers, isTrue);
      expect(policy.preservePartialData, isTrue);
      expect(policy.maxErrorsPerContainer, equals(10));
      expect(policy.continueAfterCriticalError, isTrue);
      expect(policy.enableDetailedLogging, isTrue);
      expect(policy.attemptContainerRepair, isTrue);
      expect(policy.maxRecoveryScanBytes, equals(16384));
    });

    test('creates conservative policy with minimal recovery settings', () {
      final policy = ErrorRecoveryPolicy.conservative();

      expect(policy.skipCorruptedContainers, isTrue);
      expect(policy.preservePartialData, isFalse);
      expect(policy.maxErrorsPerContainer, equals(2));
      expect(policy.continueAfterCriticalError, isFalse);
      expect(policy.enableDetailedLogging, isFalse);
      expect(policy.attemptContainerRepair, isFalse);
      expect(policy.maxRecoveryScanBytes, equals(4096));
    });
  });

  group('ErrorContext', () {
    test('creates error context from corrupted container exception', () {
      final exception = const CorruptedContainerException(
        'Invalid frame header',
        byteOffset: 1024,
        context: 'test context',
      );

      final errorContext = ErrorContext.fromCorruptedContainer(
        exception,
        containerType: 'ID3v2',
        containerVersion: '2.4',
        operation: 'frame_parsing',
        additionalContext: {'frame_id': 'TIT2'},
        recoveryAction: RecoveryAction.skipFrame,
      );

      expect(errorContext.exception, equals(exception));
      expect(errorContext.byteOffset, equals(1024));
      expect(errorContext.containerType, equals('ID3v2'));
      expect(errorContext.containerVersion, equals('2.4'));
      expect(errorContext.operation, equals('frame_parsing'));
      expect(errorContext.additionalContext['frame_id'], equals('TIT2'));
      expect(errorContext.recoveryAction, equals(RecoveryAction.skipFrame));
    });

    test('creates error context from generic exception', () {
      final exception = Exception('Generic error');

      final errorContext = ErrorContext.fromException(
        exception,
        byteOffset: 512,
        containerType: 'MP4',
        operation: 'atom_parsing',
        recoveryAction: RecoveryAction.skipContainer,
      );

      expect(errorContext.exception, isA<PhonicException>());
      expect(errorContext.byteOffset, equals(512));
      expect(errorContext.containerType, equals('MP4'));
      expect(errorContext.operation, equals('atom_parsing'));
      expect(errorContext.recoveryAction, equals(RecoveryAction.skipContainer));
    });

    test('generates detailed string representation', () {
      final exception = const CorruptedContainerException(
        'Test error',
        byteOffset: 256,
        context: 'test context',
      );

      final errorContext = ErrorContext.fromCorruptedContainer(
        exception,
        containerType: 'ID3v2',
        containerVersion: '2.4',
        operation: 'parsing',
        additionalContext: {'test_key': 'test_value'},
      );

      final detailedString = errorContext.toDetailedString();

      expect(detailedString, contains('Error Context:'));
      expect(detailedString, contains('Exception: CorruptedContainerException'));
      expect(detailedString, contains('Message: Test error'));
      expect(detailedString, contains('Byte Offset: 256'));
      expect(detailedString, contains('Container: ID3v2 v2.4'));
      expect(detailedString, contains('Operation: parsing'));
      expect(detailedString, contains('Recovery Action: skipContainer'));
      expect(detailedString, contains('test_key: test_value'));
    });

    test('generates concise string representation', () {
      final exception = const CorruptedContainerException('Test error', byteOffset: 256);
      final errorContext = ErrorContext.fromCorruptedContainer(
        exception,
        containerType: 'ID3v2',
        operation: 'parsing',
      );

      final string = errorContext.toString();

      expect(string, contains('Test error'));
      expect(string, contains('at byte 256'));
      expect(string, contains('in ID3v2'));
      expect(string, contains('during parsing'));
    });
  });

  group('RecoveryResult', () {
    test('creates successful recovery result', () {
      final tags = <MetadataTag>[
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
      ];

      final result = RecoveryResult.success(
        tags,
        containersProcessed: 2,
        statistics: {'test': 'value'},
      );

      expect(result.tags, equals(tags));
      expect(result.errors, isEmpty);
      expect(result.hasPartialSuccess, isTrue);
      expect(result.isFullSuccess, isTrue);
      expect(result.containersProcessed, equals(2));
      expect(result.containersSkipped, equals(0));
      expect(result.statistics['test'], equals('value'));
    });

    test('creates failed recovery result', () {
      final errors = [
        ErrorContext.fromException(
          Exception('Test error'),
          recoveryAction: RecoveryAction.skipContainer,
        ),
      ];

      final partialTags = <MetadataTag>[const TitleTag('Partial Title')];

      final result = RecoveryResult.failure(
        errors,
        partialTags: partialTags,
        containersProcessed: 1,
        containersSkipped: 2,
      );

      expect(result.tags, equals(partialTags));
      expect(result.errors, equals(errors));
      expect(result.hasPartialSuccess, isTrue);
      expect(result.isFullSuccess, isFalse);
      expect(result.containersProcessed, equals(1));
      expect(result.containersSkipped, equals(2));
    });

    test('generates summary string', () {
      final tags = <MetadataTag>[const TitleTag('Test')];
      final errors = [
        ErrorContext.fromException(
          Exception('Test error'),
          recoveryAction: RecoveryAction.skipContainer,
        ),
      ];

      final result = RecoveryResult(
        tags: tags,
        errors: errors,
        hasPartialSuccess: true,
        isFullSuccess: false,
        containersProcessed: 2,
        containersSkipped: 1,
      );

      final summary = result.getSummary();

      expect(summary, contains('Partial Success'));
      expect(summary, contains('1 tags recovered'));
      expect(summary, contains('1 errors'));
      expect(summary, contains('1 containers skipped'));
    });
  });

  group('ErrorRecoveryManager', () {
    late ErrorRecoveryManager manager;
    late List<ErrorContext> capturedErrors;

    setUp(() {
      capturedErrors = [];
      manager = ErrorRecoveryManager(
        policy: const ErrorRecoveryPolicy(enableDetailedLogging: false),
        onError: (error) => capturedErrors.add(error),
      );
    });

    test('recovers from containers with successful parsing', () async {
      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [_MockLocator(true, ContainerKind.id3v2)];
      final codecs = [
        _MockCodec(ContainerKind.id3v2, [const TitleTag('Test')]),
      ];

      final result = await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isTrue);
      expect(result.tags.length, equals(1));
      expect(result.tags.first, isA<TitleTag>());
      expect(result.errors, isEmpty);
      expect(result.containersProcessed, equals(1));
      expect(result.containersSkipped, equals(0));
    });

    test('handles container extraction failure gracefully', () async {
      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [_MockLocator(true, ContainerKind.id3v2, throwOnExtract: true)];
      final codecs = [_MockCodec(ContainerKind.id3v2, [])];

      final result = await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isFalse);
      expect(result.hasPartialSuccess, isFalse);
      expect(result.tags, isEmpty);
      expect(result.errors.length, equals(1));
      expect(result.containersProcessed, equals(0));
      expect(result.containersSkipped, equals(1));
      expect(capturedErrors.length, equals(1));
    });

    test('handles parsing failure with partial data recovery', () async {
      final policy = const ErrorRecoveryPolicy(
        preservePartialData: true,
        enableDetailedLogging: false,
      );
      final managerWithRecovery = ErrorRecoveryManager(
        policy: policy,
        onError: (error) => capturedErrors.add(error),
      );

      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [_MockLocator(true, ContainerKind.id3v2)];
      final codecs = [_MockCodec(ContainerKind.id3v2, [], throwOnRead: true)];

      final result = await managerWithRecovery.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isFalse);
      expect(result.errors.isNotEmpty, isTrue);
      expect(result.containersProcessed, equals(1));
      expect(capturedErrors.isNotEmpty, isTrue);
    });

    test('skips containers that do not match', () async {
      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [
        _MockLocator(false, ContainerKind.id3v2), // Does not match
        _MockLocator(true, ContainerKind.id3v1), // Matches
      ];
      final codecs = [
        _MockCodec(ContainerKind.id3v2, []),
        _MockCodec(ContainerKind.id3v1, [const ArtistTag('Test Artist')]),
      ];

      final result = await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isTrue);
      expect(result.tags.length, equals(1));
      expect(result.tags.first, isA<ArtistTag>());
      expect(result.containersProcessed, equals(1));
    });

    test('handles missing codec for container type', () async {
      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [_MockLocator(true, ContainerKind.id3v2)];
      final codecs = [_MockCodec(ContainerKind.id3v1, [])]; // Wrong codec type

      final result = await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isFalse);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.exception, isA<UnsupportedFormatException>());
      expect(result.containersSkipped, equals(1));
    });

    test('stops processing on critical error when policy disallows continuation', () async {
      final policy = const ErrorRecoveryPolicy(
        continueAfterCriticalError: false,
        enableDetailedLogging: false,
      );
      final strictManager = ErrorRecoveryManager(policy: policy);

      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [
        _MockLocator(true, ContainerKind.id3v2, throwCriticalError: true),
        _MockLocator(true, ContainerKind.id3v1), // Should not be processed
      ];
      final codecs = [
        _MockCodec(ContainerKind.id3v2, []),
        _MockCodec(ContainerKind.id3v1, [const TitleTag('Should not be reached')]),
      ];

      final result = await strictManager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      expect(result.isFullSuccess, isFalse);
      expect(result.containersSkipped, equals(1));
      // Second container should not be processed due to critical error
      expect(result.tags.any((tag) => tag.value == 'Should not be reached'), isFalse);
    });

    test('reports progress during processing', () async {
      final progressReports = <String>[];

      final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final locators = [
        _MockLocator(true, ContainerKind.id3v2),
        _MockLocator(true, ContainerKind.id3v1),
      ];
      final codecs = [
        _MockCodec(ContainerKind.id3v2, [const TitleTag('Test')]),
        _MockCodec(ContainerKind.id3v1, [const ArtistTag('Test')]),
      ];

      await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
        onProgress: (processed, total) {
          progressReports.add('$processed/$total');
        },
      );

      expect(progressReports, isNotEmpty);
      expect(progressReports.last, equals('2/2'));
    });
  });

  group('ErrorRecoveryUtils', () {
    test('finds ID3v2 frame recovery points', () {
      // Create bytes with valid ID3v2 frame IDs
      final bytes = Uint8List.fromList([
        // Invalid data
        0x00, 0x00, 0x00, 0x00,
        // Valid frame ID "TIT2"
        0x54, 0x49, 0x54, 0x32, // T I T 2
        // More invalid data
        0xFF, 0xFF, 0xFF, 0xFF,
        // Valid frame ID "TPE1"
        0x54, 0x50, 0x45, 0x31, // T P E 1
        // End
        0x00, 0x00,
      ]);

      final recoveryPoints = ErrorRecoveryUtils.findRecoveryPoints(
        bytes,
        'id3v2',
        maxScanBytes: bytes.length,
      );

      expect(recoveryPoints, contains(4)); // TIT2 at offset 4
      expect(recoveryPoints, contains(12)); // TPE1 at offset 12
    });

    test('finds MP4 atom recovery points', () {
      // Create bytes with valid MP4 atom headers
      final bytes = Uint8List.fromList([
        // Invalid data
        0x00, 0x00, 0x00, 0x00,
        // Valid atom header (size + type)
        0x00, 0x00, 0x00, 0x20, // Size: 32 bytes
        0x6D, 0x6F, 0x6F, 0x76, // Type: "moov"
        // More data
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        // Another valid atom
        0x00, 0x00, 0x00, 0x10, // Size: 16 bytes
        0x66, 0x74, 0x79, 0x70, // Type: "ftyp"
      ]);

      final recoveryPoints = ErrorRecoveryUtils.findRecoveryPoints(
        bytes,
        'mp4',
        maxScanBytes: bytes.length,
      );

      expect(recoveryPoints, contains(4)); // moov at offset 4
      expect(recoveryPoints, contains(20)); // ftyp at offset 20
    });

    test('finds Vorbis comment recovery points', () {
      // Create bytes with Vorbis comment field names
      final titleBytes = 'TITLE='.codeUnits;
      final artistBytes = 'ARTIST='.codeUnits;

      final bytes = Uint8List.fromList([
        // Invalid data
        0x00, 0x00, 0x00, 0x00,
        // TITLE= field
        ...titleBytes,
        // Some data
        0x00, 0x00, 0x00, 0x00,
        // ARTIST= field
        ...artistBytes,
        // End
        0x00, 0x00,
      ]);

      final recoveryPoints = ErrorRecoveryUtils.findRecoveryPoints(
        bytes,
        'vorbis',
        maxScanBytes: bytes.length,
      );

      expect(recoveryPoints, contains(4)); // TITLE= at offset 4
      expect(recoveryPoints, contains(14)); // ARTIST= at offset 14
    });

    test('respects max scan bytes limit', () {
      final bytes = Uint8List.fromList([
        // Valid frame ID at start
        0x54, 0x49, 0x54, 0x32, // TIT2
        // Fill with data
        ...List.filled(100, 0x00),
        // Valid frame ID beyond limit
        0x54, 0x50, 0x45, 0x31, // TPE1
      ]);

      final recoveryPoints = ErrorRecoveryUtils.findRecoveryPoints(
        bytes,
        'id3v2',
        maxScanBytes: 50, // Limit scan to first 50 bytes
      );

      expect(recoveryPoints, contains(0)); // TIT2 at start
      expect(recoveryPoints, isNot(contains(104))); // TPE1 beyond limit
    });

    test('generates comprehensive error report', () {
      final errors = [
        ErrorContext.fromCorruptedContainer(
          const CorruptedContainerException('Frame header corrupted', byteOffset: 100),
          containerType: 'ID3v2',
          recoveryAction: RecoveryAction.skipFrame,
        ),
        ErrorContext.fromCorruptedContainer(
          const CorruptedContainerException('Invalid size field', byteOffset: 200),
          containerType: 'ID3v2',
          recoveryAction: RecoveryAction.skipFrame,
        ),
        ErrorContext.fromException(
          const UnsupportedFormatException('Unknown format'),
          containerType: 'Unknown',
          recoveryAction: RecoveryAction.skipContainer,
        ),
      ];

      final report = ErrorRecoveryUtils.generateErrorReport(errors);

      expect(report, contains('Error Recovery Report'));
      expect(report, contains('Total Errors: 3'));
      expect(report, contains('CorruptedContainerException: 2 occurrences'));
      expect(report, contains('UnsupportedFormatException: 1 occurrences'));
      expect(report, contains('Frame header corrupted'));
      expect(report, contains('At byte: 100'));
      expect(report, contains('Container: ID3v2'));
    });

    test('handles empty error list', () {
      final report = ErrorRecoveryUtils.generateErrorReport([]);
      expect(report, equals('No errors occurred during processing.'));
    });
  });

  group('RecoveryAction enum', () {
    test('has all expected values', () {
      expect(RecoveryAction.values, contains(RecoveryAction.skipContainer));
      expect(RecoveryAction.values, contains(RecoveryAction.skipFrame));
      expect(RecoveryAction.values, contains(RecoveryAction.repairAndRetry));
      expect(RecoveryAction.values, contains(RecoveryAction.usePartialData));
      expect(RecoveryAction.values, contains(RecoveryAction.stopProcessing));
      expect(RecoveryAction.values, contains(RecoveryAction.useDefaults));
    });
  });

  group('Integration tests', () {
    test('complete error recovery workflow with multiple container types', () async {
      final capturedErrors = <ErrorContext>[];
      final policy = ErrorRecoveryPolicy.aggressive();
      final manager = ErrorRecoveryManager(
        policy: policy,
        onError: (error) => capturedErrors.add(error),
      );

      final fileBytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));

      final locators = [
        _MockLocator(true, ContainerKind.id3v2, throwOnExtract: true), // Fails
        _MockLocator(true, ContainerKind.id3v1), // Succeeds
        _MockLocator(true, ContainerKind.vorbis, throwOnExtract: true), // Fails
      ];

      final codecs = [
        _MockCodec(ContainerKind.id3v2, []),
        _MockCodec(ContainerKind.id3v1, [const TitleTag('Recovered Title')]),
        _MockCodec(ContainerKind.vorbis, []),
      ];

      final result = await manager.recoverFromContainers(
        fileBytes: fileBytes,
        locators: locators,
        codecs: codecs,
      );

      // Should have partial success despite failures
      expect(result.hasPartialSuccess, isTrue);
      expect(result.isFullSuccess, isFalse);
      expect(result.tags.length, equals(1));
      expect(result.tags.first.value, equals('Recovered Title'));
      expect(result.errors.length, equals(2)); // Two extraction failures
      expect(result.containersProcessed, equals(1));
      expect(result.containersSkipped, equals(2));
      expect(capturedErrors.length, equals(2));

      // Check statistics
      expect(result.statistics['containersProcessed'], equals(1));
      expect(result.statistics['containersSkipped'], equals(2));
      expect(result.statistics['tagsRecovered'], equals(1));
      expect(result.statistics['errorsEncountered'], equals(2));
    });
  });
}

// Mock classes for testing

class _MockLocator implements ContainerLocator {
  final bool _matches;
  final ContainerKind _containerKind;
  final bool _throwOnExtract;
  final bool _throwCriticalError;

  _MockLocator(
    this._matches,
    this._containerKind, {
    bool throwOnExtract = false,
    bool throwCriticalError = false,
  }) : _throwOnExtract = throwOnExtract,
       _throwCriticalError = throwCriticalError;

  @override
  ContainerKind get containerKind => _containerKind;

  @override
  bool fileMatches(Uint8List fileBytes) => _matches;

  @override
  Uint8List extract(Uint8List fileBytes) {
    if (_throwCriticalError) {
      throw const UnsupportedFormatException('Critical error for testing');
    }
    if (_throwOnExtract) {
      throw const CorruptedContainerException(
        'Mock extraction failure',
        byteOffset: 0,
      );
    }
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    throw UnimplementedError('Not needed for tests');
  }
}

class _MockCodec implements TagCodec {
  final ContainerKind _containerKind;
  final List<MetadataTag> _tags;
  final bool _throwOnRead;

  _MockCodec(
    this._containerKind,
    this._tags, {
    bool throwOnRead = false,
  }) : _throwOnRead = throwOnRead;

  @override
  ContainerKind get containerKind => _containerKind;

  @override
  String get containerVersion => '1.0';

  @override
  TagCapability get capability => const TagCapability(
    containerKind: ContainerKind.none,
    containerVersion: '',
    semanticsByKey: {},
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (_throwOnRead) {
      throw const CorruptedContainerException(
        'Mock parsing failure',
        byteOffset: 10,
      );
    }
    return _tags;
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    throw UnimplementedError('Not needed for tests');
  }
}
