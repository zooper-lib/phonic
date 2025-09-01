import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('UnknownDataPreservationConfig', () {
    test('creates default configuration with expected values', () {
      const config = UnknownDataPreservationConfig();

      expect(config.preserveUnknownFrames, isTrue);
      expect(config.preserveUnknownAtoms, isTrue);
      expect(config.preserveUnknownVorbisFields, isTrue);
      expect(config.maxPreservedDataSize, equals(1024 * 1024));
      expect(config.maxPreservedItemCount, equals(100));
      expect(config.blacklistedFrameIds, contains('PRIV'));
      expect(config.blacklistedAtomTypes, contains('free'));
      expect(config.preserveCorruptedData, isFalse);
      expect(config.validatePreservedData, isTrue);
    });

    test('creates conservative configuration', () {
      final config = UnknownDataPreservationConfig.conservative();

      expect(config.preserveUnknownFrames, isTrue);
      expect(config.maxPreservedDataSize, equals(256 * 1024));
      expect(config.maxPreservedItemCount, equals(50));
      expect(config.blacklistedFrameIds.length, greaterThan(4));
      expect(config.blacklistedAtomTypes.length, greaterThan(4));
      expect(config.preserveCorruptedData, isFalse);
      expect(config.validatePreservedData, isTrue);
    });

    test('creates aggressive configuration', () {
      final config = UnknownDataPreservationConfig.aggressive();

      expect(config.preserveUnknownFrames, isTrue);
      expect(config.maxPreservedDataSize, equals(10 * 1024 * 1024));
      expect(config.maxPreservedItemCount, equals(500));
      expect(config.blacklistedFrameIds.length, lessThan(4));
      expect(config.blacklistedAtomTypes.length, lessThan(4));
      expect(config.preserveCorruptedData, isTrue);
      expect(config.validatePreservedData, isFalse);
    });

    test('creates disabled configuration', () {
      final config = UnknownDataPreservationConfig.disabled();

      expect(config.preserveUnknownFrames, isFalse);
      expect(config.preserveUnknownAtoms, isFalse);
      expect(config.preserveUnknownVorbisFields, isFalse);
      expect(config.maxPreservedDataSize, equals(0));
      expect(config.maxPreservedItemCount, equals(0));
    });

    test('shouldPreserveFrame respects configuration', () {
      const config = UnknownDataPreservationConfig();

      expect(config.shouldPreserveFrame('TXXX'), isTrue);
      expect(config.shouldPreserveFrame('PRIV'), isFalse); // Blacklisted
      expect(config.shouldPreserveFrame('UNKN'), isTrue);
    });

    test('shouldPreserveFrame returns false when preservation disabled', () {
      final config = UnknownDataPreservationConfig.disabled();

      expect(config.shouldPreserveFrame('TXXX'), isFalse);
      expect(config.shouldPreserveFrame('UNKN'), isFalse);
    });

    test('shouldPreserveAtom respects configuration', () {
      const config = UnknownDataPreservationConfig();

      expect(config.shouldPreserveAtom('unkn'), isTrue);
      expect(config.shouldPreserveAtom('free'), isFalse); // Blacklisted
      expect(config.shouldPreserveAtom('test'), isTrue);
    });

    test('shouldPreserveVorbisField respects configuration', () {
      const config = UnknownDataPreservationConfig();

      expect(config.shouldPreserveVorbisField('CUSTOM_FIELD'), isTrue);
      expect(config.shouldPreserveVorbisField('UNKNOWN'), isTrue);
    });

    test('isWithinSizeLimit checks size constraints', () {
      const config = UnknownDataPreservationConfig(maxPreservedDataSize: 1000);

      expect(config.isWithinSizeLimit(500, 400), isTrue);
      expect(config.isWithinSizeLimit(500, 600), isFalse);
      expect(config.isWithinSizeLimit(1000, 1), isFalse);
    });

    test('isWithinSizeLimit allows unlimited when null', () {
      const config = UnknownDataPreservationConfig(maxPreservedDataSize: null);

      expect(config.isWithinSizeLimit(1000000, 1000000), isTrue);
    });

    test('isWithinItemLimit checks item count constraints', () {
      const config = UnknownDataPreservationConfig(maxPreservedItemCount: 10);

      expect(config.isWithinItemLimit(5), isTrue);
      expect(config.isWithinItemLimit(9), isTrue);
      expect(config.isWithinItemLimit(10), isFalse);
    });

    test('isWithinItemLimit allows unlimited when null', () {
      const config = UnknownDataPreservationConfig(maxPreservedItemCount: null);

      expect(config.isWithinItemLimit(1000000), isTrue);
    });
  });

  group('PreservedUnknownData', () {
    test('creates basic preserved data', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final preserved = PreservedUnknownData(
        type: 'TEST',
        data: data,
        containerFormat: 'test',
        originalOffset: 100,
      );

      expect(preserved.type, equals('TEST'));
      expect(preserved.data, equals(data));
      expect(preserved.containerFormat, equals('test'));
      expect(preserved.originalOffset, equals(100));
      expect(preserved.size, equals(4));
    });

    test('creates ID3v2 frame preserved data', () {
      final frameData = Uint8List.fromList([0x03, 0x54, 0x65, 0x73, 0x74]); // UTF-8 "Test"
      final preserved = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: frameData,
        frameFlags: 0x0000,
        originalOffset: 50,
        additionalMetadata: {'custom': 'value'},
      );

      expect(preserved.type, equals('TXXX'));
      expect(preserved.data, equals(frameData));
      expect(preserved.containerFormat, equals('id3v2'));
      expect(preserved.originalOffset, equals(50));
      expect(preserved.metadata['frame_flags'], equals(0x0000));
      expect(preserved.metadata['custom'], equals('value'));
    });

    test('creates MP4 atom preserved data', () {
      final atomData = Uint8List.fromList([0x00, 0x00, 0x00, 0x10, 0x74, 0x65, 0x73, 0x74]); // test atom
      final preserved = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: atomData,
        originalOffset: 200,
      );

      expect(preserved.type, equals('test'));
      expect(preserved.data, equals(atomData));
      expect(preserved.containerFormat, equals('mp4'));
      expect(preserved.originalOffset, equals(200));
      expect(preserved.metadata['atom_size'], equals(atomData.length));
    });

    test('creates Vorbis field preserved data', () {
      final preserved = PreservedUnknownData.vorbisField(
        fieldName: 'CUSTOM_FIELD',
        fieldValue: 'Custom Value',
        originalOffset: 300,
      );

      expect(preserved.type, equals('CUSTOM_FIELD'));
      expect(preserved.containerFormat, equals('vorbis'));
      expect(preserved.originalOffset, equals(300));
      expect(preserved.metadata['field_value'], equals('Custom Value'));

      final expectedData = 'CUSTOM_FIELD=Custom Value'.codeUnits;
      expect(preserved.data, equals(Uint8List.fromList(expectedData)));
    });

    test('validates ID3v2 frame data correctly', () {
      // Valid frame
      final validFrame = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x54, 0x65, 0x73, 0x74]),
        frameFlags: 0,
      );
      expect(validFrame.isValidForWriting(), isTrue);

      // Invalid frame ID (too short)
      final invalidFrameId = PreservedUnknownData.id3v2Frame(
        frameId: 'TX',
        frameData: Uint8List.fromList([0x03, 0x54]),
        frameFlags: 0,
      );
      expect(invalidFrameId.isValidForWriting(), isFalse);

      // Invalid frame ID (contains lowercase)
      final invalidFrameCase = PreservedUnknownData.id3v2Frame(
        frameId: 'TXxx',
        frameData: Uint8List.fromList([0x03, 0x54]),
        frameFlags: 0,
      );
      expect(invalidFrameCase.isValidForWriting(), isFalse);

      // Too large data
      final tooLarge = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List(2 * 1024 * 1024), // 2MB
        frameFlags: 0,
      );
      expect(tooLarge.isValidForWriting(), isFalse);
    });

    test('validates MP4 atom data correctly', () {
      // Valid atom
      final validAtom = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08, 0x74, 0x65, 0x73, 0x74]),
      );
      expect(validAtom.isValidForWriting(), isTrue);

      // Invalid atom type (too short)
      final invalidType = PreservedUnknownData.mp4Atom(
        atomType: 'te',
        atomData: Uint8List.fromList([0x00, 0x00]),
      );
      expect(invalidType.isValidForWriting(), isFalse);

      // Invalid atom type (non-printable)
      final invalidChar = PreservedUnknownData.mp4Atom(
        atomType: 'te\x00t',
        atomData: Uint8List.fromList([0x00, 0x00]),
      );
      expect(invalidChar.isValidForWriting(), isFalse);
    });

    test('validates Vorbis field data correctly', () {
      // Valid field
      final validField = PreservedUnknownData.vorbisField(
        fieldName: 'CUSTOM_FIELD',
        fieldValue: 'Valid Value',
      );
      expect(validField.isValidForWriting(), isTrue);

      // Invalid field name (empty)
      final emptyName = PreservedUnknownData.vorbisField(
        fieldName: '',
        fieldValue: 'Value',
      );
      expect(emptyName.isValidForWriting(), isFalse);

      // Invalid field name (lowercase)
      final lowercaseName = PreservedUnknownData.vorbisField(
        fieldName: 'custom_field',
        fieldValue: 'Value',
      );
      expect(lowercaseName.isValidForWriting(), isFalse);

      // Invalid field name (too long)
      final longName = PreservedUnknownData.vorbisField(
        fieldName: 'A' * 300,
        fieldValue: 'Value',
      );
      expect(longName.isValidForWriting(), isFalse);
    });

    test('handles equality correctly', () {
      final data1 = PreservedUnknownData(
        type: 'TEST',
        data: Uint8List.fromList([1, 2, 3]),
        containerFormat: 'test',
      );

      final data2 = PreservedUnknownData(
        type: 'TEST',
        data: Uint8List.fromList([1, 2, 3]),
        containerFormat: 'test',
      );

      final data3 = PreservedUnknownData(
        type: 'TEST',
        data: Uint8List.fromList([1, 2, 4]), // Different data
        containerFormat: 'test',
      );

      expect(data1, equals(data2));
      expect(data1, isNot(equals(data3)));
    });

    test('generates correct string representation', () {
      final preserved = PreservedUnknownData(
        type: 'TEST',
        data: Uint8List.fromList([1, 2, 3, 4]),
        containerFormat: 'test',
      );

      final string = preserved.toString();
      expect(string, contains('TEST'));
      expect(string, contains('4'));
      expect(string, contains('test'));
    });
  });

  group('UnknownDataPreservationManager', () {
    late UnknownDataPreservationManager manager;

    setUp(() {
      const config = UnknownDataPreservationConfig();
      manager = UnknownDataPreservationManager(config);
    });

    test('adds preserved data successfully', () {
      final data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x54, 0x65, 0x73, 0x74]),
        frameFlags: 0,
      );

      final added = manager.addPreservedData(data);
      expect(added, isTrue);

      final retrieved = manager.getPreservedData('id3v2');
      expect(retrieved, hasLength(1));
      expect(retrieved.first.type, equals('TXXX'));
    });

    test('rejects blacklisted frame types', () {
      final data = PreservedUnknownData.id3v2Frame(
        frameId: 'PRIV', // Blacklisted
        frameData: Uint8List.fromList([0x03, 0x54, 0x65, 0x73, 0x74]),
        frameFlags: 0,
      );

      final added = manager.addPreservedData(data);
      expect(added, isFalse);

      final retrieved = manager.getPreservedData('id3v2');
      expect(retrieved, isEmpty);
    });

    test('rejects data exceeding size limits', () {
      const config = UnknownDataPreservationConfig(maxPreservedDataSize: 100);
      final limitedManager = UnknownDataPreservationManager(config);

      final largeData = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List(200), // Exceeds limit
        frameFlags: 0,
      );

      final added = limitedManager.addPreservedData(largeData);
      expect(added, isFalse);
    });

    test('rejects data exceeding item count limits', () {
      const config = UnknownDataPreservationConfig(maxPreservedItemCount: 2);
      final limitedManager = UnknownDataPreservationManager(config);

      // Add two items (should succeed)
      for (int i = 0; i < 2; i++) {
        final data = PreservedUnknownData.id3v2Frame(
          frameId: 'TX0$i',
          frameData: Uint8List.fromList([i]),
          frameFlags: 0,
        );
        expect(limitedManager.addPreservedData(data), isTrue);
      }

      // Third item should be rejected
      final thirdData = PreservedUnknownData.id3v2Frame(
        frameId: 'TX03',
        frameData: Uint8List.fromList([3]),
        frameFlags: 0,
      );
      expect(limitedManager.addPreservedData(thirdData), isFalse);
    });

    test('rejects invalid data when validation enabled', () {
      final invalidData = PreservedUnknownData.id3v2Frame(
        frameId: 'TX', // Invalid (too short)
        frameData: Uint8List.fromList([0x03]),
        frameFlags: 0,
      );

      final added = manager.addPreservedData(invalidData);
      expect(added, isFalse);
    });

    test('accepts invalid data when validation disabled', () {
      const config = UnknownDataPreservationConfig(validatePreservedData: false);
      final noValidationManager = UnknownDataPreservationManager(config);

      final invalidData = PreservedUnknownData.id3v2Frame(
        frameId: 'TX', // Invalid (too short)
        frameData: Uint8List.fromList([0x03]),
        frameFlags: 0,
      );

      final added = noValidationManager.addPreservedData(invalidData);
      expect(added, isTrue);
    });

    test('retrieves preserved data by container format', () {
      final id3Data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x49, 0x44, 0x33]),
        frameFlags: 0,
      );

      final mp4Data = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08, 0x74, 0x65, 0x73, 0x74]),
      );

      manager.addPreservedData(id3Data);
      manager.addPreservedData(mp4Data);

      final id3Retrieved = manager.getPreservedData('id3v2');
      final mp4Retrieved = manager.getPreservedData('mp4');

      expect(id3Retrieved, hasLength(1));
      expect(id3Retrieved.first.type, equals('TXXX'));

      expect(mp4Retrieved, hasLength(1));
      expect(mp4Retrieved.first.type, equals('test'));
    });

    test('retrieves preserved data by type', () {
      final data1 = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x31]),
        frameFlags: 0,
      );

      final data2 = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x32]),
        frameFlags: 0,
      );

      final data3 = PreservedUnknownData.id3v2Frame(
        frameId: 'TYYY',
        frameData: Uint8List.fromList([0x03, 0x33]),
        frameFlags: 0,
      );

      manager.addPreservedData(data1);
      manager.addPreservedData(data2);
      manager.addPreservedData(data3);

      final txxxData = manager.getPreservedDataByType('id3v2', 'TXXX');
      final tyyyData = manager.getPreservedDataByType('id3v2', 'TYYY');

      expect(txxxData, hasLength(2));
      expect(tyyyData, hasLength(1));
      expect(tyyyData.first.type, equals('TYYY'));
    });

    test('clears all preserved data', () {
      final data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x54]),
        frameFlags: 0,
      );

      manager.addPreservedData(data);
      expect(manager.getPreservedData('id3v2'), hasLength(1));

      manager.clear();
      expect(manager.getPreservedData('id3v2'), isEmpty);
    });

    test('clears preserved data for specific container', () {
      final id3Data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x49]),
        frameFlags: 0,
      );

      final mp4Data = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08]),
      );

      manager.addPreservedData(id3Data);
      manager.addPreservedData(mp4Data);

      manager.clearForContainer('id3v2');

      expect(manager.getPreservedData('id3v2'), isEmpty);
      expect(manager.getPreservedData('mp4'), hasLength(1));
    });

    test('generates statistics correctly', () {
      final id3Data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x54, 0x65, 0x73, 0x74]), // 5 bytes
        frameFlags: 0,
      );

      final mp4Data = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08, 0x74, 0x65, 0x73, 0x74]), // 8 bytes
      );

      manager.addPreservedData(id3Data);
      manager.addPreservedData(mp4Data);

      final stats = manager.getStatistics();

      expect((stats['total_items'] as int?), equals(2));
      expect((stats['total_size'] as int?), equals(13)); // 5 + 8 bytes
      expect((stats['container_counts'] as Map<String, int>?)?['id3v2'], equals(1));
      expect((stats['container_counts'] as Map<String, int>?)?['mp4'], equals(1));
      expect((stats['container_sizes'] as Map<String, int>?)?['id3v2'], equals(5));
      expect((stats['container_sizes'] as Map<String, int>?)?['mp4'], equals(8));
    });

    test('reports enabled status correctly', () {
      const enabledConfig = UnknownDataPreservationConfig();
      final enabledManager = UnknownDataPreservationManager(enabledConfig);
      expect(enabledManager.isEnabled, isTrue);

      final disabledConfig = UnknownDataPreservationConfig.disabled();
      final disabledManager = UnknownDataPreservationManager(disabledConfig);
      expect(disabledManager.isEnabled, isFalse);
    });

    test('generates correct string representation', () {
      final data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x54]),
        frameFlags: 0,
      );

      manager.addPreservedData(data);

      final string = manager.toString();
      expect(string, contains('1')); // 1 item
      expect(string, contains('2')); // 2 bytes
      expect(string, contains('true')); // enabled
    });
  });

  group('Integration tests', () {
    test('preserves and restores ID3v2 frame data correctly', () {
      const config = UnknownDataPreservationConfig();
      final manager = UnknownDataPreservationManager(config);

      // Create unknown frame data
      final originalFrameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x43, 0x75, 0x73, 0x74, 0x6F, 0x6D, // "Custom"
      ]);

      final preservedData = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: originalFrameData,
        frameFlags: 0x0000,
        originalOffset: 100,
      );

      // Add to manager
      expect(manager.addPreservedData(preservedData), isTrue);

      // Retrieve and verify
      final retrieved = manager.getPreservedData('id3v2');
      expect(retrieved, hasLength(1));

      final restoredData = retrieved.first;
      expect(restoredData.type, equals('TXXX'));
      expect(restoredData.data, equals(originalFrameData));
      expect(restoredData.metadata['frame_flags'], equals(0x0000));
      expect(restoredData.originalOffset, equals(100));
      expect(restoredData.isValidForWriting(), isTrue);
    });

    test('preserves and restores MP4 atom data correctly', () {
      const config = UnknownDataPreservationConfig();
      final manager = UnknownDataPreservationManager(config);

      // Create unknown atom data (complete atom with header)
      final originalAtomData = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x10, // Size: 16 bytes
        0x74, 0x65, 0x73, 0x74, // Type: "test"
        0x00, 0x00, 0x00, 0x01, // Data type
        0x43, 0x75, 0x73, 0x74, // Data: "Cust"
      ]);

      final preservedData = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: originalAtomData,
        originalOffset: 200,
      );

      // Add to manager
      expect(manager.addPreservedData(preservedData), isTrue);

      // Retrieve and verify
      final retrieved = manager.getPreservedData('mp4');
      expect(retrieved, hasLength(1));

      final restoredData = retrieved.first;
      expect(restoredData.type, equals('test'));
      expect(restoredData.data, equals(originalAtomData));
      expect(restoredData.originalOffset, equals(200));
      expect(restoredData.isValidForWriting(), isTrue);
    });

    test('handles mixed container formats correctly', () {
      const config = UnknownDataPreservationConfig();
      final manager = UnknownDataPreservationManager(config);

      // Add data from different container formats
      final id3Data = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List.fromList([0x03, 0x49, 0x44, 0x33]),
        frameFlags: 0,
      );

      final mp4Data = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08, 0x74, 0x65, 0x73, 0x74]),
      );

      final vorbisData = PreservedUnknownData.vorbisField(
        fieldName: 'CUSTOM_FIELD',
        fieldValue: 'Custom Value',
      );

      expect(manager.addPreservedData(id3Data), isTrue);
      expect(manager.addPreservedData(mp4Data), isTrue);
      expect(manager.addPreservedData(vorbisData), isTrue);

      // Verify each container format is handled separately
      expect(manager.getPreservedData('id3v2'), hasLength(1));
      expect(manager.getPreservedData('mp4'), hasLength(1));
      expect(manager.getPreservedData('vorbis'), hasLength(1));

      // Verify statistics
      final stats = manager.getStatistics();
      expect((stats['total_items'] as int?), equals(3));
      expect((stats['container_counts'] as Map<String, int>?)?['id3v2'], equals(1));
      expect((stats['container_counts'] as Map<String, int>?)?['mp4'], equals(1));
      expect((stats['container_counts'] as Map<String, int>?)?['vorbis'], equals(1));
    });

    test('enforces size limits across all containers', () {
      const config = UnknownDataPreservationConfig(maxPreservedDataSize: 20);
      final manager = UnknownDataPreservationManager(config);

      // Add data that fits within limit
      final smallData = PreservedUnknownData.id3v2Frame(
        frameId: 'TXXX',
        frameData: Uint8List(10), // 10 bytes
        frameFlags: 0,
      );
      expect(manager.addPreservedData(smallData), isTrue);

      // Try to add data that would exceed limit
      final largeData = PreservedUnknownData.mp4Atom(
        atomType: 'test',
        atomData: Uint8List(15), // 15 bytes, total would be 25
      );
      expect(manager.addPreservedData(largeData), isFalse);

      // Verify only the first data was added
      expect(manager.getPreservedData('id3v2'), hasLength(1));
      expect(manager.getPreservedData('mp4'), isEmpty);
    });
  });
}
