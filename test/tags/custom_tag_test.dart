import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';

void main() {
  group('CustomTag', () {
    group('constructor', () {
      test('creates instance with custom value and default provenance', () {
        const tag = CustomTag('Application-specific metadata');

        expect(tag.value, equals('Application-specific metadata'));
        expect(tag.key, equals(TagKey.custom));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with custom value and custom provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = CustomTag('Vendor-specific data', provenance: provenance);

        expect(tag.value, equals('Vendor-specific data'));
        expect(tag.key, equals(TagKey.custom));
        expect(tag.provenance, equals(provenance));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(tag.provenance.containerVersion, equals('2.4'));
        expect(tag.provenance.confidence, equals(TagConfidence.certain));
      });

      test('creates instance with empty custom value', () {
        const tag = CustomTag('');

        expect(tag.value, equals(''));
        expect(tag.key, equals(TagKey.custom));
        expect(tag.provenance, equals(const TagProvenance.none()));
      });

      test('creates instance with unicode and special characters', () {
        const tag = CustomTag('🔧 Custom with émojis and ñ special chars 中文');

        expect(tag.value, equals('🔧 Custom with émojis and ñ special chars 中文'));
        expect(tag.key, equals(TagKey.custom));
      });

      test('creates instance with very long custom value', () {
        final longCustom = 'A' * 1000;
        final tag = CustomTag(longCustom);

        expect(tag.value, equals(longCustom));
        expect(tag.value.length, equals(1000));
        expect(tag.key, equals(TagKey.custom));
      });

      test('creates instance with multi-line custom value', () {
        const multiLineCustom = '''This is a multi-line custom field
that spans several lines
and includes various custom information
about the track.''';
        const tag = CustomTag(multiLineCustom);

        expect(tag.value, equals(multiLineCustom));
        expect(tag.key, equals(TagKey.custom));
      });

      test('key is always TagKey.custom', () {
        const tag1 = CustomTag('Custom 1');
        const tag2 = CustomTag('Custom 2');
        const tag3 = CustomTag('');

        expect(tag1.key, equals(TagKey.custom));
        expect(tag2.key, equals(TagKey.custom));
        expect(tag3.key, equals(TagKey.custom));
      });

      test('creates const instance', () {
        // This should compile as a const expression
        const tag = CustomTag(
          'Const Custom Value',
          provenance: TagProvenance.none(),
        );

        expect(tag.value, equals('Const Custom Value'));
        expect(tag.key, equals(TagKey.custom));
      });
    });

    group('withProvenance', () {
      test('returns new CustomTag instance with updated provenance', () {
        const originalTag = CustomTag(
          'Original Custom Value',
          provenance: TagProvenance(ContainerKind.id3v1, 'v1', TagConfidence.certain),
        );

        const newProvenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.inferred,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        // Original tag should be unchanged
        expect(originalTag.value, equals('Original Custom Value'));
        expect(originalTag.key, equals(TagKey.custom));
        expect(originalTag.provenance.containerKind, equals(ContainerKind.id3v1));
        expect(originalTag.provenance.containerVersion, equals('v1'));
        expect(originalTag.provenance.confidence, equals(TagConfidence.certain));

        // Updated tag should have new provenance but same value and key
        expect(updatedTag.value, equals('Original Custom Value'));
        expect(updatedTag.key, equals(TagKey.custom));
        expect(updatedTag.provenance.containerKind, equals(ContainerKind.id3v2));
        expect(updatedTag.provenance.containerVersion, equals('2.4'));
        expect(updatedTag.provenance.confidence, equals(TagConfidence.inferred));
      });

      test('returns CustomTag type specifically', () {
        const originalTag = CustomTag('Test Custom');
        const newProvenance = TagProvenance(
          ContainerKind.vorbis,
          '',
          TagConfidence.derived,
        );

        final updatedTag = originalTag.withProvenance(newProvenance);

        expect(updatedTag, isA<CustomTag>());
        expect(updatedTag.runtimeType, equals(CustomTag));
      });

      test('preserves custom value exactly', () {
        const originalTag = CustomTag('Complex Custom: éñ中文🔧 with special chars');
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
        const originalTag = CustomTag(
          'Test Custom',
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
        const originalTag = CustomTag('Test Custom');

        for (final kind in ContainerKind.values) {
          final provenance = TagProvenance(kind, 'v1', TagConfidence.certain);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.containerKind, equals(kind));
          expect(updatedTag.value, equals('Test Custom'));
          expect(updatedTag.key, equals(TagKey.custom));
        }
      });

      test('works with all confidence levels', () {
        const originalTag = CustomTag('Test Custom');

        for (final confidence in TagConfidence.values) {
          final provenance = TagProvenance(ContainerKind.id3v2, '2.4', confidence);
          final updatedTag = originalTag.withProvenance(provenance);

          expect(updatedTag.provenance.confidence, equals(confidence));
          expect(updatedTag.value, equals('Test Custom'));
          expect(updatedTag.key, equals(TagKey.custom));
        }
      });
    });

    group('equality', () {
      test('equal instances with same custom value, key, and provenance', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );

        const tag1 = CustomTag('Same Custom Value', provenance: provenance);
        const tag2 = CustomTag('Same Custom Value', provenance: provenance);

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('not equal with different custom values', () {
        const tag1 = CustomTag('Custom 1');
        const tag2 = CustomTag('Custom 2');

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

        const tag1 = CustomTag('Same Custom Value', provenance: provenance1);
        const tag2 = CustomTag('Same Custom Value', provenance: provenance2);

        expect(tag1, isNot(equals(tag2)));
      });

      test('equal with default provenance', () {
        const tag1 = CustomTag('Test Custom');
        const tag2 = CustomTag('Test Custom');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('equal with empty custom values', () {
        const tag1 = CustomTag('');
        const tag2 = CustomTag('');

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('handles case sensitivity correctly', () {
        const tag1 = CustomTag('Custom');
        const tag2 = CustomTag('custom');
        const tag3 = CustomTag('CUSTOM');

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
        const tag = CustomTag('Test Custom', provenance: provenance);

        expect(tag.props.length, equals(3));
        expect(tag.props[0], equals('Test Custom'));
        expect(tag.props[1], equals(TagKey.custom));
        expect(tag.props[2], equals(provenance));
      });

      test('props are consistent for equality', () {
        const tag1 = CustomTag('Same Custom');
        const tag2 = CustomTag('Same Custom');

        expect(tag1.props, equals(tag2.props));
      });
    });

    group('toString', () {
      test('returns formatted string with class name and custom value', () {
        const tag = CustomTag('My Custom Value');
        final result = tag.toString();

        expect(result, contains('CustomTag'));
        expect(result, contains('My Custom Value'));
        expect(result, contains('TagProvenance.none()'));
      });

      test('includes provenance information', () {
        const provenance = TagProvenance(
          ContainerKind.id3v2,
          '2.4',
          TagConfidence.certain,
        );
        const tag = CustomTag('Test Custom', provenance: provenance);
        final result = tag.toString();

        expect(result, contains('CustomTag'));
        expect(result, contains('Test Custom'));
        expect(result, contains('TagProvenance(id3v2 v2.4, certain)'));
      });

      test('handles special characters in custom value', () {
        const tag = CustomTag('Special: éñ中文🔧');
        final result = tag.toString();

        expect(result, contains('Special: éñ中文🔧'));
      });

      test('handles empty custom value', () {
        const tag = CustomTag('');
        final result = tag.toString();

        expect(result, contains('CustomTag('));
        expect(result, contains('TagProvenance.none()'));
      });

      test('handles multi-line custom values', () {
        const tag = CustomTag('Line 1\nLine 2\nLine 3');
        final result = tag.toString();

        expect(result, contains('Line 1\nLine 2\nLine 3'));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const tag = CustomTag(
          'Immutable Custom',
          provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
        );

        // These should compile without error, confirming fields are final
        expect(tag.value, equals('Immutable Custom'));
        expect(tag.key, equals(TagKey.custom));
        expect(tag.provenance.containerKind, equals(ContainerKind.id3v2));
      });

      test('withProvenance returns new instance without modifying original', () {
        const originalTag = CustomTag('Original Custom');
        const newProvenance = TagProvenance(
          ContainerKind.mp4,
          '1.0',
          TagConfidence.derived,
        );

        final newTag = originalTag.withProvenance(newProvenance);

        // Original should be unchanged
        expect(originalTag.provenance, equals(const TagProvenance.none()));
        expect(originalTag.value, equals('Original Custom'));

        // New tag should have updated provenance
        expect(newTag.provenance, equals(newProvenance));
        expect(newTag.value, equals('Original Custom'));

        // They should be different instances
        expect(identical(originalTag, newTag), isFalse);
      });
    });

    group('type safety', () {
      test('value is always String type', () {
        const tag1 = CustomTag('String Custom');
        const tag2 = CustomTag('');
        const tag3 = CustomTag('123');

        expect(tag1.value, isA<String>());
        expect(tag2.value, isA<String>());
        expect(tag3.value, isA<String>());
        expect(tag3.value, equals('123')); // String, not int
      });

      test('withProvenance maintains CustomTag type', () {
        const originalTag = CustomTag('Test');
        const newProvenance = TagProvenance.none();

        final newTag = originalTag.withProvenance(newProvenance);

        expect(newTag, isA<CustomTag>());
        expect(newTag.value, isA<String>());
        expect(newTag.runtimeType, equals(CustomTag));
      });
    });

    group('edge cases', () {
      test('handles very long custom values', () {
        final longCustom = 'A' * 10000;
        final tag = CustomTag(longCustom);

        expect(tag.value, equals(longCustom));
        expect(tag.value.length, equals(10000));
        expect(tag.key, equals(TagKey.custom));
      });

      test('handles unicode and emoji in custom values', () {
        const tag = CustomTag('🔧 Custom field with émojis and ñ special chars 中文');
        expect(tag.value, equals('🔧 Custom field with émojis and ñ special chars 中文'));
      });

      test('handles whitespace-only custom values', () {
        const tag1 = CustomTag(' ');
        const tag2 = CustomTag('   ');
        const tag3 = CustomTag('\t\n');

        expect(tag1.value, equals(' '));
        expect(tag2.value, equals('   '));
        expect(tag3.value, equals('\t\n'));
      });

      test('handles custom values with quotes and special formatting', () {
        const tag1 = CustomTag('"Quoted Custom"');
        const tag2 = CustomTag("'Single Quoted'");
        const tag3 = CustomTag('Custom with\nnewlines\tand\ttabs');

        expect(tag1.value, equals('"Quoted Custom"'));
        expect(tag2.value, equals("'Single Quoted'"));
        expect(tag3.value, equals('Custom with\nnewlines\tand\ttabs'));
      });

      test('handles typical custom field scenarios', () {
        const scenarios = [
          'Application-specific metadata field',
          'Vendor proprietary data: XYZ-123',
          'Custom rating system: 8.5/10',
          'Internal catalog reference: REF-2023-001',
          'Processing timestamp: 2023-12-15T10:30:00Z',
          'Quality assurance flag: APPROVED',
          'Custom genre classification: Neo-Progressive-Rock',
          'Licensing information: CC-BY-SA-4.0',
        ];

        for (final scenario in scenarios) {
          final tag = CustomTag(scenario);
          expect(tag.value, equals(scenario));
          expect(tag.key, equals(TagKey.custom));
        }
      });
    });

    group('integration with MetadataTag base class', () {
      test('extends MetadataTag<String> correctly', () {
        const tag = CustomTag('Test Custom');

        expect(tag, isA<CustomTag>());
        expect(tag.value, isA<String>());
        expect(tag.key, isA<TagKey>());
        expect(tag.provenance, isA<TagProvenance>());
      });

      test('implements Equatable through base class', () {
        const tag1 = CustomTag('Same Custom');
        const tag2 = CustomTag('Same Custom');
        const tag3 = CustomTag('Different Custom');

        expect(tag1 == tag2, isTrue);
        expect(tag1 == tag3, isFalse);
        expect(tag1.hashCode == tag2.hashCode, isTrue);
      });

      test('toString behavior matches base class pattern', () {
        const tag = CustomTag('Test Custom');
        final result = tag.toString();

        // Should follow the pattern from MetadataTag.toString()
        expect(result, matches(r'CustomTag\(.*\)'));
        expect(result, contains('Test Custom'));
        expect(result, contains('provenance:'));
      });
    });

    group('custom-specific scenarios', () {
      test('handles typical custom field use cases', () {
        const applicationData = CustomTag('MyApp-specific-data-v1.2');
        const vendorField = CustomTag('VENDOR_PROPRIETARY_FIELD=12345');
        const internalRef = CustomTag('Internal reference: TRACK-2023-001');
        const customRating = CustomTag('Custom rating system: 4.5 stars');

        expect(applicationData.key, equals(TagKey.custom));
        expect(vendorField.key, equals(TagKey.custom));
        expect(internalRef.key, equals(TagKey.custom));
        expect(customRating.key, equals(TagKey.custom));

        expect(applicationData.value, contains('MyApp'));
        expect(vendorField.value, contains('VENDOR'));
        expect(internalRef.value, contains('Internal'));
        expect(customRating.value, contains('stars'));
      });

      test('handles technical and metadata custom fields', () {
        const technical = CustomTag('Encoding parameters: VBR 320kbps, 44.1kHz');
        const processing = CustomTag('Audio processing: Normalized, EQ applied');
        const workflow = CustomTag('Workflow status: Mastered, QA approved');

        expect(technical.value, contains('VBR'));
        expect(processing.value, contains('Normalized'));
        expect(workflow.value, contains('QA'));
      });

      test('handles format-specific custom field scenarios', () {
        // ID3v2 TXXX frame scenario
        const id3Custom = CustomTag('User-defined text frame content');

        // Vorbis arbitrary field scenario
        const vorbisCustom = CustomTag('CUSTOM_FIELD_NAME=Custom Value');

        // MP4 freeform atom scenario
        const mp4Custom = CustomTag('----:com.example:CustomField');

        expect(id3Custom.value, contains('User-defined'));
        expect(vorbisCustom.value, contains('CUSTOM_FIELD'));
        expect(mp4Custom.value, contains('com.example'));
      });

      test('handles cross-format compatibility considerations', () {
        const portableCustom = CustomTag('Portable custom data');
        const formatSpecific = CustomTag('Format-specific proprietary data');
        const standardExtension = CustomTag('Extended standard field data');

        // All should have the same key regardless of intended format
        expect(portableCustom.key, equals(TagKey.custom));
        expect(formatSpecific.key, equals(TagKey.custom));
        expect(standardExtension.key, equals(TagKey.custom));
      });
    });
  });
}
