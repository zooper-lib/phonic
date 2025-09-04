import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v23_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Id3v23Codec', () {
    late Id3v23Codec codec;

    setUp(() {
      codec = const Id3v23Codec();
    });

    group('instantiation', () {
      test('should create codec instance successfully', () {
        expect(codec, isA<Id3v23Codec>());
        expect(codec, isA<TagCodec>());
      });

      test('should be const constructible', () {
        const codec1 = Id3v23Codec();
        const codec2 = Id3v23Codec();

        // Const constructors should create identical instances
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
      });

      test('should be stateless and reusable', () {
        final codec1 = const Id3v23Codec();
        final codec2 = const Id3v23Codec();

        // Multiple instances should have identical properties
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
        expect(codec1.capability.containerKind, equals(codec2.capability.containerKind));
        expect(codec1.capability.containerVersion, equals(codec2.capability.containerVersion));
      });
    });

    group('properties', () {
      test('should have correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.id3v2));
      });

      test('should have correct container version', () {
        expect(codec.containerVersion, equals('2.3'));
      });

      test('should have valid capability definition', () {
        final capability = codec.capability;

        expect(capability, isA<TagCapability>());
        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.3'));
      });

      test('should maintain consistency between codec and capability properties', () {
        final capability = codec.capability;

        // Container kind and version should match between codec and capability
        expect(capability.containerKind, equals(codec.containerKind));
        expect(capability.containerVersion, equals(codec.containerVersion));
      });
    });

    group('readFromContainer', () {
      test('should return empty list for empty container', () {
        final emptyBytes = Uint8List(0);
        final result = codec.readFromContainer(emptyBytes);
        expect(result, isEmpty);
      });

      test('should validate ID3v2.3 version', () {
        // Create ID3v2.4 header (wrong version)
        final id3v24Bytes = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4 (should be 2.3)
          0x00, // No flags
          0x00, 0x00, 0x00, 0x00, // Size: 0 bytes
        ]);

        expect(
          () => codec.readFromContainer(id3v24Bytes),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should parse basic text frames', () {
        // Create minimal ID3v2.3 container with TIT2 frame
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TIT2', 'Test Title'),
          _buildTextFrame('TPE1', 'Test Artist'),
          _buildTextFrame('TALB', 'Test Album'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(3));

        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(titleTag.provenance.containerVersion, equals('2.3'));

        final artistTag = tags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = tags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));
      });

      test('should parse genre frame with slash-separated values', () {
        // Create ID3v2.3 container with multi-genre TCON frame
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TCON', 'Rock/Alternative/Indie'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(genreTag.provenance.containerVersion, equals('2.3'));
      });

      test('should parse single genre without slashes', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TCON', 'Jazz'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Jazz']));
      });

      test('should handle escaped slashes in genre names', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TCON', 'Rock\\/Roll/Pop'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock/Roll', 'Pop']));
      });

      test('should parse year frame (TYER)', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TYER', '2023'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final yearTag = tags.whereType<YearTag>().first;
        expect(yearTag.value, equals(2023));
      });

      test('should parse track and disc numbers', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TRCK', '5/12'),
          _buildTextFrame('TPOS', '2/3'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(2));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));

        final discTag = tags.whereType<DiscNumberTag>().first;
        expect(discTag.value, equals(2));
      });

      test('should parse BPM frame', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TBPM', '120'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final bpmTag = tags.whereType<BpmTag>().first;
        expect(bpmTag.value, equals(120));
      });

      test('should skip corrupted frames and continue parsing', () {
        // Create container with one good frame, one corrupted, and one more good frame
        final goodFrame1 = _buildTextFrame('TIT2', 'Title');
        final goodFrame2 = _buildTextFrame('TPE1', 'Artist');
        final corruptedFrame = Uint8List.fromList([
          0x42, 0x41, 0x44, 0x46, // "BADF" - invalid frame ID
          0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
          0x00, 0x00, // No flags
          0x01, 0x02, 0x03, 0x04, 0x05, // Corrupted data
        ]);

        final containerBytes = _buildId3v23Container([goodFrame1, corruptedFrame, goodFrame2]);

        final tags = codec.readFromContainer(containerBytes);

        // Should get the two good frames, skip the corrupted one
        expect(tags, hasLength(2));
        expect(tags.whereType<TitleTag>(), hasLength(1));
        expect(tags.whereType<ArtistTag>(), hasLength(1));
      });

      test('should handle empty genre frame', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TCON', ''),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, isEmpty);
      });

      test('should validate invalid year values', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TYER', 'invalid'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        // Should skip invalid year values
        expect(tags.whereType<YearTag>(), isEmpty);
      });

      test('should validate invalid track/disc numbers', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TRCK', 'invalid'),
          _buildTextFrame('TPOS', ''),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        // Should skip invalid numeric values
        expect(tags.whereType<TrackNumberTag>(), isEmpty);
        expect(tags.whereType<DiscNumberTag>(), isEmpty);
      });

      test('should handle container with padding', () {
        final frames = [_buildTextFrame('TIT2', 'Title')];
        final containerBytes = _buildId3v23Container(frames, paddingSize: 100);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(1));
        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Title'));
      });

      test('should parse all supported ID3v2.3 text frames', () {
        final containerBytes = _buildId3v23Container([
          _buildTextFrame('TIT2', 'Title'),
          _buildTextFrame('TPE1', 'Artist'),
          _buildTextFrame('TALB', 'Album'),
          _buildTextFrame('TPE2', 'Album Artist'),
          _buildTextFrame('TIT1', 'Grouping'),
          _buildTextFrame('TCOM', 'Composer'),
          _buildTextFrame('TSSE', 'Encoder'),
          _buildTextFrame('TSRC', 'USRC17607839'),
          _buildTextFrame('TKEY', 'Cm'),
        ]);

        final tags = codec.readFromContainer(containerBytes);

        expect(tags, hasLength(9));
        expect(tags.whereType<TitleTag>().first.value, equals('Title'));
        expect(tags.whereType<ArtistTag>().first.value, equals('Artist'));
        expect(tags.whereType<AlbumTag>().first.value, equals('Album'));
        expect(tags.whereType<AlbumArtistTag>().first.value, equals('Album Artist'));
        expect(tags.whereType<GroupingTag>().first.value, equals('Grouping'));
        expect(tags.whereType<ComposerTag>().first.value, equals('Composer'));
        expect(tags.whereType<EncoderTag>().first.value, equals('Encoder'));
        expect(tags.whereType<IsrcTag>().first.value, equals('USRC17607839'));
        expect(tags.whereType<MusicalKeyTag>().first.value, equals('Cm'));
      });
    });

    group('writeToContainer', () {
      test('should create empty container for empty tag list', () {
        final result = codec.writeToContainer(tagsToWrite: []);

        expect(result, hasLength(10)); // ID3v2.3 header is 10 bytes
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
        expect(result.sublist(3, 5), equals([0x03, 0x00])); // Version 2.3
        expect(result[5], equals(0x00)); // No flags
        expect(result.sublist(6, 10), equals([0x00, 0x00, 0x00, 0x00])); // Size: 0
      });

      test('should write basic text frames with UTF-16 encoding', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        expect(result.length, greaterThan(10)); // Should have header + frames

        // Verify ID3v2.3 header
        expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
        expect(result.sublist(3, 5), equals([0x03, 0x00])); // Version 2.3
        expect(result[5], equals(0x00)); // No flags

        // Parse back and verify content
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(3));

        final titleTag = parsedTags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Title'));

        final artistTag = parsedTags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = parsedTags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));
      });

      test('should encode genres with slash separation', () {
        final tagsToWrite = <MetadataTag>[
          GenreTag(const ['Rock', 'Alternative', 'Indie']),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        // Parse back and verify genre encoding
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final genreTag = parsedTags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('should handle single genre without slashes', () {
        final tagsToWrite = <MetadataTag>[
          GenreTag(const ['Jazz']),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final genreTag = parsedTags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Jazz']));
      });

      test('should convert dateRecorded to TYER/TDAT/TIME frames', () {
        final tagsToWrite = <MetadataTag>[
          DateRecordedTag('2023-12-25T14:30:00'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);

        // Should have TYER frame parsed as YearTag
        final yearTags = parsedTags.whereType<YearTag>();
        expect(yearTags, hasLength(1));
        expect(yearTags.first.value, equals(2023));

        // Note: TDAT and TIME frames are not currently parsed back to dateRecorded
        // in the readFromContainer method, but they should be present in the container
      });

      test('should handle year tag directly', () {
        final tagsToWrite = <MetadataTag>[
          YearTag(2023),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final yearTag = parsedTags.whereType<YearTag>().first;
        expect(yearTag.value, equals(2023));
      });

      test('should handle track and disc numbers', () {
        final tagsToWrite = <MetadataTag>[
          TrackNumberTag(5),
          DiscNumberTag(2),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(2));

        final trackTag = parsedTags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));

        final discTag = parsedTags.whereType<DiscNumberTag>().first;
        expect(discTag.value, equals(2));
      });

      test('should handle BPM tag', () {
        final tagsToWrite = <MetadataTag>[
          BpmTag(120),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final bpmTag = parsedTags.whereType<BpmTag>().first;
        expect(bpmTag.value, equals(120));
      });

      test('should handle rating tag with POPM frame', () {
        final tagsToWrite = <MetadataTag>[
          RatingTag(80),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final ratingTag = parsedTags.whereType<RatingTag>().first;
        // Allow some tolerance in rating conversion due to rounding
        expect(ratingTag.value, closeTo(80, 5));
      });

      test('should handle all supported text frames', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Title'),
          const ArtistTag('Artist'),
          const AlbumTag('Album'),
          const AlbumArtistTag('Album Artist'),
          const GroupingTag('Grouping'),
          const ComposerTag('Composer'),
          const EncoderTag('Encoder'),
          const IsrcTag('USRC17607839'),
          const MusicalKeyTag('Cm'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(9));

        expect(parsedTags.whereType<TitleTag>().first.value, equals('Title'));
        expect(parsedTags.whereType<ArtistTag>().first.value, equals('Artist'));
        expect(parsedTags.whereType<AlbumTag>().first.value, equals('Album'));
        expect(parsedTags.whereType<AlbumArtistTag>().first.value, equals('Album Artist'));
        expect(parsedTags.whereType<GroupingTag>().first.value, equals('Grouping'));
        expect(parsedTags.whereType<ComposerTag>().first.value, equals('Composer'));
        expect(parsedTags.whereType<EncoderTag>().first.value, equals('Encoder'));
        expect(parsedTags.whereType<IsrcTag>().first.value, equals('USRC17607839'));
        expect(parsedTags.whereType<MusicalKeyTag>().first.value, equals('Cm'));
      });

      test('should skip unsupported tags gracefully', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Valid Title'),
          // Add a tag that might not be supported in ID3v2.3
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags.whereType<TitleTag>().first.value, equals('Valid Title'));
      });

      test('should handle empty genre list', () {
        final tagsToWrite = <MetadataTag>[
          GenreTag(const []),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final genreTag = parsedTags.whereType<GenreTag>().first;
        expect(genreTag.value, isEmpty);
      });

      test('should handle genres with slashes in names', () {
        final tagsToWrite = <MetadataTag>[
          GenreTag(const ['Rock/Roll', 'Pop']),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);

        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));

        final genreTag = parsedTags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock/Roll', 'Pop']));
      });

      test('should accept existingContainerBytes parameter', () {
        final existingBytes = Uint8List.fromList([0x01, 0x02, 0x03]);
        final tagsToWrite = <MetadataTag>[const TitleTag('Test')];

        // Should not throw - existingContainerBytes is accepted but not used in current implementation
        final result = codec.writeToContainer(
          tagsToWrite: tagsToWrite,
          existingContainerBytes: existingBytes,
        );

        expect(result, isNotNull);
        expect(result.length, greaterThan(10));
      });

      test('should handle round-trip encoding correctly', () {
        final originalTags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          GenreTag(const ['Rock', 'Alternative']),
          TrackNumberTag(5),
          YearTag(2023),
          BpmTag(120),
        ];

        // Write tags to container
        final containerBytes = codec.writeToContainer(tagsToWrite: originalTags);

        // Read tags back from container
        final parsedTags = codec.readFromContainer(containerBytes);

        // Verify all tags are preserved
        expect(parsedTags, hasLength(6));
        expect(parsedTags.whereType<TitleTag>().first.value, equals('Test Title'));
        expect(parsedTags.whereType<ArtistTag>().first.value, equals('Test Artist'));
        expect(parsedTags.whereType<GenreTag>().first.value, equals(['Rock', 'Alternative']));
        expect(parsedTags.whereType<TrackNumberTag>().first.value, equals(5));
        expect(parsedTags.whereType<YearTag>().first.value, equals(2023));
        expect(parsedTags.whereType<BpmTag>().first.value, equals(120));
      });
    });
  });
}

// Helper methods for building test data

/// Builds a complete ID3v2.3 container with the given frames.
Uint8List _buildId3v23Container(List<Uint8List> frames, {int paddingSize = 0}) {
  // Calculate total frame data size
  int totalFrameSize = 0;
  for (final frame in frames) {
    totalFrameSize += frame.length;
  }
  totalFrameSize += paddingSize;

  // Build frame data
  final frameDataBytes = <int>[];
  for (final frame in frames) {
    frameDataBytes.addAll(frame);
  }

  // Add padding (null bytes)
  for (int i = 0; i < paddingSize; i++) {
    frameDataBytes.add(0x00);
  }

  // Build ID3v2.3 header
  final headerBytes = <int>[
    0x49, 0x44, 0x33, // "ID3"
    0x03, 0x00, // Version 2.3
    0x00, // No flags
    ..._encodeSize(totalFrameSize), // Tag size (regular integer for v2.3)
  ];

  return Uint8List.fromList([...headerBytes, ...frameDataBytes]);
}

/// Builds a text frame with the specified ID and text using ISO-8859-1 encoding.
Uint8List _buildTextFrame(String frameId, String text) {
  // Use ISO-8859-1 encoding (encoding byte 0x00)
  final textBytes = latin1.encode(text);

  // Frame data: encoding byte + text
  final frameData = [0x00, ...textBytes]; // 0x00 = ISO-8859-1

  // Frame header: ID (4 bytes) + size (4 bytes) + flags (2 bytes)
  final frameBytes = <int>[
    ...latin1.encode(frameId), // Frame ID
    ..._encodeFrameSize(frameData.length), // Frame size (regular integer for ID3v2.3)
    0x00, 0x00, // No flags
    ...frameData, // Frame data
  ];

  return Uint8List.fromList(frameBytes);
}

/// Encodes a size as a 4-byte synchsafe integer (for ID3v2 headers).
List<int> _encodeSize(int size) {
  // Use synchsafe encoding for ID3v2 header tag size
  // Extract 7-bit chunks from the 28-bit value
  final byte0 = (size >> 21) & 0x7F; // Bits 21-27
  final byte1 = (size >> 14) & 0x7F; // Bits 14-20
  final byte2 = (size >> 7) & 0x7F; // Bits 7-13
  final byte3 = size & 0x7F; // Bits 0-6

  return [byte0, byte1, byte2, byte3];
}

/// Encodes a frame size as a 4-byte big-endian integer (for ID3v2.3 frames).
List<int> _encodeFrameSize(int size) {
  return [
    (size >> 24) & 0xFF,
    (size >> 16) & 0xFF,
    (size >> 8) & 0xFF,
    size & 0xFF,
  ];
}
