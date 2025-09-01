import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  group('RollbackManager', () {
    late RollbackManager rollbackManager;

    setUp(() {
      rollbackManager = RollbackManager();
    });

    group('State Management', () {
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

      test('should handle multiple states with stack behavior', () {
        final fileBytes1 = Uint8List.fromList([1, 2, 3]);
        final fileBytes2 = Uint8List.fromList([4, 5, 6]);
        final tags1 = <TagKey, List<MetadataTag>>{
          TagKey.title: [const TitleTag('Title 1')],
        };
        final tags2 = <TagKey, List<MetadataTag>>{
          TagKey.title: [const TitleTag('Title 2')],
        };

        // Save first state
        rollbackManager.saveState(
          fileBytes: fileBytes1,
          tags: tags1,
          description: 'State 1',
        );

        // Save second state
        rollbackManager.saveState(
          fileBytes: fileBytes2,
          tags: tags2,
          description: 'State 2',
        );

        expect(rollbackManager.stateCount, equals(2));

        // Rollback should return most recent state
        final restoredState2 = rollbackManager.rollback();
        expect(restoredState2!.description, equals('State 2'));
        expect(restoredState2.fileBytes, equals(fileBytes2));

        // Next rollback should return first state
        final restoredState1 = rollbackManager.rollback();
        expect(restoredState1!.description, equals('State 1'));
        expect(restoredState1.fileBytes, equals(fileBytes1));

        expect(rollbackManager.canRollback, isFalse);
      });

      test('should return null when no states available', () {
        expect(rollbackManager.canRollback, isFalse);
        expect(rollbackManager.rollback(), isNull);
      });

      test('should enforce maximum stack size', () {
        final manager = RollbackManager(maxStackSize: 2);

        // Add 3 states (exceeds limit)
        for (int i = 0; i < 3; i++) {
          manager.saveState(
            fileBytes: Uint8List.fromList([i]),
            tags: <TagKey, List<MetadataTag>>{},
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

    group('Targeted Rollback', () {
      test('should rollback to specific token', () {
        final fileBytes1 = Uint8List.fromList([1]);
        final fileBytes2 = Uint8List.fromList([2]);
        final fileBytes3 = Uint8List.fromList([3]);
        final tags = <TagKey, List<MetadataTag>>{};

        // Save three states
        rollbackManager.saveState(
          fileBytes: fileBytes1,
          tags: tags,
          description: 'State 1',
        );

        final token2 = rollbackManager.saveState(
          fileBytes: fileBytes2,
          tags: tags,
          description: 'State 2',
        );

        rollbackManager.saveState(
          fileBytes: fileBytes3,
          tags: tags,
          description: 'State 3',
        );

        expect(rollbackManager.stateCount, equals(3));

        // Rollback to token2 (should discard state 3)
        final restoredState = rollbackManager.rollbackTo(token2);
        expect(restoredState!.description, equals('State 2'));
        expect(rollbackManager.stateCount, equals(1)); // Only state 1 should remain

        // Verify state 1 is still there
        final restoredState1 = rollbackManager.rollback();
        expect(restoredState1!.description, equals('State 1'));
      });

      test('should return null for invalid token', () {
        final fileBytes = Uint8List.fromList([1]);
        final tags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 1',
        );

        // Create a different manager with different token
        final otherManager = RollbackManager();
        final otherToken = otherManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'Other state',
        );

        // Try to rollback to token from other manager
        final result = rollbackManager.rollbackTo(otherToken);
        expect(result, isNull);
        expect(rollbackManager.stateCount, equals(1)); // Original state should remain
      });
    });

    group('State Discarding', () {
      test('should discard last state', () {
        final fileBytes = Uint8List.fromList([1]);
        final tags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 1',
        );

        expect(rollbackManager.stateCount, equals(1));

        final discarded = rollbackManager.discardLastState();
        expect(discarded, isTrue);
        expect(rollbackManager.stateCount, equals(0));

        // Try to discard when no states
        final discardedAgain = rollbackManager.discardLastState();
        expect(discardedAgain, isFalse);
      });

      test('should discard states up to token', () {
        final fileBytes = Uint8List.fromList([1]);
        final tags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 1',
        );

        final token2 = rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 2',
        );

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 3',
        );

        expect(rollbackManager.stateCount, equals(3));

        // Discard up to and including token2
        final discardedCount = rollbackManager.discardStatesUpTo(token2);
        expect(discardedCount, equals(2)); // States 1 and 2 discarded
        expect(rollbackManager.stateCount, equals(1)); // Only state 3 remains

        final remainingState = rollbackManager.rollback();
        expect(remainingState!.description, equals('State 3'));
      });

      test('should return 0 for invalid token in discard', () {
        final fileBytes = Uint8List.fromList([1]);
        final tags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 1',
        );

        // Create token from different manager
        final otherManager = RollbackManager();
        final otherToken = otherManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'Other state',
        );

        final discardedCount = rollbackManager.discardStatesUpTo(otherToken);
        expect(discardedCount, equals(0));
        expect(rollbackManager.stateCount, equals(1)); // Original state should remain
      });

      test('should clear all states', () {
        final fileBytes = Uint8List.fromList([1]);
        final tags = <TagKey, List<MetadataTag>>{};

        // Add multiple states
        for (int i = 0; i < 3; i++) {
          rollbackManager.saveState(
            fileBytes: fileBytes,
            tags: tags,
            description: 'State $i',
          );
        }

        expect(rollbackManager.stateCount, equals(3));

        rollbackManager.clearAll();
        expect(rollbackManager.stateCount, equals(0));
        expect(rollbackManager.canRollback, isFalse);
      });
    });

    group('Memory Management', () {
      test('should calculate memory usage correctly', () {
        expect(rollbackManager.memoryUsage, equals(0));

        final fileBytes1 = Uint8List(100);
        final fileBytes2 = Uint8List(200);
        final tags = <TagKey, List<MetadataTag>>{};

        rollbackManager.saveState(
          fileBytes: fileBytes1,
          tags: tags,
          description: 'State 1',
        );

        expect(rollbackManager.memoryUsage, equals(100));

        rollbackManager.saveState(
          fileBytes: fileBytes2,
          tags: tags,
          description: 'State 2',
        );

        expect(rollbackManager.memoryUsage, equals(300));

        rollbackManager.rollback();
        expect(rollbackManager.memoryUsage, equals(100));
      });

      test('should provide stack information', () {
        final fileBytes = Uint8List(100);
        final tags = <TagKey, List<MetadataTag>>{};

        final info1 = rollbackManager.getStackInfo();
        expect(info1.stateCount, equals(0));
        expect(info1.totalMemoryUsage, equals(0));
        expect(info1.oldestStateTimestamp, isNull);
        expect(info1.newestStateTimestamp, isNull);

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
          description: 'State 1',
        );

        rollbackManager.saveState(
          fileBytes: fileBytes,
          tags: tags,
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
        expect(restoredState.tags[TagKey.title]!.first.value, equals('Original Title'));
      });
    });
  });

  group('RollbackState', () {
    test('should provide correct size calculation', () {
      final fileBytes = Uint8List(1024);
      final tags = <TagKey, List<MetadataTag>>{};

      final state = RollbackState(
        fileBytes: fileBytes,
        tags: tags,
        timestamp: DateTime.now(),
        description: 'Test state',
      );

      expect(state.sizeInBytes, equals(1024));
    });

    test('should provide meaningful summary', () {
      final fileBytes = Uint8List(1024);
      final tags = <TagKey, List<MetadataTag>>{
        TagKey.title: [const TitleTag('Title')],
        TagKey.artist: [const ArtistTag('Artist')],
      };

      final timestamp = DateTime.parse('2023-01-01T12:00:00Z');
      final state = RollbackState(
        fileBytes: fileBytes,
        tags: tags,
        timestamp: timestamp,
        description: 'Test state',
      );

      final summary = state.summary;
      expect(summary, contains('Test state'));
      expect(summary, contains('2 tags'));
      expect(summary, contains('1KB'));
      expect(summary, contains('2023-01-01T12:00:00.000Z'));
    });
  });

  group('RollbackToken', () {
    test('should provide access to state information', () {
      final rollbackManager = RollbackManager();
      final fileBytes = Uint8List(100);
      final tags = <TagKey, List<MetadataTag>>{};

      final token = rollbackManager.saveState(
        fileBytes: fileBytes,
        tags: tags,
        description: 'Test token',
      );

      expect(token.description, equals('Test token'));
      expect(token.sizeInBytes, equals(100));
      expect(token.timestamp, isA<DateTime>());
    });

    test('should support equality comparison', () {
      final rollbackManager = RollbackManager();
      final fileBytes = Uint8List(100);
      final tags = <TagKey, List<MetadataTag>>{};

      final token1 = rollbackManager.saveState(
        fileBytes: fileBytes,
        tags: tags,
        description: 'State 1',
      );

      final token2 = rollbackManager.saveState(
        fileBytes: fileBytes,
        tags: tags,
        description: 'State 2',
      );

      expect(token1 == token1, isTrue);
      expect(token1 == token2, isFalse);
      expect(token1.hashCode == token1.hashCode, isTrue);
      expect(token1.hashCode == token2.hashCode, isFalse);
    });

    test('should provide meaningful string representation', () {
      final rollbackManager = RollbackManager();
      final fileBytes = Uint8List(100);
      final tags = <TagKey, List<MetadataTag>>{};

      final token = rollbackManager.saveState(
        fileBytes: fileBytes,
        tags: tags,
        description: 'Test token',
      );

      final tokenString = token.toString();
      expect(tokenString, contains('RollbackToken'));
      expect(tokenString, contains('Test token'));
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

    test('should calculate oldest state age', () {
      final oldTimestamp = DateTime.now().subtract(const Duration(hours: 1));
      final info = RollbackStackInfo(
        stateCount: 1,
        totalMemoryUsage: 100,
        oldestStateTimestamp: oldTimestamp,
        descriptions: ['State 1'],
      );

      final age = info.oldestStateAge;
      expect(age, isNotNull);
      expect(age!.inMinutes, greaterThan(50)); // Should be close to 60 minutes
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
