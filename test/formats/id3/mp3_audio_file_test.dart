import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/phonic_audio_file_impl.dart';
import 'package:phonic/src/core/post_write_validator.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/id3/id3.dart';
import 'package:phonic/src/utils/locators/locators.dart';

void main() {
  group('Mp3AudioFile', () {
    group('Constructor', () {
      test('creates instance with valid MP3 bytes', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        expect(mp3File, isNotNull);
        expect(mp3File.isDirty, isFalse);
      });

      test('creates instance with isDirty flag', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes, isDirty: true);

        expect(mp3File.isDirty, isTrue);
      });

      test('creates instance with empty bytes', () {
        final emptyBytes = Uint8List(0);
        final mp3File = Mp3AudioFile.fromBytes(emptyBytes);

        expect(mp3File, isNotNull);
        expect(mp3File.isDirty, isFalse);
      });
    });

    group('Codec Registry Configuration', () {
      test('includes all required ID3 codecs', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Test that all expected codecs are available
        expect(mp3File.codecRegistry.findCodec(ContainerKind.id3v2, '2.4'), isNotNull);
        expect(mp3File.codecRegistry.findCodec(ContainerKind.id3v2, '2.3'), isNotNull);
        expect(mp3File.codecRegistry.findCodec(ContainerKind.id3v2, '2.2'), isNotNull);
        expect(mp3File.codecRegistry.findCodec(ContainerKind.id3v1, 'v1'), isNotNull);
      });

      test('includes all required locators', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Test that all expected locators are available
        expect(mp3File.codecRegistry.findLocator(ContainerKind.id3v2), isNotNull);
        expect(mp3File.codecRegistry.findLocator(ContainerKind.id3v1), isNotNull);
      });

      test('uses Mp3FormatStrategy', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        expect(mp3File.formatStrategy.mediaKind.name, equals('mp3'));
        expect(mp3File.formatStrategy.precedence.length, equals(4));
        expect(mp3File.formatStrategy.fanout.length, equals(2));
      });
    });

    group('Tag Operations', () {
      test('reads ID3v2.4 tags correctly', () async {
        final mp3Bytes = _createMp3WithId3v24Tags();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Extract containers and decode tags
        await mp3File.extractContainersAndDecode();

        final titleTag = mp3File.getTag(TagKey.title);
        expect(titleTag, isNotNull);
        expect(titleTag!.value, equals('Test Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(titleTag.provenance.containerVersion, equals('2.4'));
        expect(titleTag.provenance.confidence, equals(TagConfidence.certain));

        final artistTag = mp3File.getTag(TagKey.artist);
        expect(artistTag, isNotNull);
        expect(artistTag!.value, equals('Test Artist'));
      });

      test('reads ID3v1 tags correctly', () async {
        final mp3Bytes = _createMp3WithId3v1Tags();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Extract containers and decode tags
        await mp3File.extractContainersAndDecode();

        final titleTag = mp3File.getTag(TagKey.title);
        expect(titleTag, isNotNull);
        expect(titleTag!.value, equals('Test Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(titleTag.provenance.containerVersion, equals('v1'));

        final artistTag = mp3File.getTag(TagKey.artist);
        expect(artistTag, isNotNull);
        expect(artistTag!.value, equals('Test Artist'));
      });

      test('applies correct precedence with multiple containers', () async {
        final mp3Bytes = _createMp3WithBothId3v24AndId3v1();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Extract containers and decode tags
        await mp3File.extractContainersAndDecode();

        // ID3v2.4 should take precedence over ID3v1
        final titleTag = mp3File.getTag(TagKey.title);
        expect(titleTag, isNotNull);
        expect(titleTag!.value, equals('ID3v24 Title')); // From ID3v2.4, not ID3v1
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(titleTag.provenance.containerVersion, equals('2.4'));
      });

      test('returns all tags from multiple containers', () async {
        final mp3Bytes = _createMp3WithBothId3v24AndId3v1();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Extract containers and decode tags
        await mp3File.extractContainersAndDecode();

        final allTags = mp3File.getAllTags();
        expect(allTags.length, greaterThan(0));

        // Should have tags from both containers
        final id3v24Tags = allTags.where((tag) => tag.provenance.containerKind == ContainerKind.id3v2 && tag.provenance.containerVersion == '2.4').toList();
        final id3v1Tags = allTags.where((tag) => tag.provenance.containerKind == ContainerKind.id3v1).toList();

        expect(id3v24Tags.length, greaterThan(0));
        expect(id3v1Tags.length, greaterThan(0));
      });

      test('writes tags to appropriate containers', () async {
        final mp3Bytes = _createMinimalMp3WithId3v24();

        // Create audio file with validation disabled for this test
        // since we're testing tag operations, not validation
        final disabledValidator = PostWriteValidator(
          codecRegistry: CodecRegistry(codecList: [], containerLocatorList: []), // Disable validation
          enableDeepValidation: false,
          enableRoundTripValidation: false,
        );

        // Helper function to create MP3 codec registry
        final codecRegistry = CodecRegistry(
          codecList: [
            const Id3v24Codec(),
            const Id3v23Codec(),
            const Id3v22Codec(),
            const Id3v1Codec(),
          ],
          containerLocatorList: [
            Id3v2Locator(),
            Id3v1Locator(),
          ],
        );

        final audioFile = PhonicAudioFileImpl(
          fileBytes: mp3Bytes,
          formatStrategy: const Mp3FormatStrategy(),
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
          validator: disabledValidator,
        );

        // Set tags that should be written to both ID3v2.4 and ID3v1
        audioFile.setTag(const TitleTag('New Title'));
        audioFile.setTag(const ArtistTag('New Artist'));
        audioFile.setTag(const AlbumTag('New Album'));

        expect(audioFile.isDirty, isTrue);

        // Encode the file
        final encodedBytes = await audioFile.encode();
        expect(encodedBytes.length, greaterThan(0));

        // Create new instance from encoded bytes to verify
        final verifyFile = PhonicAudioFileImpl(
          fileBytes: encodedBytes,
          formatStrategy: const Mp3FormatStrategy(),
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
          validator: disabledValidator,
        );
        await verifyFile.extractContainersAndDecode();

        final titleTag = verifyFile.getTag(TagKey.title);
        expect(titleTag, isNotNull);
        expect(titleTag!.value, equals('New Title'));

        final artistTag = verifyFile.getTag(TagKey.artist);
        expect(artistTag, isNotNull);
        expect(artistTag!.value, equals('New Artist'));
      });

      test('handles genre tags with multiple values', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Set multi-genre tag
        mp3File.setTag(GenreTag(const ['Rock', 'Alternative', 'Indie']));

        final genreTag = mp3File.getTag(TagKey.genre);
        expect(genreTag, isNotNull);
        expect(genreTag is GenreTag, isTrue);

        final genre = genreTag as GenreTag;
        expect(genre.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('handles rating tags (ID3v2 only)', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Set rating tag (should only be written to ID3v2, not ID3v1)
        mp3File.setTag(RatingTag(85));

        final ratingTag = mp3File.getTag(TagKey.rating);
        expect(ratingTag, isNotNull);
        expect(ratingTag!.value, equals(85));
      });

      test('removes tags correctly', () async {
        final mp3Bytes = _createMp3WithId3v24Tags();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Extract containers and decode tags
        await mp3File.extractContainersAndDecode();

        // Verify tag exists
        expect(mp3File.getTag(TagKey.title), isNotNull);

        // Remove tag
        mp3File.removeTag(TagKey.title);
        expect(mp3File.isDirty, isTrue);

        // Verify tag is removed
        expect(mp3File.getTag(TagKey.title), isNull);
      });

      test('removes specific tag values', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Set multi-genre tag
        final genreTag = GenreTag(const ['Rock', 'Alternative', 'Pop']);
        mp3File.setTag(genreTag);

        // Remove the specific tag value (removes the entire tag since it matches)
        mp3File.removeTagValue(TagKey.genre, ['Rock', 'Alternative', 'Pop']);

        final retrievedGenreTag = mp3File.getTag(TagKey.genre);
        expect(retrievedGenreTag, isNull);
      });
    });

    group('Memory Management', () {
      test('disposes resources correctly', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        // Should not throw
        mp3File.dispose();
      });

      test('handles large files efficiently', () {
        // Create a larger MP3 file simulation
        final largeBytes = Uint8List(1024 * 1024); // 1MB
        _writeId3v24Header(largeBytes, 0);

        final mp3File = Mp3AudioFile.fromBytes(largeBytes);
        expect(mp3File, isNotNull);

        // Should handle large files without issues
        mp3File.setTag(const TitleTag('Large File Title'));
        expect(mp3File.isDirty, isTrue);
      });
    });

    group('Error Handling', () {
      test('handles corrupted ID3 headers gracefully', () {
        final corruptedBytes = Uint8List.fromList([
          // Corrupted ID3 header
          0x49, 0x44, 0x33, // "ID3"
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid synchsafe size
        ]);

        final mp3File = Mp3AudioFile.fromBytes(corruptedBytes);
        expect(mp3File, isNotNull);

        // Should handle gracefully without throwing
        final tags = mp3File.getAllTags();
        expect(tags, isNotNull);
      });

      test('handles empty files gracefully', () {
        final emptyBytes = Uint8List(0);
        final mp3File = Mp3AudioFile.fromBytes(emptyBytes);

        expect(mp3File.getAllTags(), isEmpty);
        expect(mp3File.getTag(TagKey.title), isNull);

        // Should be able to add tags to empty file
        mp3File.setTag(const TitleTag('New Title'));
        expect(mp3File.isDirty, isTrue);
      });

      test('handles files without metadata gracefully', () {
        // Create MP3 file with only audio data (no metadata)
        final audioOnlyBytes = Uint8List.fromList([
          // MP3 frame sync pattern
          0xFF, 0xFB, 0x90, 0x00,
          // Some audio data
          ...List.filled(100, 0x00),
        ]);

        final mp3File = Mp3AudioFile.fromBytes(audioOnlyBytes);
        expect(mp3File.getAllTags(), isEmpty);

        // Should be able to add metadata to audio-only file
        mp3File.setTag(const TitleTag('Added Title'));
        expect(mp3File.isDirty, isTrue);
      });
    });

    group('Format Strategy Integration', () {
      test('uses correct precedence order', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        final precedence = mp3File.formatStrategy.precedence;
        expect(precedence.length, equals(4));

        // Verify precedence order: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
        expect(precedence[0], equals((ContainerKind.id3v2, '2.4')));
        expect(precedence[1], equals((ContainerKind.id3v2, '2.3')));
        expect(precedence[2], equals((ContainerKind.id3v2, '2.2')));
        expect(precedence[3], equals((ContainerKind.id3v1, 'v1')));
      });

      test('uses correct fanout targets', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        final fanout = mp3File.formatStrategy.fanout;
        expect(fanout.length, equals(2));

        // Verify fanout targets: ID3v2.4 (primary) + ID3v1 (compatibility)
        expect(fanout[0], equals((ContainerKind.id3v2, '2.4')));
        expect(fanout[1], equals((ContainerKind.id3v1, 'v1')));
      });

      test('detects MP3 format correctly', () {
        final mp3Bytes = _createMinimalMp3WithId3v24();
        final mp3File = Mp3AudioFile.fromBytes(mp3Bytes);

        expect(mp3File.formatStrategy.canHandle(mp3Bytes), isTrue);
        expect(mp3File.formatStrategy.detectFormat(mp3Bytes).name, equals('mp3'));
      });
    });
  });
}

// Helper methods for creating test MP3 data

/// Creates a minimal MP3 file with an empty ID3v2.4 header.
Uint8List _createMinimalMp3WithId3v24() {
  final bytes = Uint8List(1024);
  _writeId3v24Header(bytes, 0);
  return bytes;
}

/// Creates an MP3 file with ID3v2.4 tags containing test data.
Uint8List _createMp3WithId3v24Tags() {
  final bytes = Uint8List(1024);
  int offset = 0;

  // Write ID3v2.4 header with some frame data
  offset = _writeId3v24HeaderWithFrames(bytes, offset, {
    'TIT2': 'Test Title',
    'TPE1': 'Test Artist',
    'TALB': 'Test Album',
  });

  return bytes;
}

/// Creates an MP3 file with ID3v1 tags containing test data.
Uint8List _createMp3WithId3v1Tags() {
  final bytes = Uint8List(1024);

  // Write ID3v1 tag at the end
  _writeId3v1Tag(bytes, bytes.length - 128, {
    'title': 'Test Title',
    'artist': 'Test Artist',
    'album': 'Test Album',
    'year': '2023',
  });

  return bytes;
}

/// Creates an MP3 file with both ID3v2.4 and ID3v1 tags.
Uint8List _createMp3WithBothId3v24AndId3v1() {
  final bytes = Uint8List(1024);

  // Write ID3v2.4 header with frames
  _writeId3v24HeaderWithFrames(bytes, 0, {
    'TIT2': 'ID3v24 Title',
    'TPE1': 'ID3v24 Artist',
  });

  // Write ID3v1 tag at the end
  _writeId3v1Tag(bytes, bytes.length - 128, {
    'title': 'ID3v1 Title',
    'artist': 'ID3v1 Artist',
  });

  return bytes;
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

/// Writes an ID3v1 tag to the byte array.
void _writeId3v1Tag(Uint8List bytes, int offset, Map<String, String> fields) {
  // Clear the tag area
  for (int i = 0; i < 128; i++) {
    bytes[offset + i] = 0x00;
  }

  // Write "TAG" identifier
  bytes[offset + 0] = 0x54; // 'T'
  bytes[offset + 1] = 0x41; // 'A'
  bytes[offset + 2] = 0x47; // 'G'

  // Write fields
  if (fields.containsKey('title')) {
    _writeId3v1Field(bytes, offset + 3, fields['title']!, 30);
  }
  if (fields.containsKey('artist')) {
    _writeId3v1Field(bytes, offset + 33, fields['artist']!, 30);
  }
  if (fields.containsKey('album')) {
    _writeId3v1Field(bytes, offset + 63, fields['album']!, 30);
  }
  if (fields.containsKey('year')) {
    _writeId3v1Field(bytes, offset + 93, fields['year']!, 4);
  }
}

/// Writes a field to an ID3v1 tag with proper padding.
void _writeId3v1Field(Uint8List bytes, int offset, String text, int maxLength) {
  final textBytes = text.codeUnits;
  final length = textBytes.length > maxLength ? maxLength : textBytes.length;

  for (int i = 0; i < length; i++) {
    bytes[offset + i] = textBytes[i];
  }

  // Pad with spaces
  for (int i = length; i < maxLength; i++) {
    bytes[offset + i] = 0x20; // Space
  }
}

/// Writes a synchsafe integer to the byte array.
void _writeSynchsafeInt(Uint8List bytes, int offset, int value) {
  bytes[offset + 0] = (value >> 21) & 0x7F;
  bytes[offset + 1] = (value >> 14) & 0x7F;
  bytes[offset + 2] = (value >> 7) & 0x7F;
  bytes[offset + 3] = value & 0x7F;
}
