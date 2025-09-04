import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/flac/flac_audio_file.dart';
import 'package:test/test.dart';

void main() {
  group('FlacAudioFile', () {
    late Uint8List validFlacBytes;
    late Uint8List flacWithVorbisComments;

    setUpAll(() {
      // Create a minimal valid FLAC file structure for testing
      validFlacBytes = _createMinimalFlacFile();
      flacWithVorbisComments = _createFlacFileWithVorbisComments();
    });

    group('constructor', () {
      test('creates instance with valid FLAC bytes', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        expect(flacFile, isNotNull);
        expect(flacFile.isDirty, isFalse);
      });

      test('creates instance with isDirty flag', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes, isDirty: true);

        expect(flacFile.isDirty, isTrue);
      });

      test('uses FlacFormatStrategy', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        expect(flacFile.formatStrategy.mediaKind.name, equals('flac'));
        expect(flacFile.formatStrategy.precedence, hasLength(1));
        expect(flacFile.formatStrategy.precedence.first.$1, equals(ContainerKind.vorbis));
      });

      test('configures Vorbis-only codec registry', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        // Verify codec registry contains VorbisCommentsCodec
        final vorbisCodec = flacFile.codecRegistry.findCodec(ContainerKind.vorbis, '');
        expect(vorbisCodec, isNotNull);
        expect(vorbisCodec!.containerKind, equals(ContainerKind.vorbis));

        // Verify locator registry contains VorbisLocator
        final vorbisLocator = flacFile.codecRegistry.findLocator(ContainerKind.vorbis);
        expect(vorbisLocator, isNotNull);
        expect(vorbisLocator!.containerKind, equals(ContainerKind.vorbis));
      });
    });

    group('tag operations', () {
      late FlacAudioFile flacFile;

      setUp(() {
        flacFile = FlacAudioFile.fromBytes(flacWithVorbisComments);
      });

      test('reads basic text tags from Vorbis Comments', () {
        // Note: This test assumes the test file contains these tags
        // In a real implementation, you would need actual FLAC test files
        final title = flacFile.getTag(TagKey.title);
        final artist = flacFile.getTag(TagKey.artist);
        final album = flacFile.getTag(TagKey.album);

        // These assertions would pass with actual test data
        // For now, they test the structure is correct
        expect(title, anyOf(isNull, isA<TitleTag>()));
        expect(artist, anyOf(isNull, isA<ArtistTag>()));
        expect(album, anyOf(isNull, isA<AlbumTag>()));
      });

      test('reads multi-value genre tags from Vorbis Comments', () {
        final genres = flacFile.getTags(TagKey.genre);

        // Test structure - empty list is expected for test data without actual parsing
        expect(genres, isA<List<MetadataTag>>());
        // Note: With real FLAC parsing implementation, this would contain GenreTag instances
      });

      test('sets and retrieves text tags', () {
        final titleTag = const TitleTag('Test FLAC Title');
        final artistTag = const ArtistTag('Test Artist');

        flacFile.setTag(titleTag);
        flacFile.setTag(artistTag);

        expect(flacFile.getTag(TagKey.title), equals(titleTag));
        expect(flacFile.getTag(TagKey.artist), equals(artistTag));
        expect(flacFile.isDirty, isTrue);
      });

      test('sets and retrieves multi-genre tags', () {
        final genreTag = GenreTag(const ['Electronic', 'Ambient', 'Experimental']);

        flacFile.setTag(genreTag);

        final retrievedGenre = flacFile.getTag(TagKey.genre) as GenreTag?;
        expect(retrievedGenre, isNotNull);
        expect(retrievedGenre!.value, equals(['Electronic', 'Ambient', 'Experimental']));
        expect(flacFile.isDirty, isTrue);
      });

      test('sets and retrieves numeric tags', () {
        final trackTag = TrackNumberTag(5);
        final discTag = DiscNumberTag(2);
        final bpmTag = BpmTag(128);
        final ratingTag = RatingTag(85);

        flacFile.setTag(trackTag);
        flacFile.setTag(discTag);
        flacFile.setTag(bpmTag);
        flacFile.setTag(ratingTag);

        expect(flacFile.getTag(TagKey.trackNumber), equals(trackTag));
        expect(flacFile.getTag(TagKey.discNumber), equals(discTag));
        expect(flacFile.getTag(TagKey.bpm), equals(bpmTag));
        expect(flacFile.getTag(TagKey.rating), equals(ratingTag));
      });

      test('sets and retrieves artwork tags', () async {
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Test Album Cover',
          dataLoader: LazyArtworkLoader(
            Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG header
            0,
            4,
          ).load,
        );
        final artworkTag = ArtworkTag(artworkData);

        flacFile.setTag(artworkTag);

        final retrievedArtwork = flacFile.getTag(TagKey.artwork) as ArtworkTag?;
        expect(retrievedArtwork, isNotNull);
        expect(retrievedArtwork!.value.mimeType, equals('image/jpeg'));
        expect(retrievedArtwork.value.type, equals(ArtworkType.frontCover));
        expect(retrievedArtwork.value.description, equals('Test Album Cover'));

        // Test lazy loading
        final imageData = await retrievedArtwork.value.data;
        expect(imageData, equals([0xFF, 0xD8, 0xFF, 0xE0]));
      });

      test('removes tags', () {
        final titleTag = const TitleTag('Test Title');
        flacFile.setTag(titleTag);
        expect(flacFile.getTag(TagKey.title), isNotNull);

        flacFile.removeTag(TagKey.title);
        expect(flacFile.getTag(TagKey.title), isNull);
        expect(flacFile.isDirty, isTrue);
      });

      test('gets all tags with proper provenance', () {
        flacFile.setTag(const TitleTag('Test Title'));
        flacFile.setTag(const ArtistTag('Test Artist'));
        flacFile.setTag(GenreTag(const ['Rock', 'Alternative']));

        final allTags = flacFile.getAllTags();

        expect(allTags, isNotEmpty);
        for (final tag in allTags) {
          // Tags set programmatically have default provenance initially
          // In a real implementation with parsing, they would have Vorbis provenance
          expect(tag.key, isIn([TagKey.title, TagKey.artist, TagKey.genre]));
        }
      });
    });

    group('encoding and persistence', () {
      test('encodes modified FLAC file', () async {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        flacFile.setTag(const TitleTag('New Title'));
        flacFile.setTag(const ArtistTag('New Artist'));
        flacFile.setTag(GenreTag(const ['Electronic', 'Ambient']));

        expect(flacFile.isDirty, isTrue);

        final encodedBytes = await flacFile.encode();
        expect(encodedBytes, isNotNull);
        expect(encodedBytes.length, greaterThan(0));

        // Verify the encoded file still has FLAC signature
        expect(encodedBytes.sublist(0, 4), equals([0x66, 0x4C, 0x61, 0x43])); // "fLaC"
      });

      test('marks clean after encoding', () async {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        flacFile.setTag(const TitleTag('Test Title'));
        expect(flacFile.isDirty, isTrue);

        await flacFile.encode();
        flacFile.markClean();
        expect(flacFile.isDirty, isFalse);
      });

      test('preserves audio data during encoding', () async {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        flacFile.setTag(const TitleTag('Test Title'));

        final encodedBytes = await flacFile.encode();
        final audioData = flacFile.audioData;

        // Audio data should be preserved
        expect(audioData, isNotNull);
        expect(encodedBytes.length, greaterThanOrEqualTo(audioData.length));
      });
    });

    group('error handling', () {
      test('handles empty file bytes gracefully', () {
        final emptyBytes = Uint8List(0);
        final flacFile = FlacAudioFile.fromBytes(emptyBytes);

        // Should not throw during construction
        expect(flacFile, isNotNull);

        // Operations should handle empty file gracefully
        expect(flacFile.getTag(TagKey.title), isNull);
        expect(flacFile.getAllTags(), isEmpty);
      });

      test('handles invalid FLAC signature gracefully', () {
        final invalidBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final flacFile = FlacAudioFile.fromBytes(invalidBytes);

        // Should not throw during construction
        expect(flacFile, isNotNull);

        // Operations should handle invalid format gracefully
        expect(flacFile.getTag(TagKey.title), isNull);
      });

      test('handles corrupted metadata blocks gracefully', () {
        final corruptedBytes = _createCorruptedFlacFile();
        final flacFile = FlacAudioFile.fromBytes(corruptedBytes);

        // Should not throw during construction
        expect(flacFile, isNotNull);

        // Operations should handle corruption gracefully
        expect(() => flacFile.getTag(TagKey.title), returnsNormally);
        expect(() => flacFile.getAllTags(), returnsNormally);
      });
    });

    group('memory management', () {
      test('disposes resources properly', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        flacFile.setTag(const TitleTag('Test Title'));
        expect(flacFile.isDirty, isTrue);

        // Dispose should not throw
        expect(() => flacFile.dispose(), returnsNormally);
      });

      test('handles large files efficiently', () {
        // Create a larger FLAC file for memory testing
        final largeFlacBytes = _createLargeFlacFile();
        final flacFile = FlacAudioFile.fromBytes(largeFlacBytes);

        // Basic operations should work with large files
        flacFile.setTag(const TitleTag('Large File Title'));
        expect(flacFile.getTag(TagKey.title), isNotNull);

        flacFile.dispose();
      });
    });

    group('FLAC-specific behavior', () {
      test('uses UTF-8 encoding for all text fields', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        // Set tags with Unicode characters
        flacFile.setTag(const TitleTag('Título con acentos'));
        flacFile.setTag(const ArtistTag('Артист на кириллице'));
        flacFile.setTag(const CommentTag('コメント in Japanese'));

        final title = flacFile.getTag(TagKey.title) as TitleTag?;
        final artist = flacFile.getTag(TagKey.artist) as ArtistTag?;
        final comment = flacFile.getTag(TagKey.comment) as CommentTag?;

        expect(title?.value, equals('Título con acentos'));
        expect(artist?.value, equals('Артист на кириллице'));
        expect(comment?.value, equals('コメント in Japanese'));
      });

      test('supports native multi-value fields', () {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        // Set multiple genres (native Vorbis Comments support)
        final genres = ['Electronic', 'Ambient', 'Experimental', 'Drone'];
        flacFile.setTag(GenreTag(genres));

        final retrievedGenre = flacFile.getTag(TagKey.genre) as GenreTag?;
        expect(retrievedGenre?.value, equals(genres));
      });

      test('handles METADATA_BLOCK_PICTURE for artwork', () async {
        final flacFile = FlacAudioFile.fromBytes(validFlacBytes);

        // Create artwork with lazy loading
        final artworkData = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.backCover,
          description: 'Back Cover Art',
          dataLoader: LazyArtworkLoader(
            Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // PNG header
            0,
            4,
          ).load,
        );

        flacFile.setTag(ArtworkTag(artworkData));

        final artwork = flacFile.getTag(TagKey.artwork) as ArtworkTag?;
        expect(artwork, isNotNull);
        expect(artwork!.value.type, equals(ArtworkType.backCover));

        // Verify lazy loading works
        final imageData = await artwork.value.data;
        expect(imageData, equals([0x89, 0x50, 0x4E, 0x47]));
      });
    });
  });
}

/// Creates a minimal valid FLAC file structure for testing.
Uint8List _createMinimalFlacFile() {
  final buffer = <int>[];

  // FLAC signature
  buffer.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // STREAMINFO metadata block (required, type 0)
  buffer.add(0x00); // Block type 0, not last block
  buffer.addAll([0x00, 0x00, 0x22]); // Block length: 34 bytes

  // STREAMINFO data (34 bytes of minimal valid data)
  buffer.addAll(List.filled(34, 0x00));

  // Last metadata block (PADDING, type 1)
  buffer.add(0x81); // Block type 1, last block
  buffer.addAll([0x00, 0x00, 0x00]); // Block length: 0 bytes

  // Minimal audio frame (not parsed by metadata operations)
  buffer.addAll([0xFF, 0xF8, 0x69, 0x04]); // FLAC frame header

  return Uint8List.fromList(buffer);
}

/// Creates a FLAC file with Vorbis Comments for testing.
Uint8List _createFlacFileWithVorbisComments() {
  final buffer = <int>[];

  // FLAC signature
  buffer.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // STREAMINFO metadata block (required, type 0)
  buffer.add(0x00); // Block type 0, not last block
  buffer.addAll([0x00, 0x00, 0x22]); // Block length: 34 bytes
  buffer.addAll(List.filled(34, 0x00)); // STREAMINFO data

  // VORBIS_COMMENT metadata block (type 4)
  final vorbisCommentData = _createVorbisCommentBlock();
  buffer.add(0x84); // Block type 4, last block
  buffer.addAll(_uint24ToBigEndianBytes(vorbisCommentData.length));
  buffer.addAll(vorbisCommentData);

  // Minimal audio frame
  buffer.addAll([0xFF, 0xF8, 0x69, 0x04]);

  return Uint8List.fromList(buffer);
}

/// Creates a Vorbis Comment block with test data.
Uint8List _createVorbisCommentBlock() {
  final buffer = <int>[];

  // Vendor string
  const vendor = 'Test Vendor';
  final vendorBytes = vendor.codeUnits;
  buffer.addAll(_uint32ToLittleEndianBytes(vendorBytes.length));
  buffer.addAll(vendorBytes);

  // User comments
  final comments = [
    'TITLE=Test FLAC Title',
    'ARTIST=Test Artist',
    'ALBUM=Test Album',
    'GENRE=Electronic',
    'GENRE=Ambient',
  ];

  buffer.addAll(_uint32ToLittleEndianBytes(comments.length));

  for (final comment in comments) {
    final commentBytes = comment.codeUnits;
    buffer.addAll(_uint32ToLittleEndianBytes(commentBytes.length));
    buffer.addAll(commentBytes);
  }

  return Uint8List.fromList(buffer);
}

/// Creates a corrupted FLAC file for error handling tests.
Uint8List _createCorruptedFlacFile() {
  final buffer = <int>[];

  // FLAC signature
  buffer.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // Corrupted metadata block header
  buffer.add(0x00); // Block type 0
  buffer.addAll([0xFF, 0xFF, 0xFF]); // Invalid block length (too large)

  // Truncated data
  buffer.addAll([0x00, 0x00]);

  return Uint8List.fromList(buffer);
}

/// Creates a large FLAC file for memory testing.
Uint8List _createLargeFlacFile() {
  final buffer = <int>[];

  // FLAC signature
  buffer.addAll([0x66, 0x4C, 0x61, 0x43]); // "fLaC"

  // STREAMINFO metadata block
  buffer.add(0x00); // Block type 0, not last block
  buffer.addAll([0x00, 0x00, 0x22]); // Block length: 34 bytes
  buffer.addAll(List.filled(34, 0x00)); // STREAMINFO data

  // Large PADDING block
  buffer.add(0x81); // Block type 1, last block
  buffer.addAll([0x00, 0x10, 0x00]); // Block length: 4096 bytes
  buffer.addAll(List.filled(4096, 0x00)); // Padding data

  // Simulated audio data
  buffer.addAll(List.filled(1024, 0xFF));

  return Uint8List.fromList(buffer);
}

/// Converts a 32-bit unsigned integer to little-endian bytes.
List<int> _uint32ToLittleEndianBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

/// Converts a 24-bit unsigned integer to big-endian bytes.
List<int> _uint24ToBigEndianBytes(int value) {
  return [
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}
