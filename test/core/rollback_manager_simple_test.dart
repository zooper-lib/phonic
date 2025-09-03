import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/rollback_manager.dart';
import 'package:phonic/src/core/tag_key.dart';

void main() {
  group('RollbackManager', () {
    late RollbackManager rollbackManager;

    setUp(() {
      rollbackManager = RollbackManager();
    });

    group('Basic State Management', () {
      test('should save and restore state correctly', () {
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final tags = <TagKey, List<MetadataTag>>{
          TagKey.title: [const TitleTag('Test Title')],
          TagKey.artist: [const ArtistTag('Test Artist')],
        };

        // Save state
        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'Test state',
        );

        expect(rollbackManager.canRollback, isTrue);
        expect(rollbackManager.stateCount, equals(1));

        // Rollback
        final restoredState = rollbackManager.rollback();

        expect(restoredState, isNotNull);
        expect(restoredState!.fileBytes, equals(fileBytes));
        expect(restoredState.tags.length, equals(2));
        expect(restoredState.description, equals('Test state'));
        expect(rollbackManager.canRollback, isFalse);
        expect(rollbackManager.stateCount, equals(0));
      });

      test('should handle empty rollback stack', () {
        expect(rollbackManager.canRollback, isFalse);
        expect(rollbackManager.rollback(), isNull);
      });

      test('should enforce maximum stack size', () {
        final manager = RollbackManager(maxStackSize: 2);
        final emptyTags = <TagKey, List<MetadataTag>>{};

        // Add 3 states (exceeds limit)
        for (int i = 0; i < 3; i++) {
          manager.saveState(
            fileBytes: Uint8List.fromList([i]),
            tags: emptyTags,
            description: 'State $i',
          );
        }

        expect(manager.stateCount, equals(2)); // Should only keep 2 states

        // Should have states 1 and 2 (state 0 should be evicted)
        final state2 = manager.rollback();
        expect(state2!.description, equals('State 2'));

        final state1 = manager.rollback();
        expect(state1!.description, equals('State 1'));

        expect(manager.canRollback, isFalse);
      });
    });

    group('Memory Management', () {
      test('should calculate memory usage correctly', () {
        expect(rollbackManager.memoryUsage, equals(0));

        final fileBytes1 = Uint8List(100);
        final fileBytes2 = Uint8List(200);
        final emptyTags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes1,
          tags: emptyTags,
          description: 'State 1',
        );

        expect(rollbackManager.memoryUsage, equals(100));

        rollbackManager.saveState(
          fileBytes: fileBytes2,
          tags: emptyTags,
          description: 'State 2',
        );

        expect(rollbackManager.memoryUsage, equals(300));

        rollbackManager.rollback();
        expect(rollbackManager.memoryUsage, equals(100));
      });

      test('should clear all states', () {
        final fileBytes = Uint8List(100);
        final emptyTags = <TagKey, List<MetadataTag>>{};

        // Add multiple states
        for (int i = 0; i < 3; i++) {
          rollbackManager.saveState(
            fileBytes: fileBytes,
            tags: emptyTags,
            description: 'State $i',
          );
        }

        expect(rollbackManager.stateCount, equals(3));

        rollbackManager.clearAll();
        expect(rollbackManager.stateCount, equals(0));
        expect(rollbackManager.canRollback, isFalse);
      });
    });

    group('Stack Information', () {
      test('should provide stack information', () {
        final fileBytes = Uint8List(100);
        final emptyTags = <TagKey, List<MetadataTag>>{};

        final info1 = rollbackManager.getStackInfo();
        expect(info1.stateCount, equals(0));
        expect(info1.totalMemoryUsage, equals(0));
        expect(info1.oldestStateTimestamp, isNull);
        expect(info1.newestStateTimestamp, isNull);

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: emptyTags,
          description: 'State 1',
        );

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: emptyTags,
          description: 'State 2',
        );

        final info2 = rollbackManager.getStackInfo();
        expect(info2.stateCount, equals(2));
        expect(info2.totalMemoryUsage, equals(200));
        expect(info2.oldestStateTimestamp, isNotNull);
        expect(info2.newestStateTimestamp, isNotNull);
        expect(info2.descriptions, equals(['State 1', 'State 2']));
      });
    });

    group('Data Integrity', () {
      test('should create deep copies of data', () {
        final originalBytes = Uint8List.fromList([1, 2, 3]);
        final originalTags = <TagKey, List<MetadataTag>>{
          TagKey.title: [const TitleTag('Original Title')],
        };

        rollbackManager.saveState(
          fileBytes: originalBytes,
          tags: originalTags,
          description: 'Test state',
        );

        // Modify original data
        originalBytes[0] = 99;
        originalTags[TagKey.artist] = [const ArtistTag('New Artist')];

        // Rollback should return unmodified data
        final restoredState = rollbackManager.rollback();
        expect(restoredState!.fileBytes[0], equals(1)); // Not 99
        expect(restoredState.tags.containsKey(TagKey.artist), isFalse);
        expect((restoredState.tags[TagKey.title]!.first as TitleTag).value, equals('Original Title'));
      });
    });
  });

  group('RollbackStackInfo', () {
    test('should format memory usage correctly', () {
      final info1 = const RollbackStackInfo(
        stateCount: 1,
        totalMemoryUsage: 512,
        descriptions: ['State 1'],
      );
      expect(info1.memoryUsageFormatted, equals('512B'));

      final info2 = const RollbackStackInfo(
        stateCount: 1,
        totalMemoryUsage: 1536, // 1.5KB
        descriptions: ['State 1'],
      );
      expect(info2.memoryUsageFormatted, equals('1.5KB'));

      final info3 = const RollbackStackInfo(
        stateCount: 1,
        totalMemoryUsage: 2 * 1024 * 1024 + 512 * 1024, // 2.5MB
        descriptions: ['State 1'],
      );
      expect(info3.memoryUsageFormatted, equals('2.5MB'));
    });

    test('should provide meaningful summary', () {
      final info1 = const RollbackStackInfo(
        stateCount: 0,
        totalMemoryUsage: 0,
        descriptions: [],
      );
      expect(info1.summary, equals('No rollback states available'));

      final info2 = const RollbackStackInfo(
        stateCount: 3,
        totalMemoryUsage: 1536,
        descriptions: ['State 1', 'State 2', 'State 3'],
      );
      expect(info2.summary, equals('RollbackStack(3 states, 1.5KB)'));
    });
  });
}
