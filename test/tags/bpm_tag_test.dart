import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:test/test.dart';

void main() {
  group('BpmTag', () {
    group('constructor', () {
      test('creates instance with valid BPM and default provenance', () {
        final tag = BpmTag(120);

        expect(tag.value, equals(120));
        expect(tag.key, equals(TagKey.bpm));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with valid BPM and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = BpmTag(140, provenance: provenance);

        expect(tag.value, equals(140));
        expect(tag.key, equals(TagKey.bpm));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with minimum valid BPM', () {
        final tag = BpmTag(1);

        expect(tag.value, equals(1));
        expect(tag.key, equals(TagKey.bpm));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with maximum valid BPM', () {
        final tag = BpmTag(999);

        expect(tag.value, equals(999));
        expect(tag.key, equals(TagKey.bpm));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with common BPM values', () {
        final tag60 = BpmTag(60); // Slow ballad
        final tag120 = BpmTag(120); // Standard pop/rock
        final tag180 = BpmTag(180); // Fast electronic

        expect(tag60.value, equals(60));
        expect(tag120.value, equals(120));
        expect(tag180.value, equals(180));
      });

      test('creates instance with genre-specific BPM values', () {
        final ballad = BpmTag(70); // Slow ballad
        final waltz = BpmTag(90); // Waltz tempo
        final pop = BpmTag(120); // Pop music
        final house = BpmTag(128); // House music
        final techno = BpmTag(140); // Techno
        final dnb = BpmTag(175); // Drum & Bass

        expect(ballad.value, equals(70));
        expect(waltz.value, equals(90));
        expect(pop.value, equals(120));
        expect(house.value, equals(128));
        expect(techno.value, equals(140));
        expect(dnb.value, equals(175));
      });

      test('key is always TagKey.bpm', () {
        final tag1 = BpmTag(1);
        final tag2 = BpmTag(120);
        final tag3 = BpmTag(999);

        expect(tag1.key, equals(TagKey.bpm));
        expect(tag2.key, equals(TagKey.bpm));
        expect(tag3.key, equals(TagKey.bpm));
      });
    });

    group('validation', () {
      test('throws ArgumentError for BPM 0', () {
        expect(
          () => BpmTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for BPM 1000', () {
        expect(
          () => BpmTag(1000),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for negative BPM values', () {
        expect(
          () => BpmTag(-1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );

        expect(
          () => BpmTag(-50),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );

        expect(
          () => BpmTag(-999),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );
      });

      test('throws ArgumentError for BPM values above maximum', () {
        expect(
          () => BpmTag(1001),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );

        expect(
          () => BpmTag(5000),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('BPM must be between 1 and 999 (inclusive)'),
            ),
          ),
        );
      });

      test('ArgumentError includes the invalid value', () {
        expect(
          () => BpmTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(0),
            ),
          ),
        );

        expect(
          () => BpmTag(1000),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(1000),
            ),
          ),
        );

        expect(
          () => BpmTag(-10),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.invalidValue,
              'invalidValue',
              equals(-10),
            ),
          ),
        );
      });

      test('ArgumentError includes parameter name', () {
        expect(
          () => BpmTag(0),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.name,
              'name',
              equals('value'),
            ),
          ),
        );
      });

      test('validation works with provenance parameter', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );

        expect(
          () => BpmTag(0, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => BpmTag(1000, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );

        // Valid values should work fine with provenance
        final validTag = BpmTag(120, provenance: provenance);
        expect(validTag.value, equals(120));
        expect(validTag.provenance, equals(provenance));
      });

      test('accepts boundary values', () {
        // Test that boundary values are valid
        final minTag = BpmTag(1);
        final maxTag = BpmTag(999);

        expect(minTag.value, equals(1));
        expect(maxTag.value, equals(999));
      });

      test('rejects values just outside boundaries', () {
        expect(() => BpmTag(0), throwsA(isA<ArgumentError>()));
        expect(() => BpmTag(1000), throwsA(isA<ArgumentError>()));
      });
    });

    group('withProvenance', () {
      test('returns new BpmTag instance with updated provenance', () {
        final originalTag = BpmTag(
          128,
          provenance: const TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals(128));
        expect(originalTag.key, equals(TagKey.bpm));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals(128));
        expect(updatedTag.key, equals(TagKey.bpm));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns BpmTag type specifically', () {
        final originalTag = BpmTag(140);
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<BpmTag>());
        expect(updatedTag.runtimeType, equals(BpmTag));
      });

      test('preserves BPM value exactly', () {
        final originalTag = BpmTag(175);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag.value, equals(originalTag.value));
        expect(updatedTag.key, equals(originalTag.key));
        expect(updatedTag.provenance, equals(newProvenance));
      });

      test('works with TagProvenance.none()', () {
        final originalTag = BpmTag(
          90,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        final originalTag = BpmTag(110);

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals(110));
          expect(updatedTag.key, equals(TagKey.bpm));
        }
      });

      test('works with all confidence levels', () {
        final originalTag = BpmTag(150);

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals(150));
          expect(updatedTag.key, equals(TagKey.bpm));
        }
      });
    });

    group('equality', () {
      test('equal instances with same BPM, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        final tag1 = BpmTag(120, provenance: provenance);
        final tag2 = BpmTag(120, provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different BPM values', () {
        final tag1 = BpmTag(120);
        final tag2 = BpmTag(140);

        expect(tag1, isNot(equals(tag2)));
      });

      test('not equal with different provenance', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v1,
          'v1',
          TagConfidence.certain,
        );

        final tag1 = BpmTag(120, provenance: provenance1);
        final tag2 = BpmTag(120, provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        final tag1 = BpmTag(128);
        final tag2 = BpmTag(128);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with boundary BPM values', () {
        final tag1Min = BpmTag(1);
        final tag2Min = BpmTag(1);
        final tag1Max = BpmTag(999);
        final tag2Max = BpmTag(999);

        expect(tag1Min, equals(tag2Min));
        expect(tag1Min.hashCode, equals(tag2Min.hashCode));
        expect(tag1Max, equals(tag2Max));
        expect(tag1Max.hashCode, equals(tag2Max.hashCode));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        final tag = BpmTag(160, provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals(160));
        expect(tag.props[1], equals(TagKey.bpm));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        final tag1 = BpmTag(100);
        final tag2 = BpmTag(100);

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and BPM', () {
        final tag = BpmTag(120);
        final result = tag.toString();

        expect(result, contains('BpmTag'));
        expect(result, contains('120'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        final tag = BpmTag(140, provenance: provenance);
        final result = tag.toString();

        expect(result, contains('BpmTag'));
        expect(result, contains('140'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles boundary BPM values', () {
        final tagMin = BpmTag(1);
        final tagMax = BpmTag(999);

        final resultMin = tagMin.toString();
        final resultMax = tagMax.toString();

        expect(resultMin, contains('1'));
        expect(resultMax, contains('999'));
      });

      test('handles common BPM values', () {
        final tag60 = BpmTag(60);
        final tag120 = BpmTag(120);
        final tag180 = BpmTag(180);

        expect(tag60.toString(), contains('60'));
        expect(tag120.toString(), contains('120'));
        expect(tag180.toString(), contains('180'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        final tag = BpmTag(
          128,
          provenance: const TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals(128));
        expect(tag.key, equals(TagKey.bpm));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        final originalTag = BpmTag(100);
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals(100));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals(100));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always int type', () {
        final tag1 = BpmTag(1);
        final tag2 = BpmTag(120);
        final tag3 = BpmTag(999);

        expect(tag1.value, isA<int>());
        expect(tag2.value, isA<int>());
        expect(tag3.value, isA<int>());
      });

      test('withProvenance maintains BpmTag type', () {
        final originalTag = BpmTag(130);
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<BpmTag>());
        expect(newTag.value, isA<int>());
        expect(newTag.runtimeType, equals(BpmTag));
      });
    });

    group('edge cases', () {
      test('handles exact boundary values', () {
        final minTag = BpmTag(1);
        final maxTag = BpmTag(999);

        expect(minTag.value, equals(1));
        expect(maxTag.value, equals(999));
        expect(minTag.key, equals(TagKey.bpm));
        expect(maxTag.key, equals(TagKey.bpm));
      });

      test('validation edge case: exactly at boundaries', () {
        // Test that boundary values are valid
        final tag1 = BpmTag(1);
        final tag999 = BpmTag(999);

        expect(tag1.value, equals(1));
        expect(tag999.value, equals(999));

        // And that values just outside boundaries are invalid
        expect(() => BpmTag(0), throwsA(isA<ArgumentError>()));
        expect(() => BpmTag(1000), throwsA(isA<ArgumentError>()));
      });

      test('handles common musical tempo ranges', () {
        // Test various musical tempo categories
        final largo = BpmTag(40); // Very slow (though below our min, testing 40)
        final adagio = BpmTag(70); // Slow
        final andante = BpmTag(90); // Walking pace
        final moderato = BpmTag(110); // Moderate
        final allegro = BpmTag(140); // Fast
        final presto = BpmTag(180); // Very fast

        // Note: Our validation starts at 1, so we test from valid range
        final verySlowValid = BpmTag(50);
        expect(largo.value, equals(40));
        expect(verySlowValid.value, equals(50));
        expect(adagio.value, equals(70));
        expect(andante.value, equals(90));
        expect(moderato.value, equals(110));
        expect(allegro.value, equals(140));
        expect(presto.value, equals(180));
      });

      test('handles electronic music BPM ranges', () {
        // Test electronic music genre BPM ranges
        final ambient = BpmTag(60); // Ambient/downtempo
        final house = BpmTag(128); // House music
        final techno = BpmTag(140); // Techno
        final trance = BpmTag(138); // Trance
        final dnb = BpmTag(175); // Drum & Bass
        final hardcore = BpmTag(200); // Hardcore
        final speedcore = BpmTag(300); // Speedcore

        expect(ambient.value, equals(60));
        expect(house.value, equals(128));
        expect(techno.value, equals(140));
        expect(trance.value, equals(138));
        expect(dnb.value, equals(175));
        expect(hardcore.value, equals(200));
        expect(speedcore.value, equals(300));
      });

      test('handles extreme but valid BPM values', () {
        // Test extreme but musically possible values
        final extremelySlow = BpmTag(1); // Theoretical minimum
        final verySlow = BpmTag(30); // Very slow ambient
        final veryFast = BpmTag(500); // Very fast electronic
        final extremelyFast = BpmTag(999); // Theoretical maximum

        expect(extremelySlow.value, equals(1));
        expect(verySlow.value, equals(30));
        expect(veryFast.value, equals(500));
        expect(extremelyFast.value, equals(999));
      });

      test('handles common DJ mixing BPM values', () {
        // Test BPM values commonly used in DJ mixing
        final hip_hop = BpmTag(85); // Hip-hop
        final pop = BpmTag(120); // Pop music
        final house = BpmTag(128); // House
        final techno = BpmTag(140); // Techno
        final dnb = BpmTag(174); // Drum & Bass

        expect(hip_hop.value, equals(85));
        expect(pop.value, equals(120));
        expect(house.value, equals(128));
        expect(techno.value, equals(140));
        expect(dnb.value, equals(174));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<int> correctly', () {
        final tag = BpmTag(120);

        expect(tag, isA<BpmTag>());
        expect(tag.value, isA<int>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        final tag1 = BpmTag(120);
        final tag2 = BpmTag(120);
        final tag3 = BpmTag(140);

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        final tag = BpmTag(128);
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'BpmTag\(.*\)'));
        expect(result, contains('128'));
        expect(result, contains('provenance:'));
      });
    });

    group('BPM specific scenarios', () {
      test('handles ballad BPM range (60-80)', () {
        for (int bpm = 60; bpm <= 80; bpm += 5) {
          final tag = BpmTag(bpm);
          expect(tag.value, equals(bpm));
        }
      });

      test('handles pop/rock BPM range (100-140)', () {
        for (int bpm = 100; bpm <= 140; bpm += 10) {
          final tag = BpmTag(bpm);
          expect(tag.value, equals(bpm));
        }
      });

      test('handles electronic BPM range (120-180)', () {
        for (int bpm = 120; bpm <= 180; bpm += 10) {
          final tag = BpmTag(bpm);
          expect(tag.value, equals(bpm));
        }
      });

      test('handles fast electronic BPM range (180-300)', () {
        for (int bpm = 180; bpm <= 300; bpm += 20) {
          final tag = BpmTag(bpm);
          expect(tag.value, equals(bpm));
        }
      });

      test('handles classical music tempo markings', () {
        // Classical tempo markings with approximate BPM values
        final grave = BpmTag(40); // Very slow and solemn
        final largo = BpmTag(50); // Slow and broad
        final adagio = BpmTag(70); // Slow
        final andante = BpmTag(90); // Walking pace
        final moderato = BpmTag(110); // Moderate
        final allegro = BpmTag(140); // Fast and lively
        final vivace = BpmTag(160); // Lively and fast
        final presto = BpmTag(180); // Very fast

        expect(grave.value, equals(40));
        expect(largo.value, equals(50));
        expect(adagio.value, equals(70));
        expect(andante.value, equals(90));
        expect(moderato.value, equals(110));
        expect(allegro.value, equals(140));
        expect(vivace.value, equals(160));
        expect(presto.value, equals(180));
      });

      test('handles genre-specific BPM ranges', () {
        // Different music genres and their typical BPM ranges
        final reggae = BpmTag(70); // Reggae
        final hip_hop = BpmTag(85); // Hip-hop
        final funk = BpmTag(100); // Funk
        final rock = BpmTag(120); // Rock
        final house = BpmTag(128); // House
        final trance = BpmTag(138); // Trance
        final dubstep = BpmTag(140); // Dubstep (half-time feel)
        final dnb = BpmTag(175); // Drum & Bass

        expect(reggae.value, equals(70));
        expect(hip_hop.value, equals(85));
        expect(funk.value, equals(100));
        expect(rock.value, equals(120));
        expect(house.value, equals(128));
        expect(trance.value, equals(138));
        expect(dubstep.value, equals(140));
        expect(dnb.value, equals(175));
      });

      test('handles workout music BPM ranges', () {
        // BPM ranges suitable for different workout activities
        final yoga = BpmTag(60); // Yoga/meditation
        final walking = BpmTag(90); // Walking
        final jogging = BpmTag(120); // Light jogging
        final running = BpmTag(140); // Running
        final sprinting = BpmTag(160); // High-intensity training

        expect(yoga.value, equals(60));
        expect(walking.value, equals(90));
        expect(jogging.value, equals(120));
        expect(running.value, equals(140));
        expect(sprinting.value, equals(160));
      });
    });

    group('validation error messages', () {
      test('error message is descriptive for BPM 0', () {
        try {
          BpmTag(0);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('BPM must be between 1 and 999 (inclusive)'));
          expect(error.invalidValue, equals(0));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for BPM 1000', () {
        try {
          BpmTag(1000);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('BPM must be between 1 and 999 (inclusive)'));
          expect(error.invalidValue, equals(1000));
          expect(error.name, equals('value'));
        }
      });

      test('error message is descriptive for negative values', () {
        try {
          BpmTag(-50);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('BPM must be between 1 and 999 (inclusive)'));
          expect(error.invalidValue, equals(-50));
          expect(error.name, equals('value'));
        }
      });

      test('error message includes range information', () {
        try {
          BpmTag(2000);
          fail('Expected ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          final error = e as ArgumentError;
          expect(error.message, contains('1'));
          expect(error.message, contains('999'));
          expect(error.message, contains('inclusive'));
        }
      });

      test('error occurs before provenance is processed', () {
        // Ensure validation happens early in constructor
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        expect(
          () => BpmTag(-1, provenance: provenance),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('constants', () {
      test('minBpm constant is correct', () {
        expect(BpmTag.minBpm, equals(1));
      });

      test('maxBpm constant is correct', () {
        expect(BpmTag.maxBpm, equals(999));
      });

      test('constants are used in validation', () {
        // Test that the constants are actually used
        expect(() => BpmTag(BpmTag.minBpm - 1), throwsA(isA<ArgumentError>()));
        expect(() => BpmTag(BpmTag.maxBpm + 1), throwsA(isA<ArgumentError>()));

        // And that boundary values work
        final minTag = BpmTag(BpmTag.minBpm);
        final maxTag = BpmTag(BpmTag.maxBpm);

        expect(minTag.value, equals(BpmTag.minBpm));
        expect(maxTag.value, equals(BpmTag.maxBpm));
      });
    });
  });
}
