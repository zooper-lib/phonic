import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('EncoderTag', () {
    group('constructor', () {
      test('creates instance with encoder value and default provenance', () {
        const tag = EncoderTag('LAME 3.100');

        expect(tag.value, equals('LAME 3.100'));
        expect(tag.key, equals(TagKey.encoder));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with encoder value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = EncoderTag('Fraunhofer FDK AAC', provenance: provenance);

        expect(tag.value, equals('Fraunhofer FDK AAC'));
        expect(tag.key, equals(TagKey.encoder));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty encoder', () {
        const tag = EncoderTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.encoder));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = EncoderTag('🎵 Encoder Name with émojis and ñ special chars 中文');

        expect(tag.value, equals('🎵 Encoder Name with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.encoder));
      });

      test('creates instance with very long encoder name', () {
        final longEncoder = 'A' * 1000;
        final tag = EncoderTag(longEncoder);

        expect(tag.value, equals(longEncoder));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.encoder));
      });

      test('key is always TagKey.encoder', () {
        const tag1 = EncoderTag('Encoder 1');
        const tag2 = EncoderTag('Encoder 2');
        const tag3 = EncoderTag('');

        expect(tag1.key, equals(TagKey.encoder));
        expect(tag2.key, equals(TagKey.encoder));
        expect(tag3.key, equals(TagKey.encoder));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = EncoderTag(
          'Const Encoder',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Encoder'));
        expect(tag.key, equals(TagKey.encoder));
      });
    });

    group('withProvenance', () {
      test('returns new EncoderTag instance with updated provenance', () {
        const originalTag = EncoderTag(
          'LAME 3.100',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('LAME 3.100'));
        expect(originalTag.key, equals(TagKey.encoder));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('LAME 3.100'));
        expect(updatedTag.key, equals(TagKey.encoder));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns EncoderTag type specifically', () {
        const originalTag = EncoderTag('Test Encoder');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<EncoderTag>());
        expect(updatedTag.runtimeType, equals(EncoderTag));
      });

      test('preserves encoder value exactly', () {
        const originalTag = EncoderTag('Complex Encoder: éñ中文🎵 with special chars');
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
        const originalTag = EncoderTag(
          'Test Encoder',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        const noneProvenance = TagProvenance.none();
        final updatedTag = originalTag.withProvenance(noneProvenance);

        expect(updatedTag.provenance, equals(noneProvenance));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.none));
        expect(updatedTag.provenance.containerVersion, equals(''));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('works with all container kinds', () {
        const originalTag = EncoderTag('Test Encoder');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Encoder'));
          expect(updatedTag.key, equals(TagKey.encoder));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = EncoderTag('Test Encoder');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Encoder'));
          expect(updatedTag.key, equals(TagKey.encoder));
        }
      });
    });

    group('equality', () {
      test('equal instances with same encoder, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = EncoderTag('Same Encoder', provenance: provenance);
        const tag2 = EncoderTag('Same Encoder', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different encoders', () {
        const tag1 = EncoderTag('Encoder 1');
        const tag2 = EncoderTag('Encoder 2');

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

        const tag1 = EncoderTag('Same Encoder', provenance: provenance1);
        const tag2 = EncoderTag('Same Encoder', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = EncoderTag('Test Encoder');
        const tag2 = EncoderTag('Test Encoder');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty encoders', () {
        const tag1 = EncoderTag('');
        const tag2 = EncoderTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = EncoderTag('Encoder');
        const tag2 = EncoderTag('encoder');
        const tag3 = EncoderTag('ENCODER');

        expect(tag1, isNot(equals(tag2)));
        expect(tag1, isNot(equals(tag3)));
        expect(tag2, isNot(equals(tag3)));
      });
    });

    group('props', () {
      test('includes value, key, and provenance in correct order', () {
        const provenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.inferred,
        );
        const tag = EncoderTag('Test Encoder', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Encoder'));
        expect(tag.props[1], equals(TagKey.encoder));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = EncoderTag('Same Encoder');
        const tag2 = EncoderTag('Same Encoder');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and encoder', () {
        const tag = EncoderTag('My Favorite Encoder');
        final result = tag.toString();

        expect(result, contains('EncoderTag'));
        expect(result, contains('My Favorite Encoder'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = EncoderTag('Test Encoder', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('EncoderTag'));
        expect(result, contains('Test Encoder'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in encoder', () {
        const tag = EncoderTag('Special: éñ中文🎵');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🎵'));
      });

      test('handles empty encoder', () {
        const tag = EncoderTag('');
        final result = tag.toString();

        expect(result, contains('EncoderTag('));
        expect(result, contains('TagProvenance.none()'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = EncoderTag(
          'Immutable Encoder',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Encoder'));
        expect(tag.key, equals(TagKey.encoder));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = EncoderTag('Original Encoder');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Encoder'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Encoder'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = EncoderTag('String Encoder');
        const tag2 = EncoderTag('');
        const tag3 = EncoderTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains EncoderTag type', () {
        const originalTag = EncoderTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<EncoderTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(EncoderTag));
      });
    });

    group('edge cases', () {
      test('handles very long encoder values', () {
        final longEncoder = 'A' * 10000;
        final tag = EncoderTag(longEncoder);

        expect(tag.value, equals(longEncoder));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.encoder));
      });

      test('handles unicode and emoji in encoder values', () {
        const tag = EncoderTag('🎵 Encoder Name with émojis and ñ special chars 中文');
        expect(tag.value, equals('🎵 Encoder Name with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only encoders', () {
        const tag1 = EncoderTag(' ');
        const tag2 = EncoderTag('   ');
        const tag3 = EncoderTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles encoders with quotes and special formatting', () {
        const tag1 = EncoderTag('"Quoted Encoder"');
        const tag2 = EncoderTag("'Single Quoted'");
        const tag3 = EncoderTag('Encoder with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Encoder"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Encoder with\nnewlines\tand\ttabs'));
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = EncoderTag('Test Encoder');

        expect(tag, isA<EncoderTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = EncoderTag('Same Encoder');
        const tag2 = EncoderTag('Same Encoder');
        const tag3 = EncoderTag('Different Encoder');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = EncoderTag('Test Encoder');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'EncoderTag\(.*\)'));
        expect(result, contains('Test Encoder'));
        expect(result, contains('provenance:'));
      });
    });

    group('audio encoder use cases', () {
      test('handles common MP3 encoders correctly', () {
        const encoders = [
          'LAME 3.100',
          'LAME 3.99.5',
          'Fraunhofer FhG',
          'Xing',
          'FhG',
          'LAME',
          'GoGo',
          'Shine',
        ];

        for (final encoder in encoders) {
          final tag = EncoderTag(encoder);
          expect(tag.value, equals(encoder));
          expect(tag.key, equals(TagKey.encoder));
        }
      });

      test('handles AAC encoders', () {
        const tag1 = EncoderTag('Fraunhofer FDK AAC');
        const tag2 = EncoderTag('Apple AAC');
        const tag3 = EncoderTag('Nero AAC');
        const tag4 = EncoderTag('FAAC');

        expect(tag1.value, equals('Fraunhofer FDK AAC'));
        expect(tag2.value, equals('Apple AAC'));
        expect(tag3.value, equals('Nero AAC'));
        expect(tag4.value, equals('FAAC'));
      });

      test('handles FLAC encoders', () {
        const tag1 = EncoderTag('FLAC 1.3.4');
        const tag2 = EncoderTag('libFLAC 1.3.3');
        const tag3 = EncoderTag('reference libFLAC 1.3.4 20220220');

        expect(tag1.value, equals('FLAC 1.3.4'));
        expect(tag2.value, equals('libFLAC 1.3.3'));
        expect(tag3.value, equals('reference libFLAC 1.3.4 20220220'));
      });

      test('handles Vorbis encoders', () {
        const tag1 = EncoderTag('Xiph.Org libVorbis I 20200704 (Reducing Environment)');
        const tag2 = EncoderTag('aoTuV b6.03');
        const tag3 = EncoderTag('Vorbis');

        expect(tag1.value, equals('Xiph.Org libVorbis I 20200704 (Reducing Environment)'));
        expect(tag2.value, equals('aoTuV b6.03'));
        expect(tag3.value, equals('Vorbis'));
      });

      test('handles software with version numbers', () {
        const tag1 = EncoderTag('Audacity 3.2.4');
        const tag2 = EncoderTag('iTunes 12.12.4.1');
        const tag3 = EncoderTag('dBpoweramp Release 17.7');
        const tag4 = EncoderTag('foobar2000 1.6.11');

        expect(tag1.value, equals('Audacity 3.2.4'));
        expect(tag2.value, equals('iTunes 12.12.4.1'));
        expect(tag3.value, equals('dBpoweramp Release 17.7'));
        expect(tag4.value, equals('foobar2000 1.6.11'));
      });

      test('handles encoder with settings and parameters', () {
        const tag1 = EncoderTag('LAME 3.100 -V0');
        const tag2 = EncoderTag('LAME 3.99.5 --preset standard');
        const tag3 = EncoderTag('Fraunhofer FDK AAC (VBR Profile)');

        expect(tag1.value, equals('LAME 3.100 -V0'));
        expect(tag2.value, equals('LAME 3.99.5 --preset standard'));
        expect(tag3.value, equals('Fraunhofer FDK AAC (VBR Profile)'));
      });
    });

    group('hardware encoder use cases', () {
      test('handles hardware encoder names', () {
        const tag1 = EncoderTag('Apple Silicon M1');
        const tag2 = EncoderTag('Intel Quick Sync Video');
        const tag3 = EncoderTag('NVIDIA NVENC');
        const tag4 = EncoderTag('AMD VCE');

        expect(tag1.value, equals('Apple Silicon M1'));
        expect(tag2.value, equals('Intel Quick Sync Video'));
        expect(tag3.value, equals('NVIDIA NVENC'));
        expect(tag4.value, equals('AMD VCE'));
      });

      test('handles professional equipment encoders', () {
        const tag1 = EncoderTag('Pro Tools 2023.6');
        const tag2 = EncoderTag('Logic Pro X 10.7.4');
        const tag3 = EncoderTag('Cubase 12');

        expect(tag1.value, equals('Pro Tools 2023.6'));
        expect(tag2.value, equals('Logic Pro X 10.7.4'));
        expect(tag3.value, equals('Cubase 12'));
      });
    });
  });
}
