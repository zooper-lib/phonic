import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/formats/id3/id3v22_codec.dart';
import 'package:phonic/src/formats/id3/id3v2_header_parser.dart';
import 'package:phonic/src/tags/tags.dart';

void main() {
  group('Id3v22Codec writeToContainer', () {
    late Id3v22Codec codec;

    setUp(() {
      codec = const Id3v22Codec();
    });

    test('should create empty container when no tags provided', () {
      final result = codec.writeToContainer(tagsToWrite: []);

      expect(result.length, equals(10)); // Header only
      expect(result.sublist(0, 3), equals([0x49, 0x44, 0x33])); // "ID3"
      expect(result.sublist(3, 5), equals([0x02, 0x00])); // Version 2.2
      expect(result[5], equals(0x00)); // No flags
      expect(result.sublist(6, 10), equals([0x00, 0x00, 0x00, 0x00])); // Size: 0
    });

    test('should write single text frame correctly', () {
      final tags = [
        const TitleTag('Test Title'),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      // Parse the result to verify structure
      final header = Id3v2HeaderParser.parseHeader(result);
      expect(header.majorVersion, equals(2));
      expect(header.minorVersion, equals(0));
      expect(header.tagSize, greaterThan(0));

      // Verify frame data starts after header
      final frameData = result.sublist(10);
      expect(frameData.length, equals(header.tagSize));

      // Check frame header: "TT2" + size + data
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TT2'));

      // Frame size should be 11 bytes (1 encoding + 10 text)
      final frameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      expect(frameSize, equals(11)); // 1 byte encoding + 10 bytes "Test Title"

      // Check frame data: encoding byte + text
      expect(frameData[6], equals(0x00)); // ISO-8859-1 encoding
      expect(String.fromCharCodes(frameData.sublist(7, 17)), equals('Test Title'));
    });

    test('should write multiple text frames correctly', () {
      final tags = [
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
        const AlbumTag('Test Album'),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final header = Id3v2HeaderParser.parseHeader(result);
      expect(header.majorVersion, equals(2));
      expect(header.tagSize, greaterThan(0));

      // Should contain 3 frames
      final frameData = result.sublist(10);

      // Parse frames manually to verify
      int offset = 0;
      final frameIds = <String>[];

      while (offset < frameData.length) {
        if (offset + 6 > frameData.length) break;

        final frameId = String.fromCharCodes(frameData.sublist(offset, offset + 3));
        final frameSize = (frameData[offset + 3] << 16) | (frameData[offset + 4] << 8) | frameData[offset + 5];

        frameIds.add(frameId);
        offset += 6 + frameSize; // Move to next frame
      }

      expect(frameIds, containsAll(['TT2', 'TP1', 'TAL']));
    });

    test('should handle GenreTag with slash-separated format', () {
      final tags = [
        GenreTag(const ['Rock', 'Alternative', 'Indie']),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final frameData = result.sublist(10);

      // Find TCO frame
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TCO'));

      final frameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      expect(frameData[6], equals(0x00)); // ISO-8859-1 encoding

      final genreText = String.fromCharCodes(frameData.sublist(7, 7 + frameSize - 1));
      expect(genreText, equals('Rock/Alternative/Indie')); // Slash-separated for v2.2
    });

    test('should handle numeric tags correctly', () {
      final tags = [
        YearTag(2023),
        TrackNumberTag(5),
        BpmTag(120),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final frameData = result.sublist(10);

      // Parse frames to verify numeric conversion
      int offset = 0;
      final frameContents = <String, String>{};

      while (offset < frameData.length) {
        if (offset + 6 > frameData.length) break;

        final frameId = String.fromCharCodes(frameData.sublist(offset, offset + 3));
        final frameSize = (frameData[offset + 3] << 16) | (frameData[offset + 4] << 8) | frameData[offset + 5];

        // Skip encoding byte and read text
        final textBytes = frameData.sublist(offset + 7, offset + 6 + frameSize);
        final text = String.fromCharCodes(textBytes);
        frameContents[frameId] = text;

        offset += 6 + frameSize;
      }

      expect(frameContents['TYE'], equals('2023'));
      expect(frameContents['TRK'], equals('5'));
      expect(frameContents['TBP'], equals('120'));
    });

    test('should handle CommentTag with proper COM frame structure', () {
      final tags = [
        const CommentTag('This is a test comment'),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final frameData = result.sublist(10);

      // Check COM frame structure
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('COM'));

      final frameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      expect(frameData[6], equals(0x00)); // ISO-8859-1 encoding
      expect(frameData.sublist(7, 10), equals([0x65, 0x6E, 0x67])); // "eng" language

      final commentText = String.fromCharCodes(frameData.sublist(10, 6 + frameSize));
      expect(commentText, equals('This is a test comment'));
    });

    test('should handle CustomTag with TXX frame structure', () {
      final tags = [
        const CustomTag('Custom value'),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final frameData = result.sublist(10);

      // Check TXX frame structure
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TXX'));

      final frameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      expect(frameData[6], equals(0x00)); // ISO-8859-1 encoding
      expect(frameData[7], equals(0x00)); // Empty description + null terminator

      final customText = String.fromCharCodes(frameData.sublist(8, 6 + frameSize));
      expect(customText, equals('Custom value'));
    });

    test('should skip unsupported tags for ID3v2.2', () {
      final tags = <MetadataTag>[
        const TitleTag('Supported Title'),
        RatingTag(85), // Not supported in ID3v2.2
        const LyricsTag('Not supported lyrics'), // Not supported in ID3v2.2
        DiscNumberTag(2), // Not supported in ID3v2.2
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final header = Id3v2HeaderParser.parseHeader(result);
      final frameData = result.sublist(10);

      // Should only contain the title frame
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TT2'));

      // Calculate expected size: 6 bytes frame header + 1 encoding + 15 chars = 22 bytes total
      // Tag size should be 22 bytes (frame header + frame data)
      expect(header.tagSize, equals(22)); // 6 frame header + 1 encoding + 15 text = 22
    });

    test('should handle empty string values', () {
      final tags = [
        const TitleTag(''),
        const ArtistTag('Valid Artist'),
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final header = Id3v2HeaderParser.parseHeader(result);
      expect(header.tagSize, greaterThan(0));

      // Should contain both frames, even with empty title
      final frameData = result.sublist(10);

      // First frame should be TT2 with empty content
      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TT2'));
      final firstFrameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      expect(firstFrameSize, equals(1)); // Only encoding byte
    });

    test('should handle special characters in ISO-8859-1 range', () {
      final tags = [
        const TitleTag('Café Münü'), // Contains accented characters
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final frameData = result.sublist(10);

      expect(String.fromCharCodes(frameData.sublist(0, 3)), equals('TT2'));
      expect(frameData[6], equals(0x00)); // ISO-8859-1 encoding

      // Verify the text can be decoded back
      final frameSize = (frameData[3] << 16) | (frameData[4] << 8) | frameData[5];
      final textBytes = frameData.sublist(7, 7 + frameSize - 1);
      final decodedText = latin1.decode(textBytes);
      expect(decodedText, equals('Café Münü'));
    });

    test('should create valid container that can be parsed back', () {
      final originalTags = <MetadataTag>[
        const TitleTag('Round Trip Title'),
        const ArtistTag('Round Trip Artist'),
        GenreTag(const ['Electronic', 'Ambient']),
        YearTag(2024),
      ];

      // Write tags to container
      final containerBytes = codec.writeToContainer(tagsToWrite: originalTags);

      // Parse the container back
      final parsedTags = codec.readFromContainer(containerBytes);

      // Verify we can read back the same data
      expect(parsedTags.length, equals(4));

      final titleTag = parsedTags.whereType<TitleTag>().first;
      expect(titleTag.value, equals('Round Trip Title'));

      final artistTag = parsedTags.whereType<ArtistTag>().first;
      expect(artistTag.value, equals('Round Trip Artist'));

      final genreTag = parsedTags.whereType<GenreTag>().first;
      expect(genreTag.value, equals(['Electronic', 'Ambient']));

      final yearTag = parsedTags.whereType<YearTag>().first;
      expect(yearTag.value, equals(2024));
    });

    test('should handle frame size calculation correctly', () {
      final tags = [
        const TitleTag('A'), // 1 char + 1 encoding = 2 bytes
        const ArtistTag('AB'), // 2 chars + 1 encoding = 3 bytes
        const AlbumTag('ABC'), // 3 chars + 1 encoding = 4 bytes
      ];

      final result = codec.writeToContainer(tagsToWrite: tags);

      final header = Id3v2HeaderParser.parseHeader(result);

      // Expected: 3 frames * 6 bytes header + 2 + 3 + 4 bytes data = 27 bytes
      expect(header.tagSize, equals(27));
      expect(result.length, equals(37)); // 10 header + 27 tag data
    });
  });
}
