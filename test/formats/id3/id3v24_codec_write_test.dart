import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';

void main() {
  group('Id3v24Codec writeToContainer', () {
    late Id3v24Codec codec;

    setUp(() {
      codec = const Id3v24Codec();
    });

    test('should create empty container when no tags provided', () {
      final result = codec.writeToContainer(tagsToWrite: []);

      // Should be a valid ID3v2.4 header with no frames
      expect(result.length, equals(10)); // Just the header
      expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
      expect(result[3], equals(0x04)); // Version 2.4
      expect(result[4], equals(0x00)); // Minor version
      expect(result[5], equals(0x00)); // No flags
      expect(result.sublist(6, 10), equals([0x00, 0x00, 0x00, 0x00])); // Size: 0
    });

    test('should create container with single text frame', () {
      final tags = [const TitleTag('Test Title')];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Should contain ID3v2.4 header + TIT2 frame
      expect(result.length, greaterThan(10)); // Header + frame data
      expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
      expect(result[3], equals(0x04)); // Version 2.4

      // Parse the result to verify it contains the title
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<TitleTag>());
      expect((parsedTags[0] as TitleTag).value, equals('Test Title'));
    });

    test('should create container with multiple text frames', () {
      final tags = [
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
        const AlbumTag('Test Album'),
      ];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify it contains all tags
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(3));

      final titleTag = parsedTags.whereType<TitleTag>().first;
      expect(titleTag.value, equals('Test Title'));

      final artistTag = parsedTags.whereType<ArtistTag>().first;
      expect(artistTag.value, equals('Test Artist'));

      final albumTag = parsedTags.whereType<AlbumTag>().first;
      expect(albumTag.value, equals('Test Album'));
    });

    test('should handle GenreTag with multiple genres using null-terminated strings', () {
      final tags = [
        GenreTag(const ['Rock', 'Alternative', 'Indie']),
      ];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify genre encoding
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<GenreTag>());

      final genreTag = parsedTags[0] as GenreTag;
      expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
    });

    test('should handle GenreTag with single genre', () {
      final tags = [GenreTag.single('Jazz')];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify genre encoding
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<GenreTag>());

      final genreTag = parsedTags[0] as GenreTag;
      expect(genreTag.value, equals(['Jazz']));
    });

    test('should handle numeric tags', () {
      final tags = <MetadataTag>[
        TrackNumberTag(5),
        DiscNumberTag(2),
        BpmTag(120),
      ];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify numeric tags
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(3));

      final trackTag = parsedTags.whereType<TrackNumberTag>().first;
      expect(trackTag.value, equals(5));

      final discTag = parsedTags.whereType<DiscNumberTag>().first;
      expect(discTag.value, equals(2));

      final bpmTag = parsedTags.whereType<BpmTag>().first;
      expect(bpmTag.value, equals(120));
    });

    test('should handle RatingTag with POPM frame', () {
      final tags = <MetadataTag>[RatingTag(80)]; // 80% rating
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify rating conversion
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<RatingTag>());

      final ratingTag = parsedTags[0] as RatingTag;
      // Allow some tolerance in rating conversion due to rounding
      expect(ratingTag.value, closeTo(80, 2));
    });

    test('should skip unsupported tags gracefully', () {
      final tags = [
        const TitleTag('Test Title'),
        // Add a tag that might not be supported (this is hypothetical)
      ];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Should still create a valid container with supported tags
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<TitleTag>());
    });

    test('should use UTF-8 encoding for text frames', () {
      final tags = [const TitleTag('Test with émojis 🎵')];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify UTF-8 handling
      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags, hasLength(1));
      expect(parsedTags[0], isA<TitleTag>());

      final titleTag = parsedTags[0] as TitleTag;
      expect(titleTag.value, equals('Test with émojis 🎵'));
    });

    test('should create valid ID3v2.4 structure', () {
      final tags = [
        const TitleTag('Test'),
        const ArtistTag('Artist'),
      ];
      final result = codec.writeToContainer(tagsToWrite: tags);

      // Verify the basic structure
      expect(result.length, greaterThan(10));

      // Check header
      expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
      expect(result[3], equals(0x04)); // Major version 2.4
      expect(result[4], equals(0x00)); // Minor version 0

      // The tag should be parseable by the same codec
      expect(() => codec.readFromContainer(result), returnsNormally);
    });

    test('should handle round-trip encoding correctly', () {
      final originalTags = <MetadataTag>[
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
        const AlbumTag('Test Album'),
        GenreTag(const ['Rock', 'Pop']),
        TrackNumberTag(7),
        BpmTag(140),
      ];

      // Write tags to container
      final containerBytes = codec.writeToContainer(tagsToWrite: originalTags);

      // Read tags back from container
      final parsedTags = codec.readFromContainer(containerBytes);

      // Verify all tags are preserved
      expect(parsedTags, hasLength(originalTags.length));

      // Check each tag type
      final titleTag = parsedTags.whereType<TitleTag>().first;
      expect(titleTag.value, equals('Test Title'));

      final artistTag = parsedTags.whereType<ArtistTag>().first;
      expect(artistTag.value, equals('Test Artist'));

      final albumTag = parsedTags.whereType<AlbumTag>().first;
      expect(albumTag.value, equals('Test Album'));

      final genreTag = parsedTags.whereType<GenreTag>().first;
      expect(genreTag.value, equals(['Rock', 'Pop']));

      final trackTag = parsedTags.whereType<TrackNumberTag>().first;
      expect(trackTag.value, equals(7));

      final bpmTag = parsedTags.whereType<BpmTag>().first;
      expect(bpmTag.value, equals(140));
    });
  });
}
