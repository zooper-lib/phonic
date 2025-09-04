import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/core/text_encoding.dart';
import 'package:test/test.dart';

// Test encoding sets using TextEncoding enum constants
const _utf8Only = {'UTF-8'}; // TextEncoding.utf8.standardName
const _iso88591Only = {'ISO-8859-1'}; // TextEncoding.iso88591.standardName
const _id3v23Encodings = {
  'ISO-8859-1', // TextEncoding.iso88591.standardName
  'UTF-16', // TextEncoding.utf16.standardName
};
const _id3v24Encodings = {
  'ISO-8859-1', // TextEncoding.iso88591.standardName
  'UTF-16', // TextEncoding.utf16.standardName
  'UTF-8', // TextEncoding.utf8.standardName
};

void main() {
  group('TagCapability', () {
    group('constructor', () {
      test('creates instance with required parameters', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
          },
        );

        expect(capability.containerKind, equals(ContainerKind.id3v1));
        expect(capability.containerVersion, equals('v1'));
        expect(capability.semanticsByKey, hasLength(2));
        expect(capability.semanticsByKey[TagKey.title], equals(const TagSemantics(maxTextLength: 30)));
        expect(capability.semanticsByKey[TagKey.artist], equals(const TagSemantics(maxTextLength: 30)));
      });

      test('creates instance with empty semantics map', () {
        const capability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(capability.containerKind, equals(ContainerKind.none));
        expect(capability.containerVersion, equals(''));
        expect(capability.semanticsByKey, isEmpty);
      });

      test('creates instance with complex semantics', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.title: TagSemantics(
              allowedEncodings: _id3v24Encodings,
            ),
            TagKey.genre: TagSemantics(multiValued: false),
            TagKey.artwork: TagSemantics(multiValued: true),
            TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
          },
        );

        expect(capability.containerKind, equals(ContainerKind.id3v2));
        expect(capability.containerVersion, equals('2.4'));
        expect(capability.semanticsByKey, hasLength(4));
        expect(capability.semanticsByKey[TagKey.rating]?.minValue, equals(0));
        expect(capability.semanticsByKey[TagKey.rating]?.maxValue, equals(255));
      });

      test('creates instance with unversioned container', () {
        const capability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.genre: TagSemantics(
              multiValued: true,
              allowedEncodings: _utf8Only,
            ),
          },
        );

        expect(capability.containerKind, equals(ContainerKind.vorbis));
        expect(capability.containerVersion, equals(''));
        expect(capability.semanticsByKey[TagKey.genre]?.multiValued, equals(true));
      });
    });

    group('supports', () {
      late TagCapability capability;

      setUp(() {
        capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
            TagKey.album: TagSemantics(maxTextLength: 30),
            TagKey.year: TagSemantics(maxTextLength: 4),
            TagKey.comment: TagSemantics(maxTextLength: 30),
            TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
            TagKey.genre: TagSemantics(minValue: 0, maxValue: 255),
          },
        );
      });

      test('returns true for supported fields', () {
        expect(capability.supports(TagKey.title), equals(true));
        expect(capability.supports(TagKey.artist), equals(true));
        expect(capability.supports(TagKey.album), equals(true));
        expect(capability.supports(TagKey.year), equals(true));
        expect(capability.supports(TagKey.comment), equals(true));
        expect(capability.supports(TagKey.trackNumber), equals(true));
        expect(capability.supports(TagKey.genre), equals(true));
      });

      test('returns false for unsupported fields', () {
        expect(capability.supports(TagKey.artwork), equals(false));
        expect(capability.supports(TagKey.lyrics), equals(false));
        expect(capability.supports(TagKey.albumArtist), equals(false));
        expect(capability.supports(TagKey.discNumber), equals(false));
        expect(capability.supports(TagKey.bpm), equals(false));
        expect(capability.supports(TagKey.rating), equals(false));
        expect(capability.supports(TagKey.composer), equals(false));
        expect(capability.supports(TagKey.encoder), equals(false));
        expect(capability.supports(TagKey.isrc), equals(false));
        expect(capability.supports(TagKey.musicalKey), equals(false));
        expect(capability.supports(TagKey.grouping), equals(false));
        expect(capability.supports(TagKey.dateRecorded), equals(false));
        expect(capability.supports(TagKey.custom), equals(false));
      });

      test('handles empty semantics map', () {
        const emptyCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        for (final key in TagKey.values) {
          expect(emptyCapability.supports(key), equals(false));
        }
      });

      test('handles all fields supported', () {
        final allFieldsMap = <TagKey, TagSemantics>{};
        for (final key in TagKey.values) {
          allFieldsMap[key] = const TagSemantics();
        }

        final fullCapability = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: allFieldsMap,
        );

        for (final key in TagKey.values) {
          expect(fullCapability.supports(key), equals(true));
        }
      });
    });

    group('semantics', () {
      late TagCapability capability;

      setUp(() {
        capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
            TagKey.genre: TagSemantics(
              multiValued: false,
              allowedEncodings: _iso88591Only,
            ),
          },
        );
      });

      test('returns correct semantics for supported fields', () {
        final titleSemantics = capability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, equals(30));
        expect(titleSemantics.minValue, isNull);
        expect(titleSemantics.maxValue, isNull);

        final ratingSemantics = capability.semantics(TagKey.rating);
        expect(ratingSemantics.minValue, equals(0));
        expect(ratingSemantics.maxValue, equals(255));
        expect(ratingSemantics.maxTextLength, isNull);

        final genreSemantics = capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, equals(false));
        expect(genreSemantics.allowedEncodings, equals(_iso88591Only));
      });

      test('returns default semantics for unsupported fields', () {
        final artworkSemantics = capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, equals(false));
        expect(artworkSemantics.maxTextLength, isNull);
        expect(artworkSemantics.minValue, isNull);
        expect(artworkSemantics.maxValue, isNull);
        expect(artworkSemantics.allowedEncodings, isNull);
        expect(artworkSemantics.hasConstraints, equals(false));

        final lyricsSemantics = capability.semantics(TagKey.lyrics);
        expect(lyricsSemantics, equals(const TagSemantics()));
      });

      test('returns same instance for repeated calls', () {
        final semantics1 = capability.semantics(TagKey.title);
        final semantics2 = capability.semantics(TagKey.title);
        expect(semantics1, equals(semantics2));
      });

      test('handles all tag keys', () {
        for (final key in TagKey.values) {
          final semantics = capability.semantics(key);
          expect(semantics, isA<TagSemantics>());
        }
      });
    });

    group('supportedFields', () {
      test('returns list of supported field keys', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
            TagKey.album: TagSemantics(maxTextLength: 30),
          },
        );

        final supportedFields = capability.supportedFields;
        expect(supportedFields, hasLength(3));
        expect(supportedFields, contains(TagKey.title));
        expect(supportedFields, contains(TagKey.artist));
        expect(supportedFields, contains(TagKey.album));
        expect(supportedFields, isNot(contains(TagKey.artwork)));
      });

      test('returns empty list for empty semantics map', () {
        const capability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(capability.supportedFields, isEmpty);
      });

      test('returns all fields when all are supported', () {
        final allFieldsMap = <TagKey, TagSemantics>{};
        for (final key in TagKey.values) {
          allFieldsMap[key] = const TagSemantics();
        }

        final capability = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: allFieldsMap,
        );

        final supportedFields = capability.supportedFields;
        expect(supportedFields, hasLength(TagKey.values.length));
        for (final key in TagKey.values) {
          expect(supportedFields, contains(key));
        }
      });

      test('returns modifiable list', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
          },
        );

        final supportedFields = capability.supportedFields;
        expect(() => supportedFields.add(TagKey.album), returnsNormally);
        expect(supportedFields, hasLength(3));

        // Original capability should be unaffected
        expect(capability.supportedFields, hasLength(2));
      });
    });

    group('supportedFieldCount', () {
      test('returns correct count for various field counts', () {
        const emptyCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );
        expect(emptyCapability.supportedFieldCount, equals(0));

        const singleFieldCapability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
          },
        );
        expect(singleFieldCapability.supportedFieldCount, equals(1));

        const multiFieldCapability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
            TagKey.album: TagSemantics(maxTextLength: 30),
            TagKey.year: TagSemantics(maxTextLength: 4),
            TagKey.comment: TagSemantics(maxTextLength: 30),
            TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
            TagKey.genre: TagSemantics(minValue: 0, maxValue: 255),
          },
        );
        expect(multiFieldCapability.supportedFieldCount, equals(7));
      });

      test('matches supportedFields length', () {
        const capability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
            TagKey.album: TagSemantics(),
            TagKey.genre: TagSemantics(multiValued: true),
            TagKey.artwork: TagSemantics(multiValued: true),
          },
        );

        expect(capability.supportedFieldCount, equals(capability.supportedFields.length));
      });
    });

    group('hasConstraints', () {
      test('returns true when any field has constraints', () {
        const capabilityWithConstraints = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(), // No constraints
          },
        );

        expect(capabilityWithConstraints.hasConstraints, equals(true));
      });

      test('returns false when no fields have constraints', () {
        const capabilityWithoutConstraints = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
            TagKey.album: TagSemantics(),
          },
        );

        expect(capabilityWithoutConstraints.hasConstraints, equals(false));
      });

      test('returns false for empty semantics map', () {
        const emptyCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(emptyCapability.hasConstraints, equals(false));
      });

      test('detects various constraint types', () {
        const lengthConstraint = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
          },
        );
        expect(lengthConstraint.hasConstraints, equals(true));

        const valueConstraint = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
          },
        );
        expect(valueConstraint.hasConstraints, equals(true));

        const encodingConstraint = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(allowedEncodings: _utf8Only),
          },
        );
        expect(encodingConstraint.hasConstraints, equals(true));

        const multiValueConstraint = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.genre: TagSemantics(multiValued: true),
          },
        );
        expect(multiValueConstraint.hasConstraints, equals(true));
      });
    });

    group('toString', () {
      test('formats container with version', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
            TagKey.album: TagSemantics(),
          },
        );

        expect(capability.toString(), equals('TagCapability(id3v2 2.4: 3 fields)'));
      });

      test('formats container without version', () {
        const capability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
          },
        );

        expect(capability.toString(), equals('TagCapability(vorbis: 2 fields)'));
      });

      test('formats empty capability', () {
        const capability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(capability.toString(), equals('TagCapability(none: 0 fields)'));
      });

      test('formats single field capability', () {
        const capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
          },
        );

        expect(capability.toString(), equals('TagCapability(id3v1 v1: 1 fields)'));
      });

      test('handles all container kinds', () {
        for (final kind in ContainerKind.values) {
          final capability = TagCapability(
            containerKind: kind,
            containerVersion: 'test',
            semanticsByKey: {TagKey.title: const TagSemantics()},
          );

          final result = capability.toString();
          expect(result, contains(kind.name));
          expect(result, contains('test'));
          expect(result, contains('1 fields'));
        }
      });
    });

    group('equality', () {
      test('equal instances with same values', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
          },
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
          },
        );

        expect(capability1, equals(capability2));
        expect(capability1.hashCode, equals(capability2.hashCode));
      });

      test('equal instances with same semantics in different order', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 100),
            TagKey.artist: TagSemantics(maxTextLength: 100),
          },
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.artist: TagSemantics(maxTextLength: 100),
            TagKey.title: TagSemantics(maxTextLength: 100),
          },
        );

        expect(capability1, equals(capability2));
        expect(capability1.hashCode, equals(capability2.hashCode));
      });

      test('equal empty capabilities', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        expect(capability1, equals(capability2));
        expect(capability1.hashCode, equals(capability2.hashCode));
      });

      test('not equal with different container kinds', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {TagKey.title: TagSemantics()},
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: 'v1',
          semanticsByKey: {TagKey.title: TagSemantics()},
        );

        expect(capability1, isNot(equals(capability2)));
      });

      test('not equal with different container versions', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.3',
          semanticsByKey: {TagKey.title: TagSemantics()},
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {TagKey.title: TagSemantics()},
        );

        expect(capability1, isNot(equals(capability2)));
      });

      test('not equal with different semantics maps', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
          },
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 50),
          },
        );

        expect(capability1, isNot(equals(capability2)));
      });

      test('not equal with different number of fields', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
          },
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
            TagKey.artist: TagSemantics(),
          },
        );

        expect(capability1, isNot(equals(capability2)));
      });

      test('not equal with different field keys', () {
        const capability1 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(),
          },
        );

        const capability2 = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.artist: TagSemantics(),
          },
        );

        expect(capability1, isNot(equals(capability2)));
      });
    });

    group('real-world capability examples', () {
      test('ID3v1 capability definition', () {
        const id3v1Capability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(maxTextLength: 30),
            TagKey.artist: TagSemantics(maxTextLength: 30),
            TagKey.album: TagSemantics(maxTextLength: 30),
            TagKey.year: TagSemantics(maxTextLength: 4),
            TagKey.comment: TagSemantics(maxTextLength: 30),
            TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
            TagKey.genre: TagSemantics(minValue: 0, maxValue: 255),
          },
        );

        // Test supported fields
        expect(id3v1Capability.supports(TagKey.title), equals(true));
        expect(id3v1Capability.supports(TagKey.artist), equals(true));
        expect(id3v1Capability.supports(TagKey.album), equals(true));
        expect(id3v1Capability.supports(TagKey.year), equals(true));
        expect(id3v1Capability.supports(TagKey.comment), equals(true));
        expect(id3v1Capability.supports(TagKey.trackNumber), equals(true));
        expect(id3v1Capability.supports(TagKey.genre), equals(true));

        // Test unsupported fields
        expect(id3v1Capability.supports(TagKey.artwork), equals(false));
        expect(id3v1Capability.supports(TagKey.lyrics), equals(false));
        expect(id3v1Capability.supports(TagKey.albumArtist), equals(false));

        // Test constraints
        expect(id3v1Capability.hasConstraints, equals(true));
        expect(id3v1Capability.supportedFieldCount, equals(7));

        // Test specific semantics
        final titleSemantics = id3v1Capability.semantics(TagKey.title);
        expect(titleSemantics.maxTextLength, equals(30));
        expect(titleSemantics.isValidTextLength(30), equals(true));
        expect(titleSemantics.isValidTextLength(31), equals(false));

        final trackSemantics = id3v1Capability.semantics(TagKey.trackNumber);
        expect(trackSemantics.isValidValue(1), equals(true));
        expect(trackSemantics.isValidValue(255), equals(true));
        expect(trackSemantics.isValidValue(0), equals(false));
        expect(trackSemantics.isValidValue(256), equals(false));
      });

      test('ID3v2.4 capability definition', () {
        const id3v24Capability = TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.title: TagSemantics(
              allowedEncodings: _id3v24Encodings,
            ),
            TagKey.artist: TagSemantics(
              allowedEncodings: _id3v24Encodings,
            ),
            TagKey.album: TagSemantics(
              allowedEncodings: _id3v24Encodings,
            ),
            TagKey.genre: TagSemantics(multiValued: false),
            TagKey.artwork: TagSemantics(multiValued: true),
            TagKey.rating: TagSemantics(minValue: 0, maxValue: 255),
            TagKey.dateRecorded: TagSemantics(),
            TagKey.lyrics: TagSemantics(
              allowedEncodings: _id3v24Encodings,
            ),
          },
        );

        // Test UTF-8 support (ID3v2.4 feature)
        final titleSemantics = id3v24Capability.semantics(TagKey.title);
        expect(titleSemantics.supportsEncoding(TextEncoding.utf8), equals(true));
        expect(titleSemantics.supportsEncoding(TextEncoding.utf16), equals(true));
        expect(titleSemantics.supportsEncoding(TextEncoding.iso88591), equals(true));

        // Test multi-valued artwork support
        final artworkSemantics = id3v24Capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, equals(true));

        // Test single-valued genre (encoded within frame)
        final genreSemantics = id3v24Capability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, equals(false));

        // Test rating range
        final ratingSemantics = id3v24Capability.semantics(TagKey.rating);
        expect(ratingSemantics.isValidValue(0), equals(true));
        expect(ratingSemantics.isValidValue(255), equals(true));
        expect(ratingSemantics.isValidValue(256), equals(false));

        expect(id3v24Capability.supportedFieldCount, equals(8));
      });

      test('Vorbis capability definition', () {
        const vorbisCapability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.artist: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.album: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.genre: TagSemantics(
              multiValued: true,
              allowedEncodings: _utf8Only,
            ),
            TagKey.artwork: TagSemantics(multiValued: true),
            TagKey.trackNumber: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.discNumber: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
          },
        );

        // Test UTF-8 only encoding
        final titleSemantics = vorbisCapability.semantics(TagKey.title);
        expect(titleSemantics.supportsEncoding(TextEncoding.utf8), equals(true));
        expect(titleSemantics.supportsEncoding(TextEncoding.utf16), equals(false));
        expect(titleSemantics.supportsEncoding(TextEncoding.iso88591), equals(false));

        // Test multi-valued genre support (native Vorbis feature)
        final genreSemantics = vorbisCapability.semantics(TagKey.genre);
        expect(genreSemantics.multiValued, equals(true));
        expect(genreSemantics.supportsEncoding(TextEncoding.utf8), equals(true));

        // Test multi-valued artwork support
        final artworkSemantics = vorbisCapability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, equals(true));

        expect(vorbisCapability.containerVersion, equals(''));
        expect(vorbisCapability.supportedFieldCount, equals(7));
      });

      test('MP4 capability definition', () {
        const mp4Capability = TagCapability(
          containerKind: ContainerKind.mp4,
          containerVersion: '',
          semanticsByKey: {
            TagKey.title: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.artist: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.album: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.genre: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
            TagKey.artwork: TagSemantics(multiValued: true),
            TagKey.trackNumber: TagSemantics(),
            TagKey.discNumber: TagSemantics(),
            TagKey.year: TagSemantics(),
            TagKey.custom: TagSemantics(
              allowedEncodings: _utf8Only,
            ),
          },
        );

        // Test UTF-8 encoding for text fields
        final titleSemantics = mp4Capability.semantics(TagKey.title);
        expect(titleSemantics.supportsEncoding(TextEncoding.utf8), equals(true));
        expect(titleSemantics.supportsEncoding(TextEncoding.utf16), equals(false));

        // Test custom field support (freeform atoms)
        expect(mp4Capability.supports(TagKey.custom), equals(true));
        final customSemantics = mp4Capability.semantics(TagKey.custom);
        expect(customSemantics.supportsEncoding(TextEncoding.utf8), equals(true));

        // Test multi-valued artwork
        final artworkSemantics = mp4Capability.semantics(TagKey.artwork);
        expect(artworkSemantics.multiValued, equals(true));

        expect(mp4Capability.supportedFieldCount, equals(9));
      });
    });

    group('capability lookup functionality', () {
      late List<TagCapability> capabilities;

      setUp(() {
        capabilities = [
          const TagCapability(
            containerKind: ContainerKind.id3v1,
            containerVersion: 'v1',
            semanticsByKey: {
              TagKey.title: TagSemantics(maxTextLength: 30),
              TagKey.artist: TagSemantics(maxTextLength: 30),
              TagKey.album: TagSemantics(maxTextLength: 30),
            },
          ),
          const TagCapability(
            containerKind: ContainerKind.id3v2,
            containerVersion: '2.3',
            semanticsByKey: {
              TagKey.title: TagSemantics(
                allowedEncodings: _id3v23Encodings,
              ),
              TagKey.artist: TagSemantics(
                allowedEncodings: _id3v23Encodings,
              ),
              TagKey.artwork: TagSemantics(multiValued: true),
            },
          ),
          const TagCapability(
            containerKind: ContainerKind.id3v2,
            containerVersion: '2.4',
            semanticsByKey: {
              TagKey.title: TagSemantics(
                allowedEncodings: _id3v24Encodings,
              ),
              TagKey.artist: TagSemantics(
                allowedEncodings: _id3v24Encodings,
              ),
              TagKey.artwork: TagSemantics(multiValued: true),
              TagKey.dateRecorded: TagSemantics(),
            },
          ),
        ];
      });

      test('can find capability by container kind and version', () {
        final id3v1 = capabilities.firstWhere(
          (cap) => cap.containerKind == ContainerKind.id3v1 && cap.containerVersion == 'v1',
        );
        expect(id3v1.supports(TagKey.title), equals(true));
        expect(id3v1.supports(TagKey.artwork), equals(false));

        final id3v24 = capabilities.firstWhere(
          (cap) => cap.containerKind == ContainerKind.id3v2 && cap.containerVersion == '2.4',
        );
        expect(id3v24.supports(TagKey.dateRecorded), equals(true));
        expect(id3v24.semantics(TagKey.title).supportsEncoding(TextEncoding.utf8), equals(true));
      });

      test('can filter capabilities by supported field', () {
        final artworkCapabilities = capabilities
            .where(
              (cap) => cap.supports(TagKey.artwork),
            )
            .toList();

        expect(artworkCapabilities, hasLength(2));
        expect(artworkCapabilities.every((cap) => cap.containerKind == ContainerKind.id3v2), equals(true));
      });

      test('can find most capable format for field', () {
        final titleCapabilities = capabilities
            .where(
              (cap) => cap.supports(TagKey.title),
            )
            .toList();

        // ID3v2.4 should be most capable (UTF-8 support)
        final mostCapable = titleCapabilities.reduce((a, b) {
          final aEncodings = a.semantics(TagKey.title).allowedEncodings?.length ?? 0;
          final bEncodings = b.semantics(TagKey.title).allowedEncodings?.length ?? 0;
          return aEncodings > bEncodings ? a : b;
        });

        expect(mostCapable.containerKind, equals(ContainerKind.id3v2));
        expect(mostCapable.containerVersion, equals('2.4'));
        expect(mostCapable.semantics(TagKey.title).supportsEncoding(TextEncoding.utf8), equals(true));
      });

      test('can validate field value against multiple capabilities', () {
        const longTitle = 'This is a very long title that exceeds ID3v1 limits but should work fine in ID3v2';

        for (final capability in capabilities) {
          if (capability.supports(TagKey.title)) {
            final semantics = capability.semantics(TagKey.title);
            final isValid = semantics.isValidTextLength(longTitle.length);

            if (capability.containerKind == ContainerKind.id3v1) {
              expect(isValid, equals(false)); // Exceeds 30 char limit
            } else {
              expect(isValid, equals(true)); // ID3v2 has no length limit
            }
          }
        }
      });
    });
  });
}
