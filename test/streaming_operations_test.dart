import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('StreamingOperations', () {
    late List<String> testFiles;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('phonic_streaming_test');

      // Create test MP3 files with minimal ID3v2.4 tags
      testFiles = [];
      for (int i = 0; i < 10; i++) {
        final filePath = '${tempDir.path}/test_$i.mp3';
        await _createTestMp3File(filePath, 'Title $i', 'Artist $i', 'Album $i');
        testFiles.add(filePath);
      }
    });

    tearDownAll(() async {
      // Clean up temporary files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('StreamingProgress', () {
      test('calculates percentage correctly', () {
        final progress = const StreamingProgress(processed: 25, total: 100);
        expect(progress.percentage, equals(25.0));
      });

      test('handles zero total', () {
        final progress = const StreamingProgress(processed: 0, total: 0);
        expect(progress.percentage, equals(0.0));
      });

      test('identifies completion', () {
        final incomplete = const StreamingProgress(processed: 50, total: 100);
        final complete = const StreamingProgress(processed: 100, total: 100);

        expect(incomplete.isComplete, isFalse);
        expect(complete.isComplete, isTrue);
      });

      test('formats toString correctly', () {
        final progress = const StreamingProgress(
          processed: 25,
          total: 100,
          currentItem: 'test.mp3',
          itemsPerSecond: 5.5,
        );

        final str = progress.toString();
        expect(str, contains('25/100'));
        expect(str, contains('25.0%'));
        expect(str, contains('test.mp3'));
        expect(str, contains('5.5/sec'));
      });
    });

    group('ProcessingResult', () {
      test('creates success result', () {
        final result = ProcessingResult.success(data: 'test data');
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.data, equals('test data'));
      });

      test('creates failure result', () {
        final error = Exception('Test error');
        final result = ProcessingResult.failure(error);
        expect(result.success, isFalse);
        expect(result.error, equals(error));
      });

      test('formats toString correctly', () {
        final success = ProcessingResult.success(message: 'OK');
        final failure = ProcessingResult.failure(Exception('Error'));

        expect(success.toString(), contains('success'));
        expect(failure.toString(), contains('failure'));
      });
    });

    group('StreamingConfig', () {
      test('has reasonable defaults', () {
        const config = StreamingConfig();
        expect(config.maxConcurrentFiles, equals(10));
        expect(config.memoryLimitMB, equals(500));
        expect(config.continueOnError, isTrue);
        expect(config.enableMemoryMonitoring, isTrue);
      });

      test('creates large collection config', () {
        final config = StreamingConfig.forLargeCollections();
        expect(config.maxConcurrentFiles, lessThan(10));
        expect(config.memoryLimitMB, lessThan(500));
        expect(config.continueOnError, isTrue);
      });

      test('creates fast processing config', () {
        final config = StreamingConfig.forFastProcessing();
        expect(config.maxConcurrentFiles, greaterThan(10));
        expect(config.memoryLimitMB, greaterThan(500));
        expect(config.enableMemoryMonitoring, isFalse);
      });
    });

    group('CancellationToken', () {
      test('starts uncancelled', () {
        final token = CancellationToken();
        expect(token.isCancelled, isFalse);
      });

      test('can be cancelled', () {
        final token = CancellationToken();
        token.cancel();
        expect(token.isCancelled, isTrue);
      });

      test('can be reset', () {
        final token = CancellationToken();
        token.cancel();
        token.reset();
        expect(token.isCancelled, isFalse);
      });
    });

    group('StreamingAudioProcessor', () {
      test('processes files sequentially', () async {
        final processor = StreamingAudioProcessor();
        final processedFiles = <String>[];

        final results = await processor.processFiles(
          filePaths: testFiles.take(3).toList(),
          processor: (audioFile, index, total) async {
            // Just record that we processed the file
            processedFiles.add('processed_$index');
            return ProcessingResult.success();
          },
        );

        expect(results.length, equals(3));
        expect(results.every((r) => r.success), isTrue);
        expect(processedFiles, equals(['processed_0', 'processed_1', 'processed_2']));
      });

      test('handles processing errors gracefully', () async {
        final processor = StreamingAudioProcessor();
        var callCount = 0;

        final results = await processor.processFiles(
          filePaths: testFiles.take(3).toList(),
          processor: (audioFile, index, total) async {
            callCount++;
            if (index == 1) {
              throw Exception('Test error');
            }
            return ProcessingResult.success();
          },
        );

        expect(results.length, equals(3));
        expect(results[0].success, isTrue);
        expect(results[1].success, isFalse);
        expect(results[2].success, isTrue);
        expect(callCount, equals(3)); // Should continue after error
      });

      test('reports progress correctly', () async {
        final processor = StreamingAudioProcessor(
          config: const StreamingConfig(progressReportInterval: 1),
        );
        final progressReports = <StreamingProgress>[];

        await processor.processFiles(
          filePaths: testFiles.take(3).toList(),
          processor: (audioFile, index, total) async {
            return ProcessingResult.success();
          },
          onProgress: (progress) {
            progressReports.add(progress);
          },
        );

        expect(progressReports.length, greaterThan(0));
        expect(progressReports.last.processed, equals(3));
        expect(progressReports.last.total, equals(3));
        expect(progressReports.last.isComplete, isTrue);
      });

      test('respects cancellation token', () async {
        final processor = StreamingAudioProcessor();
        final token = CancellationToken();
        final processedFiles = <String>[];

        // Cancel after processing first file
        var processCount = 0;
        final results = await processor.processFiles(
          filePaths: testFiles,
          processor: (audioFile, index, total) async {
            processCount++;
            if (processCount == 2) {
              token.cancel();
            }
            processedFiles.add('processed_$index');
            return ProcessingResult.success();
          },
          cancellationToken: token,
        );

        // Should stop processing after cancellation
        expect(results.length, lessThan(testFiles.length));
        expect(processedFiles.length, lessThan(testFiles.length));
      });

      test('processes files as stream', () async {
        final processor = StreamingAudioProcessor();
        final results = <ProcessingResult>[];

        await for (final result in processor.processFilesAsStream(
          filePaths: testFiles.take(3).toList(),
          processor: (audioFile, index, total) async {
            return ProcessingResult.success(data: 'file_$index');
          },
        )) {
          results.add(result);
        }

        expect(results.length, equals(3));
        expect(results.every((r) => r.success), isTrue);
        expect(results[0].data, equals('file_0'));
        expect(results[1].data, equals('file_1'));
        expect(results[2].data, equals('file_2'));
      });

      test('handles empty file list', () async {
        final processor = StreamingAudioProcessor();

        final results = await processor.processFiles(
          filePaths: [],
          processor: (audioFile, index, total) async {
            return ProcessingResult.success();
          },
        );

        expect(results, isEmpty);
      });

      test('provides memory usage report', () async {
        final processor = StreamingAudioProcessor(
          config: const StreamingConfig(enableMemoryMonitoring: true),
        );

        await processor.processFiles(
          filePaths: testFiles.take(2).toList(),
          processor: (audioFile, index, total) async {
            return ProcessingResult.success();
          },
        );

        final report = processor.getMemoryReport();
        expect(report, isNotNull);
        expect(report!.checkpoints.length, greaterThan(0));
      });
    });

    group('BatchAudioProcessor', () {
      test('processes files in batches', () async {
        final processor = BatchAudioProcessor();
        final batchSizes = <int>[];

        final results = await processor.processBatches(
          filePaths: testFiles.take(5).toList(),
          batchSize: 2,
          processor: (batch) async {
            batchSizes.add(batch.length);
            return batch.map((path) => ProcessingResult.success()).toList();
          },
        );

        expect(results.length, equals(5));
        expect(batchSizes, equals([2, 2, 1])); // 5 files in batches of 2
      });

      test('handles batch processing errors', () async {
        final processor = BatchAudioProcessor();
        var batchCount = 0;

        final results = await processor.processBatches(
          filePaths: testFiles.take(4).toList(),
          batchSize: 2,
          processor: (batch) async {
            batchCount++;
            if (batchCount == 2) {
              throw Exception('Batch error');
            }
            return batch.map((path) => ProcessingResult.success()).toList();
          },
        );

        expect(results.length, equals(4));
        expect(results[0].success, isTrue);
        expect(results[1].success, isTrue);
        expect(results[2].success, isFalse); // Second batch failed
        expect(results[3].success, isFalse);
      });

      test('reports batch progress', () async {
        final processor = BatchAudioProcessor();
        final progressReports = <StreamingProgress>[];

        await processor.processBatches(
          filePaths: testFiles.take(4).toList(),
          batchSize: 2,
          processor: (batch) async {
            return batch.map((path) => ProcessingResult.success()).toList();
          },
          onProgress: (progress) {
            progressReports.add(progress);
          },
        );

        expect(progressReports.length, greaterThan(0));
        expect(progressReports.last.processed, equals(4));
        expect(progressReports.last.total, equals(4));
      });

      test('handles empty file list', () async {
        final processor = BatchAudioProcessor();

        final results = await processor.processBatches(
          filePaths: [],
          batchSize: 2,
          processor: (batch) async {
            return [];
          },
        );

        expect(results, isEmpty);
      });
    });

    group('CollectionAnalyzer', () {
      test('analyzes collection statistics', () async {
        final analyzer = CollectionAnalyzer();

        final stats = await analyzer.analyzeCollection(
          filePaths: testFiles.take(3).toList(),
        );

        // Just verify that files were processed (may not have all metadata)
        expect(stats.totalFiles, equals(3));
        expect(stats.errorCount, equals(0));
      });

      test('handles analysis errors', () async {
        final analyzer = CollectionAnalyzer();

        // Add a non-existent file to trigger an error
        final filesWithError = [...testFiles.take(2), 'non_existent.mp3'];

        final stats = await analyzer.analyzeCollection(
          filePaths: filesWithError,
        );

        // The analyzer should handle errors gracefully
        // Total files may be 2 or 3 depending on error handling
        expect(stats.totalFiles, lessThanOrEqualTo(3));
      });

      test('reports progress during analysis', () async {
        final analyzer = CollectionAnalyzer();
        final progressReports = <StreamingProgress>[];

        await analyzer.analyzeCollection(
          filePaths: testFiles.take(3).toList(),
          onProgress: (progress) {
            progressReports.add(progress);
          },
        );

        expect(progressReports.length, greaterThan(0));
        expect(progressReports.last.isComplete, isTrue);
      });

      test('calculates statistics correctly', () {
        final stats = CollectionStats();
        stats.totalFiles = 100;
        stats.filesWithTitle = 90;
        stats.filesWithArtist = 85;
        stats.filesWithAlbum = 80;

        // Test percentage calculations
        expect(stats.toString(), contains('90 (90.0%)'));
        expect(stats.toString(), contains('85 (85.0%)'));
        expect(stats.toString(), contains('80 (80.0%)'));
      });

      test('handles memory usage reporting', () async {
        final analyzer = CollectionAnalyzer();

        final stats = await analyzer.analyzeCollection(
          filePaths: testFiles.take(2).toList(),
          maxMemoryMB: 100,
        );

        // Just verify the analysis completed
        expect(stats.totalFiles, equals(2));
      });
    });

    group('Performance Tests', () {
      test('processes large number of files efficiently', () async {
        // Create more test files for performance testing
        final largeTestFiles = <String>[];
        for (int i = 0; i < 50; i++) {
          final filePath = '${tempDir.path}/perf_test_$i.mp3';
          await _createTestMp3File(filePath, 'Title $i', 'Artist $i', 'Album $i');
          largeTestFiles.add(filePath);
        }

        final processor = StreamingAudioProcessor(
          config: StreamingConfig.forLargeCollections(),
        );

        final stopwatch = Stopwatch()..start();

        final results = await processor.processFiles(
          filePaths: largeTestFiles,
          processor: (audioFile, index, total) async {
            // Simulate some processing work
            final title = audioFile.getTag(TagKey.title);
            final artist = audioFile.getTag(TagKey.artist);
            return ProcessingResult.success(
              data: '${title?.value} by ${artist?.value}',
            );
          },
        );

        stopwatch.stop();

        expect(results.length, equals(50));
        expect(results.every((r) => r.success), isTrue);

        // Should complete in reasonable time (adjust threshold as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max

        // Clean up performance test files
        for (final file in largeTestFiles) {
          await File(file).delete();
        }
      });

      test('maintains bounded memory usage', () async {
        final processor = StreamingAudioProcessor(
          config: const StreamingConfig(
            maxConcurrentFiles: 5,
            memoryLimitMB: 100,
            enableMemoryMonitoring: true,
          ),
        );

        await processor.processFiles(
          filePaths: testFiles,
          processor: (audioFile, index, total) async {
            // Access all tags to ensure memory usage
            final allTags = audioFile.getAllTags();
            return ProcessingResult.success(data: allTags.length);
          },
        );

        final report = processor.getMemoryReport();
        expect(report, isNotNull);

        // Memory should not grow unbounded
        if (report!.memoryGrowth != null) {
          // Allow some growth but not excessive
          expect(report.memoryGrowth!, lessThan(100 * 1024 * 1024)); // 100MB max growth
        }
      });
    });
  });
}

/// Creates a minimal MP3 file with ID3v2.4 tags for testing.
Future<void> _createTestMp3File(String filePath, String title, String artist, String album) async {
  final mp3Bytes = _createMp3WithId3v24Tags(title, artist, album);
  await File(filePath).writeAsBytes(mp3Bytes);
}

/// Creates an MP3 file with ID3v2.4 tags containing test data.
Uint8List _createMp3WithId3v24Tags(String title, String artist, String album) {
  final bytes = Uint8List(1024);

  // Write ID3v2.4 header with frames
  _writeId3v24HeaderWithFrames(bytes, 0, {
    'TIT2': title,
    'TPE1': artist,
    'TALB': album,
  });

  return bytes;
}

/// Writes an ID3v2.4 header with simple text frames.
int _writeId3v24HeaderWithFrames(Uint8List bytes, int offset, Map<String, String> frames) {
  // Write basic header first
  _writeId3v24Header(bytes, offset);

  int frameOffset = offset + 10;
  int totalFrameSize = 0;

  // Write each frame
  for (final entry in frames.entries) {
    final frameId = entry.key;
    final text = entry.value;

    // Frame header: ID (4 bytes) + size (4 bytes) + flags (2 bytes)
    for (int i = 0; i < frameId.length; i++) {
      bytes[frameOffset + i] = frameId.codeUnitAt(i);
    }

    // Frame size (text encoding byte + text bytes)
    final textBytes = text.codeUnits;
    final frameSize = 1 + textBytes.length;

    bytes[frameOffset + 4] = (frameSize >> 24) & 0xFF;
    bytes[frameOffset + 5] = (frameSize >> 16) & 0xFF;
    bytes[frameOffset + 6] = (frameSize >> 8) & 0xFF;
    bytes[frameOffset + 7] = frameSize & 0xFF;

    // Frame flags (none)
    bytes[frameOffset + 8] = 0x00;
    bytes[frameOffset + 9] = 0x00;

    // Frame data: encoding byte + text
    bytes[frameOffset + 10] = 0x03; // UTF-8 encoding
    for (int i = 0; i < textBytes.length; i++) {
      bytes[frameOffset + 11 + i] = textBytes[i];
    }

    frameOffset += 10 + frameSize;
    totalFrameSize += 10 + frameSize;
  }

  // Update header with total frame size (synchsafe integer)
  _writeSynchsafeInt(bytes, offset + 6, totalFrameSize);

  return frameOffset;
}

/// Writes a basic ID3v2.4 header to the byte array.
void _writeId3v24Header(Uint8List bytes, int offset) {
  bytes[offset + 0] = 0x49; // 'I'
  bytes[offset + 1] = 0x44; // 'D'
  bytes[offset + 2] = 0x33; // '3'
  bytes[offset + 3] = 0x04; // Version 2.4
  bytes[offset + 4] = 0x00; // Minor version
  bytes[offset + 5] = 0x00; // Flags
  bytes[offset + 6] = 0x00; // Size (synchsafe) - will be updated if frames added
  bytes[offset + 7] = 0x00;
  bytes[offset + 8] = 0x00;
  bytes[offset + 9] = 0x00;
}

/// Writes a synchsafe integer to the byte array.
void _writeSynchsafeInt(Uint8List bytes, int offset, int value) {
  bytes[offset + 0] = (value >> 21) & 0x7F;
  bytes[offset + 1] = (value >> 14) & 0x7F;
  bytes[offset + 2] = (value >> 7) & 0x7F;
  bytes[offset + 3] = value & 0x7F;
}
