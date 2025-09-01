import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('TagProvenance', () {
    group('constructor', () {
      test('creates instance with all parameters', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        expect(provenance.containerKind, equals(ContainerKind.id3v2));
        expect(provenance.containerVersion, equals('2.4'));
        expect(provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty version string', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );

        expect(provenance.containerKind, equals(ContainerKind.vorbis));
        expect(provenance.containerVersion, equals(''));
        expect(provenance.confidence, equals(TagConfidence.inferred));
      });

      test('creates instance with all container kinds', () {
        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(
            kind,
            'test-version',
            TagConfidence.derived,
          );

          expect(provenance.containerKind, equals(kind));
          expect(provenance.containerVersion, equals('test-version'));
          expect(provenance.confidence, equals(TagConfidence.derived));
        }
      });

      test('creates instance with all confidence levels', () {
        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(
            ContainerKind.mp4,
            '1.0',
            confidence,
          );

          expect(provenance.containerKind, equals(ContainerKind.mp4));
          expect(provenance.containerVersion, equals('1.0'));
          expect(provenance.confidence, equals(confidence));
        }
      });
    });

    group('none constructor', () {
      test('creates default provenance with none container', () {
        const provenance = TagProvenance.none();

        expect(provenance.containerKind, equals(ContainerKind.none));
        expect(provenance.containerVersion, equals(''));
        expect(provenance.confidence, equals(TagConfidence.certain));
      });

      test('multiple none instances are equal', () {
        const provenance1 = TagProvenance.none();
        const provenance2 = TagProvenance.none();

        expect(provenance1, equals(provenance2));
        expect(provenance1.hashCode, equals(provenance2.hashCode));
      });
    });

    group('equality', () {
      test('equal instances with same values', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        expect(provenance1, equals(provenance2));
        expect(provenance1.hashCode, equals(provenance2.hashCode));
      });

      test('not equal with different container kinds', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v1,
          '2.4',
          TagConfidence.certain,
        );

        expect(provenance1, isNot(equals(provenance2)));
      });

      test('not equal with different container versions', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v2,
          '2.3',
          TagConfidence.certain,
        );

        expect(provenance1, isNot(equals(provenance2)));
      });

      test('not equal with different confidence levels', () {
        const provenance1 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const provenance2 = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        expect(provenance1, isNot(equals(provenance2)));
      });

      test('equal to none constructor result', () {
        const provenance1 = TagProvenance.none();
        const provenance2 = TagProvenance(
          ContainerKind.none,
          '',
          TagConfidence.certain,
        );

        expect(provenance1, equals(provenance2));
        expect(provenance1.hashCode, equals(provenance2.hashCode));
      });
    });

    group('toString', () {
      test('returns special format for none provenance', () {
        const provenance = TagProvenance.none();
        expect(provenance.toString(), equals('TagProvenance.none()'));
      });

      test('returns formatted string with version', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        expect(
          provenance.toString(),
          equals('TagProvenance(id3v2 v2.4, certain)'),
        );
      });

      test('returns formatted string without version', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        expect(
          provenance.toString(),
          equals('TagProvenance(vorbis, inferred)'),
        );
      });

      test('handles all container kinds correctly', () {
        const testCases = [
          (ContainerKind.id3v1, 'v1', 'TagProvenance(id3v1 vv1, certain)'),
          (ContainerKind.id3v2, '2.3', 'TagProvenance(id3v2 v2.3, certain)'),
          (ContainerKind.vorbis, '', 'TagProvenance(vorbis, certain)'),
          (ContainerKind.mp4, '1.0', 'TagProvenance(mp4 v1.0, certain)'),
        ];

        for (final (kind, version, expected) in testCases) {
          final provenance = TagProvenance(kind, version, TagConfidence.certain);
          expect(provenance.toString(), equals(expected));
        }
      });

      test('handles all confidence levels correctly', () {
        const testCases = [
          (TagConfidence.certain, 'TagProvenance(id3v2 v2.4, certain)'),
          (TagConfidence.inferred, 'TagProvenance(id3v2 v2.4, inferred)'),
          (TagConfidence.derived, 'TagProvenance(id3v2 v2.4, derived)'),
        ];

        for (final (confidence, expected) in testCases) {
          final provenance = TagProvenance(
            ContainerKind.id3v2,
            '2.4',
            confidence,
          );
          expect(provenance.toString(), equals(expected));
        }
      });
    });

    group('props', () {
      test('includes all fields in props for equality', () {
        const provenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        expect(
          provenance.props,
          equals([ContainerKind.mp4, '1.0', TagConfidence.derived]),
        );
      });

      test('props order matches constructor parameter order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          'test',
          TagConfidence.inferred,
        );

        expect(provenance.props.length, equals(3));
        expect(provenance.props[0], equals(ContainerKind.vorbis));
        expect(provenance.props[1], equals('test'));
        expect(provenance.props[2], equals(TagConfidence.inferred));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        // These should compile without error, confirming fields are final
        expect(provenance.containerKind, equals(ContainerKind.id3v2));
        expect(provenance.containerVersion, equals('2.4'));
        expect(provenance.confidence, equals(TagConfidence.certain));
      });

      test('const constructor creates compile-time constants', () {
        // This should compile as a const expression
        const provenance = TagProvenance(
          ContainerKind.id3v1,
          'v1',
          TagConfidence.certain,
        );

        expect(provenance.containerKind, equals(ContainerKind.id3v1));
      });
    });
  });
}
