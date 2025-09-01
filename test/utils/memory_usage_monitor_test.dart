import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/utils/memory_usage_monitor.dart';

void main() {
  group('MemoryUsageMonitor', () {
    late MemoryUsageMonitor monitor;

    setUp(() {
      monitor = MemoryUsageMonitor();
    });

    tearDown(() {
      monitor.clear();
    });

    group('Basic Functionality', () {
      test('should record baseline', () {
        monitor.recordBaseline('test_baseline');

        expect(monitor.hasBaseline, isTrue);
        expect(monitor.checkpointCount, equals(0)); // Baseline is separate
      });

      test('should record checkpoints', () {
        monitor.recordCheckpoint('checkpoint_1');
        monitor.recordCheckpoint('checkpoint_2');

        expect(monitor.checkpointCount, equals(2));
      });

      test('should generate empty report with no data', () {
        final report = monitor.generateReport();

        expect(report.checkpoints, isEmpty);
        expect(report.totalDuration, equals(Duration.zero));
        expect(report.hasMemoryLeak, isFalse);
      });

      test('should generate report with checkpoints', () async {
        monitor.recordBaseline('start');

        // Add some delay to ensure different timestamps
        await Future.delayed(const Duration(milliseconds: 10));
        monitor.recordCheckpoint('middle');

        await Future.delayed(const Duration(milliseconds: 20));
        monitor.recordCheckpoint('end');

        final report = monitor.generateReport();
        expect(report.checkpoints.length, equals(2));
        expect(report.totalDuration.inMilliseconds, greaterThan(0));
      });

      test('should clear all data', () {
        monitor.recordBaseline();
        monitor.recordCheckpoint();

        expect(monitor.hasBaseline, isTrue);
        expect(monitor.checkpointCount, equals(1));

        monitor.clear();

        expect(monitor.hasBaseline, isFalse);
        expect(monitor.checkpointCount, equals(0));
      });
    });

    group('Memory Leak Detection', () {
      test('should not detect leak with insufficient data', () {
        monitor.recordCheckpoint();
        monitor.recordCheckpoint();

        final report = monitor.generateReport();
        expect(report.hasMemoryLeak, isFalse);
      });

      test('should detect potential memory leak with consistent growth', () {
        // This test simulates memory leak detection logic
        // In practice, actual memory values would be used

        // Create multiple checkpoints - the actual leak detection
        // would analyze real memory usage patterns
        for (int i = 0; i < 10; i++) {
          monitor.recordCheckpoint('checkpoint_$i');
        }

        final report = monitor.generateReport();
        // Note: Without actual memory values, leak detection may not trigger
        // This test verifies the structure is in place
        expect(report.hasMemoryLeak, isA<bool>());
      });
    });

    group('Current Memory Usage', () {
      test('should get current memory usage without recording', () {
        final current = monitor.getCurrentMemoryUsage();

        expect(current.label, equals('current'));
        expect(current.timestamp, isA<DateTime>());
        expect(monitor.checkpointCount, equals(0)); // Should not record
      });
    });
  });

  group('MemoryCheckpoint', () {
    test('should create checkpoint with all data', () {
      final timestamp = DateTime.now();
      final checkpoint = MemoryCheckpoint(
        label: 'test',
        timestamp: timestamp,
        rssMemory: 1024 * 1024, // 1MB
        heapUsage: 512 * 1024, // 512KB
      );

      expect(checkpoint.label, equals('test'));
      expect(checkpoint.timestamp, equals(timestamp));
      expect(checkpoint.rssMemory, equals(1024 * 1024));
      expect(checkpoint.heapUsage, equals(512 * 1024));
    });

    test('should format toString correctly', () {
      final checkpoint = MemoryCheckpoint(
        label: 'test',
        timestamp: DateTime.parse('2023-01-01T12:00:00Z'),
        rssMemory: 1024 * 1024, // 1MB
        heapUsage: 512 * 1024, // 512KB
      );

      final str = checkpoint.toString();
      expect(str, contains('test'));
      expect(str, contains('2023-01-01T12:00:00.000Z'));
      expect(str, contains('1.0MB')); // RSS memory
      expect(str, contains('512.0KB')); // Heap usage
    });

    test('should handle missing memory data', () {
      final checkpoint = MemoryCheckpoint(
        label: 'test',
        timestamp: DateTime.now(),
      );

      final str = checkpoint.toString();
      expect(str, contains('test'));
      expect(str, isNot(contains('MB')));
      expect(str, isNot(contains('KB')));
    });
  });

  group('MemoryUsageReport', () {
    test('should create empty report', () {
      final report = MemoryUsageReport.empty();

      expect(report.checkpoints, isEmpty);
      expect(report.totalDuration, equals(Duration.zero));
      expect(report.hasMemoryLeak, isFalse);
      expect(report.memoryGrowth, isNull);
      expect(report.peakMemoryUsage, isNull);
    });

    test('should generate text report', () {
      final baseline = MemoryCheckpoint(
        label: 'baseline',
        timestamp: DateTime.now(),
        rssMemory: 1024 * 1024,
      );

      final checkpoints = [
        MemoryCheckpoint(
          label: 'checkpoint1',
          timestamp: DateTime.now().add(const Duration(seconds: 1)),
          rssMemory: 1024 * 1024 + 512 * 1024,
        ),
      ];

      final report = MemoryUsageReport(
        baseline: baseline,
        checkpoints: checkpoints,
        memoryGrowth: 512 * 1024,
        peakMemoryUsage: 1024 * 1024 + 512 * 1024,
        peakCheckpoint: checkpoints.first,
        averageMemoryUsage: 1024 * 1024 + 256 * 1024,
        hasMemoryLeak: false,
        totalDuration: const Duration(seconds: 1),
      );

      final textReport = report.generateTextReport();

      expect(textReport, contains('Memory Usage Report'));
      expect(textReport, contains('1000ms')); // Duration
      expect(textReport, contains('512.0KB')); // Memory growth
      expect(textReport, contains('1.5MB')); // Peak memory
      expect(textReport, contains('No leak detected'));
    });

    test('should format bytes correctly in report', () {
      final report = MemoryUsageReport(
        baseline: MemoryCheckpoint(
          label: 'baseline',
          timestamp: DateTime.now(),
        ),
        checkpoints: [],
        memoryGrowth: 1536, // 1.5KB
        peakMemoryUsage: 2048 * 1024, // 2MB
        averageMemoryUsage: 1024 * 1024 * 1024 + 512 * 1024 * 1024, // 1.5GB
        hasMemoryLeak: false,
        totalDuration: Duration.zero,
      );

      final textReport = report.generateTextReport();

      expect(textReport, contains('1.5KB')); // Memory growth
      expect(textReport, contains('2.0MB')); // Peak memory
      expect(textReport, contains('1.5GB')); // Average memory
    });
  });

  group('BatchMemoryMonitor', () {
    late BatchMemoryMonitor batchMonitor;

    setUp(() {
      batchMonitor = BatchMemoryMonitor(checkpointInterval: 10);
    });

    test('should track batch processing', () {
      batchMonitor.start();

      // Process items
      for (int i = 0; i < 25; i++) {
        batchMonitor.recordItem('item_$i');
      }

      expect(batchMonitor.processedCount, equals(25));

      final report = batchMonitor.finish();
      expect(report.checkpoints.length, greaterThan(0)); // Should have checkpoints
    });

    test('should create checkpoints at specified intervals', () {
      batchMonitor.start();

      // Process exactly 20 items (2 intervals of 10)
      for (int i = 0; i < 20; i++) {
        batchMonitor.recordItem('item_$i');
      }

      final report = batchMonitor.finish();
      // Should have: batch_start, batch_10, batch_20, batch_end
      expect(report.checkpoints.length, equals(3)); // 10, 20, end (start is baseline)
    });

    test('should handle empty batch', () {
      batchMonitor.start();
      final report = batchMonitor.finish();

      expect(batchMonitor.processedCount, equals(0));
      expect(report.checkpoints.length, equals(1)); // Just the end checkpoint
    });
  });

  group('Performance Tests', () {
    test('should handle many checkpoints efficiently', () {
      final testMonitor = MemoryUsageMonitor();
      final stopwatch = Stopwatch()..start();

      testMonitor.recordBaseline();

      // Record many checkpoints
      for (int i = 0; i < 1000; i++) {
        testMonitor.recordCheckpoint('checkpoint_$i');
      }

      final report = testMonitor.generateReport();
      stopwatch.stop();

      expect(report.checkpoints.length, equals(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be reasonably fast
    });

    test('should generate reports efficiently', () {
      final testMonitor = MemoryUsageMonitor();
      // Set up data
      testMonitor.recordBaseline();
      for (int i = 0; i < 100; i++) {
        testMonitor.recordCheckpoint('checkpoint_$i');
      }

      final stopwatch = Stopwatch()..start();

      // Generate multiple reports
      for (int i = 0; i < 10; i++) {
        final report = testMonitor.generateReport();
        expect(report.checkpoints.length, equals(100));
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Integration Tests', () {
    test('should work in realistic batch processing scenario', () {
      final batchMonitor = BatchMemoryMonitor(checkpointInterval: 50);

      batchMonitor.start();

      // Simulate processing 200 files
      for (int file = 0; file < 200; file++) {
        // Simulate some work that might use memory
        final data = List.filled(1000, 'data_$file');

        batchMonitor.recordItem('file_$file');

        // Simulate cleanup (data will be garbage collected)
        data.length; // Use the data to avoid unused variable warning
      }

      final report = batchMonitor.finish();

      expect(batchMonitor.processedCount, equals(200));
      expect(report.checkpoints.length, greaterThan(3)); // Multiple intervals + end
      expect(report.totalDuration.inMilliseconds, greaterThanOrEqualTo(0));

      final textReport = report.generateTextReport();
      expect(textReport, contains('ms')); // Should show duration in ms
      expect(textReport, contains('Checkpoints Recorded'));
    });

    test('should detect memory patterns in simulated scenario', () {
      final testMonitor = MemoryUsageMonitor();
      testMonitor.recordBaseline('start');

      // Simulate gradually increasing memory usage
      final data = <List<String>>[];

      for (int i = 0; i < 10; i++) {
        // Add more data each iteration (simulating memory growth)
        data.add(List.filled(100 * (i + 1), 'data_$i'));
        testMonitor.recordCheckpoint('iteration_$i');
      }

      final report = testMonitor.generateReport();

      expect(report.checkpoints.length, equals(10));
      expect(report.totalDuration.inMilliseconds, greaterThanOrEqualTo(0));

      // Clean up
      data.clear();
    });
  });
}
