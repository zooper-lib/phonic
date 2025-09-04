import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/core/tag_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isMultiValued', () {
    group('returns true for inherently multi-valued tags', () {
      test('genre tag supports multiple values', () {
        expect(isMultiValued(TagKey.genre), isTrue);
      });

      test('artwork tag supports multiple values', () {
        expect(isMultiValued(TagKey.artwork), isTrue);
      });

      test('custom tag supports multiple values', () {
        expect(isMultiValued(TagKey.custom), isTrue);
      });
    });

    group('returns false for single-valued tags', () {
      test('title tag is single-valued', () {
        expect(isMultiValued(TagKey.title), isFalse);
      });

      test('artist tag is single-valued', () {
        expect(isMultiValued(TagKey.artist), isFalse);
      });

      test('album tag is single-valued', () {
        expect(isMultiValued(TagKey.album), isFalse);
      });

      test('album artist tag is single-valued', () {
        expect(isMultiValued(TagKey.albumArtist), isFalse);
      });

      test('comment tag is single-valued', () {
        expect(isMultiValued(TagKey.comment), isFalse);
      });

      test('grouping tag is single-valued', () {
        expect(isMultiValued(TagKey.grouping), isFalse);
      });

      test('composer tag is single-valued', () {
        expect(isMultiValued(TagKey.composer), isFalse);
      });

      test('encoder tag is single-valued', () {
        expect(isMultiValued(TagKey.encoder), isFalse);
      });

      test('isrc tag is single-valued', () {
        expect(isMultiValued(TagKey.isrc), isFalse);
      });

      test('musical key tag is single-valued', () {
        expect(isMultiValued(TagKey.musicalKey), isFalse);
      });

      test('lyrics tag is single-valued', () {
        expect(isMultiValued(TagKey.lyrics), isFalse);
      });

      test('track number tag is single-valued', () {
        expect(isMultiValued(TagKey.trackNumber), isFalse);
      });

      test('disc number tag is single-valued', () {
        expect(isMultiValued(TagKey.discNumber), isFalse);
      });

      test('year tag is single-valued', () {
        expect(isMultiValued(TagKey.year), isFalse);
      });

      test('date recorded tag is single-valued', () {
        expect(isMultiValued(TagKey.dateRecorded), isFalse);
      });

      test('bpm tag is single-valued', () {
        expect(isMultiValued(TagKey.bpm), isFalse);
      });

      test('rating tag is single-valued', () {
        expect(isMultiValued(TagKey.rating), isFalse);
      });
    });

    group('covers all TagKey enum values', () {
      test('handles all enum values without throwing', () {
        // Ensure all TagKey values are handled by the function
        for (final key in TagKey.values) {
          expect(() => isMultiValued(key), returnsNormally);
        }
      });

      test('returns consistent results for same input', () {
        // Test that the function is deterministic
        for (final key in TagKey.values) {
          final result1 = isMultiValued(key);
          final result2 = isMultiValued(key);
          expect(result1, equals(result2), reason: 'Function should be deterministic for $key');
        }
      });
    });

    group('semantic correctness', () {
      test('multi-valued tags align with common usage patterns', () {
        // Genre is commonly multi-valued across formats
        expect(isMultiValued(TagKey.genre), isTrue, reason: 'Genres are commonly multiple (Rock, Alternative, etc.)');

        // Artwork commonly includes multiple types
        expect(isMultiValued(TagKey.artwork), isTrue, reason: 'Artwork often includes front cover, back cover, etc.');

        // Custom fields may need multiple values
        expect(isMultiValued(TagKey.custom), isTrue, reason: 'Custom fields may require multiple values');
      });

      test('single-valued tags align with semantic meaning', () {
        // These fields semantically represent single concepts
        expect(isMultiValued(TagKey.title), isFalse, reason: 'A track has one title');
        expect(isMultiValued(TagKey.artist), isFalse, reason: 'Primary artist is typically singular');
        expect(isMultiValued(TagKey.album), isFalse, reason: 'A track belongs to one album');
        expect(isMultiValued(TagKey.trackNumber), isFalse, reason: 'A track has one position number');
        expect(isMultiValued(TagKey.year), isFalse, reason: 'A track has one release year');
        expect(isMultiValued(TagKey.rating), isFalse, reason: 'A track has one rating value');
      });
    });
  });

  group('isMultiValuedInContainer', () {
    late TagCapability multiValueCapability;
    late TagCapability singleValueCapability;
    late TagCapability mixedCapability;

    setUp(() {
      // Capability that supports multi-values for most fields
      multiValueCapability = const TagCapability(
        containerKind: ContainerKind.vorbis,
        containerVersion: '',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: true),
          TagKey.artwork: TagSemantics(multiValued: true),
          TagKey.custom: TagSemantics(multiValued: true),
          TagKey.title: TagSemantics(multiValued: false),
          TagKey.artist: TagSemantics(multiValued: false),
        },
      );

      // Capability that doesn't support multi-values (like ID3v1)
      singleValueCapability = const TagCapability(
        containerKind: ContainerKind.id3v1,
        containerVersion: 'v1',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: false),
          TagKey.artwork: TagSemantics(multiValued: false), // ID3v1 doesn't support artwork
          TagKey.title: TagSemantics(multiValued: false),
          TagKey.artist: TagSemantics(multiValued: false),
        },
      );

      // Mixed capability (like ID3v2.4)
      mixedCapability = const TagCapability(
        containerKind: ContainerKind.id3v2,
        containerVersion: '2.4',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: true), // ID3v2.4 supports null-terminated genres
          TagKey.artwork: TagSemantics(multiValued: true), // Multiple APIC frames
          TagKey.custom: TagSemantics(multiValued: true),
          TagKey.title: TagSemantics(multiValued: false),
          TagKey.artist: TagSemantics(multiValued: false),
          TagKey.rating: TagSemantics(multiValued: false),
        },
      );
    });

    group('multi-value capability container', () {
      test('returns true for multi-valued fields', () {
        expect(isMultiValuedInContainer(TagKey.genre, multiValueCapability), isTrue);
        expect(isMultiValuedInContainer(TagKey.artwork, multiValueCapability), isTrue);
        expect(isMultiValuedInContainer(TagKey.custom, multiValueCapability), isTrue);
      });

      test('returns false for single-valued fields', () {
        expect(isMultiValuedInContainer(TagKey.title, multiValueCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.artist, multiValueCapability), isFalse);
      });
    });

    group('single-value capability container', () {
      test('returns false for all fields', () {
        expect(isMultiValuedInContainer(TagKey.genre, singleValueCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.artwork, singleValueCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.title, singleValueCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.artist, singleValueCapability), isFalse);
      });
    });

    group('mixed capability container', () {
      test('returns true for supported multi-valued fields', () {
        expect(isMultiValuedInContainer(TagKey.genre, mixedCapability), isTrue);
        expect(isMultiValuedInContainer(TagKey.artwork, mixedCapability), isTrue);
        expect(isMultiValuedInContainer(TagKey.custom, mixedCapability), isTrue);
      });

      test('returns false for single-valued fields', () {
        expect(isMultiValuedInContainer(TagKey.title, mixedCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.artist, mixedCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.rating, mixedCapability), isFalse);
      });
    });

    group('unsupported fields', () {
      test('returns false for fields not in capability', () {
        const limitedCapability = TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.title: TagSemantics(multiValued: false),
          },
        );

        // Fields not in the capability should return false (default TagSemantics)
        expect(isMultiValuedInContainer(TagKey.genre, limitedCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.artwork, limitedCapability), isFalse);
        expect(isMultiValuedInContainer(TagKey.custom, limitedCapability), isFalse);
      });
    });

    group('empty capability', () {
      test('returns false for all fields when no semantics defined', () {
        const emptyCapability = TagCapability(
          containerKind: ContainerKind.none,
          containerVersion: '',
          semanticsByKey: {},
        );

        for (final key in TagKey.values) {
          expect(isMultiValuedInContainer(key, emptyCapability), isFalse, reason: 'Empty capability should return false for $key');
        }
      });
    });

    group('consistency with TagSemantics', () {
      test('delegates to TagSemantics.multiValued property', () {
        const testCapability = TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.genre: TagSemantics(multiValued: true),
            TagKey.title: TagSemantics(multiValued: false),
          },
        );

        // Should match the semantics directly
        final genreSemantics = testCapability.semantics(TagKey.genre);
        final titleSemantics = testCapability.semantics(TagKey.title);

        expect(isMultiValuedInContainer(TagKey.genre, testCapability), equals(genreSemantics.multiValued));
        expect(isMultiValuedInContainer(TagKey.title, testCapability), equals(titleSemantics.multiValued));
      });
    });
  });

  group('function relationship', () {
    test('isMultiValued provides general guidance independent of container', () {
      // isMultiValued should give general guidance about multi-value nature
      // regardless of specific container capabilities

      // Genre is generally multi-valued
      expect(isMultiValued(TagKey.genre), isTrue);

      // But specific containers may not support it
      const id3v1Capability = TagCapability(
        containerKind: ContainerKind.id3v1,
        containerVersion: 'v1',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: false), // ID3v1 limitation
        },
      );

      expect(isMultiValuedInContainer(TagKey.genre, id3v1Capability), isFalse);
    });

    test('container-specific function provides precise capability information', () {
      // Different containers may have different multi-value support for the same field

      const vorbisCapability = TagCapability(
        containerKind: ContainerKind.vorbis,
        containerVersion: '',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: true), // Native multi-value support
        },
      );

      const mp4Capability = TagCapability(
        containerKind: ContainerKind.mp4,
        containerVersion: '',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: false), // Single atom with delimiters
        },
      );

      // Same field, different container support
      expect(isMultiValuedInContainer(TagKey.genre, vorbisCapability), isTrue);
      expect(isMultiValuedInContainer(TagKey.genre, mp4Capability), isFalse);

      // But general assessment remains the same
      expect(isMultiValued(TagKey.genre), isTrue);
    });
  });

  group('performance characteristics', () {
    test('isMultiValued executes quickly for all enum values', () {
      // Test that the function is performant for repeated calls
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        for (final key in TagKey.values) {
          isMultiValued(key);
        }
      }

      stopwatch.stop();

      // Should complete quickly (less than 100ms for 1000 iterations of all keys)
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Function should be performant for repeated calls');
    });

    test('isMultiValuedInContainer executes quickly', () {
      const testCapability = TagCapability(
        containerKind: ContainerKind.vorbis,
        containerVersion: '',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: true),
          TagKey.title: TagSemantics(multiValued: false),
        },
      );

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        for (final key in TagKey.values) {
          isMultiValuedInContainer(key, testCapability);
        }
      }

      stopwatch.stop();

      // Should complete quickly (less than 100ms for 1000 iterations)
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Container-specific function should be performant');
    });
  });

  group('documentation examples', () {
    test('basic usage examples work correctly', () {
      // Examples from the documentation should work as described

      // Check if a field supports multiple values
      if (isMultiValued(TagKey.genre)) {
        // This should be true
        expect(true, isTrue);
      } else {
        fail('Genre should be multi-valued according to documentation example');
      }

      if (isMultiValued(TagKey.artwork)) {
        // This should be true
        expect(true, isTrue);
      } else {
        fail('Artwork should be multi-valued according to documentation example');
      }

      if (!isMultiValued(TagKey.title)) {
        // This should be true (title is not multi-valued)
        expect(true, isTrue);
      } else {
        fail('Title should not be multi-valued according to documentation example');
      }
    });

    test('container-specific examples work correctly', () {
      // Create test capabilities similar to documentation examples
      const vorbisCapability = TagCapability(
        containerKind: ContainerKind.vorbis,
        containerVersion: '',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: true),
        },
      );

      const id3v1Capability = TagCapability(
        containerKind: ContainerKind.id3v1,
        containerVersion: 'v1',
        semanticsByKey: {
          TagKey.genre: TagSemantics(multiValued: false),
        },
      );

      // Vorbis supports multi-genre
      final vorbisSupportsMultiGenre = isMultiValuedInContainer(TagKey.genre, vorbisCapability);
      expect(vorbisSupportsMultiGenre, isTrue);

      // ID3v1 doesn't support multi-genre
      final id3v1SupportsMultiGenre = isMultiValuedInContainer(TagKey.genre, id3v1Capability);
      expect(id3v1SupportsMultiGenre, isFalse);
    });
  });
}
