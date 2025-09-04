import 'package:phonic/src/capabilities/id3v23_capability.dart';
import 'package:phonic/src/capabilities/id3v24_capability.dart';
import 'package:phonic/src/conversion/datetime_group_converter.dart';
import 'package:phonic/src/conversion/metadata_converter.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:test/test.dart';

void main() {
  group('DateTimeGroupConverter', () {
    late DateTimeGroupConverter converter;

    setUp(() {
      converter = DateTimeGroupConverter();
    });

    test('handles Year → DateRecorded conversion (ID3v2.3 → ID3v2.4)', () {
      // Arrange
      final sourceTags = [YearTag(2023)];
      final context = const ConversionContext(
        sourceFormat: (ContainerKind.id3v2, '2.3'),
        targetFormat: (ContainerKind.id3v2, '2.4'),
        mode: ConversionMode.conservative,
        sourceCapabilities: id3v23Capability,
        targetCapabilities: id3v24Capability,
        options: {},
      );

      // Act
      final result = converter.convert(sourceTags, context);

      // Assert
      expect(result.success, isTrue);
      expect(result.convertedTags, hasLength(1));
      expect(result.convertedTags.first.key, equals(TagKey.dateRecorded));
      expect(result.convertedTags.first.value, equals('2023'));
      expect(result.appliedActions[TagKey.year], equals(ConversionAction.expansion));
    });

    test('handles DateRecorded → Year conversion (ID3v2.4 → ID3v2.3)', () {
      // Arrange
      final sourceTags = [DateRecordedTag('2023-03-15')];
      final context = const ConversionContext(
        sourceFormat: (ContainerKind.id3v2, '2.4'),
        targetFormat: (ContainerKind.id3v2, '2.3'),
        mode: ConversionMode.conservative,
        sourceCapabilities: id3v24Capability,
        targetCapabilities: id3v23Capability,
        options: {},
      );

      // Act
      final result = converter.convert(sourceTags, context);

      // Assert
      expect(result.success, isTrue);
      expect(result.convertedTags, hasLength(1));
      expect(result.convertedTags.first.key, equals(TagKey.year));
      expect(result.convertedTags.first.value, equals(2023));
      expect(result.appliedActions[TagKey.dateRecorded], equals(ConversionAction.consolidation));
    });

    test('applies to ID3v2 version transitions', () {
      expect(converter.appliesTo((ContainerKind.id3v2, '2.3'), (ContainerKind.id3v2, '2.4')), isTrue);
      expect(converter.appliesTo((ContainerKind.id3v2, '2.4'), (ContainerKind.id3v2, '2.3')), isTrue);
    });

    test('applies to cross-format conversions', () {
      expect(converter.appliesTo((ContainerKind.id3v2, '2.4'), (ContainerKind.vorbis, '')), isTrue);
      expect(converter.appliesTo((ContainerKind.vorbis, ''), (ContainerKind.mp4, '')), isTrue);
    });

    test('does not apply to same format conversions without date conflicts', () {
      expect(converter.appliesTo((ContainerKind.id3v2, '2.4'), (ContainerKind.id3v2, '2.4')), isFalse);
      expect(converter.appliesTo((ContainerKind.vorbis, ''), (ContainerKind.vorbis, '')), isFalse);
    });

    test('handles year-only date strings correctly', () {
      // Arrange
      final sourceTags = [DateRecordedTag('2023')];
      final context = const ConversionContext(
        sourceFormat: (ContainerKind.id3v2, '2.4'),
        targetFormat: (ContainerKind.id3v2, '2.3'),
        mode: ConversionMode.conservative,
        sourceCapabilities: id3v24Capability,
        targetCapabilities: id3v23Capability,
        options: {},
      );

      // Act
      final result = converter.convert(sourceTags, context);

      // Assert
      expect(result.success, isTrue);
      expect(result.convertedTags.first.value, equals(2023));
    });
  });
}
