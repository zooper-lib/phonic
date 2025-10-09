import 'dart:typed_data';

import 'package:phonic/src/core/artwork_type.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/utils/mp4_atom_parser.dart';
import 'package:phonic/src/utils/mp4_standard_atom_parser.dart';
import 'package:test/test.dart';

import '../../helpers/mp4_atom_test_helpers.dart';

/// Helper to convert full atom bytes to Mp4Atom (header + data)
Mp4Atom _atomFromBytes(Uint8List fullAtom) {
  final view = ByteData.sublistView(fullAtom);
  final size = view.getUint32(0, Endian.big);
  final type = String.fromCharCodes(fullAtom.sublist(4, 8));

  return Mp4Atom(
    header: Mp4AtomHeader(
      size: size,
      type: type,
      offset: 0,
    ),
    data: fullAtom.sublist(8),
  );
}

void main() {
  group('Mp4StandardAtomParser', () {
    late TagProvenance provenance;

    setUp(() {
      provenance = const TagProvenance(
        ContainerKind.mp4,
        '',
        TagConfidence.certain,
      );
    });

    group('parseTextAtom', () {
      test('parses title atom correctly', () {
        final fullAtom = buildTextAtom('©nam', 'Test Song Title');
        final atom = _atomFromBytes(fullAtom);

        final result = Mp4StandardAtomParser.parseTextAtom(
          atom,
          TagKey.title,
          provenance,
        );

        expect(result, isA<TitleTag>());
        expect(result.value, equals('Test Song Title'));
        expect(result.provenance, equals(provenance));
      });

      test('parses genre atom with multiple genres', () {
        final fullAtom = buildTextAtom('©gen', 'Rock;Alternative;Indie');
        final atom = _atomFromBytes(fullAtom);

        final result = Mp4StandardAtomParser.parseTextAtom(
          atom,
          TagKey.genre,
          provenance,
        );

        expect(result, isA<GenreTag>());
        final genreTag = result as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('throws on malformed atom data', () {
        final atomData = Uint8List.fromList([0x00, 0x00]); // Too short

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: atomData.length + 8,
            type: '©nam',
            offset: 100,
          ),
          data: atomData,
        );

        expect(
          () => Mp4StandardAtomParser.parseTextAtom(
            atom,
            TagKey.title,
            provenance,
          ),
          throwsA(isA<CorruptedContainerException>()),
        );
      });
    });

    group('parseTrackNumberAtom', () {
      test('parses track number correctly', () {
        final fullAtom = buildTrackNumberAtom(5);
        final atom = _atomFromBytes(fullAtom);

        final result = Mp4StandardAtomParser.parseTrackNumberAtom(
          atom,
          provenance,
        );

        expect(result, isA<TrackNumberTag>());
        expect(result.value, equals(5));
      });
    });

    group('parseArtworkAtom', () {
      test('parses JPEG artwork correctly', () {
        final jpegData = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
          ...List.filled(100, 0x42), // Dummy JPEG data
        ]);

        final fullAtom = buildArtworkAtom(jpegData);
        final atom = _atomFromBytes(fullAtom);

        final containerBytes = Uint8List.fromList([
          ...List.filled(50, 0x00), // Padding before atom
          ...fullAtom,
        ]);

        final result = Mp4StandardAtomParser.parseArtworkAtom(
          atom,
          provenance,
          containerBytes,
        );

        expect(result, isA<ArtworkTag>());
        final artworkTag = result;
        expect(artworkTag.value.mimeType, equals('image/jpeg'));
        expect(artworkTag.value.type, equals(ArtworkType.frontCover));
      });
    });

    group('parseStandardAtom', () {
      test('routes text atoms correctly', () {
        final fullAtom = buildTextAtom('©nam', 'Test Title');
        final atom = _atomFromBytes(fullAtom);

        final result = Mp4StandardAtomParser.parseStandardAtom(
          atom,
          provenance,
          Uint8List(0),
        );

        expect(result, isA<TitleTag>());
        expect(result!.value, equals('Test Title'));
      });

      test('returns null for unsupported atom types', () {
        final atomData = Uint8List.fromList([
          0x00,
          0x00,
          0x00,
          0x01,
          ...('Some data'.codeUnits),
        ]);

        final atom = Mp4Atom(
          header: Mp4AtomHeader(
            size: atomData.length + 8,
            type: 'UNKN', // Unknown atom type
            offset: 0,
          ),
          data: atomData,
        );

        final result = Mp4StandardAtomParser.parseStandardAtom(
          atom,
          provenance,
          Uint8List(0),
        );

        expect(result, isNull);
      });
    });
  });
}
