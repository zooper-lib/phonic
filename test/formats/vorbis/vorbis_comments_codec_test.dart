import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/artwork_data.dart';
import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/vorbis/vorbis_comments_codec.dart';
import 'package:phonic/src/utils/flac_picture_parser.dart';
import 'package:phonic/src/utils/vorbis_comment_parser.dart';

void main() {
  group('VorbisCommentsCodec', () {
    late VorbisCommentsCodec codec;

    setUp(() {
      codec = const VorbisCommentsCodec();
    });

    group('instantiation', () {
      test('should create codec instance successfully', () {
        expect(codec, isA<VorbisCommentsCodec>());
        expect(codec, isA<TagCodec>());
      });

      test('should be const constructible', () {
        const codec1 = VorbisCommentsCodec();
        const codec2 = VorbisCommentsCodec();

        // Const constructors should create identical instances
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
      });

      test('should be stateless and reusable', () {
        final codec1 = const VorbisCommentsCodec();
        final codec2 = const VorbisCommentsCodec();

        // Multiple instances should have identical properties
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
        expect(codec1.capability.containerKind, equals(codec2.capability.containerKind));
        expect(codec1.capability.containerVersion, equals(codec2.capability.containerVersion));
      });
    });

    group('properties', () {
      test('should have correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.vorbis));
      });

      test('should have correct container version', () {
        expect(codec.containerVersion, equals(''));
      });

      test('should have vorbis capability', () {
        expect(codec.capability, isNotNull);
        expect(codec.capability.containerKind, equals(ContainerKind.vorbis));
        expect(codec.capability.containerVersion, equals(''));
      });

      test('should support expected tag keys', () {
        final capability = codec.capability;

        // Test core text fields
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.album), isTrue);
        expect(capability.supports(TagKey.albumArtist), isTrue);
        expect(capability.supports(TagKey.comment), isTrue);
        expect(capability.supports(TagKey.grouping), isTrue);
        expect(capability.supports(TagKey.composer), isTrue);
        expect(capability.supports(TagKey.encoder), isTrue);
        expect(capability.supports(TagKey.isrc), isTrue);
        expect(capability.supports(TagKey.musicalKey), isTrue);
        expect(capability.supports(TagKey.lyrics), isTrue);

        // Test numeric fields
        expect(capability.supports(TagKey.trackNumber), isTrue);
        expect(capability.supports(TagKey.discNumber), isTrue);
        expect(capability.supports(TagKey.year), isTrue);
        expect(capability.supports(TagKey.bpm), isTrue);
        expect(capability.supports(TagKey.rating), isTrue);

        // Test date field
        expect(capability.supports(TagKey.dateRecorded), isTrue);

        // Test multi-valued fields
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.artwork), isTrue);
        expect(capability.supports(TagKey.custom), isTrue);
      });

      test('should have correct multi-valued field semantics', () {
        final capability = codec.capability;

        // Genre should support multiple values
        final genreSemantics = capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, isTrue);

        // Artwork should support multiple values
        final artworkSemantics = capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, isTrue);

        // Custom fields should support multiple values
        final customSemantics = capability.semantics(TagKey.custom);
        expect(customSemantics.multiValued, isTrue);

        // Single-valued fields should not support multiple values
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.multiValued, isFalse);

        final artistSemantics = capability.semantics(TagKey.artist);
        expect(artistSemantics.multiValued, isFalse);
      });

      test('should have UTF-8 encoding for text fields', () {
        final capability = codec.capability;

        // Check that text fields specify UTF-8 encoding
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.allowedEncodings, isNotNull);
        expect(titleSemantics.allowedEncodings!.contains('UTF-8'), isTrue);

        final artistSemantics = capability.semantics(TagKey.artist);
        expect(artistSemantics.allowedEncodings, isNotNull);
        expect(artistSemantics.allowedEncodings!.contains('UTF-8'), isTrue);

        final genreSemantics = capability.semantics(TagKey.genre);
        expect(genreSemantics.allowedEncodings, isNotNull);
        expect(genreSemantics.allowedEncodings!.contains('UTF-8'), isTrue);
      });

      test('should have reasonable numeric field constraints', () {
        final capability = codec.capability;

        // Track number constraints
        final trackSemantics = capability.semantics(TagKey.trackNumber);
        expect(trackSemantics.minValue, equals(1));
        expect(trackSemantics.maxValue, equals(999));

        // Disc number constraints
        final discSemantics = capability.semantics(TagKey.discNumber);
        expect(discSemantics.minValue, equals(1));
        expect(discSemantics.maxValue, equals(99));

        // Year constraints
        final yearSemantics = capability.semantics(TagKey.year);
        expect(yearSemantics.minValue, equals(1000));
        expect(yearSemantics.maxValue, equals(3000));

        // BPM constraints
        final bpmSemantics = capability.semantics(TagKey.bpm);
        expect(bpmSemantics.minValue, equals(1));
        expect(bpmSemantics.maxValue, equals(999));

        // Rating constraints (0-100 scale)
        final ratingSemantics = capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(100));
      });
    });

    group('interface compliance', () {
      test('should implement TagCodec interface', () {
        expect(codec, isA<TagCodec>());
      });

      test('should have readFromContainer method', () {
        // Empty container should return empty list
        final result = codec.readFromContainer(Uint8List(0));
        expect(result, isEmpty);
      });

      test('should have writeToContainer method', () {
        // Empty tags should create minimal comment block
        final result = codec.writeToContainer(tagsToWrite: []);
        expect(result, isNotEmpty);
      });
    });

    group('readFromContainer', () {
      test('should return empty list for empty container', () {
        final result = codec.readFromContainer(Uint8List(0));
        expect(result, isEmpty);
      });

      test('should return empty list for malformed container', () {
        // Create malformed Vorbis comment data
        final malformedData = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
        final result = codec.readFromContainer(malformedData);
        expect(result, isEmpty);
      });

      test('should parse basic text fields correctly', () {
        // Create a simple Vorbis comment block with basic fields
        final commentData = _createVorbisCommentBlock([
          'TITLE=Test Song',
          'ARTIST=Test Artist',
          'ALBUM=Test Album',
          'ALBUMARTIST=Test Album Artist',
          'COMMENT=Test Comment',
          'GROUPING=Test Grouping',
          'COMPOSER=Test Composer',
          'ENCODER=Test Encoder',
          'ISRC=USRC17607839',
          'KEY=C major',
          'LYRICS=Test lyrics content',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(11));

        // Verify each tag type and value
        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Song'));
        expect(titleTag.provenance.containerKind, equals(ContainerKind.vorbis));

        final artistTag = result.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = result.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));

        final albumArtistTag = result.whereType<AlbumArtistTag>().first;
        expect(albumArtistTag.value, equals('Test Album Artist'));

        final commentTag = result.whereType<CommentTag>().first;
        expect(commentTag.value, equals('Test Comment'));

        final groupingTag = result.whereType<GroupingTag>().first;
        expect(groupingTag.value, equals('Test Grouping'));

        final composerTag = result.whereType<ComposerTag>().first;
        expect(composerTag.value, equals('Test Composer'));

        final encoderTag = result.whereType<EncoderTag>().first;
        expect(encoderTag.value, equals('Test Encoder'));

        final isrcTag = result.whereType<IsrcTag>().first;
        expect(isrcTag.value, equals('USRC17607839'));

        final keyTag = result.whereType<MusicalKeyTag>().first;
        expect(keyTag.value, equals('C major'));

        final lyricsTag = result.whereType<LyricsTag>().first;
        expect(lyricsTag.value, equals('Test lyrics content'));
      });

      test('should parse numeric fields correctly', () {
        final commentData = _createVorbisCommentBlock([
          'TRACKNUMBER=5',
          'DISCNUMBER=2',
          'DATE=2023-05-15',
          'BPM=120',
          'RATING=85',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(5));

        final trackTag = result.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));

        final discTag = result.whereType<DiscNumberTag>().first;
        expect(discTag.value, equals(2));

        final dateTag = result.whereType<DateRecordedTag>().first;
        expect(dateTag.value, equals('2023-05-15'));

        final bpmTag = result.whereType<BpmTag>().first;
        expect(bpmTag.value, equals(120));

        final ratingTag = result.whereType<RatingTag>().first;
        expect(ratingTag.value, equals(85));
      });

      test('should handle multiple GENRE fields correctly', () {
        final commentData = _createVorbisCommentBlock([
          'GENRE=Rock',
          'GENRE=Alternative',
          'GENRE=Indie',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(1));

        final genreTag = result.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(genreTag.provenance.containerKind, equals(ContainerKind.vorbis));
      });

      test('should handle delimited GENRE fields correctly', () {
        final commentData = _createVorbisCommentBlock([
          'GENRE=Rock;Alternative;Indie',
          'GENRE=Electronic',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(1));

        final genreTag = result.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie', 'Electronic']));
      });

      test('should handle mixed GENRE field formats', () {
        final commentData = _createVorbisCommentBlock([
          'GENRE=Rock/Alternative', // Slash-separated
          'GENRE=Electronic;Ambient', // Semicolon-separated
          'GENRE=Jazz', // Single genre
          'GENRE=Classical, Orchestral', // Comma-separated
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(1));

        final genreTag = result.whereType<GenreTag>().first;
        expect(genreTag.value, containsAll(['Rock', 'Alternative', 'Electronic', 'Ambient', 'Jazz', 'Classical', 'Orchestral']));
      });

      test('should handle invalid numeric values gracefully', () {
        final commentData = _createVorbisCommentBlock([
          'TRACKNUMBER=invalid',
          'DISCNUMBER=0', // Invalid (must be > 0)
          'BPM=0', // Invalid (must be >= 1)
          'BPM=2000', // Invalid (must be <= 999)
          'RATING=-5', // Invalid (must be >= 0)
          'RATING=150', // Invalid (must be <= 100)
          'TITLE=Valid Title', // This should still work
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(1)); // Only the valid title tag

        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Valid Title'));

        // Verify no invalid numeric tags were created
        expect(result.whereType<TrackNumberTag>(), isEmpty);
        expect(result.whereType<DiscNumberTag>(), isEmpty);
        expect(result.whereType<BpmTag>(), isEmpty);
        expect(result.whereType<RatingTag>(), isEmpty);
      });

      test('should handle custom fields correctly', () {
        final commentData = _createVorbisCommentBlock([
          'TITLE=Test Song',
          'CUSTOM_FIELD=Custom Value 1',
          'MY_APP_DATA=Custom Value 2',
          'UNKNOWN_TAG=Custom Value 3',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(4)); // 1 standard + 3 custom

        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Song'));

        final customTags = result.whereType<CustomTag>().toList();
        expect(customTags, hasLength(3));

        final customValues = customTags.map((tag) => tag.value).toList();
        expect(customValues, containsAll(['Custom Value 1', 'Custom Value 2', 'Custom Value 3']));
      });

      test('should handle case-insensitive field names', () {
        final commentData = _createVorbisCommentBlock([
          'title=Test Song', // lowercase
          'ARTIST=Test Artist', // uppercase
          'Album=Test Album', // mixed case
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(3));

        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Song'));

        final artistTag = result.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = result.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));
      });

      test('should handle empty and whitespace values', () {
        final commentData = _createVorbisCommentBlock([
          'TITLE=', // Empty value
          'ARTIST=   ', // Whitespace only
          'ALBUM=Valid Album', // Valid value
          'GENRE=', // Empty genre
          'GENRE=Rock', // Valid genre
        ]);

        final result = codec.readFromContainer(commentData);

        // Should create tags for empty values (they might be meaningful)
        final titleTag = result.whereType<TitleTag>().firstOrNull;
        expect(titleTag?.value, equals(''));

        final artistTag = result.whereType<ArtistTag>().firstOrNull;
        expect(artistTag?.value, equals('   '));

        final albumTag = result.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Valid Album'));

        // Genre should only include non-empty values
        final genreTag = result.whereType<GenreTag>().first;
        expect(genreTag.value, equals(['Rock']));
      });

      test('should set correct provenance for all tags', () {
        final commentData = _createVorbisCommentBlock([
          'TITLE=Test Song',
          'ARTIST=Test Artist',
          'TRACKNUMBER=5',
          'GENRE=Rock',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(4));

        for (final tag in result) {
          expect(tag.provenance.containerKind, equals(ContainerKind.vorbis));
          expect(tag.provenance.containerVersion, equals(''));
          expect(tag.provenance.confidence, equals(TagConfidence.certain));
        }
      });

      test('should handle UTF-8 encoded text correctly', () {
        final commentData = _createVorbisCommentBlock([
          'TITLE=Test Song with émojis 🎵',
          'ARTIST=Artiste français',
          'ALBUM=Альбом на русском',
          'COMMENT=コメント in Japanese',
        ]);

        final result = codec.readFromContainer(commentData);
        expect(result, hasLength(4));

        final titleTag = result.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Song with émojis 🎵'));

        final artistTag = result.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Artiste français'));

        final albumTag = result.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Альбом на русском'));

        final commentTag = result.whereType<CommentTag>().first;
        expect(commentTag.value, equals('コメント in Japanese'));
      });
    });

    group('writeToContainer', () {
      test('should create minimal comment block for empty tags', () {
        final result = codec.writeToContainer(tagsToWrite: []);
        expect(result, isNotEmpty);

        // Should contain vendor string and zero comments
        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        expect(comments, isEmpty);
      });

      test('should encode basic text fields correctly', () {
        final tagsToWrite = [
          const TitleTag('Test Song'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
          const AlbumArtistTag('Test Album Artist'),
          const CommentTag('Test Comment'),
          const GroupingTag('Test Grouping'),
          const ComposerTag('Test Composer'),
          const EncoderTag('Test Encoder'),
          const IsrcTag('USRC17607839'),
          const MusicalKeyTag('C major'),
          const LyricsTag('Test lyrics content'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        // Parse the result and verify all fields are present
        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['TITLE']?.first, equals('Test Song'));
        expect(grouped['ARTIST']?.first, equals('Test Artist'));
        expect(grouped['ALBUM']?.first, equals('Test Album'));
        expect(grouped['ALBUMARTIST']?.first, equals('Test Album Artist'));
        expect(grouped['COMMENT']?.first, equals('Test Comment'));
        expect(grouped['GROUPING']?.first, equals('Test Grouping'));
        expect(grouped['COMPOSER']?.first, equals('Test Composer'));
        expect(grouped['ENCODER']?.first, equals('Test Encoder'));
        expect(grouped['ISRC']?.first, equals('USRC17607839'));
        expect(grouped['KEY']?.first, equals('C major'));
        expect(grouped['LYRICS']?.first, equals('Test lyrics content'));
      });

      test('should encode numeric fields correctly', () {
        final tagsToWrite = <MetadataTag>[
          TrackNumberTag(5),
          DiscNumberTag(2),
          DateRecordedTag('2023-05-15'),
          BpmTag(120),
          RatingTag(85),
          YearTag(2023),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['TRACKNUMBER']?.first, equals('5'));
        expect(grouped['DISCNUMBER']?.first, equals('2'));
        expect(grouped['DATE']?.first, equals('2023-05-15'));
        expect(grouped['BPM']?.first, equals('120'));
        expect(grouped['RATING']?.first, equals('85'));
        // Year should be mapped to DATE field
        expect(grouped['DATE']?.length, equals(2)); // Both dateRecorded and year
        expect(grouped['DATE'], containsAll(['2023-05-15', '2023']));
      });

      test('should encode GenreTag to multiple GENRE fields', () {
        final genreTag = GenreTag(const ['Rock', 'Alternative', 'Indie']);
        final tagsToWrite = [genreTag];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['GENRE'], hasLength(3));
        expect(grouped['GENRE'], containsAll(['Rock', 'Alternative', 'Indie']));
      });

      test('should handle single genre correctly', () {
        final genreTag = GenreTag.single('Jazz');
        final tagsToWrite = [genreTag];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['GENRE'], hasLength(1));
        expect(grouped['GENRE']?.first, equals('Jazz'));
      });

      test('should handle empty genre list', () {
        final genreTag = GenreTag(const []);
        final tagsToWrite = [genreTag];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['GENRE'], isNull);
      });

      test('should handle custom tags correctly', () {
        final customTag = const CustomTag('Custom Value');
        final tagsToWrite = [customTag];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['CUSTOM']?.first, equals('Custom Value'));
      });

      test('should handle UTF-8 encoded text correctly', () {
        final tagsToWrite = [
          const TitleTag('Test Song with émojis 🎵'),
          const ArtistTag('Artiste français'),
          const AlbumTag('Альбом на русском'),
          const CommentTag('コメント in Japanese'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['TITLE']?.first, equals('Test Song with émojis 🎵'));
        expect(grouped['ARTIST']?.first, equals('Artiste français'));
        expect(grouped['ALBUM']?.first, equals('Альбом на русском'));
        expect(grouped['COMMENT']?.first, equals('コメント in Japanese'));
      });

      test('should handle mixed tag types correctly', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Mixed Test'),
          TrackNumberTag(7),
          GenreTag(const ['Electronic', 'Ambient']),
          BpmTag(128),
          const ArtistTag('Test Artist'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['TITLE']?.first, equals('Mixed Test'));
        expect(grouped['TRACKNUMBER']?.first, equals('7'));
        expect(grouped['GENRE'], containsAll(['Electronic', 'Ambient']));
        expect(grouped['BPM']?.first, equals('128'));
        expect(grouped['ARTIST']?.first, equals('Test Artist'));
      });

      test('should skip artwork tags in comment encoding', () {
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Test artwork',
          dataLoader: () async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );
        final artworkTag = ArtworkTag(artworkData);
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Test Song'),
          artworkTag,
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        // Should only have the title, artwork should be skipped
        expect(grouped.keys, hasLength(1));
        expect(grouped['TITLE']?.first, equals('Test Song'));
      });

      test('should handle duplicate tag keys correctly', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('First Title'),
          const TitleTag('Second Title'),
          GenreTag(const ['Rock']),
          GenreTag(const ['Alternative']),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        // Should have both titles (last one wins in most parsers)
        expect(grouped['TITLE'], hasLength(2));
        expect(grouped['TITLE'], containsAll(['First Title', 'Second Title']));

        // Should have both genres
        expect(grouped['GENRE'], hasLength(2));
        expect(grouped['GENRE'], containsAll(['Rock', 'Alternative']));
      });

      test('should create valid Vorbis comment structure', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag('Structure Test'),
          const ArtistTag('Test Artist'),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        // Verify the structure can be parsed back correctly
        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        expect(comments, hasLength(2));

        final grouped = parser.groupCommentsByField(comments);
        expect(grouped['TITLE']?.first, equals('Structure Test'));
        expect(grouped['ARTIST']?.first, equals('Test Artist'));
      });

      test('should handle empty string values', () {
        final tagsToWrite = <MetadataTag>[
          const TitleTag(''),
          const ArtistTag('Valid Artist'),
          const CommentTag(''),
        ];

        final result = codec.writeToContainer(tagsToWrite: tagsToWrite);
        expect(result, isNotEmpty);

        final parser = const VorbisCommentParser();
        final comments = parser.parseComments(result);
        final grouped = parser.groupCommentsByField(comments);

        expect(grouped['TITLE']?.first, equals(''));
        expect(grouped['ARTIST']?.first, equals('Valid Artist'));
        expect(grouped['COMMENT']?.first, equals(''));
      });
    });

    group('encodeMetadataBlockPicture', () {
      test('should encode artwork data to METADATA_BLOCK_PICTURE format', () async {
        final imageData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: 'Test artwork',
          dataLoader: () async => imageData,
        );

        final result = await codec.encodeMetadataBlockPicture(artworkData);
        expect(result, isNotEmpty);

        // Verify the structure can be parsed back
        const parser = FlacPictureParser();
        final parsedArtwork = parser.parsePictureBlock(result);

        expect(parsedArtwork.mimeType, equals('image/jpeg'));
        expect(parsedArtwork.type, equals(ArtworkType.frontCover));
        expect(parsedArtwork.description, equals('Test artwork'));

        final parsedImageData = await parsedArtwork.data;
        expect(parsedImageData, equals(imageData));
      });

      test('should handle artwork without description', () async {
        final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
        final artworkData = ArtworkData(
          mimeType: 'image/png',
          type: ArtworkType.backCover,
          dataLoader: () async => imageData,
        );

        final result = await codec.encodeMetadataBlockPicture(artworkData);
        expect(result, isNotEmpty);

        const parser = FlacPictureParser();
        final parsedArtwork = parser.parsePictureBlock(result);

        expect(parsedArtwork.mimeType, equals('image/png'));
        expect(parsedArtwork.type, equals(ArtworkType.backCover));
        expect(parsedArtwork.description, isNull);

        final parsedImageData = await parsedArtwork.data;
        expect(parsedImageData, equals(imageData));
      });

      test('should handle different artwork types', () async {
        final imageData = Uint8List.fromList([0x47, 0x49, 0x46, 0x38]); // GIF header
        final artworkData = ArtworkData(
          mimeType: 'image/gif',
          type: ArtworkType.artist,
          description: 'Artist photo',
          dataLoader: () async => imageData,
        );

        final result = await codec.encodeMetadataBlockPicture(artworkData);
        expect(result, isNotEmpty);

        const parser = FlacPictureParser();
        final parsedArtwork = parser.parsePictureBlock(result);

        expect(parsedArtwork.mimeType, equals('image/gif'));
        expect(parsedArtwork.type, equals(ArtworkType.artist));
        expect(parsedArtwork.description, equals('Artist photo'));
      });
    });

    group('round-trip encoding', () {
      test('should maintain data integrity through encode/decode cycle', () {
        final originalTags = <MetadataTag>[
          const TitleTag('Round Trip Test'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
          TrackNumberTag(5),
          GenreTag(const ['Rock', 'Alternative']),
          BpmTag(120),
          RatingTag(85),
        ];

        // Encode tags to Vorbis comment block
        final encoded = codec.writeToContainer(tagsToWrite: originalTags);
        expect(encoded, isNotEmpty);

        // Decode the block back to tags
        final decodedTags = codec.readFromContainer(encoded);
        expect(decodedTags, hasLength(7));

        // Verify each tag type and value
        final titleTag = decodedTags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Round Trip Test'));

        final artistTag = decodedTags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = decodedTags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));

        final trackTag = decodedTags.whereType<TrackNumberTag>().first;
        expect(trackTag.value, equals(5));

        final genreTag = decodedTags.whereType<GenreTag>().first;
        expect(genreTag.value, containsAll(['Rock', 'Alternative']));

        final bpmTag = decodedTags.whereType<BpmTag>().first;
        expect(bpmTag.value, equals(120));

        final ratingTag = decodedTags.whereType<RatingTag>().first;
        expect(ratingTag.value, equals(85));
      });

      test('should handle UTF-8 text in round-trip', () {
        final originalTags = <MetadataTag>[
          const TitleTag('Test Song with émojis 🎵'),
          const ArtistTag('Artiste français'),
          const AlbumTag('Альбом на русском'),
          const CommentTag('コメント in Japanese'),
        ];

        final encoded = codec.writeToContainer(tagsToWrite: originalTags);
        final decodedTags = codec.readFromContainer(encoded);

        expect(decodedTags, hasLength(4));

        final titleTag = decodedTags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Song with émojis 🎵'));

        final artistTag = decodedTags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Artiste français'));

        final albumTag = decodedTags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Альбом на русском'));

        final commentTag = decodedTags.whereType<CommentTag>().first;
        expect(commentTag.value, equals('コメント in Japanese'));
      });
    });

    group('thread safety', () {
      test('should be thread-safe and stateless', () {
        // Create multiple codec instances
        final codecs = List.generate(10, (_) => const VorbisCommentsCodec());

        // All instances should have identical properties
        for (final testCodec in codecs) {
          expect(testCodec.containerKind, equals(ContainerKind.vorbis));
          expect(testCodec.containerVersion, equals(''));
          expect(testCodec.capability.containerKind, equals(ContainerKind.vorbis));
        }

        // Instances should be independent (no shared mutable state)
        expect(codecs.every((c) => c.containerKind == ContainerKind.vorbis), isTrue);
        expect(codecs.every((c) => c.containerVersion == ''), isTrue);
      });
    });
  });
}

/// Helper method to create a Vorbis comment block from a list of comment strings.
///
/// This creates a properly formatted Vorbis comment block with:
/// - Vendor string length and content
/// - User comment list length
/// - Individual comment lengths and content
///
/// The format follows the Vorbis specification for comment blocks.
Uint8List _createVorbisCommentBlock(List<String> comments) {
  final buffer = <int>[];

  // Vendor string (using a simple test vendor)
  const vendorString = 'Test Encoder';
  final vendorBytes = utf8.encode(vendorString);

  // Write vendor string length (little-endian)
  buffer.addAll(_uint32ToBytes(vendorBytes.length));

  // Write vendor string
  buffer.addAll(vendorBytes);

  // Write user comment list length (little-endian)
  buffer.addAll(_uint32ToBytes(comments.length));

  // Write each comment
  for (final comment in comments) {
    final commentBytes = utf8.encode(comment);

    // Write comment length (little-endian)
    buffer.addAll(_uint32ToBytes(commentBytes.length));

    // Write comment content
    buffer.addAll(commentBytes);
  }

  return Uint8List.fromList(buffer);
}

/// Helper method to convert a 32-bit unsigned integer to little-endian bytes.
List<int> _uint32ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}
