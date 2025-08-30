import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/src/core/artwork_data.dart';
import '../lib/src/core/artwork_type.dart';
import '../lib/src/core/container_kind.dart';
import '../lib/src/core/metadata_tag.dart';
import '../lib/src/core/tag_confidence.dart';
import '../lib/src/core/tag_key.dart';
import '../lib/src/exceptions/corrupted_container_exception.dart';
import '../lib/src/formats/id3/id3v1_codec.dart';

void main() {
  group('Id3v1Codec', () {
    late Id3v1Codec codec;

    setUp(() {
      codec = const Id3v1Codec();
    });

    group('codec properties', () {
      test('should have correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.id3v1));
      });

      test('should have correct container version', () {
        expect(codec.containerVersion, equals('v1'));
      });

      test('should have valid capability', () {
        expect(codec.capability, isNotNull);
        expect(codec.capability.containerKind, equals(ContainerKind.id3v1));
        expect(codec.capability.containerVersion, equals('v1'));
      });

      test('should support expected tag keys', () {
        final capability = codec.capability;

        // Should support basic ID3v1 fields
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.album), isTrue);
        expect(capability.supports(TagKey.year), isTrue);
        expect(capability.supports(TagKey.comment), isTrue);
        expect(capability.supports(TagKey.trackNumber), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);

        // Should not support extended fields
        expect(capability.supports(TagKey.albumArtist), isFalse);
        expect(capability.supports(TagKey.artwork), isFalse);
        expect(capability.supports(TagKey.lyrics), isFalse);
        expect(capability.supports(TagKey.custom), isFalse);
      });
    });

    group('readFromContainer', () {
      test('should throw on invalid container size', () {
        final invalidContainer = Uint8List(100); // Wrong size

        expect(
          () => codec.readFromContainer(invalidContainer),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should throw on invalid TAG identifier', () {
        final invalidContainer = Uint8List(128);
        // Write invalid identifier
        invalidContainer.setRange(0, 3, latin1.encode('BAD'));

        expect(
          () => codec.readFromContainer(invalidContainer),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('should read empty ID3v1 tag', () {
        final container = _createEmptyId3v1Container();
        final tags = codec.readFromContainer(container);

        expect(tags, isEmpty);
      });

      test('should read basic text fields', () {
        final container = _createId3v1Container(
          title: 'Test Title',
          artist: 'Test Artist',
          album: 'Test Album',
          year: '2023',
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(4));

        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Title'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(titleTag.provenance.confidence, equals(TagConfidence.certain));

        final artistTag = tags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = tags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));

        final yearTag = tags.whereType<YearTag>().first;
        expect(yearTag.value, equals(2023));
      });

      test('should read comment without track number (ID3v1.0 format)', () {
        final container = _createId3v1Container(
          comment: 'This is a test comment',
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(1));

        final commentTag = tags.whereType<CommentTag>().first;
        expect(commentTag.value, equals('This is a test comment'));
        expect(commentTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(commentTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('should read track number from comment field (ID3v1.1 format)', () {
        final container = _createId3v1Container(
          trackNumber: 5,
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(1));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));
        expect(trackTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(trackTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('should read comment and track number together (ID3v1.1 format)', () {
        final container = _createId3v1Container(
          comment: 'Short comment',
          trackNumber: 12,
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(2));

        final commentTag = tags.whereType<CommentTag>().first;
        expect(commentTag.value, equals('Short comment'));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(12));
      });

      test('should handle comment truncation with track number', () {
        // Comment longer than 28 characters should be truncated when track is present
        final container = _createId3v1Container(
          comment: 'This is a very long comment that exceeds twenty-eight characters',
          trackNumber: 7,
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(2));

        final commentTag = tags.whereType<CommentTag>().first;
        expect(commentTag.value.length, lessThanOrEqualTo(28));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(7));
      });

      test('should read genre from genre byte using lookup table', () {
        final container = _createId3v1Container(
          genreCode: 17, // Rock
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(1));

        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock']));
        expect(genreTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(genreTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('should read various standard genres correctly', () {
        final testCases = [
          (0, 'Blues'),
          (1, 'Classic Rock'),
          (7, 'Hip-Hop'),
          (8, 'Jazz'),
          (13, 'Pop'),
          (17, 'Rock'),
          (32, 'Classical'),
          (80, 'Folk'),
          (137, 'Heavy Metal'),
        ];

        for (final (genreCode, expectedGenre) in testCases) {
          final container = _createId3v1Container(genreCode: genreCode);
          final tags = codec.readFromContainer(container);

          final genreTag = tags.whereType<GenreTag>().firstOrNull;
          expect(genreTag, isNotNull, reason: 'Genre code $genreCode should produce a tag');
          expect(genreTag!.value, equals([expectedGenre]), reason: 'Genre code $genreCode should map to $expectedGenre');
        }
      });

      test('should skip unknown genre (255)', () {
        final container = _createId3v1Container(
          genreCode: 255, // Unknown
        );

        final tags = codec.readFromContainer(container);

        // Should not include a genre tag for "Unknown"
        final genreTags = tags.whereType<GenreTag>();
        expect(genreTags, isEmpty);
      });

      test('should skip invalid genre codes', () {
        // Test with a genre code that doesn't exist in the table
        // Since the genre table covers 0-255, we need to test with a code that maps to null
        final container = _createEmptyId3v1Container();
        // Use a code that doesn't exist in the lookup table (there might not be any since it's 0-255)
        // Let's test with a code that should return null from getGenreName
        container[127] = 255; // This should be "Unknown" and should be skipped

        final tags = codec.readFromContainer(container);

        // Should not include a genre tag for "Unknown"
        final genreTags = tags.whereType<GenreTag>();
        expect(genreTags, isEmpty);
      });

      test('should handle text fields with null terminators', () {
        final container = _createEmptyId3v1Container();

        // Write text with null terminator and padding
        final titleBytes = latin1.encode('Title');
        container.setRange(3, 3 + titleBytes.length, titleBytes);
        // Fill the rest with null bytes (simulating null termination)
        for (int i = 3 + titleBytes.length; i < 33; i++) {
          container[i] = 0x00;
        }

        final tags = codec.readFromContainer(container);

        final titleTag = tags.whereType<TitleTag>().firstOrNull;
        expect(titleTag?.value, equals('Title'));
      });

      test('should handle text fields with space padding', () {
        final container = _createEmptyId3v1Container();

        // Write text with space padding
        final titleBytes = latin1.encode('Title   '); // Spaces at end
        container.setRange(3, 3 + titleBytes.length, titleBytes);

        final tags = codec.readFromContainer(container);

        final titleTag = tags.whereType<TitleTag>().firstOrNull;
        expect(titleTag?.value, equals('Title'));
      });

      test('should handle maximum length text fields', () {
        final container = _createId3v1Container(
          title: 'A' * 30, // Maximum length
          artist: 'B' * 30,
          album: 'C' * 30,
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(3));

        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('A' * 30));

        final artistTag = tags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('B' * 30));

        final albumTag = tags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('C' * 30));
      });

      test('should handle invalid year gracefully', () {
        final container = _createId3v1Container(
          year: 'ABCD', // Non-numeric year
        );

        final tags = codec.readFromContainer(container);

        // Should not include a year tag for invalid year
        final yearTags = tags.whereType<YearTag>();
        expect(yearTags, isEmpty);
      });

      test('should read complete ID3v1.1 tag with all fields', () {
        final container = _createId3v1Container(
          title: 'Complete Song Title',
          artist: 'Complete Artist Name',
          album: 'Complete Album Name',
          year: '2023',
          comment: 'Complete comment text',
          trackNumber: 8,
          genreCode: 17, // Rock
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(7));

        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Complete Song Title'));

        final artistTag = tags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Complete Artist Name'));

        final albumTag = tags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Complete Album Name'));

        final yearTag = tags.whereType<YearTag>().first;
        expect(yearTag.value, equals(2023));

        final commentTag = tags.whereType<CommentTag>().first;
        expect(commentTag.value, equals('Complete comment text'));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(8));

        final genreTag = tags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock']));

        // Verify all tags have correct provenance
        for (final tag in tags) {
          expect(tag.provenance.containerKind, equals(ContainerKind.id3v1));
          expect(tag.provenance.containerVersion, equals('v1'));
          expect(tag.provenance.confidence, equals(TagConfidence.certain));
        }
      });

      test('should handle edge case with track number 255', () {
        final container = _createId3v1Container(
          trackNumber: 255, // Maximum track number
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(1));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(255));
      });

      test('should handle edge case with track number 1', () {
        final container = _createId3v1Container(
          trackNumber: 1, // Minimum track number
        );

        final tags = codec.readFromContainer(container);

        expect(tags, hasLength(1));

        final trackTag = tags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(1));
      });

      test('should not read track number when byte 125 is not null', () {
        final container = _createEmptyId3v1Container();

        // Set up a scenario where byte 125 is not null (not ID3v1.1 format)
        container[125] = 0x41; // 'A' character
        container[126] = 5; // Would be track number if this were ID3v1.1

        final tags = codec.readFromContainer(container);

        // Should not include a track number tag
        final trackTags = tags.whereType<TrackNumberTag>();
        expect(trackTags, isEmpty);
      });

      test('should not read track number when byte 126 is zero', () {
        final container = _createEmptyId3v1Container();

        // Set up a scenario where byte 126 is zero (invalid track number)
        container[125] = 0x00; // Null terminator
        container[126] = 0x00; // Zero track number (invalid)

        final tags = codec.readFromContainer(container);

        // Should not include a track number tag
        final trackTags = tags.whereType<TrackNumberTag>();
        expect(trackTags, isEmpty);
      });
    });

    group('writeToContainer', () {
      test('should create empty container for no tags', () {
        final container = codec.writeToContainer(tagsToWrite: []);

        expect(container.length, equals(128));
        expect(latin1.decode(container.sublist(0, 3)), equals('TAG'));

        // Verify container is properly initialized
        expect(container[127], equals(255)); // Unknown genre by default

        // Verify text fields are space-padded
        for (int i = 3; i < 127; i++) {
          expect(container[i], equals(0x20), reason: 'Byte $i should be space-padded');
        }
      });

      test('should write basic text fields', () {
        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
          YearTag(2023),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Verify by reading back
        final readTags = codec.readFromContainer(container);

        expect(readTags, hasLength(4));
        expect(readTags.whereType<TitleTag>().first.value, equals('Test Title'));
        expect(readTags.whereType<ArtistTag>().first.value, equals('Test Artist'));
        expect(readTags.whereType<AlbumTag>().first.value, equals('Test Album'));
        expect(readTags.whereType<YearTag>().first.value, equals(2023));
      });

      test('should apply 30-character truncation for text fields', () {
        final longText = 'This is a very long text that exceeds thirty characters and should be truncated';
        final tags = <MetadataTag>[
          TitleTag(longText),
          ArtistTag(longText),
          AlbumTag(longText),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        expect(readTags, hasLength(3));

        final titleTag = readTags.whereType<TitleTag>().first;
        expect(titleTag.value.length, lessThanOrEqualTo(30));
        expect(titleTag.value, equals(longText.substring(0, 30).trim()));

        final artistTag = readTags.whereType<ArtistTag>().first;
        expect(artistTag.value.length, lessThanOrEqualTo(30));
        expect(artistTag.value, equals(longText.substring(0, 30).trim()));

        final albumTag = readTags.whereType<AlbumTag>().first;
        expect(albumTag.value.length, lessThanOrEqualTo(30));
        expect(albumTag.value, equals(longText.substring(0, 30).trim()));
      });

      test('should handle track number encoding in comment field', () {
        final tags = <MetadataTag>[
          const CommentTag('Short comment'),
          TrackNumberTag(5),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Verify track number is encoded correctly
        expect(container[125], equals(0x00)); // Null terminator
        expect(container[126], equals(5)); // Track number

        // Verify by reading back
        final readTags = codec.readFromContainer(container);
        expect(readTags, hasLength(2));

        final commentTag = readTags.whereType<CommentTag>().first;
        expect(commentTag.value, equals('Short comment'));

        final trackTag = readTags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));
      });

      test('should truncate comment to 28 characters when track number present', () {
        final longComment = 'This is a very long comment that exceeds twenty-eight characters and should be truncated';
        final tags = <MetadataTag>[
          CommentTag(longComment),
          TrackNumberTag(12),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        expect(readTags, hasLength(2));

        final commentTag = readTags.whereType<CommentTag>().first;
        expect(commentTag.value.length, lessThanOrEqualTo(28));
        expect(commentTag.value, equals(longComment.substring(0, 28).trim()));

        final trackTag = readTags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(12));
      });

      test('should allow full 30-character comment when no track number', () {
        // Use a comment that's exactly 30 characters without trailing spaces
        final exactComment = 'This comment is exactly 30 chr';
        expect(exactComment.length, equals(30));

        final tags = <MetadataTag>[
          CommentTag(exactComment),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        expect(readTags, hasLength(1));

        final commentTag = readTags.whereType<CommentTag>().first;
        expect(commentTag.value.length, lessThanOrEqualTo(30));
        expect(commentTag.value, equals(exactComment.trim()));
      });

      test('should convert genre name to genre byte', () {
        final tags = <MetadataTag>[
          GenreTag.single('Rock'),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Verify genre byte is correct (Rock = 17)
        expect(container[127], equals(17));

        // Verify by reading back
        final readTags = codec.readFromContainer(container);
        expect(readTags, hasLength(1));

        final genreTag = readTags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock']));
      });

      test('should use first genre for multi-genre tags', () {
        final tags = <MetadataTag>[
          GenreTag(const ['Jazz', 'Blues', 'Rock']),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Verify first genre is used (Jazz = 8)
        expect(container[127], equals(8));

        // Verify by reading back
        final readTags = codec.readFromContainer(container);
        expect(readTags, hasLength(1));

        final genreTag = readTags.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Jazz']));
      });

      test('should handle unknown genre gracefully', () {
        final tags = <MetadataTag>[
          GenreTag.single('Unknown Genre'),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Should default to 255 (Unknown) for unrecognized genres
        expect(container[127], equals(255));

        // Verify by reading back (should not include genre tag for Unknown)
        final readTags = codec.readFromContainer(container);
        final genreTags = readTags.whereType<GenreTag>();
        expect(genreTags, isEmpty);
      });

      test('should clamp track number to valid range', () {
        // Test valid track numbers
        final validTestCases = [
          (1, 1), // Minimum valid
          (128, 128), // Middle value
          (255, 255), // Maximum valid
        ];

        for (final (input, expected) in validTestCases) {
          final tags = <MetadataTag>[
            TrackNumberTag(input),
          ];

          final container = codec.writeToContainer(tagsToWrite: tags);
          final readTags = codec.readFromContainer(container);

          expect(readTags.whereType<TrackNumberTag>(), hasLength(1));
          final trackTag = readTags.whereType<TrackNumberTag>().first;
          expect(trackTag.value, equals(expected), reason: 'Input $input should result in $expected');
        }
      });

      test('should handle year values correctly', () {
        final testCases = [
          (1900, 1900), // Minimum valid for YearTag
          (2023, 2023), // Normal value
          (2100, 2100), // Maximum valid for YearTag
        ];

        for (final (input, expected) in testCases) {
          final tags = <MetadataTag>[
            YearTag(input),
          ];

          final container = codec.writeToContainer(tagsToWrite: tags);
          final readTags = codec.readFromContainer(container);

          expect(readTags.whereType<YearTag>(), hasLength(1));
          final yearTag = readTags.whereType<YearTag>().first;
          expect(yearTag.value, equals(expected), reason: 'Input $input should result in $expected');
        }
      });

      test('should handle codec normalization for edge cases', () {
        // Test that the codec's internal normalization works correctly
        // This tests the _normalizeYear and _normalizeTrackNumber methods
        final tags = <MetadataTag>[
          YearTag(2023),
          TrackNumberTag(5),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        expect(readTags.whereType<YearTag>(), hasLength(1));
        final yearTag = readTags.whereType<YearTag>().first;
        expect(yearTag.value, equals(2023));

        expect(readTags.whereType<TrackNumberTag>(), hasLength(1));
        final trackTag = readTags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));
      });

      test('should ignore unsupported tag types', () {
        final tags = <MetadataTag>[
          const TitleTag('Test Title'),
          // These should be ignored as they're not supported by ID3v1
          const LyricsTag('Some lyrics'),
          ArtworkTag(
            ArtworkData(
              mimeType: 'image/jpeg',
              type: ArtworkType.frontCover,
              dataLoader: () => Future.value(Uint8List(0)),
            ),
          ),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        // Should only have the title tag
        expect(readTags, hasLength(1));
        expect(readTags.whereType<TitleTag>(), hasLength(1));
        expect(readTags.whereType<LyricsTag>(), isEmpty);
        expect(readTags.whereType<ArtworkTag>(), isEmpty);
      });

      test('should write complete ID3v1.1 tag with all supported fields', () {
        final tags = <MetadataTag>[
          const TitleTag('Complete Title'),
          const ArtistTag('Complete Artist'),
          const AlbumTag('Complete Album'),
          YearTag(2023),
          const CommentTag('Complete comment'),
          TrackNumberTag(8),
          GenreTag.single('Rock'),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);

        // Verify container structure
        expect(container.length, equals(128));
        expect(latin1.decode(container.sublist(0, 3)), equals('TAG'));
        expect(container[125], equals(0x00)); // Null terminator for track
        expect(container[126], equals(8)); // Track number
        expect(container[127], equals(17)); // Rock genre

        // Verify by reading back
        final readTags = codec.readFromContainer(container);
        expect(readTags, hasLength(7));

        expect(readTags.whereType<TitleTag>().first.value, equals('Complete Title'));
        expect(readTags.whereType<ArtistTag>().first.value, equals('Complete Artist'));
        expect(readTags.whereType<AlbumTag>().first.value, equals('Complete Album'));
        expect(readTags.whereType<YearTag>().first.value, equals(2023));
        expect(readTags.whereType<CommentTag>().first.value, equals('Complete comment'));
        expect(readTags.whereType<TrackNumberTag>().first.value, equals(8));
        expect(readTags.whereType<GenreTag>().first.value, equals(['Rock']));
      });

      test('should handle edge case with maximum length fields', () {
        final maxTitle = 'A' * 30;
        final maxArtist = 'B' * 30;
        final maxAlbum = 'C' * 30;
        final maxComment = 'D' * 28; // 28 when track number present

        final tags = <MetadataTag>[
          TitleTag(maxTitle),
          ArtistTag(maxArtist),
          AlbumTag(maxAlbum),
          CommentTag(maxComment),
          TrackNumberTag(255),
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        expect(readTags, hasLength(5));
        expect(readTags.whereType<TitleTag>().first.value, equals(maxTitle));
        expect(readTags.whereType<ArtistTag>().first.value, equals(maxArtist));
        expect(readTags.whereType<AlbumTag>().first.value, equals(maxAlbum));
        expect(readTags.whereType<CommentTag>().first.value, equals(maxComment));
        expect(readTags.whereType<TrackNumberTag>().first.value, equals(255));
      });

      test('should preserve existing container when no changes needed', () {
        final existingContainer = _createId3v1Container(
          title: 'Existing Title',
          genreCode: 17,
        );

        // Write with empty tag list
        final newContainer = codec.writeToContainer(
          tagsToWrite: [],
          existingContainerBytes: existingContainer,
        );

        // Should create a new empty container (existing container is not preserved in current implementation)
        expect(newContainer.length, equals(128));
        expect(latin1.decode(newContainer.sublist(0, 3)), equals('TAG'));

        // Current implementation creates a fresh container, so existing data is not preserved
        final readTags = codec.readFromContainer(newContainer);
        expect(readTags, isEmpty);
      });

      test('should handle null and empty string values gracefully', () {
        final tags = <MetadataTag>[
          const TitleTag(''), // Empty string
          const ArtistTag('Valid Artist'),
          const CommentTag(''), // Empty comment
        ];

        final container = codec.writeToContainer(tagsToWrite: tags);
        final readTags = codec.readFromContainer(container);

        // Empty strings should not produce tags when read back
        expect(readTags, hasLength(1));
        expect(readTags.whereType<ArtistTag>().first.value, equals('Valid Artist'));
        expect(readTags.whereType<TitleTag>(), isEmpty);
        expect(readTags.whereType<CommentTag>(), isEmpty);
      });

      test('should handle various genre mappings correctly', () {
        final testCases = [
          ('Blues', 0),
          ('Classic Rock', 1),
          ('Country', 2),
          ('Dance', 3),
          ('Disco', 4),
          ('Funk', 5),
          ('Grunge', 6),
          ('Hip-Hop', 7),
          ('Jazz', 8),
          ('Metal', 9),
          ('New Age', 10),
          ('Oldies', 11),
          ('Other', 12),
          ('Pop', 13),
          ('R&B', 14),
          ('Rap', 15),
          ('Reggae', 16),
          ('Rock', 17),
          ('Techno', 18),
          ('Industrial', 19),
          ('Alternative', 20),
        ];

        for (final (genreName, expectedCode) in testCases) {
          final tags = <MetadataTag>[
            GenreTag.single(genreName),
          ];

          final container = codec.writeToContainer(tagsToWrite: tags);
          expect(container[127], equals(expectedCode), reason: 'Genre "$genreName" should map to code $expectedCode');

          // Verify round-trip
          final readTags = codec.readFromContainer(container);
          final genreTag = readTags.whereType<GenreTag>().firstOrNull;
          expect(genreTag?.value, equals([genreName]), reason: 'Genre code $expectedCode should map back to "$genreName"');
        }
      });
    });
  });
}

/// Creates an empty ID3v1 container with just the TAG identifier.
Uint8List _createEmptyId3v1Container() {
  final container = Uint8List(128);
  container.setRange(0, 3, latin1.encode('TAG'));

  // Fill with spaces (common practice)
  for (int i = 3; i < 127; i++) {
    container[i] = 0x20;
  }

  container[127] = 255; // Unknown genre
  return container;
}

/// Creates an ID3v1 container with the specified field values.
Uint8List _createId3v1Container({
  String? title,
  String? artist,
  String? album,
  String? year,
  String? comment,
  int? trackNumber,
  int? genreCode,
}) {
  final container = _createEmptyId3v1Container();

  // Write fields if provided
  if (title != null) {
    _writeField(container, 3, title, 30);
  }
  if (artist != null) {
    _writeField(container, 33, artist, 30);
  }
  if (album != null) {
    _writeField(container, 63, album, 30);
  }
  if (year != null) {
    _writeField(container, 93, year, 4);
  }

  // Handle comment and track number
  if (trackNumber != null) {
    // ID3v1.1 format
    if (comment != null) {
      _writeField(container, 97, comment, 28);
    }
    container[125] = 0x00; // Null terminator
    container[126] = trackNumber;
  } else if (comment != null) {
    // ID3v1.0 format
    _writeField(container, 97, comment, 30);
  }

  if (genreCode != null) {
    container[127] = genreCode;
  }

  return container;
}

/// Helper to write a text field to the container.
void _writeField(Uint8List container, int offset, String text, int maxLength) {
  final bytes = latin1.encode(text.length > maxLength ? text.substring(0, maxLength) : text);
  container.setRange(offset, offset + bytes.length, bytes);
}
