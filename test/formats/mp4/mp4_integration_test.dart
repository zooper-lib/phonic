import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/formats/mp4/m4a_audio_file.dart';
import 'package:phonic/src/formats/mp4/mp4_audio_file.dart';
import 'package:test/test.dart';

void main() {
  group('MP4 Integration Test', () {
    test('Mp4AudioFile and M4aAudioFile are exported and accessible', () {
      // Create minimal test files
      final mp4Bytes = _createMinimalMp4File();
      final m4aBytes = _createMinimalM4aFile();

      // Verify both classes can be instantiated
      final mp4File = Mp4AudioFile.fromBytes(mp4Bytes);
      final m4aFile = M4aAudioFile.fromBytes(m4aBytes);

      expect(mp4File, isA<Mp4AudioFile>());
      expect(m4aFile, isA<M4aAudioFile>());

      // Verify they use the same format strategy
      expect(mp4File.formatStrategy.runtimeType, equals(m4aFile.formatStrategy.runtimeType));

      // Verify they use the same codec registry structure
      expect(mp4File.codecRegistry.findCodec(ContainerKind.mp4, ''), isNotNull);
      expect(m4aFile.codecRegistry.findCodec(ContainerKind.mp4, ''), isNotNull);
    });

    test('Both classes support the same tag operations', () {
      final mp4Bytes = _createMinimalMp4File();
      final m4aBytes = _createMinimalM4aFile();

      final mp4File = Mp4AudioFile.fromBytes(mp4Bytes);
      final m4aFile = M4aAudioFile.fromBytes(m4aBytes);

      // Test setting the same tags on both
      final titleTag = const TitleTag('Test Title');
      final genreTag = GenreTag(const ['Electronic', 'Ambient']);

      mp4File.setTag(titleTag);
      mp4File.setTag(genreTag);

      m4aFile.setTag(titleTag);
      m4aFile.setTag(genreTag);

      // Verify both handle tags identically
      expect(mp4File.getTag(TagKey.title), equals(titleTag));
      expect(m4aFile.getTag(TagKey.title), equals(titleTag));

      expect(mp4File.getTag(TagKey.genre), equals(genreTag));
      expect(m4aFile.getTag(TagKey.genre), equals(genreTag));

      // Verify both are marked dirty
      expect(mp4File.isDirty, isTrue);
      expect(m4aFile.isDirty, isTrue);
    });
  });
}

/// Creates a minimal MP4 file for testing.
Uint8List _createMinimalMp4File() {
  final buffer = <int>[];

  // ftyp atom with MP4 brand
  buffer.addAll([0x00, 0x00, 0x00, 0x14]); // size: 20
  buffer.addAll('ftyp'.codeUnits);
  buffer.addAll('mp41'.codeUnits); // major brand
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // minor version

  // Minimal moov atom
  buffer.addAll([0x00, 0x00, 0x00, 0x08]); // size: 8
  buffer.addAll('moov'.codeUnits);

  return Uint8List.fromList(buffer);
}

/// Creates a minimal M4A file for testing.
Uint8List _createMinimalM4aFile() {
  final buffer = <int>[];

  // ftyp atom with M4A brand
  buffer.addAll([0x00, 0x00, 0x00, 0x14]); // size: 20
  buffer.addAll('ftyp'.codeUnits);
  buffer.addAll('M4A '.codeUnits); // major brand
  buffer.addAll([0x00, 0x00, 0x00, 0x00]); // minor version

  // Minimal moov atom
  buffer.addAll([0x00, 0x00, 0x00, 0x08]); // size: 8
  buffer.addAll('moov'.codeUnits);

  return Uint8List.fromList(buffer);
}
