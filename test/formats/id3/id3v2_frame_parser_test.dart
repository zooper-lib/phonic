import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/text_encoding.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/formats/id3/id3v2_frame_parser.dart';

void main() {
  group('Id3v2FrameFlags', () {
    group('fromBytes', () {
      test('creates default flags for ID3v2.2', () {
        final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 2);

        expect(flags.tagAlterPreservation, isFalse);
        expect(flags.fileAlterPreservation, isFalse);
        expect(flags.readOnly, isFalse);
        expect(flags.groupingIdentity, isFalse);
        expect(flags.compression, isFalse);
        expect(flags.encryption, isFalse);
        expect(flags.unsynchronization, isFalse);
        expect(flags.dataLengthIndicator, isFalse);
        expect(flags.statusFlags, equals(0));
        expect(flags.formatFlags, equals(0));
      });

      test('parses ID3v2.3 flags correctly', () {
        // Status: tag alter (0x80), file alter (0x40), read only (0x20)
        // Format: compression (0x80), encryption (0x40), grouping (0x20)
        final flags = Id3v2FrameFlags.fromBytes(0xE0, 0xE0, 3);

        expect(flags.tagAlterPreservation, isTrue);
        expect(flags.fileAlterPreservation, isTrue);
        expect(flags.readOnly, isTrue);
        expect(flags.compression, isTrue);
        expect(flags.encryption, isTrue);
        expect(flags.groupingIdentity, isTrue);
        expect(flags.unsynchronization, isFalse);
        expect(flags.dataLengthIndicator, isFalse);
      });

      test('parses ID3v2.4 flags correctly', () {
        // Status: tag alter (0x40), file alter (0x20), read only (0x10)
        // Format: grouping (0x40), compression (0x08), encryption (0x04), unsync (0x02), data length (0x01)
        final flags = Id3v2FrameFlags.fromBytes(0x70, 0x4F, 4);

        expect(flags.tagAlterPreservation, isTrue);
        expect(flags.fileAlterPreservation, isTrue);
        expect(flags.readOnly, isTrue);
        expect(flags.groupingIdentity, isTrue);
        expect(flags.compression, isTrue);
        expect(flags.encryption, isTrue);
        expect(flags.unsynchronization, isTrue);
        expect(flags.dataLengthIndicator, isTrue);
      });

      test('throws on invalid ID3v2.3 status flags', () {
        expect(
          () => Id3v2FrameFlags.fromBytes(0x1F, 0x00, 3), // Reserved bits set
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on invalid ID3v2.4 status flags', () {
        expect(
          () => Id3v2FrameFlags.fromBytes(0x8F, 0x00, 4), // Reserved bits set
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on invalid ID3v2.4 format flags', () {
        expect(
          () => Id3v2FrameFlags.fromBytes(0x00, 0xB0, 4), // Reserved bits set
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on unsupported version', () {
        expect(
          () => Id3v2FrameFlags.fromBytes(0x00, 0x00, 5),
          throwsA(isA<FormatException>()),
        );
      });
    });

    test('hasFormatFlags returns correct value', () {
      final noFlags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      expect(noFlags.hasFormatFlags, isFalse);

      final withFlags = Id3v2FrameFlags.fromBytes(0x00, 0x0F, 4);
      expect(withFlags.hasFormatFlags, isTrue);
    });

    test('toString includes active flags', () {
      final flags = Id3v2FrameFlags.fromBytes(0x70, 0x4F, 4);
      final str = flags.toString();

      expect(str, contains('tag-alter'));
      expect(str, contains('file-alter'));
      expect(str, contains('read-only'));
      expect(str, contains('grouped'));
      expect(str, contains('compressed'));
      expect(str, contains('encrypted'));
      expect(str, contains('unsync'));
      expect(str, contains('data-length'));
    });

    test('equality works correctly', () {
      final flags1 = Id3v2FrameFlags.fromBytes(0x40, 0x08, 4);
      final flags2 = Id3v2FrameFlags.fromBytes(0x40, 0x08, 4);
      final flags3 = Id3v2FrameFlags.fromBytes(0x20, 0x08, 4);

      expect(flags1, equals(flags2));
      expect(flags1, isNot(equals(flags3)));
      expect(flags1.hashCode, equals(flags2.hashCode));
    });
  });

  group('Id3v2Frame', () {
    test('creates frame with correct properties', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 6,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(frame.id, equals('TIT2'));
      expect(frame.size, equals(6));
      expect(frame.flags, equals(flags));
      expect(frame.data, equals(data));
      expect(frame.majorVersion, equals(4));
    });

    test('calculates totalSize correctly for different versions', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame22 = Id3v2Frame(
        id: 'TT2',
        size: 5,
        flags: flags,
        data: data,
        majorVersion: 2,
      );
      expect(frame22.totalSize, equals(11)); // 6-byte header + 5 data

      final frame24 = Id3v2Frame(
        id: 'TIT2',
        size: 5,
        flags: flags,
        data: data,
        majorVersion: 4,
      );
      expect(frame24.totalSize, equals(15)); // 10-byte header + 5 data
    });

    test('identifies text frames correctly', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x00]);

      // ID3v2.2 text frames
      final textFrame22 = Id3v2Frame(
        id: 'TT2',
        size: 1,
        flags: flags,
        data: data,
        majorVersion: 2,
      );
      expect(textFrame22.isTextFrame, isTrue);

      final userTextFrame22 = Id3v2Frame(
        id: 'TXX',
        size: 1,
        flags: flags,
        data: data,
        majorVersion: 2,
      );
      expect(userTextFrame22.isTextFrame, isFalse);
      expect(userTextFrame22.isUserTextFrame, isTrue);

      // ID3v2.4 text frames
      final textFrame24 = Id3v2Frame(
        id: 'TIT2',
        size: 1,
        flags: flags,
        data: data,
        majorVersion: 4,
      );
      expect(textFrame24.isTextFrame, isTrue);

      final userTextFrame24 = Id3v2Frame(
        id: 'TXXX',
        size: 1,
        flags: flags,
        data: data,
        majorVersion: 4,
      );
      expect(userTextFrame24.isTextFrame, isFalse);
      expect(userTextFrame24.isUserTextFrame, isTrue);
    });

    test('identifies URL frames correctly', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x68, 0x74, 0x74, 0x70]);

      // ID3v2.2 URL frames
      final urlFrame22 = Id3v2Frame(
        id: 'WAR',
        size: 4,
        flags: flags,
        data: data,
        majorVersion: 2,
      );
      expect(urlFrame22.isUrlFrame, isTrue);

      final userUrlFrame22 = Id3v2Frame(
        id: 'WXX',
        size: 4,
        flags: flags,
        data: data,
        majorVersion: 2,
      );
      expect(userUrlFrame22.isUrlFrame, isFalse);
      expect(userUrlFrame22.isUserUrlFrame, isTrue);

      // ID3v2.4 URL frames
      final urlFrame24 = Id3v2Frame(
        id: 'WOAR',
        size: 4,
        flags: flags,
        data: data,
        majorVersion: 4,
      );
      expect(urlFrame24.isUrlFrame, isTrue);

      final userUrlFrame24 = Id3v2Frame(
        id: 'WXXX',
        size: 4,
        flags: flags,
        data: data,
        majorVersion: 4,
      );
      expect(userUrlFrame24.isUrlFrame, isFalse);
      expect(userUrlFrame24.isUserUrlFrame, isTrue);
    });

    test('equality works correctly', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame1 = Id3v2Frame(
        id: 'TIT2',
        size: 5,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final frame2 = Id3v2Frame(
        id: 'TIT2',
        size: 5,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final frame3 = Id3v2Frame(
        id: 'TPE1',
        size: 5,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(frame1, equals(frame2));
      expect(frame1, isNot(equals(frame3)));
      expect(frame1.hashCode, equals(frame2.hashCode));
    });
  });

  group('Id3v2TextFrameData', () {
    test('creates text frame data correctly', () {
      final textData = const Id3v2TextFrameData(
        text: 'Hello World',
        encoding: TextEncoding.utf8,
        encodingByte: 0x03,
      );

      expect(textData.text, equals('Hello World'));
      expect(textData.encoding, equals(TextEncoding.utf8));
      expect(textData.encodingByte, equals(0x03));
    });

    test('equality works correctly', () {
      final textData1 = const Id3v2TextFrameData(
        text: 'Hello',
        encoding: TextEncoding.utf8,
        encodingByte: 0x03,
      );

      final textData2 = const Id3v2TextFrameData(
        text: 'Hello',
        encoding: TextEncoding.utf8,
        encodingByte: 0x03,
      );

      final textData3 = const Id3v2TextFrameData(
        text: 'World',
        encoding: TextEncoding.utf8,
        encodingByte: 0x03,
      );

      expect(textData1, equals(textData2));
      expect(textData1, isNot(equals(textData3)));
      expect(textData1.hashCode, equals(textData2.hashCode));
    });
  });

  group('Id3v2FrameParser.parseFrame', () {
    test('parses ID3v2.2 frame correctly', () {
      final frameBytes = Uint8List.fromList([
        // Frame header (6 bytes)
        0x54, 0x54, 0x32, // "TT2"
        0x00, 0x00, 0x06, // Size: 6 bytes (24-bit)
        // Frame data
        0x00, // ISO-8859-1 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 2);

      expect(frame.id, equals('TT2'));
      expect(frame.size, equals(6));
      expect(frame.majorVersion, equals(2));
      expect(frame.flags.statusFlags, equals(0));
      expect(frame.flags.formatFlags, equals(0));
      expect(frame.data.length, equals(6));
      expect(frame.totalSize, equals(12));
    });

    test('parses ID3v2.3 frame correctly', () {
      final frameBytes = Uint8List.fromList([
        // Frame header (10 bytes)
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x06, // Size: 6 bytes (regular integer)
        0x00, 0x00, // No flags
        // Frame data
        0x00, // ISO-8859-1 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 3);

      expect(frame.id, equals('TIT2'));
      expect(frame.size, equals(6));
      expect(frame.majorVersion, equals(3));
      expect(frame.flags.statusFlags, equals(0));
      expect(frame.flags.formatFlags, equals(0));
      expect(frame.data.length, equals(6));
      expect(frame.totalSize, equals(16));
    });

    test('parses ID3v2.4 frame correctly', () {
      final frameBytes = Uint8List.fromList([
        // Frame header (10 bytes)
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x06, // Size: 6 bytes (synchsafe)
        0x00, 0x00, // No flags
        // Frame data
        0x03, // UTF-8 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 4);

      expect(frame.id, equals('TIT2'));
      expect(frame.size, equals(6));
      expect(frame.majorVersion, equals(4));
      expect(frame.flags.statusFlags, equals(0));
      expect(frame.flags.formatFlags, equals(0));
      expect(frame.data.length, equals(6));
      expect(frame.totalSize, equals(16));
    });

    test('parses frame with flags correctly', () {
      final frameBytes = Uint8List.fromList([
        // Frame header (10 bytes)
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x06, // Size: 6 bytes
        0x40, 0x08, // Flags: tag alter preservation + compression
        // Frame data
        0x03, // UTF-8 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 4);

      expect(frame.flags.tagAlterPreservation, isTrue);
      expect(frame.flags.compression, isTrue);
      expect(frame.flags.fileAlterPreservation, isFalse);
      expect(frame.flags.encryption, isFalse);
    });

    test('throws on insufficient bytes for header', () {
      final shortBytes = Uint8List.fromList([0x54, 0x49, 0x54]); // Only 3 bytes

      expect(
        () => Id3v2FrameParser.parseFrame(shortBytes, 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on invalid frame ID', () {
      final frameBytes = Uint8List.fromList([
        // Invalid frame ID with lowercase
        0x74, 0x69, 0x74, 0x32, // "tit2"
        0x00, 0x00, 0x00, 0x06, // Size: 6 bytes
        0x00, 0x00, // No flags
        0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F,
      ]);

      expect(
        () => Id3v2FrameParser.parseFrame(frameBytes, 4),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('throws on insufficient bytes for frame data', () {
      final frameBytes = Uint8List.fromList([
        // Frame header claims 10 bytes but only 5 provided
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x0A, // Size: 10 bytes
        0x00, 0x00, // No flags
        0x03, 0x48, 0x65, 0x6C, 0x6C, // Only 5 bytes
      ]);

      expect(
        () => Id3v2FrameParser.parseFrame(frameBytes, 4),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('handles frame at offset correctly', () {
      final frameBytes = Uint8List.fromList([
        // Padding bytes
        0xFF, 0xFF, 0xFF,
        // Frame header (10 bytes)
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x00, 0x00, 0x00, 0x06, // Size: 6 bytes
        0x00, 0x00, // No flags
        // Frame data
        0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F,
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 4, 3);

      expect(frame.id, equals('TIT2'));
      expect(frame.size, equals(6));
      expect(frame.data.length, equals(6));
    });
  });

  group('Id3v2FrameParser.parseTextFrameData', () {
    test('parses ISO-8859-1 text correctly', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
      expect(textData.encoding, equals(TextEncoding.iso88591));
      expect(textData.encodingByte, equals(0x00));
    });

    test('parses UTF-16 text correctly', () {
      final frameData = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding
        0xFF, 0xFE, // UTF-16 LE BOM
        0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, // "Hello" in UTF-16 LE
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
      expect(textData.encoding, equals(TextEncoding.utf16));
      expect(textData.encodingByte, equals(0x01));
    });

    test('parses UTF-16BE text correctly (ID3v2.4 only)', () {
      final frameData = Uint8List.fromList([
        0x02, // UTF-16BE encoding
        0x00, 0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, // "Hello" in UTF-16 BE
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
      expect(textData.encoding, equals(TextEncoding.utf16be));
      expect(textData.encodingByte, equals(0x02));
    });

    test('parses UTF-8 text correctly (ID3v2.4 only)', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, // "Hello"
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
      expect(textData.encoding, equals(TextEncoding.utf8));
      expect(textData.encodingByte, equals(0x03));
    });

    test('removes single null terminators from ISO-8859-1 text', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, // "Hello" with single null terminator
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
    });

    test('removes multiple null terminators from ISO-8859-1 text', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x00, 0x00, // "Hello" with multiple null terminators
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
    });

    test('removes double null terminators from UTF-16 text', () {
      final frameData = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding
        0xFF, 0xFE, // UTF-16 LE BOM
        0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, // "Hello" in UTF-16 LE
        0x00, 0x00, // UTF-16 null terminator
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
    });

    test('removes multiple double null terminators from UTF-16 text', () {
      final frameData = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding
        0xFF, 0xFE, // UTF-16 LE BOM
        0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, // "Hello" in UTF-16 LE
        0x00, 0x00, 0x00, 0x00, // Multiple UTF-16 null terminators
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
    });

    test('handles UTF-8 with Unicode characters and null terminators', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, // "Hello "
        0xF0, 0x9F, 0x8C, 0x8D, // 🌍 (Earth emoji in UTF-8)
        0x00, // Null terminator
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello 🌍'));
    });

    test('handles UTF-16BE without BOM and null terminators', () {
      final frameData = Uint8List.fromList([
        0x02, // UTF-16BE encoding
        0x00, 0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, // "Hello" in UTF-16 BE
        0x00, 0x00, // UTF-16 null terminator
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals('Hello'));
    });

    test('handles empty text with only encoding byte', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        // No text data
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals(''));
      expect(textData.encoding, equals(TextEncoding.iso88591));
    });

    test('handles text with only null terminators', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x00, 0x00, 0x00, // Only null bytes
      ]);

      final textData = Id3v2FrameParser.parseTextFrameData(frameData, 4);

      expect(textData.text, equals(''));
    });

    test('throws on empty frame data', () {
      final frameData = Uint8List.fromList([]);

      expect(
        () => Id3v2FrameParser.parseTextFrameData(frameData, 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on invalid encoding for ID3v2.3', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding (not supported in v2.3)
        0x48, 0x65, 0x6C, 0x6C, 0x6F,
      ]);

      expect(
        () => Id3v2FrameParser.parseTextFrameData(frameData, 3),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on invalid encoding byte', () {
      final frameData = Uint8List.fromList([
        0xFF, // Invalid encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F,
      ]);

      expect(
        () => Id3v2FrameParser.parseTextFrameData(frameData, 4),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Id3v2FrameParser.extractFrameData', () {
    test('returns data unchanged when no format flags are set', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x00, 4);
      final data = Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 6,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(data));
    });

    test('skips data length indicator when flag is set', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x01, 4); // Data length indicator
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x06, // Data length indicator (4 bytes)
        0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F, // Actual data
      ]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 10,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F])));
    });

    test('removes unsynchronization when flag is set', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x02, 4); // Unsynchronization
      final data = Uint8List.fromList([
        0x03, 0x48, 0xFF, 0x00, 0x65, 0x6C, 0x6C, 0x6F, // Data with unsync pattern
      ]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 8,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(Uint8List.fromList([0x03, 0x48, 0xFF, 0x65, 0x6C, 0x6C, 0x6F])));
    });

    test('skips group identifier when flag is set', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x40, 4); // Grouping identity
      final data = Uint8List.fromList([
        0x01, // Group identifier
        0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F, // Actual data
      ]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 7,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F])));
    });

    test('throws on compression flag', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x08, 4); // Compression
      final data = Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 6,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(
        () => Id3v2FrameParser.extractFrameData(frame),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('throws on encryption flag', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x04, 4); // Encryption
      final data = Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 6,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(
        () => Id3v2FrameParser.extractFrameData(frame),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('throws when data length indicator flag set but insufficient bytes', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x01, 4); // Data length indicator
      final data = Uint8List.fromList([0x03, 0x48]); // Only 2 bytes, need 4 for length indicator

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 2,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(
        () => Id3v2FrameParser.extractFrameData(frame),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('throws when grouping flag set but no data', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x40, 4); // Grouping identity
      final data = Uint8List.fromList([]); // Empty data

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 0,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      expect(
        () => Id3v2FrameParser.extractFrameData(frame),
        throwsA(isA<CorruptedContainerException>()),
      );
    });
  });

  group('Id3v2FrameParser.detectFrameTextEncoding', () {
    test('detects ISO-8859-1 encoding', () {
      final frameData = Uint8List.fromList([0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      final encoding = Id3v2FrameParser.detectFrameTextEncoding(frameData, 4);
      expect(encoding, equals(TextEncoding.iso88591));
    });

    test('detects UTF-16 encoding', () {
      final frameData = Uint8List.fromList([0x01, 0xFF, 0xFE, 0x48, 0x00]);
      final encoding = Id3v2FrameParser.detectFrameTextEncoding(frameData, 4);
      expect(encoding, equals(TextEncoding.utf16));
    });

    test('detects UTF-16BE encoding (ID3v2.4 only)', () {
      final frameData = Uint8List.fromList([0x02, 0x00, 0x48]);
      final encoding = Id3v2FrameParser.detectFrameTextEncoding(frameData, 4);
      expect(encoding, equals(TextEncoding.utf16be));
    });

    test('detects UTF-8 encoding (ID3v2.4 only)', () {
      final frameData = Uint8List.fromList([0x03, 0x48, 0x65, 0x6C, 0x6C, 0x6F]);
      final encoding = Id3v2FrameParser.detectFrameTextEncoding(frameData, 4);
      expect(encoding, equals(TextEncoding.utf8));
    });

    test('throws on empty frame data', () {
      final frameData = Uint8List.fromList([]);
      expect(
        () => Id3v2FrameParser.detectFrameTextEncoding(frameData, 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on UTF-16BE in ID3v2.3', () {
      final frameData = Uint8List.fromList([0x02, 0x00, 0x48]);
      expect(
        () => Id3v2FrameParser.detectFrameTextEncoding(frameData, 3),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on UTF-8 in ID3v2.3', () {
      final frameData = Uint8List.fromList([0x03, 0x48, 0x65]);
      expect(
        () => Id3v2FrameParser.detectFrameTextEncoding(frameData, 3),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on invalid encoding byte', () {
      final frameData = Uint8List.fromList([0xFF, 0x48, 0x65]);
      expect(
        () => Id3v2FrameParser.detectFrameTextEncoding(frameData, 4),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Id3v2FrameParser.parseStandardTextFrame', () {
    test('parses TIT2 frame correctly', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x4D, 0x79, 0x20, 0x53, 0x6F, 0x6E, 0x67, // "My Song"
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('My Song'));
    });

    test('parses TPE1 frame with null terminators', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x41, 0x72, 0x74, 0x69, 0x73, 0x74, 0x00, // "Artist" with null terminator
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('Artist'));
    });

    test('parses TALB frame with UTF-16', () {
      final frameData = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding
        0xFF, 0xFE, // UTF-16 LE BOM
        0x41, 0x00, 0x6C, 0x00, 0x62, 0x00, 0x75, 0x00, 0x6D, 0x00, // "Album" in UTF-16 LE
        0x00, 0x00, // UTF-16 null terminator
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('Album'));
    });

    test('handles empty frame gracefully', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        // No text data
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals(''));
    });
  });

  group('Id3v2FrameParser.parseMultiValueTextFrame', () {
    test('parses single value in ISO-8859-1', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x52, 0x6F, 0x63, 0x6B, // "Rock"
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock']));
    });

    test('parses multiple values separated by null in ISO-8859-1', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x52, 0x6F, 0x63, 0x6B, 0x00, // "Rock" + null
        0x50, 0x6F, 0x70, 0x00, // "Pop" + null
        0x4A, 0x61, 0x7A, 0x7A, // "Jazz"
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock', 'Pop', 'Jazz']));
    });

    test('parses multiple values in UTF-8', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x52, 0x6F, 0x63, 0x6B, 0x00, // "Rock" + null
        0x41, 0x6C, 0x74, 0x65, 0x72, 0x6E, 0x61, 0x74, 0x69, 0x76, 0x65, 0x00, // "Alternative" + null
        0x49, 0x6E, 0x64, 0x69, 0x65, // "Indie"
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock', 'Alternative', 'Indie']));
    });

    test('parses multiple values in UTF-16BE without BOM', () {
      final frameData = Uint8List.fromList([
        0x02, // UTF-16BE encoding (no BOM)
        0x00, 0x52, 0x00, 0x6F, 0x00, 0x63, 0x00, 0x6B, // "Rock" in UTF-16 BE (8 bytes)
        0x00, 0x00, // UTF-16 null separator (2 bytes)
        0x00, 0x50, 0x00, 0x6F, 0x00, 0x70, // "Pop" in UTF-16 BE (6 bytes)
        0x00, 0x00, // UTF-16 null separator (2 bytes)
        0x00, 0x4A, 0x00, 0x61, 0x00, 0x7A, 0x00, 0x7A, // "Jazz" in UTF-16 BE (8 bytes)
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock', 'Pop', 'Jazz']));
    });

    test('parses multiple values in UTF-16BE', () {
      final frameData = Uint8List.fromList([
        0x02, // UTF-16BE encoding
        0x00, 0x52, 0x00, 0x6F, 0x00, 0x63, 0x00, 0x6B, // "Rock" in UTF-16 BE
        0x00, 0x00, // UTF-16 null separator
        0x00, 0x50, 0x00, 0x6F, 0x00, 0x70, // "Pop" in UTF-16 BE
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock', 'Pop']));
    });

    test('handles empty segments gracefully', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x52, 0x6F, 0x63, 0x6B, 0x00, // "Rock" + null
        0x00, // Empty segment (double null)
        0x50, 0x6F, 0x70, // "Pop"
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals(['Rock', 'Pop']));
    });

    test('handles frame with only null terminators', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x00, 0x00, 0x00, // Only null bytes
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals([]));
    });

    test('handles empty frame data', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        // No text data
      ]);

      final values = Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4);

      expect(values, equals([]));
    });

    test('throws on empty frame data', () {
      final frameData = Uint8List.fromList([]);

      expect(
        () => Id3v2FrameParser.parseMultiValueTextFrame(frameData, 4),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on invalid encoding for version', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding (not supported in v2.3)
        0x52, 0x6F, 0x63, 0x6B,
      ]);

      expect(
        () => Id3v2FrameParser.parseMultiValueTextFrame(frameData, 3),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Text frame parsing with various encodings', () {
    test('handles Latin-1 extended characters', () {
      final frameData = Uint8List.fromList([
        0x00, // ISO-8859-1 encoding
        0x43, 0x61, 0x66, 0xE9, // "Café" (é = 0xE9 in Latin-1)
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('Café'));
    });

    test('handles UTF-8 with multibyte characters', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, // "Hello "
        0xE4, 0xB8, 0x96, 0xE7, 0x95, 0x8C, // "世界" (World in Chinese)
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('Hello 世界'));
    });

    test('handles UTF-16 with surrogate pairs', () {
      final frameData = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding
        0xFF, 0xFE, // UTF-16 LE BOM
        0x3C, 0xD8, 0x0D, 0xDF, // 🌍 (Earth emoji as UTF-16 LE surrogate pair)
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('🌍'));
    });

    test('handles mixed content with special characters in UTF-8', () {
      final frameData = Uint8List.fromList([
        0x03, // UTF-8 encoding
        0x52, 0x6F, 0x63, 0x6B, 0x20, 0x26, 0x20, // "Rock & "
        0x52, 0x6F, 0x6C, 0x6C, 0x21, // "Roll!"
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameData, 4);

      expect(text, equals('Rock & Roll!'));
    });

    test('handles version-specific encoding restrictions', () {
      // ID3v2.3 should only support encodings 0x00 and 0x01
      final frameDataV23 = Uint8List.fromList([
        0x01, // UTF-16 with BOM encoding (supported in v2.3)
        0xFF, 0xFE, // UTF-16 LE BOM
        0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, // "Hello"
      ]);

      final text = Id3v2FrameParser.parseStandardTextFrame(frameDataV23, 3);
      expect(text, equals('Hello'));

      // ID3v2.2 should also support the same encodings
      final textV22 = Id3v2FrameParser.parseStandardTextFrame(frameDataV23, 2);
      expect(textV22, equals('Hello'));
    });
  });

  group('Edge cases and error handling', () {
    test('handles maximum frame size correctly', () {
      // Create a frame with maximum synchsafe size (0x0FFFFFFF)
      final frameBytes = Uint8List.fromList([
        0x54, 0x49, 0x54, 0x32, // "TIT2"
        0x7F, 0x7F, 0x7F, 0x7F, // Maximum synchsafe size
        0x00, 0x00, // No flags
        // Note: We can't actually create 268MB of data for testing,
        // so this will fail on insufficient bytes, which is expected
      ]);

      expect(
        () => Id3v2FrameParser.parseFrame(frameBytes, 4),
        throwsA(isA<CorruptedContainerException>()),
      );
    });

    test('handles frame ID with numbers correctly', () {
      final frameBytes = Uint8List.fromList([
        0x54, 0x58, 0x58, 0x58, // "TXXX"
        0x00, 0x00, 0x00, 0x05, // Size: 5 bytes
        0x00, 0x00, // No flags
        0x00, 0x48, 0x65, 0x6C, 0x6C, // Data
      ]);

      final frame = Id3v2FrameParser.parseFrame(frameBytes, 4);
      expect(frame.id, equals('TXXX'));
    });

    test('handles complex unsynchronization patterns', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x02, 4); // Unsynchronization
      final data = Uint8List.fromList([
        0xFF, 0x00, 0xFF, 0x00, 0xFF, 0xE0, // Multiple unsync patterns
      ]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 6,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xE0])));
    });

    test('handles multiple format flags together', () {
      final flags = Id3v2FrameFlags.fromBytes(0x00, 0x43, 4); // Data length + grouping + unsync
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x08, // Data length indicator
        0x01, // Group identifier
        0xFF, 0x00, 0x48, 0x65, 0x6C, 0x6C, 0x6F, // Data with unsync
      ]);

      final frame = Id3v2Frame(
        id: 'TIT2',
        size: 12,
        flags: flags,
        data: data,
        majorVersion: 4,
      );

      final extractedData = Id3v2FrameParser.extractFrameData(frame);
      expect(extractedData, equals(Uint8List.fromList([0xFF, 0x48, 0x65, 0x6C, 0x6C, 0x6F])));
    });
  });
}
