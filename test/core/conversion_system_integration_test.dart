import 'package:phonic/src/conversion/metadata_converter.dart';
import 'package:phonic/src/conversion/unified_metadata_converter.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/tags/tags.dart';
import 'package:test/test.dart';

/// Integration tests for the conversion system
void main() {
  group('Unified Metadata Conversion System Integration Tests', () {
    late UnifiedMetadataConverter converter;

    setUp(() {
      converter = UnifiedMetadataConverter();
    });

    test('should handle cross-format mapping between ID3v2.4 and Vorbis', () {
      final sourceTags = [
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
      ];

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        (ContainerKind.vorbis, ''),
        const ConversionOptions(),
      );

      expect(result.convertedTags, isNotEmpty);
      expect(result.errors, isEmpty);
    });

    test('should handle date time conversion', () {
      final sourceTags = [
        YearTag(2023),
      ];

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        (ContainerKind.vorbis, ''),
        const ConversionOptions(),
      );

      expect(result.convertedTags, isNotEmpty);
      expect(result.errors, isEmpty);
    });

    test('should handle capability degradation', () {
      final sourceTags = [
        const TitleTag('Very Long Title That Exceeds ID3v1 Limits And Should Be Truncated To Fit'),
      ];

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        (ContainerKind.id3v1, 'v1'), // Fixed: use 'v1' instead of empty string
        const ConversionOptions(),
      );

      expect(result.convertedTags, isNotEmpty);
      // Should not be completely lossless due to length limitation
      expect(result.isLossless, isFalse);
      // Should have warnings about truncation
      expect(result.warnings, isNotEmpty);
    });

    test('should handle multi-value conversion', () {
      final sourceTags = [
        const ArtistTag('Artist1/Artist2/Artist3'),
      ];

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        (ContainerKind.vorbis, ''),
        const ConversionOptions(),
      );

      expect(result.convertedTags, isNotEmpty);
      expect(result.errors, isEmpty);
    });

    test('should handle ID3 version transitions', () {
      final sourceTags = [
        YearTag(2023),
      ];

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.3'),
        (ContainerKind.id3v2, '2.4'),
        const ConversionOptions(),
      );

      expect(result.convertedTags, isNotEmpty);
      expect(result.errors, isEmpty);
    });

    test('should analyze conversion feasibility', () {
      final sourceTags = [
        const TitleTag('Test Title'),
        const ArtistTag('Test Artist'),
      ];

      final analysis = converter.analyzeConversion(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        (ContainerKind.vorbis, ''),
      );

      expect(analysis, isNotNull);
      expect(analysis.viability, isNotNull);
    });

    test('enhanced converter should route conversions correctly', () {
      final sourceTags = [
        const TitleTag('Test Title', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
        const ArtistTag('Test Artist', provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain)),
      ];

      final targetFormat = (ContainerKind.vorbis, '');

      final result = converter.convertTags(
        sourceTags,
        (ContainerKind.id3v2, '2.4'),
        targetFormat,
        const ConversionOptions(),
      );

      expect(result, isNotNull);
      expect(result.convertedTags, isNotEmpty);
      expect(result.convertedTags, hasLength(2));

      final titleTags = result.convertedTags.whereType<TitleTag>().toList();
      final artistTags = result.convertedTags.whereType<ArtistTag>().toList();

      expect(titleTags, hasLength(1));
      expect(artistTags, hasLength(1));
      expect(titleTags.first.value, equals('Test Title'));
      expect(artistTags.first.value, equals('Test Artist'));
    });
  });
}
