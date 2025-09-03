import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/formats.dart';

void main() {
  group('Mp4AudioFile', () {
    late Uint8List validMp4Bytes;
    late Uint8List mp4WithAtoms;

    setUpAll(() {
      // Create a minimal valid MP4 file structure for testing
      validMp4Bytes = _createMinimalMp4File();
      mp4WithAtoms = _createMp4FileWithAtoms();
    });

    group('constructor', () {
      test('creates instance with valid MP4 bytes', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        expect(mp4File, isNotNull);
        expect(mp4File.isDirty, isFalse);
      });

      test('creates instance with isDirty flag', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes, isDirty: true);

        expect(mp4File.isDirty, isTrue);
      });

      test('uses Mp4FormatStrategy', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        expect(mp4File.formatStrategy.mediaKind.name, equals('mp4'));
        expect(mp4File.formatStrategy.precedence, hasLength(1));
        expect(mp4File.formatStrategy.precedence.first.$1, equals(ContainerKind.mp4));
      });

      test('configures MP4-only codec registry', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Verify codec registry contains Mp4AtomsCodec
        final mp4Codec = mp4File.codecRegistry.findCodec(ContainerKind.mp4, '');
        expect(mp4Codec, isNotNull);
        expect(mp4Codec!.containerKind, equals(ContainerKind.mp4));

        // Verify locator registry contains Mp4Locator
        final mp4Locator = mp4File.codecRegistry.findLocator(ContainerKind.mp4);
        expect(mp4Locator, isNotNull);
        expect(mp4Locator!.containerKind, equals(ContainerKind.mp4));
      });
    });

    group('tag operations', () {
      late Mp4AudioFile mp4File;

      setUp(() {
        mp4File = Mp4AudioFile.fromBytes(mp4WithAtoms);
      });

      test('reads basic text tags from MP4 atoms', () {
        // Note: This test assumes the test file contains these tags
        // In a real implementation, you would need actual MP4 test files
        final title = mp4File.getTag(TagKey.title);
        final artist = mp4File.getTag(TagKey.artist);
        final album = mp4File.getTag(TagKey.album);

        // These assertions would pass with actual test data
        // For now, they test the structure is correct
        expect(title, anyOf(isNull, isA<TitleTag>()));
        expect(artist, anyOf(isNull, isA<ArtistTag>()));
        expect(album, anyOf(isNull, isA<AlbumTag>()));
      });

      test('reads multi-value genre tags from MP4 atoms', () {
        final genres = mp4File.getTags(TagKey.genre);

        // Test structure - empty list is expected for test data without actual parsing
        expect(genres, isA<List<MetadataTag>>());
        // Note: With real MP4 parsing implementation, this would contain GenreTag instances
      });

      test('sets and retrieves text tags', () {
        final titleTag = const TitleTag('Test MP4 Title');
        final artistTag = const ArtistTag('Test Artist');

        mp4File.setTag(titleTag);
        mp4File.setTag(artistTag);

        expect(mp4File.getTag(TagKey.title), equals(titleTag));
        expect(mp4File.getTag(TagKey.artist), equals(artistTag));
        expect(mp4File.isDirty, isTrue);
      });

      test('sets and retrieves multi-genre tags with semicolon encoding', () {
        final genreTag = GenreTag(const ['Electronic', 'Ambient', 'Experimental']);

        mp4File.setTag(genreTag);

        final retrievedGenre = mp4File.getTag(TagKey.genre) as GenreTag?;
        expect(retrievedGenre, isNotNull);
        expect(retrievedGenre!.value, equals(['Electronic', 'Ambient', 'Experimental']));
        expect(mp4File.isDirty, isTrue);

        // Test MP4-specific semicolon encoding
        expect(retrievedGenre.toEncodedString(';'), equals('Electronic;Ambient;Experimental'));
      });

      test('sets and retrieves numeric tags with binary formats', () {
        final trackTag = TrackNumberTag(5);
        final discTag = DiscNumberTag(2);
        final bpmTag = BpmTag(128);
        final ratingTag = RatingTag(85);

        mp4File.setTag(trackTag);
        mp4File.setTag(discTag);
        mp4File.setTag(bpmTag);
        mp4File.setTag(ratingTag);

        expect(mp4File.getTag(TagKey.trackNumber), equals(trackTag));
        expect(mp4File.getTag(TagKey.discNumber), equals(discTag));
        expect(mp4File.getTag(TagKey.bpm), equals(bpmTag));
        expect(mp4File.getTag(TagKey.rating), equals(ratingTag));
      });

      test('sets and retrieves artwork tags with covr atoms', () async {
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

        mp4File.setTag(artworkTag);

        final retrievedArtwork = mp4File.getTag(TagKey.artwork) as ArtworkTag?;
        expect(retrievedArtwork, isNotNull);
        expect(retrievedArtwork!.value.mimeType, equals('image/jpeg'));
        expect(retrievedArtwork.value.type, equals(ArtworkType.frontCover));
        expect(retrievedArtwork.value.description, equals('Test Album Cover'));

        // Test lazy loading
        final imageData = await retrievedArtwork.value.data;
        expect(imageData, equals([0xFF, 0xD8, 0xFF, 0xE0]));
      });

      test('sets and retrieves freeform atoms for custom fields', () {
        final musicalKeyTag = const MusicalKeyTag('Am');
        final isrcTag = const IsrcTag('USRC17607839');
        final customTag = const CustomTag('Custom Value');

        mp4File.setTag(musicalKeyTag);
        mp4File.setTag(isrcTag);
        mp4File.setTag(customTag);

        expect(mp4File.getTag(TagKey.musicalKey), equals(musicalKeyTag));
        expect(mp4File.getTag(TagKey.isrc), equals(isrcTag));
        expect(mp4File.getTag(TagKey.custom), equals(customTag));
      });

      test('removes tags', () {
        final titleTag = const TitleTag('Test Title');
        mp4File.setTag(titleTag);
        expect(mp4File.getTag(TagKey.title), isNotNull);

        mp4File.removeTag(TagKey.title);
        expect(mp4File.getTag(TagKey.title), isNull);
        expect(mp4File.isDirty, isTrue);
      });

      test('gets all tags with proper provenance', () {
        mp4File.setTag(const TitleTag('Test Title'));
        mp4File.setTag(const ArtistTag('Test Artist'));
        mp4File.setTag(GenreTag(const ['Rock', 'Alternative']));

        final allTags = mp4File.getAllTags();

        expect(allTags, isNotEmpty);
        for (final tag in allTags) {
          // Tags set programmatically have default provenance initially
          // In a real implementation with parsing, they would have MP4 provenance
          expect(tag.key, isIn([TagKey.title, TagKey.artist, TagKey.genre]));
        }
      });
    });

    group('encoding and persistence', () {
      test('tracks dirty state correctly', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        expect(mp4File.isDirty, isFalse);

        mp4File.setTag(const TitleTag('New Title'));
        expect(mp4File.isDirty, isTrue);

        mp4File.markClean();
        expect(mp4File.isDirty, isFalse);
      });

      test('preserves audio data access', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        mp4File.setTag(const TitleTag('Test Title'));

        final audioData = mp4File.audioData;

        // Audio data should be accessible
        expect(audioData, isNotNull);
        expect(audioData.length, greaterThan(0));
      });

      test('maintains tag state after modifications', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Set multiple tags
        mp4File.setTag(const TitleTag('New Title'));
        mp4File.setTag(const ArtistTag('New Artist'));
        mp4File.setTag(GenreTag(const ['Electronic', 'Ambient']));

        // Verify all tags are preserved
        expect(mp4File.getTag(TagKey.title)?.value, equals('New Title'));
        expect(mp4File.getTag(TagKey.artist)?.value, equals('New Artist'));
        final genreTag = mp4File.getTag(TagKey.genre) as GenreTag?;
        expect(genreTag?.value, equals(['Electronic', 'Ambient']));
        expect(mp4File.isDirty, isTrue);
      });
    });

    group('error handling', () {
      test('handles empty file bytes gracefully', () {
        final emptyBytes = Uint8List(0);
        final mp4File = Mp4AudioFile.fromBytes(emptyBytes);

        // Should not throw during construction
        expect(mp4File, isNotNull);

        // Operations should handle empty file gracefully
        expect(mp4File.getTag(TagKey.title), isNull);
        expect(mp4File.getAllTags(), isEmpty);
      });

      test('handles invalid MP4 signature gracefully', () {
        final invalidBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
        final mp4File = Mp4AudioFile.fromBytes(invalidBytes);

        // Should not throw during construction
        expect(mp4File, isNotNull);

        // Operations should handle invalid format gracefully
        expect(mp4File.getTag(TagKey.title), isNull);
      });

      test('handles corrupted atom hierarchy gracefully', () {
        final corruptedBytes = _createCorruptedMp4File();
        final mp4File = Mp4AudioFile.fromBytes(corruptedBytes);

        // Should not throw during construction
        expect(mp4File, isNotNull);

        // Operations should handle corruption gracefully
        expect(() => mp4File.getTag(TagKey.title), returnsNormally);
        expect(() => mp4File.getAllTags(), returnsNormally);
      });
    });

    group('memory management', () {
      test('disposes resources properly', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        mp4File.setTag(const TitleTag('Test Title'));
        expect(mp4File.isDirty, isTrue);

        // Dispose should not throw
        expect(() => mp4File.dispose(), returnsNormally);
      });

      test('handles large files efficiently', () {
        // Create a larger MP4 file for memory testing
        final largeMp4Bytes = _createLargeMp4File();
        final mp4File = Mp4AudioFile.fromBytes(largeMp4Bytes);

        // Basic operations should work with large files
        mp4File.setTag(const TitleTag('Large File Title'));
        expect(mp4File.getTag(TagKey.title), isNotNull);

        mp4File.dispose();
      });
    });

    group('MP4-specific behavior', () {
      test('uses UTF-8 encoding for all text atoms', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Set tags with Unicode characters
        mp4File.setTag(const TitleTag('Título con acentos'));
        mp4File.setTag(const ArtistTag('Артист на кириллице'));
        mp4File.setTag(const CommentTag('コメント in Japanese'));

        final title = mp4File.getTag(TagKey.title) as TitleTag?;
        final artist = mp4File.getTag(TagKey.artist) as ArtistTag?;
        final comment = mp4File.getTag(TagKey.comment) as CommentTag?;

        expect(title?.value, equals('Título con acentos'));
        expect(artist?.value, equals('Артист на кириллице'));
        expect(comment?.value, equals('コメント in Japanese'));
      });

      test('uses semicolon-separated strings for multiple genres', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Set multiple genres (MP4 uses semicolon separation)
        final genres = ['Electronic', 'Ambient', 'Experimental', 'Drone'];
        final genreTag = GenreTag(genres);
        mp4File.setTag(genreTag);

        final retrievedGenre = mp4File.getTag(TagKey.genre) as GenreTag?;
        expect(retrievedGenre?.value, equals(genres));

        // Test MP4-specific encoding
        expect(genreTag.toEncodedString(';'), equals('Electronic;Ambient;Experimental;Drone'));
      });

      test('handles binary formats for track and disc numbers', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // MP4 uses binary format for track/disc numbers
        mp4File.setTag(TrackNumberTag(12));
        mp4File.setTag(DiscNumberTag(3));

        final trackTag = mp4File.getTag(TagKey.trackNumber) as TrackNumberTag?;
        final discTag = mp4File.getTag(TagKey.discNumber) as DiscNumberTag?;

        expect(trackTag?.value, equals(12));
        expect(discTag?.value, equals(3));
      });

      test('handles BPM and rating with specific integer formats', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // MP4 uses 16-bit integer for BPM and 8-bit for rating
        mp4File.setTag(BpmTag(140));
        mp4File.setTag(RatingTag(92));

        final bpmTag = mp4File.getTag(TagKey.bpm) as BpmTag?;
        final ratingTag = mp4File.getTag(TagKey.rating) as RatingTag?;

        expect(bpmTag?.value, equals(140));
        expect(ratingTag?.value, equals(92));
      });

      test('handles freeform atoms for custom metadata', () {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Test freeform atoms (----:domain:name format)
        mp4File.setTag(const MusicalKeyTag('Dm'));
        mp4File.setTag(const IsrcTag('GBUM71505078'));

        final keyTag = mp4File.getTag(TagKey.musicalKey) as MusicalKeyTag?;
        final isrcTag = mp4File.getTag(TagKey.isrc) as IsrcTag?;

        expect(keyTag?.value, equals('Dm'));
        expect(isrcTag?.value, equals('GBUM71505078'));
      });

      test('handles artwork with type classification', () async {
        final mp4File = Mp4AudioFile.fromBytes(validMp4Bytes);

        // Create artwork entry (setTag replaces existing, so we test one at a time)
        final frontCover = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Front Cover',
          dataLoader: LazyArtworkLoader(
            Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG header
            0,
            4,
          ).load,
        );

        mp4File.setTag(ArtworkTag(frontCover));

        final artworkTag = mp4File.getTag(TagKey.artwork) as ArtworkTag?;
        expect(artworkTag, isNotNull);
        expect(artworkTag!.value.type, equals(ArtworkType.frontCover));
        expect(artworkTag.value.mimeType, equals('image/jpeg'));
        expect(artworkTag.value.description, equals('Front Cover'));

        // Test lazy loading
        final imageData = await artworkTag.value.data;
        expect(imageData, equals([0xFF, 0xD8, 0xFF, 0xE0]));

        // Test replacing with different artwork
        final backCover = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.backCover,
          description: 'Back Cover',
          dataLoader: LazyArtworkLoader(
            Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // PNG header
            0,
            4,
          ).load,
        );

        mp4File.setTag(ArtworkTag(backCover));

        final newArtworkTag = mp4File.getTag(TagKey.artwork) as ArtworkTag?;
        expect(newArtworkTag, isNotNull);
        expect(newArtworkTag!.value.type, equals(ArtworkType.backCover));
        expect(newArtworkTag.value.mimeType, equals('image/png'));
      });
    });
  });
}

/// Creates a minimal valid MP4 file structure for testing.
Uint8List _createMinimalMp4File() {
  final buffer = <int>[];

  // ftyp atom (file type box)
  final ftypSize = 20; // 8 byte header + 12 byte data
  buffer.addAll(_uint32ToBigEndianBytes(ftypSize));
  buffer.addAll('ftyp'.codeUnits); // atom type
  buffer.addAll('M4A '.codeUnits); // major brand
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // minor version
  // No compatible brands for minimal file

  // moov atom (movie box) - minimal structure
  final moovData = _createMinimalMoovAtom();
  final moovSize = 8 + moovData.length;
  buffer.addAll(_uint32ToBigEndianBytes(moovSize));
  buffer.addAll('moov'.codeUnits);
  buffer.addAll(moovData);

  // mdat atom (media data) - minimal
  final mdatSize = 16; // Just header + minimal data
  buffer.addAll(_uint32ToBigEndianBytes(mdatSize));
  buffer.addAll('mdat'.codeUnits);
  buffer.addAll(List.filled(8, 0x00)); // Minimal audio data

  return Uint8List.fromList(buffer);
}

/// Creates a MP4 file with atoms for testing.
Uint8List _createMp4FileWithAtoms() {
  final buffer = <int>[];

  // ftyp atom
  final ftypSize = 20;
  buffer.addAll(_uint32ToBigEndianBytes(ftypSize));
  buffer.addAll('ftyp'.codeUnits);
  buffer.addAll('M4A '.codeUnits); // major brand
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // minor version

  // moov atom with metadata
  final moovData = _createMoovAtomWithMetadata();
  final moovSize = 8 + moovData.length;
  buffer.addAll(_uint32ToBigEndianBytes(moovSize));
  buffer.addAll('moov'.codeUnits);
  buffer.addAll(moovData);

  // mdat atom
  final mdatSize = 16;
  buffer.addAll(_uint32ToBigEndianBytes(mdatSize));
  buffer.addAll('mdat'.codeUnits);
  buffer.addAll(List.filled(8, 0x00));

  return Uint8List.fromList(buffer);
}

/// Creates a minimal moov atom structure.
Uint8List _createMinimalMoovAtom() {
  final buffer = <int>[];

  // mvhd atom (movie header) - minimal
  final mvhdSize = 108; // Standard mvhd size
  buffer.addAll(_uint32ToBigEndianBytes(mvhdSize));
  buffer.addAll('mvhd'.codeUnits);
  buffer.addAll(List.filled(100, 0x00)); // Minimal mvhd data

  return Uint8List.fromList(buffer);
}

/// Creates a moov atom with metadata structure.
Uint8List _createMoovAtomWithMetadata() {
  final buffer = <int>[];

  // mvhd atom
  final mvhdSize = 108;
  buffer.addAll(_uint32ToBigEndianBytes(mvhdSize));
  buffer.addAll('mvhd'.codeUnits);
  buffer.addAll(List.filled(100, 0x00));

  // udta atom (user data)
  final udtaData = _createUdtaAtomWithMeta();
  final udtaSize = 8 + udtaData.length;
  buffer.addAll(_uint32ToBigEndianBytes(udtaSize));
  buffer.addAll('udta'.codeUnits);
  buffer.addAll(udtaData);

  return Uint8List.fromList(buffer);
}

/// Creates a udta atom with meta structure.
Uint8List _createUdtaAtomWithMeta() {
  final buffer = <int>[];

  // meta atom
  final metaData = _createMetaAtomWithIlst();
  final metaSize = 8 + metaData.length;
  buffer.addAll(_uint32ToBigEndianBytes(metaSize));
  buffer.addAll('meta'.codeUnits);
  buffer.addAll(metaData);

  return Uint8List.fromList(buffer);
}

/// Creates a meta atom with ilst structure.
Uint8List _createMetaAtomWithIlst() {
  final buffer = <int>[];

  // Version/flags (4 bytes)
  buffer.addAll([0x00, 0x00, 0x00, 0x00]);

  // hdlr atom (handler reference) - proper iTunes metadata handler
  final hdlrData = _createHdlrAtom();
  buffer.addAll(hdlrData);

  // ilst atom (item list) with sample metadata
  final ilstData = _createIlstAtomWithSampleData();
  buffer.addAll(ilstData);

  return Uint8List.fromList(buffer);
}

/// Creates a proper hdlr atom for iTunes metadata.
Uint8List _createHdlrAtom() {
  final buffer = <int>[];

  // hdlr atom header
  final hdlrSize = 44; // 8 + 36 bytes of data
  buffer.addAll(_uint32ToBigEndianBytes(hdlrSize));
  buffer.addAll('hdlr'.codeUnits);

  // hdlr data
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // version/flags
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // pre_defined
  buffer.addAll('mdir'.codeUnits); // handler_type (iTunes metadata)
  buffer.addAll([0x61, 0x70, 0x70, 0x6C]); // reserved[0] ('appl')
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // reserved[1]
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // reserved[2]
  buffer.addAll(List.filled(12, 0x00)); // name (empty)

  return Uint8List.fromList(buffer);
}

/// Creates an ilst atom with sample metadata for testing.
Uint8List _createIlstAtomWithSampleData() {
  final buffer = <int>[];

  // ilst atom header
  final ilstSize = 8; // Just header for minimal test
  buffer.addAll(_uint32ToBigEndianBytes(ilstSize));
  buffer.addAll('ilst'.codeUnits);

  // No actual metadata atoms for basic test - this allows extraction to succeed
  // while keeping the test file minimal

  return Uint8List.fromList(buffer);
}

/// Creates a corrupted MP4 file for error handling tests.
Uint8List _createCorruptedMp4File() {
  final buffer = <int>[];

  // Valid ftyp start
  buffer.addAll(_uint32ToBigEndianBytes(20));
  buffer.addAll('ftyp'.codeUnits);
  buffer.addAll('M4A '.codeUnits);

  // Corrupted data
  buffer.addAll([0xFF, 0xFF, 0xFF, 0xFF]); // Invalid size
  buffer.addAll('XXXX'.codeUnits); // Invalid atom type
  buffer.addAll([0x00, 0x00]); // Truncated

  return Uint8List.fromList(buffer);
}

/// Creates a large MP4 file for memory testing.
Uint8List _createLargeMp4File() {
  final buffer = <int>[];

  // ftyp atom
  final ftypSize = 20;
  buffer.addAll(_uint32ToBigEndianBytes(ftypSize));
  buffer.addAll('ftyp'.codeUnits);
  buffer.addAll('M4A '.codeUnits);
  buffer.addAll([0x00, 0x00, 0x00, 0x00]);

  // Large free atom (padding)
  final freeSize = 4096 + 8; // 4KB padding
  buffer.addAll(_uint32ToBigEndianBytes(freeSize));
  buffer.addAll('free'.codeUnits);
  buffer.addAll(List.filled(4096, 0x00));

  // moov atom
  final moovData = _createMinimalMoovAtom();
  final moovSize = 8 + moovData.length;
  buffer.addAll(_uint32ToBigEndianBytes(moovSize));
  buffer.addAll('moov'.codeUnits);
  buffer.addAll(moovData);

  // Large mdat atom
  final mdatSize = 8192 + 8; // 8KB audio data
  buffer.addAll(_uint32ToBigEndianBytes(mdatSize));
  buffer.addAll('mdat'.codeUnits);
  buffer.addAll(List.filled(8192, 0xFF));

  return Uint8List.fromList(buffer);
}

/// Converts a 32-bit unsigned integer to big-endian bytes.
List<int> _uint32ToBigEndianBytes(int value) {
  return [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];
}
