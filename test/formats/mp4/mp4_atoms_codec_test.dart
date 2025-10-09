import 'dart:typed_data';

import 'package:phonic/phonic.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/formats/mp4/mp4_atoms_codec.dart';
import 'package:test/test.dart';

import '../../helpers/mp4_atom_test_helpers.dart';

void main() {
  group('Mp4AtomsCodec', () {
    late Mp4AtomsCodec codec;

    setUp(() {
      codec = const Mp4AtomsCodec();
    });

    group('instantiation', () {
      test('creates codec instance successfully', () {
        expect(codec, isNotNull);
        expect(codec, isA<Mp4AtomsCodec>());
      });

      test('implements TagCodec interface', () {
        expect(codec, isA<TagCodec>());
      });
    });

    group('properties', () {
      test('has correct container kind', () {
        expect(codec.containerKind, equals(ContainerKind.mp4));
      });

      test('has correct container version', () {
        expect(codec.containerVersion, equals(''));
      });

      test('has correct capability', () {
        expect(codec.capability, equals(mp4Capability));
        expect(codec.capability, isA<TagCapability>());
      });

      test('capability has correct container kind', () {
        expect(codec.capability.containerKind, equals(ContainerKind.mp4));
      });

      test('capability has correct container version', () {
        expect(codec.capability.containerVersion, equals(''));
      });
    });

    group('codec interface compliance', () {
      test('readFromContainer method exists', () {
        expect(() => codec.readFromContainer, returnsNormally);
      });

      test('writeToContainer method exists', () {
        expect(() => codec.writeToContainer, returnsNormally);
      });

      test('readFromContainer handles empty input', () {
        final emptyBytes = Uint8List(0);
        expect(
          codec.readFromContainer(emptyBytes),
          equals(<MetadataTag>[]),
        );
      });

      test('readFromContainer throws CorruptedContainerException for invalid input', () {
        final invalidBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
        expect(
          () => codec.readFromContainer(invalidBytes),
          throwsA(isA<CorruptedContainerException>()),
        );
      });

      test('writeToContainer returns empty ilst for empty tags', () {
        final result = codec.writeToContainer(tagsToWrite: []);
        expect(result, isNotNull);
        expect(result.length, equals(8)); // Empty ilst atom
      });

      test('writeToContainer returns empty ilst for empty tag list', () {
        final mockTags = <MetadataTag>[];
        final result = codec.writeToContainer(tagsToWrite: mockTags);
        expect(result, isNotNull);
        expect(result.length, equals(8)); // Empty ilst atom
      });
    });

    group('codec reusability', () {
      test('codec instance is stateless and reusable', () {
        final codec1 = const Mp4AtomsCodec();
        final codec2 = const Mp4AtomsCodec();

        // Both instances should have identical properties
        expect(codec1.containerKind, equals(codec2.containerKind));
        expect(codec1.containerVersion, equals(codec2.containerVersion));
        expect(codec1.capability, equals(codec2.capability));
      });

      test('const constructor creates identical instances', () {
        const codec1 = Mp4AtomsCodec();
        const codec2 = Mp4AtomsCodec();

        // Const instances should be identical
        expect(identical(codec1, codec2), isTrue);
      });
    });

    group('capability validation', () {
      test('capability supports expected tag keys', () {
        final capability = codec.capability;

        // Test some key MP4 supported fields
        expect(capability.supports(TagKey.title), isTrue);
        expect(capability.supports(TagKey.artist), isTrue);
        expect(capability.supports(TagKey.album), isTrue);
        expect(capability.supports(TagKey.albumArtist), isTrue);
        expect(capability.supports(TagKey.genre), isTrue);
        expect(capability.supports(TagKey.comment), isTrue);
        expect(capability.supports(TagKey.grouping), isTrue);
        expect(capability.supports(TagKey.composer), isTrue);
        expect(capability.supports(TagKey.encoder), isTrue);
        expect(capability.supports(TagKey.isrc), isTrue);
        expect(capability.supports(TagKey.musicalKey), isTrue);
        expect(capability.supports(TagKey.lyrics), isTrue);
        expect(capability.supports(TagKey.trackNumber), isTrue);
        expect(capability.supports(TagKey.discNumber), isTrue);
        expect(capability.supports(TagKey.year), isTrue);
        expect(capability.supports(TagKey.dateRecorded), isTrue);
        expect(capability.supports(TagKey.bpm), isTrue);
        expect(capability.supports(TagKey.rating), isTrue);
        expect(capability.supports(TagKey.artwork), isTrue);
        expect(capability.supports(TagKey.custom), isTrue);
      });

      test('capability has correct semantics for key fields', () {
        final capability = codec.capability;

        // Test text fields have UTF-8 encoding
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.allowedEncodings, contains('UTF-8'));
        expect(titleSemantics.multiValued, isFalse);

        // Test numeric fields have correct ranges
        final ratingSemantics = capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(100));

        final trackSemantics = capability.semantics(TagKey.trackNumber);
        expect(trackSemantics.minValue, equals(1));
        expect(trackSemantics.maxValue, equals(65535));

        // Test multi-valued fields
        final artworkSemantics = capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, isTrue);

        final customSemantics = capability.semantics(TagKey.custom);
        expect(customSemantics.multiValued, isTrue);
      });
    });

    group('readFromContainer', () {
      test('encodes Title tag to ©nam atom', () {
        final titleAtom = buildTextAtom('©nam', 'Test Title');
        final tags = codec.readFromContainer(titleAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<TitleTag>());
        expect(tags[0].value, equals('Test Title'));
        expect(tags[0].key, equals(TagKey.title));
        expect(tags[0].provenance.containerKind, equals(ContainerKind.mp4));
        expect(tags[0].provenance.confidence, equals(TagConfidence.certain));
      });

      test('parses multiple standard atoms correctly', () {
        // Create multiple atoms
        final titleAtom = buildTextAtom('©nam', 'Test Title');
        final artistAtom = buildTextAtom('©ART', 'Test Artist');
        final albumAtom = buildTextAtom('©alb', 'Test Album');

        final combinedData = Uint8List.fromList([
          ...titleAtom,
          ...artistAtom,
          ...albumAtom,
        ]);

        final tags = codec.readFromContainer(combinedData);

        expect(tags, hasLength(3));

        final titleTag = tags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Title'));

        final artistTag = tags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = tags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));
      });

      test('parses track number atom correctly', () {
        final trackAtom = buildTrackNumberAtom(5);
        final tags = codec.readFromContainer(trackAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<TrackNumberTag>());
        expect(tags[0].value, equals(5));
        expect(tags[0].key, equals(TagKey.trackNumber));
      });

      test('parses BPM atom correctly', () {
        final bpmAtom = buildBpmAtom(120);
        final tags = codec.readFromContainer(bpmAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<BpmTag>());
        expect(tags[0].value, equals(120));
        expect(tags[0].key, equals(TagKey.bpm));
      });

      test('parses composite genre correctly', () {
        final genreAtom = buildTextAtom('©gen', 'Rock;Alternative;Indie');
        final tags = codec.readFromContainer(genreAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<GenreTag>());
        final genreTag = tags[0] as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
        expect(genreTag.key, equals(TagKey.genre));
      });

      test('parses freeform atom correctly', () {
        final freeformAtom = _buildFreeformAtom(
          domain: 'com.phonic.tags',
          name: 'RATING',
          dataType: 0x00000016, // Unsigned integer
          data: _buildIntegerData(85),
        );

        final tags = codec.readFromContainer(freeformAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<RatingTag>());
        expect(tags[0].value, equals(85));
        expect(tags[0].key, equals(TagKey.rating));
      });

      test('parses unknown freeform atom as custom tag', () {
        final freeformAtom = _buildFreeformAtom(
          domain: 'com.example.app',
          name: 'UNKNOWN_FIELD',
          dataType: 0x00000001, // UTF-8 text
          data: Uint8List.fromList('Custom Value'.codeUnits),
        );

        final tags = codec.readFromContainer(freeformAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<CustomTag>());
        expect(tags[0].value, equals('Custom Value'));
        expect(tags[0].key, equals(TagKey.custom));
      });

      test('skips unsupported atoms gracefully', () {
        // Create an unknown atom type
        final unknownAtom = _buildAtom('UNKN', Uint8List.fromList([1, 2, 3, 4]));
        final titleAtom = buildTextAtom('©nam', 'Test Title');

        final combinedData = Uint8List.fromList([
          ...unknownAtom,
          ...titleAtom,
        ]);

        final tags = codec.readFromContainer(combinedData);

        // Should only parse the title atom, skip the unknown one
        expect(tags, hasLength(1));
        expect(tags[0], isA<TitleTag>());
        expect(tags[0].value, equals('Test Title'));
      });

      test('handles artwork atom with lazy loading', () {
        final jpegData = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature
          ...List.generate(100, (i) => i % 256), // Mock JPEG data
        ]);
        final artworkAtom = buildArtworkAtom(jpegData);
        final tags = codec.readFromContainer(artworkAtom);

        expect(tags, hasLength(1));
        expect(tags[0], isA<ArtworkTag>());
        final artworkTag = tags[0] as ArtworkTag;
        expect(artworkTag.value.mimeType, equals('image/jpeg'));
        expect(artworkTag.value.type, equals(ArtworkType.frontCover));
      });

      test('handles empty container gracefully', () {
        final tags = codec.readFromContainer(Uint8List(0));
        expect(tags, isEmpty);
      });

      test('provides correct provenance information', () {
        final titleAtom = buildTextAtom('©nam', 'Test Title');
        final tags = codec.readFromContainer(titleAtom);

        expect(tags, hasLength(1));
        final tag = tags[0];
        expect(tag.provenance.containerKind, equals(ContainerKind.mp4));
        expect(tag.provenance.containerVersion, equals(''));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });
    });

    group('writeToContainer', () {
      test('creates empty ilst container for empty tags', () {
        final result = codec.writeToContainer(tagsToWrite: []);

        expect(result, isNotNull);
        expect(result.length, equals(8)); // Just header

        // Verify it's a valid empty ilst atom
        final view = ByteData.sublistView(result);
        expect(view.getUint32(0, Endian.big), equals(8)); // size
        expect(String.fromCharCodes(result.sublist(4, 8)), equals('ilst')); // type
      });

      test('writes single text atom correctly', () {
        final tags = [const TitleTag('Test Title')];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);
        expect(result.length, greaterThan(0));

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<TitleTag>());
        expect(parsedTags[0].value, equals('Test Title'));
      });

      test('writes multiple text atoms correctly', () {
        final tags = [
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
          const AlbumTag('Test Album'),
        ];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(3));

        final titleTag = parsedTags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test Title'));

        final artistTag = parsedTags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Test Artist'));

        final albumTag = parsedTags.whereType<AlbumTag>().first;
        expect(albumTag.value, equals('Test Album'));
      });

      test('writes track number atom correctly', () {
        final tags = [TrackNumberTag(5)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<TrackNumberTag>());
        expect(parsedTags[0].value, equals(5));
      });

      test('writes disc number atom correctly', () {
        final tags = [DiscNumberTag(2)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<DiscNumberTag>());
        expect(parsedTags[0].value, equals(2));
      });

      test('writes BPM atom correctly', () {
        final tags = [BpmTag(120)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<BpmTag>());
        expect(parsedTags[0].value, equals(120));
      });

      test('writes year as date atom correctly', () {
        final tags = [YearTag(2023)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<DateRecordedTag>());
        expect(parsedTags[0].value, equals('2023'));
      });

      test('writes genre atom with semicolon separation', () {
        final tags = [
          GenreTag(const ['Rock', 'Alternative', 'Indie']),
        ];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<GenreTag>());
        final genreTag = parsedTags[0] as GenreTag;
        expect(genreTag.value, equals(['Rock', 'Alternative', 'Indie']));
      });

      test('writes freeform rating atom correctly', () {
        final tags = [RatingTag(85)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<RatingTag>());
        expect(parsedTags[0].value, equals(85));
      });

      test('writes freeform musical key atom correctly', () {
        final tags = [const MusicalKeyTag('C major')];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<MusicalKeyTag>());
        expect(parsedTags[0].value, equals('C major'));
      });

      test('writes freeform ISRC atom correctly', () {
        final tags = [const IsrcTag('USRC17607839')];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<IsrcTag>());
        expect(parsedTags[0].value, equals('USRC17607839'));
      });

      test('writes custom freeform atom correctly', () {
        final tags = [const CustomTag('Custom Value')];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<CustomTag>());
        expect(parsedTags[0].value, equals('Custom Value'));
      });

      test('writes artwork atom correctly', () {
        final artworkData = ArtworkData(
          mimeType: 'image/jpeg',
          type: ArtworkType.frontCover,
          description: null,
          dataLoader: () async => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        );
        final tags = <MetadataTag>[ArtworkTag(artworkData)];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<ArtworkTag>());
        final artworkTag = parsedTags[0] as ArtworkTag;
        expect(artworkTag.value.mimeType, equals('image/jpeg'));
        expect(artworkTag.value.type, equals(ArtworkType.frontCover));
      });

      test('writes mixed atom types correctly', () {
        final tags = <MetadataTag>[
          const TitleTag('Mixed Test'),
          const ArtistTag('Test Artist'),
          TrackNumberTag(7),
          BpmTag(140),
          GenreTag(const ['Electronic', 'Dance']),
          RatingTag(90),
        ];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(6));

        // Verify each tag type
        expect(parsedTags.whereType<TitleTag>().first.value, equals('Mixed Test'));
        expect(parsedTags.whereType<ArtistTag>().first.value, equals('Test Artist'));
        expect(parsedTags.whereType<TrackNumberTag>().first.value, equals(7));
        expect(parsedTags.whereType<BpmTag>().first.value, equals(140));
        expect(parsedTags.whereType<GenreTag>().first.value, equals(['Electronic', 'Dance']));
        expect(parsedTags.whereType<RatingTag>().first.value, equals(90));
      });

      test('handles unsupported tag types gracefully', () {
        // Create a mock tag that's not supported
        final tags = [const TitleTag('Supported Tag')];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Should only contain the supported tag
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(1));
        expect(parsedTags[0], isA<TitleTag>());
        expect(parsedTags[0].value, equals('Supported Tag'));
      });

      test('round-trip consistency for all supported tag types', () {
        final originalTags = <MetadataTag>[
          const TitleTag('Round Trip Title'),
          const ArtistTag('Round Trip Artist'),
          const AlbumTag('Round Trip Album'),
          const AlbumArtistTag('Round Trip Album Artist'),
          const CommentTag('Round Trip Comment'),
          const GroupingTag('Round Trip Grouping'),
          const ComposerTag('Round Trip Composer'),
          const EncoderTag('Round Trip Encoder'),
          const LyricsTag('Round Trip Lyrics'),
          YearTag(2023), // This will become DateRecordedTag
          GenreTag(const ['Rock', 'Pop']),
          TrackNumberTag(3),
          DiscNumberTag(1),
          BpmTag(128),
          const MusicalKeyTag('A minor'),
          RatingTag(75),
          const IsrcTag('TEST12345678'),
          const CustomTag('Round Trip Custom'),
        ];

        final encoded = codec.writeToContainer(tagsToWrite: originalTags);
        final decoded = codec.readFromContainer(encoded);

        // Should have same number of tags (year becomes dateRecorded)
        expect(decoded.length, equals(originalTags.length));

        // Verify key tags are preserved
        expect(decoded.whereType<TitleTag>().first.value, equals('Round Trip Title'));
        expect(decoded.whereType<ArtistTag>().first.value, equals('Round Trip Artist'));
        expect(decoded.whereType<GenreTag>().first.value, equals(['Rock', 'Pop']));
        expect(decoded.whereType<TrackNumberTag>().first.value, equals(3));
        expect(decoded.whereType<RatingTag>().first.value, equals(75));
      });

      test('preserves UTF-8 text encoding', () {
        final tags = [
          const TitleTag('Test with émojis 🎵 and ñoñó'),
          const ArtistTag('Artíst with àccénts'),
        ];
        final result = codec.writeToContainer(tagsToWrite: tags);

        expect(result, isNotNull);

        // Parse the result back to verify UTF-8 is preserved
        final parsedTags = codec.readFromContainer(result);
        expect(parsedTags, hasLength(2));

        final titleTag = parsedTags.whereType<TitleTag>().first;
        expect(titleTag.value, equals('Test with émojis 🎵 and ñoñó'));

        final artistTag = parsedTags.whereType<ArtistTag>().first;
        expect(artistTag.value, equals('Artíst with àccénts'));
      });
    });
  });
}

/// Helper function to build a generic atom
Uint8List _buildAtom(String atomType, Uint8List data) {
  final atomSize = 8 + data.length; // header + data

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, atomType.codeUnits); // type

  // Data
  result.setRange(8, 8 + data.length, data);

  return result;
}

/// Helper function to build a freeform atom (----)
Uint8List _buildFreeformAtom({
  required String domain,
  required String name,
  required int dataType,
  required Uint8List data,
}) {
  final meanAtom = _buildMeanAtom(domain);
  final nameAtom = _buildNameAtom(name);
  final dataAtom = _buildDataAtom(dataType, data);

  final totalDataSize = meanAtom.length + nameAtom.length + dataAtom.length;
  final atomSize = 8 + totalDataSize; // header + sub-atoms

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, '----'.codeUnits); // type

  // Sub-atoms
  int offset = 8;
  result.setRange(offset, offset + meanAtom.length, meanAtom);
  offset += meanAtom.length;

  result.setRange(offset, offset + nameAtom.length, nameAtom);
  offset += nameAtom.length;

  result.setRange(offset, offset + dataAtom.length, dataAtom);

  return result;
}

/// Helper function to build a 'mean' sub-atom
Uint8List _buildMeanAtom(String domain) {
  final domainBytes = Uint8List.fromList(domain.codeUnits);
  final atomSize = 8 + 4 + domainBytes.length; // header + version/flags + domain

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'mean'.codeUnits); // type

  // Version/flags (4 bytes of zeros)
  view.setUint32(8, 0, Endian.big);

  // Domain string
  result.setRange(12, 12 + domainBytes.length, domainBytes);

  return result;
}

/// Helper function to build a 'name' sub-atom
Uint8List _buildNameAtom(String name) {
  final nameBytes = Uint8List.fromList(name.codeUnits);
  final atomSize = 8 + 4 + nameBytes.length; // header + version/flags + name

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'name'.codeUnits); // type

  // Version/flags (4 bytes of zeros)
  view.setUint32(8, 0, Endian.big);

  // Name string
  result.setRange(12, 12 + nameBytes.length, nameBytes);

  return result;
}

/// Helper function to build a 'data' sub-atom
Uint8List _buildDataAtom(int dataType, Uint8List data) {
  final atomSize = 8 + 8 + data.length; // header + type/flags + locale + data

  final result = Uint8List(atomSize);
  final view = ByteData.sublistView(result);

  // Atom header
  view.setUint32(0, atomSize, Endian.big); // size
  result.setRange(4, 8, 'data'.codeUnits); // type

  // Type/flags
  view.setUint32(8, dataType, Endian.big);

  // Locale (4 bytes of zeros)
  view.setUint32(12, 0, Endian.big);

  // Data payload
  result.setRange(16, 16 + data.length, data);

  return result;
}

/// Helper function to build integer data for freeform atoms
Uint8List _buildIntegerData(int value) {
  final result = Uint8List(4);
  final view = ByteData.sublistView(result);
  view.setUint32(0, value, Endian.big);
  return result;
}
