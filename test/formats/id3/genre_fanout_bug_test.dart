import 'dart:typed_data';

import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/phonic_audio_file_impl.dart';
import 'package:phonic/src/core/post_write_validator.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/id3/id3v1_codec.dart';
import 'package:phonic/src/formats/id3/id3v22_codec.dart';
import 'package:phonic/src/formats/id3/id3v23_codec.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';
import 'package:phonic/src/utils/locators/id3v1_locator.dart';
import 'package:phonic/src/utils/locators/id3v2_locator.dart';
import 'package:test/test.dart';

/// Regression test for the genre fanout bug
///
/// Bug description: When changing genre from "Blues" to "Blues, RNB",
/// Dolphin showed "Blues, RNB and Blues" because the old ID3v1 genre was
/// being merged with the new ID3v2 genre during read operations.
///
/// Root cause: The encoding process was combining prepared tags from all
/// containers back into one list, causing each container to receive tags
/// that were already normalized for other containers.
void main() {
  group('Genre Fanout Bug Regression Test', () {
    late CodecRegistry codecRegistry;
    late PostWriteValidator validator;

    setUp(() {
      codecRegistry = CodecRegistry(
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

      validator = PostWriteValidator(
        codecRegistry: codecRegistry,
        enableDeepValidation: false,
        enableRoundTripValidation: false,
      );
    });

    test('should correctly update both ID3v1 and ID3v2 when changing genre', () async {
      // Create initial MP3 file with genre "Blues" in both ID3v1 and ID3v2.4
      final initialFile = _createMp3WithGenre('Blues');

      // Load the file
      final audioFile = PhonicAudioFileImpl(
        fileBytes: initialFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await audioFile.extractContainersAndDecode();

      // Verify initial genre
      final initialGenre = audioFile.getTag(TagKey.genre) as GenreTag?;
      expect(initialGenre?.value, equals(['Blues']));

      // Change genre to multi-value
      audioFile.setTag(GenreTag(const ['Blues', 'RNB']));

      // Encode the file
      final encodedFile = await audioFile.encode();

      // Create a new instance from the encoded file to verify
      final verifyFile = PhonicAudioFileImpl(
        fileBytes: encodedFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await verifyFile.extractContainersAndDecode();

      // Verify the genre is correctly updated
      final finalGenre = verifyFile.getTag(TagKey.genre) as GenreTag?;
      expect(finalGenre, isNotNull);

      // The genre should be exactly ['Blues', 'RNB'], NOT ['Blues', 'RNB', 'Blues']
      expect(finalGenre!.value, equals(['Blues', 'RNB']), reason: 'Genre should not contain duplicates from ID3v1');
      expect(finalGenre.value.length, equals(2), reason: 'Should have exactly 2 genres, not more');
    });

    test('should handle comma-delimited genre strings correctly', () async {
      // Create initial MP3 file
      final initialFile = _createMp3WithGenre('Blues');

      final audioFile = PhonicAudioFileImpl(
        fileBytes: initialFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await audioFile.extractContainersAndDecode();

      // Set genre using fromString which parses comma delimiter
      audioFile.setTag(GenreTag.fromString('Blues, RNB'));

      // Encode and verify
      final encodedFile = await audioFile.encode();
      final verifyFile = PhonicAudioFileImpl(
        fileBytes: encodedFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await verifyFile.extractContainersAndDecode();

      final finalGenre = verifyFile.getTag(TagKey.genre) as GenreTag?;
      expect(finalGenre?.value, equals(['Blues', 'RNB']));
    });

    test('ID3v1 should only store first genre from multi-genre tag', () async {
      final initialFile = _createMp3WithGenre('Rock');

      final audioFile = PhonicAudioFileImpl(
        fileBytes: initialFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await audioFile.extractContainersAndDecode();

      // Set multi-genre tag
      audioFile.setTag(GenreTag(const ['Electronic', 'Ambient', 'Techno']));

      final encodedFile = await audioFile.encode();

      // Extract and check ID3v1 directly
      final id3v1Locator = Id3v1Locator();
      final id3v1Bytes = id3v1Locator.extract(encodedFile);
      expect(id3v1Bytes, isNotNull);

      final id3v1Codec = const Id3v1Codec();
      final id3v1Tags = id3v1Codec.readFromContainer(id3v1Bytes!);
      final id3v1Genre = id3v1Tags.whereType<GenreTag>().firstOrNull;

      // ID3v1 should only have the first genre
      expect(id3v1Genre?.value, equals(['Electronic']), reason: 'ID3v1 should only store first genre from multi-genre tag');

      // But the merged result should have all genres from ID3v2
      final verifyFile = PhonicAudioFileImpl(
        fileBytes: encodedFile,
        formatStrategy: const Mp3FormatStrategy(),
        codecRegistry: codecRegistry,
        mergePolicy: MergePolicy.fromStrategy(const Mp3FormatStrategy()),
        validator: validator,
      );

      await verifyFile.extractContainersAndDecode();
      final mergedGenre = verifyFile.getTag(TagKey.genre) as GenreTag?;

      // After merge, should have all genres from ID3v2 (which has precedence)
      expect(mergedGenre?.value, equals(['Electronic', 'Ambient', 'Techno']), reason: 'Merged result should prioritize ID3v2 multi-genre');
    });
  });
}

/// Creates a minimal MP3 file with specified genre in both ID3v2.4 and ID3v1
Uint8List _createMp3WithGenre(String genre) {
  final bytes = Uint8List(1024);

  // Write ID3v2.4 header with genre frame
  int offset = 0;

  // ID3v2.4 header
  bytes[offset++] = 0x49; // 'I'
  bytes[offset++] = 0x44; // 'D'
  bytes[offset++] = 0x33; // '3'
  bytes[offset++] = 0x04; // Version 2.4
  bytes[offset++] = 0x00; // Revision 0
  bytes[offset++] = 0x00; // Flags

  // Size (synchsafe) - we'll write a simple TCON frame
  final frameData = _createTconFrame(genre);
  final tagSize = frameData.length;
  bytes[offset++] = (tagSize >> 21) & 0x7F;
  bytes[offset++] = (tagSize >> 14) & 0x7F;
  bytes[offset++] = (tagSize >> 7) & 0x7F;
  bytes[offset++] = tagSize & 0x7F;

  // Write frame data
  bytes.setRange(offset, offset + frameData.length, frameData);
  offset += frameData.length;

  // Fill with MP3 audio data (minimal)
  for (int i = offset; i < bytes.length - 128; i++) {
    bytes[i] = 0xFF;
  }

  // Write ID3v1 tag at the end
  offset = bytes.length - 128;
  bytes[offset++] = 0x54; // 'T'
  bytes[offset++] = 0x41; // 'A'
  bytes[offset++] = 0x47; // 'G'

  // Skip title, artist, album, year, comment (fill with spaces)
  for (int i = 0; i < 124; i++) {
    bytes[offset++] = 0x20;
  }

  // Write genre byte
  final genreCode = _getGenreCode(genre);
  bytes[offset] = genreCode;

  return bytes;
}

/// Creates a TCON (genre) frame for ID3v2.4
Uint8List _createTconFrame(String genre) {
  final genreBytes = genre.codeUnits;
  final frameSize = 1 + genreBytes.length; // encoding byte + text

  final frame = Uint8List(10 + frameSize);
  int offset = 0;

  // Frame ID: TCON
  frame[offset++] = 0x54; // 'T'
  frame[offset++] = 0x43; // 'C'
  frame[offset++] = 0x4F; // 'O'
  frame[offset++] = 0x4E; // 'N'

  // Size (synchsafe)
  frame[offset++] = (frameSize >> 21) & 0x7F;
  frame[offset++] = (frameSize >> 14) & 0x7F;
  frame[offset++] = (frameSize >> 7) & 0x7F;
  frame[offset++] = frameSize & 0x7F;

  // Flags
  frame[offset++] = 0x00;
  frame[offset++] = 0x00;

  // Encoding (ISO-8859-1)
  frame[offset++] = 0x00;

  // Genre text
  frame.setRange(offset, offset + genreBytes.length, genreBytes);

  return frame;
}

/// Simple genre code lookup for testing
int _getGenreCode(String genre) {
  const genreCodes = {
    'Blues': 0,
    'Rock': 17,
    'Electronic': 52,
  };
  return genreCodes[genre] ?? 255; // 255 = Unknown
}
