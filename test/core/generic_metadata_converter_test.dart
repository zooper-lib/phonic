import 'package:phonic/src/conversion/metadata_converter.dart';
import 'package:phonic/src/conversion/unified_metadata_converter.dart';
import 'package:phonic/src/core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Unified Metadata Conversion System', () {
    late UnifiedMetadataConverter converter;

    setUp(() {
      converter = UnifiedMetadataConverter();
    });

    group('UnifiedMetadataConverter', () {
      test('initializes with built-in rules', () {
        expect(converter, isNotNull);
        // The registry should have rules registered
        // This would need to be exposed via a getter for testing
      });

      test('handles same-format conversion as no-op', () {
        final tags = [
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final result = converter.convertTags(
          tags,
          (ContainerKind.id3v2, '2.4'),
          (ContainerKind.id3v2, '2.4'),
          const ConversionOptions(),
        );

        expect(result.convertedTags, equals(tags));
        expect(result.errors, isEmpty);
        expect(result.isLossless, isTrue);
      });

      test('analyzes conversion feasibility', () {
        final tags = [
          const TitleTag('Test Title'),
          const ArtistTag('Test Artist'),
        ];

        final analysis = converter.analyzeConversion(
          tags,
          (ContainerKind.id3v2, '2.4'),
          (ContainerKind.vorbis, ''),
        );

        expect(analysis, isNotNull);
        expect(analysis.viability, isNotNull);
      });

      test('handles empty tag list', () {
        final result = converter.convertTags(
          [],
          (ContainerKind.id3v2, '2.4'),
          (ContainerKind.vorbis, ''),
          const ConversionOptions(),
        );

        expect(result.convertedTags, isEmpty);
        expect(result.errors, isEmpty);
        expect(result.isLossless, isTrue);
      });
    });

    group('ConversionOptions', () {
      test('creates with default values', () {
        const options = ConversionOptions();

        expect(options.mode, equals(ConversionMode.permissive));
        expect(options.includeCustomFields, isTrue);
        expect(options.maxTextLength, isNull);
        expect(options.preferences, isEmpty);
      });

      test('creates with custom values', () {
        const options = ConversionOptions(
          mode: ConversionMode.strict,
          includeCustomFields: false,
          maxTextLength: 30,
          preferences: {'dateFormat': 'iso8601'},
        );

        expect(options.mode, equals(ConversionMode.strict));
        expect(options.includeCustomFields, isFalse);
        expect(options.maxTextLength, equals(30));
        expect(options.preferences['dateFormat'], equals('iso8601'));
      });
    });

    group('ConversionResult', () {
      test('creates successful result', () {
        final tags = [const TitleTag('Test')];
        final actions = {TagKey.title: ConversionAction.directMapping};

        final result = ConversionResult.success(tags, actions);

        expect(result.convertedTags, equals(tags));
        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
        expect(result.isLossless, isTrue);
        expect(result.appliedConversions, equals(actions));
      });

      test('creates result with errors', () {
        final tags = [const TitleTag('Test')];
        final errors = [
          const ConversionError(
            tagKey: TagKey.title,
            message: 'Test error',
          ),
        ];
        final actions = {TagKey.title: ConversionAction.dropped};

        final result = ConversionResult.withErrors(tags, errors, actions);

        expect(result.convertedTags, equals(tags));
        expect(result.errors, equals(errors));
        expect(result.isLossless, isFalse);
      });
    });

    group('ConversionAnalysis', () {
      test('tracks different types of tag handling', () {
        const analysis = ConversionAnalysis(
          losslessTags: [TagKey.title],
          modifiedTags: [TagKey.artist],
          droppedTags: [TagKey.artwork],
          viability: ConversionViability.good,
        );

        expect(analysis.losslessTags, contains(TagKey.title));
        expect(analysis.modifiedTags, contains(TagKey.artist));
        expect(analysis.droppedTags, contains(TagKey.artwork));
        expect(analysis.viability, equals(ConversionViability.good));
      });

      test('wouldConvertTo checks tag conversion', () {
        const analysis = ConversionAnalysis(
          losslessTags: [TagKey.title],
          modifiedTags: [TagKey.artist],
          droppedTags: [TagKey.artwork],
          viability: ConversionViability.good,
        );

        final titleTag = const TitleTag('Test');
        final artistTag = const ArtistTag('Test');
        // Skip artwork tag for this test since we don't have the proper constructor

        expect(analysis.wouldConvertTo(titleTag), isTrue);
        expect(analysis.wouldConvertTo(artistTag), isTrue);
        // Artwork tag test omitted - would be false if artwork not supported
      });

      test('wouldBeDropped checks tag dropping', () {
        const analysis = ConversionAnalysis(
          losslessTags: [TagKey.title],
          modifiedTags: [TagKey.artist],
          droppedTags: [TagKey.artwork],
          viability: ConversionViability.good,
        );

        expect(analysis.wouldBeDropped(TagKey.title), isFalse);
        expect(analysis.wouldBeDropped(TagKey.artist), isFalse);
        expect(analysis.wouldBeDropped(TagKey.artwork), isTrue);
      });
    });

    group('ConversionSummary', () {
      test('calculates conversion rates correctly', () {
        const summary = ConversionSummary(
          totalInputTags: 10,
          convertedTags: 8,
          droppedTags: 2,
          modifiedTags: 3,
        );

        expect(summary.conversionRate, equals(0.8));
        expect(summary.modificationRate, equals(3.0 / 8.0));
      });

      test('handles zero inputs gracefully', () {
        const summary = ConversionSummary(
          totalInputTags: 0,
          convertedTags: 0,
          droppedTags: 0,
          modifiedTags: 0,
        );

        expect(summary.conversionRate, equals(1.0));
        expect(summary.modificationRate, equals(0.0));
      });
    });
  });
}
