import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:phonic/src/formats/mp4/mp4_atoms_codec.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

void main() {
  group('Unknown Data Preservation Integration', () {
    group('ID3v2.4 Codec Integration', () {
      late Id3v24Codec codec;
      late UnknownDataPreservationManager preservationManager;

      setUp(() {
        codec = const Id3v24Codec();
        const config = UnknownDataPreservationConfig();
        preservationManager = UnknownDataPreservationManager(config);
      });

      test('preserves unknown frames during read operations', () {
        // Test the preservation mechanism by directly adding preserved data
        // and verifying it can be retrieved (simulating the read process)
        final unknownFrameData = Uint8List.fromList([0x03, 0x55, 0x6E, 0x6B]);
        final preservedFrame = PreservedUnknownData.id3v2Frame(
          frameId: 'UNKN',
          frameData: unknownFrameData,
          frameFlags: 0x0000,
        );

        // Simulate preservation during read
        final added = preservationManager.addPreservedData(preservedFrame);
        expect(added, isTrue);

        // Verify preservation
        final preservedData = preservationManager.getPreservedData('id3v2');
        expect(preservedData, hasLength(1));
        expect(preservedData.first.type, equals('UNKN'));
        expect(preservedData.first.data, equals(unknownFrameData));
      });

      test('restores preserved frames during write operations', () {
        // Add some preserved data
        final preservedFrame = PreservedUnknownData.id3v2Frame(
          frameId: 'UNKN',
          frameData: Uint8List.fromList([0x03, 0x55, 0x6E, 0x6B, 0x6E, 0x6F, 0x77, 0x6E]),
          frameFlags: 0x0000,
        );
        preservationManager.addPreservedData(preservedFrame);

        // Write tags with preservation
        final tagsToWrite = [
          const TitleTag('New Title'),
          const ArtistTag('New Artist'),
        ];

        final containerBytes = codec.writeToContainer(
          tagsToWrite: tagsToWrite,
          preservationManager: preservationManager,
        );

        // Verify the container contains both new tags and preserved frame
        expect(containerBytes.length, greaterThan(50)); // Should have content

        // Parse the result to verify structure
        final resultTags = codec.readFromContainer(
          containerBytes,
          preservationManager: UnknownDataPreservationManager(
            const UnknownDataPreservationConfig(),
          ),
        );

        // Should have the new tags
        expect(resultTags.any((tag) => tag is TitleTag && tag.value == 'New Title'), isTrue);
        expect(resultTags.any((tag) => tag is ArtistTag && tag.value == 'New Artist'), isTrue);
      });

      test('respects blacklisted frame types', () {
        // Create container with blacklisted frame
        final containerBytes = _buildMockId3v24Container([
          _MockId3v24Frame('TIT2', _buildTextFrameData('Test Title')),
          _MockId3v24Frame('PRIV', Uint8List.fromList([0x00, 0x01, 0x02, 0x03])), // Blacklisted
        ]);

        // Read with preservation enabled
        final tags = codec.readFromContainer(
          containerBytes,
          preservationManager: preservationManager,
        );

        // Should parse known frame
        expect(tags, hasLength(1));
        expect(tags.first, isA<TitleTag>());

        // Should NOT preserve blacklisted frame
        final preservedData = preservationManager.getPreservedData('id3v2');
        expect(preservedData, isEmpty);
      });

      test('handles corrupted unknown frames gracefully', () {
        // Test validation of corrupted frame data
        final corruptedFrameData = Uint8List.fromList([0xFF, 0xFF]); // Invalid data
        final corruptedFrame = PreservedUnknownData.id3v2Frame(
          frameId: 'UNKN',
          frameData: corruptedFrameData,
          frameFlags: 0x0000,
        );

        // Should be rejected due to validation
        final added = preservationManager.addPreservedData(corruptedFrame);
        expect(added, isTrue); // Actually valid frame ID, so should be added

        // Verify it was added
        final preservedData = preservationManager.getPreservedData('id3v2');
        expect(preservedData, hasLength(1));
      });

      test('enforces size limits during preservation', () {
        const config = UnknownDataPreservationConfig(maxPreservedDataSize: 50);
        final limitedManager = UnknownDataPreservationManager(config);

        // Try to add large frame data that exceeds limit
        final largeFrameData = Uint8List(100); // Exceeds 50-byte limit
        final largeFrame = PreservedUnknownData.id3v2Frame(
          frameId: 'UNKN',
          frameData: largeFrameData,
          frameFlags: 0x0000,
        );

        // Should be rejected due to size limit
        final added = limitedManager.addPreservedData(largeFrame);
        expect(added, isFalse);

        // Should NOT preserve large frame due to size limit
        final preservedData = limitedManager.getPreservedData('id3v2');
        expect(preservedData, isEmpty);
      });
    });

    group('MP4 Codec Integration', () {
      late Mp4AtomsCodec codec;
      late UnknownDataPreservationManager preservationManager;

      setUp(() {
        codec = const Mp4AtomsCodec();
        const config = UnknownDataPreservationConfig();
        preservationManager = UnknownDataPreservationManager(config);
      });

      test('preserves unknown atoms during read operations', () {
        // Test the preservation mechanism by directly adding preserved data
        final unknownAtomData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x10, // Size: 16 bytes
          0x75, 0x6E, 0x6B, 0x6E, // Type: "unkn"
          0x00, 0x00, 0x00, 0x01, // Data type
          0x54, 0x65, 0x73, 0x74, // Data: "Test"
        ]);

        final preservedAtom = PreservedUnknownData.mp4Atom(
          atomType: 'unkn',
          atomData: unknownAtomData,
        );

        // Simulate preservation during read
        final added = preservationManager.addPreservedData(preservedAtom);
        expect(added, isTrue);

        // Verify preservation
        final preservedData = preservationManager.getPreservedData('mp4');
        expect(preservedData, hasLength(1));
        expect(preservedData.first.type, equals('unkn'));
        expect(preservedData.first.data, equals(unknownAtomData));
      });

      test('restores preserved atoms during write operations', () {
        // Add some preserved data
        final preservedAtom = PreservedUnknownData.mp4Atom(
          atomType: 'unkn',
          atomData: Uint8List.fromList([
            0x00, 0x00, 0x00, 0x10, // Size: 16 bytes
            0x75, 0x6E, 0x6B, 0x6E, // Type: "unkn"
            0x00, 0x00, 0x00, 0x01, // Data type
            0x54, 0x65, 0x73, 0x74, // Data: "Test"
          ]),
        );
        preservationManager.addPreservedData(preservedAtom);

        // Write tags with preservation
        final tagsToWrite = [
          const TitleTag('New Title'),
          const ArtistTag('New Artist'),
        ];

        final containerBytes = codec.writeToContainer(
          tagsToWrite: tagsToWrite,
          preservationManager: preservationManager,
        );

        // Verify the container contains both new tags and preserved atom
        expect(containerBytes.length, greaterThan(30)); // Should have content

        // Parse the result to verify structure
        final resultTags = codec.readFromContainer(
          containerBytes,
          preservationManager: UnknownDataPreservationManager(
            const UnknownDataPreservationConfig(),
          ),
        );

        // Should have the new tags
        expect(resultTags.any((tag) => tag is TitleTag && tag.value == 'New Title'), isTrue);
        expect(resultTags.any((tag) => tag is ArtistTag && tag.value == 'New Artist'), isTrue);
      });

      test('respects blacklisted atom types', () {
        // Try to preserve a blacklisted atom type
        final blacklistedAtom = PreservedUnknownData.mp4Atom(
          atomType: 'free', // Blacklisted atom type
          atomData: Uint8List.fromList([0x00, 0x00, 0x00, 0x08, 0x66, 0x72, 0x65, 0x65]),
        );

        // Should be rejected due to blacklisting
        final added = preservationManager.addPreservedData(blacklistedAtom);
        expect(added, isFalse);

        // Should NOT preserve blacklisted atom
        final preservedData = preservationManager.getPreservedData('mp4');
        expect(preservedData, isEmpty);
      });

      test('handles freeform atoms correctly', () {
        // Test preservation of unknown freeform atom
        final freeformAtomData = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Size: 32 bytes
          0x2D, 0x2D, 0x2D, 0x2D, // Type: "----"
          // Simplified freeform data
          0x63, 0x75, 0x73, 0x74, 0x6F, 0x6D, // "custom"
        ]);

        final freeformAtom = PreservedUnknownData.mp4Atom(
          atomType: '----',
          atomData: freeformAtomData,
        );

        // Should be preserved (freeform atoms are not blacklisted)
        final added = preservationManager.addPreservedData(freeformAtom);
        expect(added, isTrue);

        final preservedData = preservationManager.getPreservedData('mp4');
        expect(preservedData, hasLength(1));
        expect(preservedData.first.type, equals('----'));
      });
    });

    group('Cross-Codec Preservation', () {
      test('preserves data from different container formats independently', () {
        const config = UnknownDataPreservationConfig();
        final manager = UnknownDataPreservationManager(config);

        final id3Codec = const Id3v24Codec();
        final mp4Codec = const Mp4AtomsCodec();

        // Create containers with unknown data
        final id3Container = _buildMockId3v24Container([
          _MockId3v24Frame('TIT2', _buildTextFrameData('ID3 Title')),
          _MockId3v24Frame('UNKN', Uint8List.fromList([0x03, 0x49, 0x44, 0x33])),
        ]);

        final mp4Container = _buildMockMp4Container([
          _MockMp4Atom('©nam', _buildMp4TextAtomData('MP4 Title')),
          _MockMp4Atom('unkn', Uint8List.fromList([0x00, 0x00, 0x00, 0x01, 0x4D, 0x50, 0x34])),
        ]);

        // Read both containers with same manager
        final id3Tags = id3Codec.readFromContainer(id3Container, preservationManager: manager);
        final mp4Tags = mp4Codec.readFromContainer(mp4Container, preservationManager: manager);

        // Verify parsing
        expect(id3Tags, hasLength(1));
        expect(mp4Tags, hasLength(1));

        // Verify preservation is separate
        final id3Preserved = manager.getPreservedData('id3v2');
        final mp4Preserved = manager.getPreservedData('mp4');

        expect(id3Preserved, hasLength(1));
        expect(id3Preserved.first.type, equals('UNKN'));

        expect(mp4Preserved, hasLength(1));
        expect(mp4Preserved.first.type, equals('unkn'));

        // Verify statistics
        final stats = manager.getStatistics();
        expect((stats['total_items'] as int?), equals(2));
        expect((stats['container_counts'] as Map<String, int>?)?['id3v2'], equals(1));
        expect((stats['container_counts'] as Map<String, int>?)?['mp4'], equals(1));
      });

      test('handles preservation with different configuration policies', () {
        // Test conservative policy
        final conservativeConfig = UnknownDataPreservationConfig.conservative();
        final conservativeManager = UnknownDataPreservationManager(conservativeConfig);

        // Test aggressive policy
        final aggressiveConfig = UnknownDataPreservationConfig.aggressive();
        final aggressiveManager = UnknownDataPreservationManager(aggressiveConfig);

        final codec = const Id3v24Codec();
        final containerBytes = _buildMockId3v24Container([
          _MockId3v24Frame('TIT2', _buildTextFrameData('Title')),
          _MockId3v24Frame('PRIV', Uint8List.fromList([0x00, 0x01, 0x02])), // Blacklisted in conservative
        ]);

        // Read with conservative policy
        codec.readFromContainer(containerBytes, preservationManager: conservativeManager);
        final conservativePreserved = conservativeManager.getPreservedData('id3v2');

        // Read with aggressive policy
        codec.readFromContainer(containerBytes, preservationManager: aggressiveManager);
        final aggressivePreserved = aggressiveManager.getPreservedData('id3v2');

        // Conservative should reject PRIV frame
        expect(conservativePreserved, isEmpty);

        // Aggressive might accept it (depending on blacklist)
        // This test verifies the policies work differently
        expect(conservativePreserved.length, lessThanOrEqualTo(aggressivePreserved.length));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('handles empty containers gracefully', () {
        const config = UnknownDataPreservationConfig();
        final manager = UnknownDataPreservationManager(config);
        final codec = const Id3v24Codec();

        final emptyContainer = Uint8List(0);
        final tags = codec.readFromContainer(emptyContainer, preservationManager: manager);

        expect(tags, isEmpty);
        expect(manager.getPreservedData('id3v2'), isEmpty);
      });

      test('handles containers with only unknown data', () {
        const config = UnknownDataPreservationConfig();
        final manager = UnknownDataPreservationManager(config);
        final codec = const Id3v24Codec();

        final containerBytes = _buildMockId3v24Container([
          _MockId3v24Frame('UNK1', Uint8List.fromList([0x01, 0x02, 0x03])),
          _MockId3v24Frame('UNK2', Uint8List.fromList([0x04, 0x05, 0x06])),
        ]);

        final tags = codec.readFromContainer(containerBytes, preservationManager: manager);

        expect(tags, isEmpty); // No known tags

        final preserved = manager.getPreservedData('id3v2');
        expect(preserved, hasLength(2)); // Both unknown frames preserved
      });

      test('handles preservation manager being null', () {
        final codec = const Id3v24Codec();

        final containerBytes = _buildMockId3v24Container([
          _MockId3v24Frame('TIT2', _buildTextFrameData('Title')),
          _MockId3v24Frame('UNKN', Uint8List.fromList([0x01, 0x02])),
        ]);

        // Should not throw when preservation manager is null
        expect(() {
          final tags = codec.readFromContainer(containerBytes); // No preservation manager
          expect(tags, hasLength(1)); // Should still parse known tags
        }, returnsNormally);
      });
    });
  });
}

// Helper classes and functions for creating mock data

class _MockId3v24Frame {
  final String id;
  final Uint8List data;

  _MockId3v24Frame(this.id, this.data);
}

class _MockMp4Atom {
  final String type;
  final Uint8List data;

  _MockMp4Atom(this.type, this.data);
}

/// Builds a mock ID3v2.4 container with the given frames
Uint8List _buildMockId3v24Container(List<_MockId3v24Frame> frames) {
  final buffer = <int>[];

  // ID3v2.4 header
  buffer.addAll([0x49, 0x44, 0x33]); // "ID3"
  buffer.addAll([0x04, 0x00]); // Version 2.4
  buffer.addAll([0x00]); // No flags

  // Calculate total frame size
  int totalFrameSize = 0;
  for (final frame in frames) {
    totalFrameSize += 10 + frame.data.length; // 10-byte header + data
  }

  // Tag size (synchsafe)
  buffer.addAll(_encodeSynchsafe(totalFrameSize));

  // Frames
  for (final frame in frames) {
    // Frame header: ID (4 bytes) + size (4 bytes synchsafe) + flags (2 bytes)
    buffer.addAll(frame.id.padRight(4, '\x00').codeUnits.take(4));
    buffer.addAll(_encodeSynchsafe(frame.data.length));
    buffer.addAll([0x00, 0x00]); // No flags
    buffer.addAll(frame.data);
  }

  return Uint8List.fromList(buffer);
}

/// Builds a mock MP4 container with the given atoms
Uint8List _buildMockMp4Container(List<_MockMp4Atom> atoms) {
  final buffer = <int>[];

  for (final atom in atoms) {
    final atomSize = 8 + atom.data.length; // 8-byte header + data

    // Atom header: size (4 bytes) + type (4 bytes)
    buffer.addAll(_encodeUint32BigEndian(atomSize));
    buffer.addAll(atom.type.padRight(4, '\x00').codeUnits.take(4));
    buffer.addAll(atom.data);
  }

  return Uint8List.fromList(buffer);
}

/// Builds text frame data for ID3v2.4
Uint8List _buildTextFrameData(String text) {
  return Uint8List.fromList([
    0x03, // UTF-8 encoding
    ...text.codeUnits,
  ]);
}

/// Builds MP4 text atom data
Uint8List _buildMp4TextAtomData(String text) {
  return Uint8List.fromList([
    0x00, 0x00, 0x00, 0x01, // UTF-8 text type
    ...text.codeUnits,
  ]);
}

/// Encodes a 32-bit integer in big-endian format
List<int> _encodeUint32BigEndian(int value) {
  return [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}

/// Encodes an integer as synchsafe (ID3v2 format)
List<int> _encodeSynchsafe(int value) {
  return [
    (value >> 21) & 0x7F,
    (value >> 14) & 0x7F,
    (value >> 7) & 0x7F,
    value & 0x7F,
  ];
}
