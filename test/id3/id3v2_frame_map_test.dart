import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/id3/id3v2_frame_map.dart';
import 'package:phonic/src/tag_key.dart';

void main() {
  group('Id3v2FrameMap', () {
    group('v24 mappings', () {
      test('should contain all expected frame mappings', () {
        final v24 = Id3v2FrameMap.v24;

        // Test core text frames
        expect(v24[TagKey.title], equals('TIT2'));
        expect(v24[TagKey.artist], equals('TPE1'));
        expect(v24[TagKey.album], equals('TALB'));
        expect(v24[TagKey.albumArtist], equals('TPE2'));
        expect(v24[TagKey.trackNumber], equals('TRCK'));
        expect(v24[TagKey.discNumber], equals('TPOS'));
        expect(v24[TagKey.genre], equals('TCON'));
        expect(v24[TagKey.grouping], equals('TIT1'));
        expect(v24[TagKey.composer], equals('TCOM'));
        expect(v24[TagKey.encoder], equals('TSSE'));
        expect(v24[TagKey.isrc], equals('TSRC'));
        expect(v24[TagKey.bpm], equals('TBPM'));
        expect(v24[TagKey.musicalKey], equals('TKEY'));

        // Test v2.4 specific frames
        expect(v24[TagKey.dateRecorded], equals('TDRC'));

        // Test special frames
        expect(v24[TagKey.comment], equals('COMM'));
        expect(v24[TagKey.lyrics], equals('USLT'));
        expect(v24[TagKey.artwork], equals('APIC'));
        expect(v24[TagKey.rating], equals('POPM'));
        expect(v24[TagKey.custom], equals('TXXX'));
      });

      test('should not contain year field (uses dateRecorded/TDRC instead)', () {
        expect(Id3v2FrameMap.v24.containsKey(TagKey.year), isFalse);
      });

      test('should have expected number of mappings', () {
        // v2.4 should support most fields except year (which uses dateRecorded)
        expect(Id3v2FrameMap.v24.length, equals(19));
      });
    });

    group('v23 mappings', () {
      test('should contain all expected frame mappings', () {
        final v23 = Id3v2FrameMap.v23;

        // Test core text frames (same as v2.4)
        expect(v23[TagKey.title], equals('TIT2'));
        expect(v23[TagKey.artist], equals('TPE1'));
        expect(v23[TagKey.album], equals('TALB'));
        expect(v23[TagKey.albumArtist], equals('TPE2'));
        expect(v23[TagKey.trackNumber], equals('TRCK'));
        expect(v23[TagKey.discNumber], equals('TPOS'));
        expect(v23[TagKey.genre], equals('TCON'));
        expect(v23[TagKey.grouping], equals('TIT1'));
        expect(v23[TagKey.composer], equals('TCOM'));
        expect(v23[TagKey.encoder], equals('TSSE'));
        expect(v23[TagKey.isrc], equals('TSRC'));
        expect(v23[TagKey.bpm], equals('TBPM'));
        expect(v23[TagKey.musicalKey], equals('TKEY'));

        // Test v2.3 specific frames
        expect(v23[TagKey.year], equals('TYER'));

        // Test special frames
        expect(v23[TagKey.comment], equals('COMM'));
        expect(v23[TagKey.lyrics], equals('USLT'));
        expect(v23[TagKey.artwork], equals('APIC'));
        expect(v23[TagKey.rating], equals('POPM'));
        expect(v23[TagKey.custom], equals('TXXX'));
      });

      test('should not contain dateRecorded field (uses year/TYER instead)', () {
        expect(Id3v2FrameMap.v23.containsKey(TagKey.dateRecorded), isFalse);
      });

      test('should have expected number of mappings', () {
        // v2.3 should support most fields except dateRecorded (which uses year)
        expect(Id3v2FrameMap.v23.length, equals(19));
      });
    });

    group('v22 mappings', () {
      test('should contain all supported 3-character frame mappings', () {
        final v22 = Id3v2FrameMap.v22;

        // Test core text frames (3-character IDs)
        expect(v22[TagKey.title], equals('TT2'));
        expect(v22[TagKey.artist], equals('TP1'));
        expect(v22[TagKey.album], equals('TAL'));
        expect(v22[TagKey.albumArtist], equals('TP2'));
        expect(v22[TagKey.trackNumber], equals('TRK'));
        expect(v22[TagKey.year], equals('TYE'));
        expect(v22[TagKey.genre], equals('TCO'));
        expect(v22[TagKey.grouping], equals('TT1'));
        expect(v22[TagKey.composer], equals('TCM'));
        expect(v22[TagKey.encoder], equals('TSS'));
        expect(v22[TagKey.bpm], equals('TBP'));

        // Test special frames
        expect(v22[TagKey.comment], equals('COM'));
        expect(v22[TagKey.artwork], equals('PIC')); // PIC instead of APIC
        expect(v22[TagKey.custom], equals('TXX'));
      });

      test('should not contain unsupported fields', () {
        final v22 = Id3v2FrameMap.v22;

        // These fields are not supported in v2.2
        expect(v22.containsKey(TagKey.discNumber), isFalse);
        expect(v22.containsKey(TagKey.musicalKey), isFalse);
        expect(v22.containsKey(TagKey.rating), isFalse);
        expect(v22.containsKey(TagKey.lyrics), isFalse);
        expect(v22.containsKey(TagKey.isrc), isFalse);
        expect(v22.containsKey(TagKey.dateRecorded), isFalse);
      });

      test('should have expected number of mappings', () {
        // v2.2 has limited field support
        expect(Id3v2FrameMap.v22.length, equals(14));
      });

      test('all frame IDs should be 3 characters', () {
        for (final frameId in Id3v2FrameMap.v22.values) {
          expect(frameId.length, equals(3), reason: 'Frame ID "$frameId" should be 3 characters for v2.2');
        }
      });
    });

    group('getSupportedTags', () {
      test('should return correct tag sets for each version', () {
        final v22Tags = Id3v2FrameMap.getSupportedTags('2.2');
        final v23Tags = Id3v2FrameMap.getSupportedTags('2.3');
        final v24Tags = Id3v2FrameMap.getSupportedTags('2.4');

        // v2.2 should have fewer tags
        expect(v22Tags.length, lessThan(v23Tags.length));
        expect(v22Tags.length, lessThan(v24Tags.length));

        // v2.3 and v2.4 should have same number (different fields but same count)
        expect(v23Tags.length, equals(v24Tags.length));

        // Check specific version differences
        expect(v22Tags.contains(TagKey.rating), isFalse);
        expect(v23Tags.contains(TagKey.rating), isTrue);
        expect(v24Tags.contains(TagKey.rating), isTrue);

        expect(v22Tags.contains(TagKey.year), isTrue);
        expect(v23Tags.contains(TagKey.year), isTrue);
        expect(v24Tags.contains(TagKey.year), isFalse);

        expect(v22Tags.contains(TagKey.dateRecorded), isFalse);
        expect(v23Tags.contains(TagKey.dateRecorded), isFalse);
        expect(v24Tags.contains(TagKey.dateRecorded), isTrue);
      });

      test('should throw for unsupported version', () {
        expect(() => Id3v2FrameMap.getSupportedTags('2.1'), throwsA(isA<ArgumentError>()));
        expect(() => Id3v2FrameMap.getSupportedTags('3.0'), throwsA(isA<ArgumentError>()));
        expect(() => Id3v2FrameMap.getSupportedTags('invalid'), throwsA(isA<ArgumentError>()));
      });
    });

    group('getFrameId', () {
      test('should return correct frame IDs for supported tags', () {
        // Test across versions
        expect(Id3v2FrameMap.getFrameId(TagKey.title, '2.2'), equals('TT2'));
        expect(Id3v2FrameMap.getFrameId(TagKey.title, '2.3'), equals('TIT2'));
        expect(Id3v2FrameMap.getFrameId(TagKey.title, '2.4'), equals('TIT2'));

        expect(Id3v2FrameMap.getFrameId(TagKey.artist, '2.2'), equals('TP1'));
        expect(Id3v2FrameMap.getFrameId(TagKey.artist, '2.3'), equals('TPE1'));
        expect(Id3v2FrameMap.getFrameId(TagKey.artist, '2.4'), equals('TPE1'));

        // Test version-specific differences
        expect(Id3v2FrameMap.getFrameId(TagKey.year, '2.2'), equals('TYE'));
        expect(Id3v2FrameMap.getFrameId(TagKey.year, '2.3'), equals('TYER'));
        expect(Id3v2FrameMap.getFrameId(TagKey.year, '2.4'), isNull);

        expect(Id3v2FrameMap.getFrameId(TagKey.dateRecorded, '2.2'), isNull);
        expect(Id3v2FrameMap.getFrameId(TagKey.dateRecorded, '2.3'), isNull);
        expect(Id3v2FrameMap.getFrameId(TagKey.dateRecorded, '2.4'), equals('TDRC'));
      });

      test('should return null for unsupported tags', () {
        // v2.2 doesn't support rating
        expect(Id3v2FrameMap.getFrameId(TagKey.rating, '2.2'), isNull);

        // v2.2 doesn't support lyrics
        expect(Id3v2FrameMap.getFrameId(TagKey.lyrics, '2.2'), isNull);

        // v2.4 doesn't support year (uses dateRecorded)
        expect(Id3v2FrameMap.getFrameId(TagKey.year, '2.4'), isNull);
      });

      test('should throw for unsupported version', () {
        expect(() => Id3v2FrameMap.getFrameId(TagKey.title, '2.1'), throwsA(isA<ArgumentError>()));
        expect(() => Id3v2FrameMap.getFrameId(TagKey.title, 'invalid'), throwsA(isA<ArgumentError>()));
      });
    });

    group('getTagKey', () {
      test('should return correct tag keys for known frame IDs', () {
        // Test v2.4/v2.3 frame IDs
        expect(Id3v2FrameMap.getTagKey('TIT2'), equals(TagKey.title));
        expect(Id3v2FrameMap.getTagKey('TPE1'), equals(TagKey.artist));
        expect(Id3v2FrameMap.getTagKey('TALB'), equals(TagKey.album));
        expect(Id3v2FrameMap.getTagKey('TCON'), equals(TagKey.genre));
        expect(Id3v2FrameMap.getTagKey('POPM'), equals(TagKey.rating));
        expect(Id3v2FrameMap.getTagKey('APIC'), equals(TagKey.artwork));

        // Test v2.2 frame IDs
        expect(Id3v2FrameMap.getTagKey('TT2'), equals(TagKey.title));
        expect(Id3v2FrameMap.getTagKey('TP1'), equals(TagKey.artist));
        expect(Id3v2FrameMap.getTagKey('TAL'), equals(TagKey.album));
        expect(Id3v2FrameMap.getTagKey('TCO'), equals(TagKey.genre));
        expect(Id3v2FrameMap.getTagKey('PIC'), equals(TagKey.artwork));

        // Test version-specific frames
        expect(Id3v2FrameMap.getTagKey('TYER'), equals(TagKey.year));
        expect(Id3v2FrameMap.getTagKey('TYE'), equals(TagKey.year));
        expect(Id3v2FrameMap.getTagKey('TDRC'), equals(TagKey.dateRecorded));
      });

      test('should return null for unknown frame IDs', () {
        expect(Id3v2FrameMap.getTagKey('XXXX'), isNull);
        expect(Id3v2FrameMap.getTagKey('UNKN'), isNull);
        expect(Id3v2FrameMap.getTagKey(''), isNull);
        expect(Id3v2FrameMap.getTagKey('ABC'), isNull);
      });

      test('should handle case sensitivity', () {
        // Frame IDs should be case sensitive
        expect(Id3v2FrameMap.getTagKey('tit2'), isNull);
        expect(Id3v2FrameMap.getTagKey('TIT2'), equals(TagKey.title));
      });
    });

    group('mapping completeness', () {
      test('should have no duplicate frame IDs within each version', () {
        // Check v2.4
        final v24FrameIds = Id3v2FrameMap.v24.values.toList();
        final v24UniqueIds = v24FrameIds.toSet();
        expect(v24FrameIds.length, equals(v24UniqueIds.length), reason: 'v2.4 should have no duplicate frame IDs');

        // Check v2.3
        final v23FrameIds = Id3v2FrameMap.v23.values.toList();
        final v23UniqueIds = v23FrameIds.toSet();
        expect(v23FrameIds.length, equals(v23UniqueIds.length), reason: 'v2.3 should have no duplicate frame IDs');

        // Check v2.2
        final v22FrameIds = Id3v2FrameMap.v22.values.toList();
        final v22UniqueIds = v22FrameIds.toSet();
        expect(v22FrameIds.length, equals(v22UniqueIds.length), reason: 'v2.2 should have no duplicate frame IDs');
      });

      test('should have consistent mappings for common fields', () {
        // Fields that exist in all versions should map to equivalent frames
        final commonFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.albumArtist,
          TagKey.trackNumber,
          TagKey.genre,
          TagKey.comment,
          TagKey.grouping,
          TagKey.composer,
          TagKey.encoder,
          TagKey.custom,
        ];

        for (final field in commonFields) {
          expect(Id3v2FrameMap.v22.containsKey(field), isTrue, reason: '$field should be supported in v2.2');
          expect(Id3v2FrameMap.v23.containsKey(field), isTrue, reason: '$field should be supported in v2.3');
          expect(Id3v2FrameMap.v24.containsKey(field), isTrue, reason: '$field should be supported in v2.4');
        }
      });

      test('should have correct frame ID formats', () {
        // v2.4 and v2.3 should use 4-character IDs
        for (final frameId in Id3v2FrameMap.v24.values) {
          expect(frameId.length, equals(4), reason: 'v2.4 frame ID "$frameId" should be 4 characters');
          expect(frameId, matches(RegExp(r'^[A-Z0-9]{4}$')), reason: 'v2.4 frame ID "$frameId" should be uppercase alphanumeric');
        }

        for (final frameId in Id3v2FrameMap.v23.values) {
          expect(frameId.length, equals(4), reason: 'v2.3 frame ID "$frameId" should be 4 characters');
          expect(frameId, matches(RegExp(r'^[A-Z0-9]{4}$')), reason: 'v2.3 frame ID "$frameId" should be uppercase alphanumeric');
        }

        // v2.2 should use 3-character IDs
        for (final frameId in Id3v2FrameMap.v22.values) {
          expect(frameId.length, equals(3), reason: 'v2.2 frame ID "$frameId" should be 3 characters');
          expect(frameId, matches(RegExp(r'^[A-Z0-9]{3}$')), reason: 'v2.2 frame ID "$frameId" should be uppercase alphanumeric');
        }
      });
    });

    group('version evolution', () {
      test('should show proper evolution from v2.2 to v2.3/v2.4', () {
        // Common mappings that evolved from 3-char to 4-char
        final evolutionMappings = {
          TagKey.title: ['TT2', 'TIT2', 'TIT2'],
          TagKey.artist: ['TP1', 'TPE1', 'TPE1'],
          TagKey.album: ['TAL', 'TALB', 'TALB'],
          TagKey.albumArtist: ['TP2', 'TPE2', 'TPE2'],
          TagKey.trackNumber: ['TRK', 'TRCK', 'TRCK'],
          TagKey.genre: ['TCO', 'TCON', 'TCON'],
          TagKey.grouping: ['TT1', 'TIT1', 'TIT1'],
          TagKey.composer: ['TCM', 'TCOM', 'TCOM'],
          TagKey.encoder: ['TSS', 'TSSE', 'TSSE'],
          TagKey.bpm: ['TBP', 'TBPM', 'TBPM'],
        };

        for (final entry in evolutionMappings.entries) {
          final tagKey = entry.key;
          final expectedIds = entry.value;

          expect(Id3v2FrameMap.v22[tagKey], equals(expectedIds[0]), reason: '$tagKey should map to ${expectedIds[0]} in v2.2');
          expect(Id3v2FrameMap.v23[tagKey], equals(expectedIds[1]), reason: '$tagKey should map to ${expectedIds[1]} in v2.3');
          expect(Id3v2FrameMap.v24[tagKey], equals(expectedIds[2]), reason: '$tagKey should map to ${expectedIds[2]} in v2.4');
        }
      });

      test('should handle date field evolution correctly', () {
        // v2.2 and v2.3 use year, v2.4 uses dateRecorded
        expect(Id3v2FrameMap.v22[TagKey.year], equals('TYE'));
        expect(Id3v2FrameMap.v23[TagKey.year], equals('TYER'));
        expect(Id3v2FrameMap.v24.containsKey(TagKey.year), isFalse);

        expect(Id3v2FrameMap.v22.containsKey(TagKey.dateRecorded), isFalse);
        expect(Id3v2FrameMap.v23.containsKey(TagKey.dateRecorded), isFalse);
        expect(Id3v2FrameMap.v24[TagKey.dateRecorded], equals('TDRC'));
      });

      test('should handle artwork field evolution correctly', () {
        // v2.2 uses PIC, v2.3/v2.4 use APIC
        expect(Id3v2FrameMap.v22[TagKey.artwork], equals('PIC'));
        expect(Id3v2FrameMap.v23[TagKey.artwork], equals('APIC'));
        expect(Id3v2FrameMap.v24[TagKey.artwork], equals('APIC'));
      });
    });
  });
}
