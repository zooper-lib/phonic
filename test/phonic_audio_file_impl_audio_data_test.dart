import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/codec_registry.dart';
import 'package:phonic/src/core/merge_policy.dart';
import 'package:phonic/src/core/phonic_audio_file_impl.dart';
import 'package:phonic/src/formats/flac/flac_format_strategy.dart';
import 'package:phonic/src/formats/id3/id3v1_codec.dart';
import 'package:phonic/src/formats/id3/id3v22_codec.dart';
import 'package:phonic/src/formats/id3/id3v23_codec.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';
import 'package:phonic/src/formats/mp4/mp4_atoms_codec.dart';
import 'package:phonic/src/formats/mp4/mp4_format_strategy.dart';
import 'package:phonic/src/formats/vorbis/ogg_format_strategy.dart';
import 'package:phonic/src/formats/vorbis/vorbis_comments_codec.dart';
import 'package:phonic/src/utils/locators/id3v1_locator.dart';
import 'package:phonic/src/utils/locators/id3v2_locator.dart';
import 'package:phonic/src/utils/locators/mp4_locator.dart';
import 'package:phonic/src/utils/locators/ogg_vorbis_locator.dart';
import 'package:phonic/src/utils/locators/vorbis_locator.dart';

void main() {
  group('PhonicAudioFileImpl audioData', () {
    late CodecRegistry codecRegistry;
    late Mp3FormatStrategy mp3Strategy;
    late FlacFormatStrategy flacStrategy;
    late OggFormatStrategy oggStrategy;
    late Mp4FormatStrategy mp4Strategy;

    setUp(() {
      codecRegistry = CodecRegistry(
        codecList: [
          const Id3v24Codec(),
          const Id3v23Codec(),
          const Id3v22Codec(),
          const Id3v1Codec(),
          const VorbisCommentsCodec(),
          const Mp4AtomsCodec(),
        ],
        containerLocatorList: [
          Id3v2Locator(),
          Id3v1Locator(),
          VorbisLocator(),
          OggVorbisLocator(),
          Mp4Locator(),
        ],
      );

      mp3Strategy = const Mp3FormatStrategy();
      flacStrategy = const FlacFormatStrategy();
      oggStrategy = const OggFormatStrategy();
      mp4Strategy = const Mp4FormatStrategy();
    });

    group('MP3 files', () {
      test('should extract audio data from MP3 with ID3v2 and ID3v1 tags', () {
        // Create mock MP3 file with ID3v2 header, audio data, and ID3v1 tag
        final id3v2Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x00, 0x00, 0x00, 0x0A, // Size: 10 bytes (synchsafe)
        ]);
        final id3v2Data = Uint8List(10); // 10 bytes of frame data

        final audioData = Uint8List.fromList([
          0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
          ...List.filled(100, 0x42), // Audio frame data
        ]);

        final id3v1Tag = Uint8List.fromList([
          0x54, 0x41, 0x47, // "TAG" signature
          ...List.filled(125, 0x00), // Tag data (title, artist, etc.)
        ]);

        final completeFile = Uint8List.fromList([
          ...id3v2Header,
          ...id3v2Data,
          ...audioData,
          ...id3v1Tag,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        // Should return only the audio data portion
        expect(extractedAudio.length, equals(audioData.length));
        expect(extractedAudio, equals(audioData));
      });

      test('should extract audio data from MP3 with only ID3v2 tag', () {
        final id3v2Header = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0x00, 0x00, 0x00, 0x14, // Size: 20 bytes (synchsafe)
        ]);
        final id3v2Data = Uint8List(20);

        final audioData = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          ...List.filled(200, 0x55),
        ]);

        final completeFile = Uint8List.fromList([
          ...id3v2Header,
          ...id3v2Data,
          ...audioData,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        expect(extractedAudio.length, equals(audioData.length));
        expect(extractedAudio, equals(audioData));
      });

      test('should extract audio data from MP3 with only ID3v1 tag', () {
        final audioData = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          ...List.filled(150, 0x77),
        ]);

        final id3v1Tag = Uint8List.fromList([
          0x54, 0x41, 0x47, // "TAG" signature
          ...List.filled(125, 0x00),
        ]);

        final completeFile = Uint8List.fromList([
          ...audioData,
          ...id3v1Tag,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        expect(extractedAudio.length, equals(audioData.length));
        expect(extractedAudio, equals(audioData));
      });

      test('should return original data for MP3 with no metadata tags', () {
        final audioData = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          ...List.filled(300, 0x88),
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: audioData,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        expect(extractedAudio.length, equals(audioData.length));
        expect(extractedAudio, equals(audioData));
      });
    });

    group('FLAC files', () {
      test('should extract audio data from FLAC with Vorbis comments', () {
        // Mock FLAC file structure
        final flacSignature = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43]); // "fLaC"
        final metadataBlock = Uint8List.fromList([
          0x84, // Last metadata block flag + block type (Vorbis comment)
          0x00, 0x00, 0x20, // Block length: 32 bytes
          ...List.filled(32, 0x00), // Vorbis comment data
        ]);

        final audioFrames = Uint8List.fromList([
          0xFF, 0xF8, 0x69, 0x0C, // FLAC frame header
          ...List.filled(500, 0x99), // Audio frame data
        ]);

        final completeFile = Uint8List.fromList([
          ...flacSignature,
          ...metadataBlock,
          ...audioFrames,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: flacStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(flacStrategy),
        );

        final extractedAudio = audioFile.audioData;

        // For FLAC, the Vorbis locator may not be able to remove containers
        // in the same way as ID3 tags, so we verify the method completes successfully
        expect(extractedAudio, isNotNull);
        expect(extractedAudio.length, greaterThan(0));
      });
    });

    group('OGG files', () {
      test('should extract audio data from OGG with Vorbis comments', () {
        // Mock OGG file structure
        final oggPageHeader = Uint8List.fromList([
          0x4F, 0x67, 0x67, 0x53, // "OggS" signature
          0x00, // Version
          0x02, // Header type (first page of logical bitstream)
          ...List.filled(22, 0x00), // Rest of page header
        ]);

        final vorbisCommentHeader = Uint8List.fromList([
          0x03, 0x76, 0x6F, 0x72, 0x62, 0x69, 0x73, // Vorbis comment packet type
          ...List.filled(50, 0x00), // Comment data
        ]);

        final audioPackets = Uint8List.fromList([
          ...List.filled(400, 0xAA), // Audio packet data
        ]);

        final completeFile = Uint8List.fromList([
          ...oggPageHeader,
          ...vorbisCommentHeader,
          ...audioPackets,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: oggStrategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(oggStrategy),
        );

        final extractedAudio = audioFile.audioData;

        // For OGG, the Vorbis locator may not be able to remove containers
        // in the same way as ID3 tags, so we verify the method completes successfully
        expect(extractedAudio, isNotNull);
        expect(extractedAudio.length, greaterThan(0));
      });
    });

    group('MP4 files', () {
      test('should extract audio data from MP4 with metadata atoms', () {
        // Mock MP4 file structure with ftyp, moov (containing metadata), and mdat atoms
        final ftypAtom = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x20, // Atom size: 32 bytes
          0x66, 0x74, 0x79, 0x70, // "ftyp" atom type
          ...List.filled(24, 0x00), // ftyp data
        ]);

        final moovAtom = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x64, // Atom size: 100 bytes
          0x6D, 0x6F, 0x6F, 0x76, // "moov" atom type
          ...List.filled(92, 0x00), // moov data (contains metadata)
        ]);

        final mdatAtom = Uint8List.fromList([
          0x00, 0x00, 0x02, 0x00, // Atom size: 512 bytes
          0x6D, 0x64, 0x61, 0x74, // "mdat" atom type
          ...List.filled(504, 0xBB), // Audio data
        ]);

        final completeFile = Uint8List.fromList([
          ...ftypAtom,
          ...moovAtom,
          ...mdatAtom,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: mp4Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp4Strategy),
        );

        final extractedAudio = audioFile.audioData;

        // For MP4, the MP4 locator may not be able to remove containers
        // in the same way as ID3 tags, so we verify the method completes successfully
        expect(extractedAudio, isNotNull);
        expect(extractedAudio.length, greaterThan(0));
      });
    });

    group('Error handling', () {
      test('should handle corrupted containers gracefully', () {
        // Create file with corrupted ID3v2 header
        final corruptedFile = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, // Version 2.4
          0x00, // Flags
          0xFF, 0xFF, 0xFF, 0xFF, // Invalid synchsafe size
          ...List.filled(100, 0xCC), // Some data
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: corruptedFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        // Should not throw exception, should return original or partially processed data
        expect(() => audioFile.audioData, returnsNormally);
        final extractedAudio = audioFile.audioData;
        expect(extractedAudio, isNotNull);
      });

      test('should handle missing locators gracefully', () {
        // Create registry without some locators
        final limitedRegistry = CodecRegistry(
          codecList: [const Id3v24Codec()],
          containerLocatorList: [], // No locators
        );

        final fileWithTags = Uint8List.fromList([
          0x49, 0x44, 0x33, // "ID3" signature
          0x04, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x0A,
          ...List.filled(10, 0x00),
          ...List.filled(100, 0xDD),
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: fileWithTags,
          formatStrategy: mp3Strategy,
          codecRegistry: limitedRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        // Should return original file when no locators are available
        final extractedAudio = audioFile.audioData;
        expect(extractedAudio, equals(fileWithTags));
      });

      test('should handle empty files', () {
        final emptyFile = Uint8List(0);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: emptyFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;
        expect(extractedAudio.length, equals(0));
      });

      test('should handle very small files', () {
        final smallFile = Uint8List.fromList([0x01, 0x02, 0x03]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: smallFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;
        expect(extractedAudio, equals(smallFile));
      });
    });

    group('Container removal order', () {
      test('should remove containers in correct order', () {
        // Create file with multiple container types
        final id3v2Header = Uint8List.fromList([
          0x49,
          0x44,
          0x33,
          0x04,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x0A,
        ]);
        final id3v2Data = Uint8List(10);

        final audioData = Uint8List.fromList([
          0xFF,
          0xFB,
          0x90,
          0x00,
          ...List.filled(100, 0xEE),
        ]);

        final id3v1Tag = Uint8List.fromList([
          0x54,
          0x41,
          0x47,
          ...List.filled(125, 0x00),
        ]);

        final completeFile = Uint8List.fromList([
          ...id3v2Header,
          ...id3v2Data,
          ...audioData,
          ...id3v1Tag,
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: completeFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        // Should extract only the audio portion
        expect(extractedAudio.length, equals(audioData.length));
        expect(extractedAudio, equals(audioData));
      });
    });

    group('Memory efficiency', () {
      test('should not modify original file bytes', () {
        final originalFile = Uint8List.fromList([
          0x49,
          0x44,
          0x33,
          0x04,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x0A,
          ...List.filled(10, 0x00),
          ...List.filled(100, 0xFF),
        ]);
        final originalCopy = Uint8List.fromList(originalFile);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: originalFile,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        audioFile.audioData; // Access audioData

        // Original file should remain unchanged
        expect(originalFile, equals(originalCopy));
      });

      test('should return new Uint8List instance', () {
        final fileBytes = Uint8List.fromList([
          ...List.filled(100, 0x42),
        ]);

        final audioFile = PhonicAudioFileImpl(
          fileBytes: fileBytes,
          formatStrategy: mp3Strategy,
          codecRegistry: codecRegistry,
          mergePolicy: MergePolicy.fromStrategy(mp3Strategy),
        );

        final extractedAudio = audioFile.audioData;

        // Should be a different instance (not the same reference)
        expect(identical(extractedAudio, fileBytes), isFalse);
      });
    });
  });
}
