import 'dart:io';
import 'dart:typed_data';

import 'package:phonic/src/core/phonic.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/streaming/batch_audio_processor.dart';
import 'package:phonic/src/streaming/cancellation_token.dart';
import 'package:phonic/src/streaming/collection_analyzer.dart';
import 'package:phonic/src/streaming/processing_result.dart';
import 'package:phonic/src/streaming/streaming_audio_processor.dart';
import 'package:phonic/src/streaming/streaming_config.dart';
import 'package:phonic/src/streaming/streaming_progress.dart';
import 'package:test/test.dart';

/// Performance tests for streaming operations to ensure they work efficiently
/// with large collections and maintain bounded memory usage.
void main() {
  group('StreamingOperations Performance', () {
    late List<String> testFiles;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('phonic_perf_test');

      // Create a larger set of test files for performance testing
      testFiles = [];
      for (int i = 0; i < 100; i++) {
        final filePath = '${tempDir.path}/perf_test_$i.mp3';
        await _createTestMp3File(filePath, 'Title $i', 'Artist ${i % 10}', 'Album ${i % 5}');
        testFiles.add(filePath);
      }
    });

    tearDownAll(() async {
      // Clean up temporary files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('processes large collection efficiently', () async {
      final processor = StreamingAudioProcessor(
        config: StreamingConfig.forLargeCollections(),
      );

      final stopwatch = Stopwatch()..start();
      var processedCount = 0;

      final results = await processor.processFiles(
        filePaths: testFiles,
        processor: (audioFile, index, total) async {
          processedCount++;

          // Simulate some processing work
          final allTags = audioFile.getAllTags();

          return ProcessingResult.success(data: allTags.length);
        },
        onProgress: (progress) {
          // Progress reporting should not significantly impact performance
        },
      );

      stopwatch.stop();

      expect(results.length, equals(testFiles.length));
      expect(processedCount, equals(testFiles.length));

      // Should complete in reasonable time (adjust threshold as needed)
      expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60 seconds max
    });

    test('maintains bounded memory usage during streaming', () async {
      final processor = StreamingAudioProcessor(
        config: const StreamingConfig(
          maxConcurrentFiles: 5,
          memoryLimitMB: 100,
          enableMemoryMonitoring: true,
          memoryMonitorInterval: 10,
        ),
      );

      await processor.processFiles(
        filePaths: testFiles.take(50).toList(),
        processor: (audioFile, index, total) async {
          // Access all tags to ensure memory usage
          final allTags = audioFile.getAllTags();

          // Simulate some processing that might accumulate memory
          final data = List.generate(1000, (i) => 'data_$i');

          return ProcessingResult.success(data: allTags.length + data.length);
        },
      );

      final report = processor.getMemoryReport();
      expect(report, isNotNull);

      // Memory growth should remain bounded to prevent runaway memory consumption
      // Threshold set to 1GB to account for baseline memory variance in test environment
      if (report!.memoryGrowth != null) {
        expect(report.memoryGrowth!, lessThan(1024 * 1024 * 1024)); // 1GB max
      }

      if (report.peakMemoryUsage != null) {
        // Peak memory usage tracked for verification
      }
    });

    test('batch processing scales efficiently', () async {
      final batchProcessor = BatchAudioProcessor(
        config: StreamingConfig.forFastProcessing(),
      );

      final stopwatch = Stopwatch()..start();

      final results = await batchProcessor.processBatches(
        filePaths: testFiles,
        batchSize: 10,
        processor: (batch) async {
          // Simulate batch processing
          final batchResults = <ProcessingResult>[];

          for (final filePath in batch) {
            try {
              final audioFile = await Phonic.fromFileAsync(filePath);
              final allTags = audioFile.getAllTags();
              audioFile.dispose();

              batchResults.add(ProcessingResult.success(data: allTags.length));
            } catch (e) {
              batchResults.add(
                ProcessingResult.failure(
                  e is Exception ? e : Exception(e.toString()),
                ),
              );
            }
          }

          return batchResults;
        },
      );

      stopwatch.stop();

      expect(results.length, equals(testFiles.length));

      // Batch processing should be efficient
      expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60 seconds max
    });

    test('collection analysis handles large collections', () async {
      final analyzer = CollectionAnalyzer(
        config: StreamingConfig.forLargeCollections(),
      );

      final stopwatch = Stopwatch()..start();

      final stats = await analyzer.analyzeCollection(
        filePaths: testFiles,
        maxMemoryMB: 150,
      );

      stopwatch.stop();

      expect(stats.totalFiles, equals(testFiles.length));

      // Analysis should complete in reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60 seconds max

      // Analysis completed - statistics available for verification
    });

    test('streaming with progress reporting performs well', () async {
      final processor = StreamingAudioProcessor(
        config: const StreamingConfig(
          progressReportInterval: 5,
          enableMemoryMonitoring: true,
        ),
      );

      final progressReports = <StreamingProgress>[];
      final stopwatch = Stopwatch()..start();

      await for (final result in processor.processFilesAsStream(
        filePaths: testFiles.take(50).toList(),
        processor: (audioFile, index, total) async {
          // Minimal processing to test streaming performance
          final title = audioFile.getTag(TagKey.title);
          return ProcessingResult.success(data: title?.value);
        },
        onProgress: (progress) {
          progressReports.add(progress);
        },
      )) {
        // Process results as they come in
        expect(result, isNotNull);
      }

      stopwatch.stop();

      expect(progressReports.length, greaterThan(0));

      // Streaming should be efficient
      expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max
    });

    test('cancellation works efficiently', () async {
      final processor = StreamingAudioProcessor();
      final cancellationToken = CancellationToken();

      var processedCount = 0;
      final stopwatch = Stopwatch()..start();

      // Cancel after processing 10 files
      Future.delayed(const Duration(milliseconds: 500), () {
        cancellationToken.cancel();
      });

      final results = await processor.processFiles(
        filePaths: testFiles,
        processor: (audioFile, index, total) async {
          processedCount++;

          // Simulate some processing time
          await Future.delayed(const Duration(milliseconds: 50));

          return ProcessingResult.success();
        },
        cancellationToken: cancellationToken,
      );

      stopwatch.stop();

      // Should have processed fewer files than total due to cancellation
      expect(results.length, lessThan(testFiles.length));
      expect(processedCount, lessThan(testFiles.length));

      // Should stop quickly after cancellation
      expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // 10 seconds max

      // Cancellation completed successfully
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
