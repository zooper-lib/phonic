import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_semantics.dart';
import 'package:phonic/src/utils/numeric_normalization.dart';
import 'package:test/test.dart';

void main() {
  group('NumericNormalization', () {
    group('Track Number Validation', () {
      test('validates valid track numbers', () {
        expect(NumericNormalization.validateTrackNumber(1), equals(1));
        expect(NumericNormalization.validateTrackNumber(5), equals(5));
        expect(NumericNormalization.validateTrackNumber(99), equals(99));
        expect(NumericNormalization.validateTrackNumber(9999), equals(9999));
      });

      test('throws ArgumentError for invalid track numbers', () {
        expect(
          () => NumericNormalization.validateTrackNumber(0),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateTrackNumber(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateTrackNumber(10000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clamps track numbers to valid range', () {
        expect(NumericNormalization.clampTrackNumber(0), equals(1));
        expect(NumericNormalization.clampTrackNumber(-5), equals(1));
        expect(NumericNormalization.clampTrackNumber(5), equals(5));
        expect(NumericNormalization.clampTrackNumber(10000), equals(9999));
        expect(NumericNormalization.clampTrackNumber(15000), equals(9999));
      });
    });

    group('Disc Number Validation', () {
      test('validates valid disc numbers', () {
        expect(NumericNormalization.validateDiscNumber(1), equals(1));
        expect(NumericNormalization.validateDiscNumber(2), equals(2));
        expect(NumericNormalization.validateDiscNumber(50), equals(50));
        expect(NumericNormalization.validateDiscNumber(999), equals(999));
      });

      test('throws ArgumentError for invalid disc numbers', () {
        expect(
          () => NumericNormalization.validateDiscNumber(0),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateDiscNumber(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateDiscNumber(1000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clamps disc numbers to valid range', () {
        expect(NumericNormalization.clampDiscNumber(0), equals(1));
        expect(NumericNormalization.clampDiscNumber(-3), equals(1));
        expect(NumericNormalization.clampDiscNumber(2), equals(2));
        expect(NumericNormalization.clampDiscNumber(1000), equals(999));
        expect(NumericNormalization.clampDiscNumber(2000), equals(999));
      });
    });

    group('BPM Validation', () {
      test('validates valid BPM values', () {
        expect(NumericNormalization.validateBpm(1), equals(1));
        expect(NumericNormalization.validateBpm(60), equals(60));
        expect(NumericNormalization.validateBpm(120), equals(120));
        expect(NumericNormalization.validateBpm(180), equals(180));
        expect(NumericNormalization.validateBpm(999), equals(999));
      });

      test('throws ArgumentError for invalid BPM values', () {
        expect(
          () => NumericNormalization.validateBpm(0),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateBpm(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateBpm(1000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clamps BPM values to valid range', () {
        expect(NumericNormalization.clampBpm(0), equals(1));
        expect(NumericNormalization.clampBpm(-10), equals(1));
        expect(NumericNormalization.clampBpm(120), equals(120));
        expect(NumericNormalization.clampBpm(1000), equals(999));
        expect(NumericNormalization.clampBpm(1500), equals(999));
      });
    });

    group('Rating Validation', () {
      test('validates valid rating values', () {
        expect(NumericNormalization.validateRating(0), equals(0));
        expect(NumericNormalization.validateRating(25), equals(25));
        expect(NumericNormalization.validateRating(50), equals(50));
        expect(NumericNormalization.validateRating(85), equals(85));
        expect(NumericNormalization.validateRating(100), equals(100));
      });

      test('throws ArgumentError for invalid rating values', () {
        expect(
          () => NumericNormalization.validateRating(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateRating(101),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateRating(150),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clamps rating values to valid range', () {
        expect(NumericNormalization.clampRating(-10), equals(0));
        expect(NumericNormalization.clampRating(-1), equals(0));
        expect(NumericNormalization.clampRating(50), equals(50));
        expect(NumericNormalization.clampRating(101), equals(100));
        expect(NumericNormalization.clampRating(150), equals(100));
      });
    });

    group('Year Validation', () {
      test('validates valid year values', () {
        expect(NumericNormalization.validateYear(1900), equals(1900));
        expect(NumericNormalization.validateYear(1950), equals(1950));
        expect(NumericNormalization.validateYear(1995), equals(1995));
        expect(NumericNormalization.validateYear(2023), equals(2023));
        expect(NumericNormalization.validateYear(2100), equals(2100));
      });

      test('throws ArgumentError for invalid year values', () {
        expect(
          () => NumericNormalization.validateYear(1899),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateYear(1800),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateYear(2101),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.validateYear(2200),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('clamps year values to valid range', () {
        expect(NumericNormalization.clampYear(1800), equals(1900));
        expect(NumericNormalization.clampYear(1899), equals(1900));
        expect(NumericNormalization.clampYear(1995), equals(1995));
        expect(NumericNormalization.clampYear(2101), equals(2100));
        expect(NumericNormalization.clampYear(2200), equals(2100));
      });
    });

    group('Container-Specific Normalization', () {
      late TagCapability id3v1Capability;
      late TagCapability id3v24Capability;
      late TagCapability vorbisCapability;

      setUp(() {
        id3v1Capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {
            TagKey.trackNumber: TagSemantics(maxValue: 255),
            TagKey.year: TagSemantics(maxValue: 2155),
          },
        );

        id3v24Capability = const TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {
            TagKey.trackNumber: TagSemantics(),
            TagKey.discNumber: TagSemantics(),
            TagKey.bpm: TagSemantics(),
            TagKey.rating: TagSemantics(),
            TagKey.year: TagSemantics(),
          },
        );

        vorbisCapability = const TagCapability(
          containerKind: ContainerKind.vorbis,
          containerVersion: '',
          semanticsByKey: {
            TagKey.trackNumber: TagSemantics(),
            TagKey.discNumber: TagSemantics(),
            TagKey.bpm: TagSemantics(),
            TagKey.rating: TagSemantics(),
            TagKey.year: TagSemantics(),
          },
        );
      });

      test('applies ID3v1 track number constraints', () {
        // Within ID3v1 limits
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.trackNumber,
            100,
            id3v1Capability,
          ),
          equals(100),
        );

        // Exceeds ID3v1 limits, should be clamped to 255
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.trackNumber,
            300,
            id3v1Capability,
          ),
          equals(255),
        );

        // Below minimum, should be clamped to 1
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.trackNumber,
            0,
            id3v1Capability,
          ),
          equals(1),
        );
      });

      test('applies ID3v1 year constraints', () {
        // Within ID3v1 limits
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.year,
            1995,
            id3v1Capability,
          ),
          equals(1995),
        );

        // Exceeds ID3v1 limits, should be clamped to 2155
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.year,
            2200,
            id3v1Capability,
          ),
          equals(2100), // Universal max is 2100, which is less than ID3v1 max
        );

        // Below minimum, should be clamped to 1900
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.year,
            1800,
            id3v1Capability,
          ),
          equals(1900),
        );
      });

      test('uses standard constraints for other containers', () {
        // ID3v2.4 should use standard constraints
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.trackNumber,
            300,
            id3v24Capability,
          ),
          equals(300),
        );

        // Vorbis should use standard constraints
        expect(
          NumericNormalization.normalizeForContainer(
            TagKey.bpm,
            500,
            vorbisCapability,
          ),
          equals(500),
        );
      });

      test('handles unsupported tag keys', () {
        expect(
          () => NumericNormalization.normalizeForContainer(
            TagKey.title, // Not a numeric tag
            100,
            id3v24Capability,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Range Queries', () {
      test('returns correct universal ranges', () {
        expect(
          NumericNormalization.getValidRange(TagKey.trackNumber),
          equals((1, 9999)),
        );
        expect(
          NumericNormalization.getValidRange(TagKey.discNumber),
          equals((1, 999)),
        );
        expect(
          NumericNormalization.getValidRange(TagKey.bpm),
          equals((1, 999)),
        );
        expect(
          NumericNormalization.getValidRange(TagKey.rating),
          equals((0, 100)),
        );
        expect(
          NumericNormalization.getValidRange(TagKey.year),
          equals((1900, 2100)),
        );
      });

      test('throws for unsupported tag keys', () {
        expect(
          () => NumericNormalization.getValidRange(TagKey.title),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => NumericNormalization.getValidRange(TagKey.artist),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('returns container-specific ranges', () {
        final id3v1Capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {},
        );

        final id3v24Capability = const TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {},
        );

        // ID3v1 has restricted track number range
        expect(
          NumericNormalization.getContainerRange(
            TagKey.trackNumber,
            id3v1Capability,
          ),
          equals((1, 255)),
        );

        // ID3v2.4 uses standard range
        expect(
          NumericNormalization.getContainerRange(
            TagKey.trackNumber,
            id3v24Capability,
          ),
          equals((1, 9999)),
        );

        // ID3v1 has restricted year range
        expect(
          NumericNormalization.getContainerRange(
            TagKey.year,
            id3v1Capability,
          ),
          equals((1900, 2155)),
        );
      });
    });

    group('Validation Helpers', () {
      test('isValidValue returns correct results', () {
        // Valid values
        expect(
          NumericNormalization.isValidValue(TagKey.trackNumber, 5),
          isTrue,
        );
        expect(
          NumericNormalization.isValidValue(TagKey.bpm, 120),
          isTrue,
        );
        expect(
          NumericNormalization.isValidValue(TagKey.rating, 85),
          isTrue,
        );

        // Invalid values
        expect(
          NumericNormalization.isValidValue(TagKey.trackNumber, 0),
          isFalse,
        );
        expect(
          NumericNormalization.isValidValue(TagKey.bpm, 1000),
          isFalse,
        );
        expect(
          NumericNormalization.isValidValue(TagKey.rating, -1),
          isFalse,
        );

        // Unsupported tag keys
        expect(
          NumericNormalization.isValidValue(TagKey.title, 100),
          isFalse,
        );
      });

      test('isValidForContainer returns correct results', () {
        final id3v1Capability = const TagCapability(
          containerKind: ContainerKind.id3v1,
          containerVersion: 'v1',
          semanticsByKey: {},
        );

        final id3v24Capability = const TagCapability(
          containerKind: ContainerKind.id3v2,
          containerVersion: '2.4',
          semanticsByKey: {},
        );

        // Valid for both containers
        expect(
          NumericNormalization.isValidForContainer(
            TagKey.trackNumber,
            100,
            id3v1Capability,
          ),
          isTrue,
        );
        expect(
          NumericNormalization.isValidForContainer(
            TagKey.trackNumber,
            100,
            id3v24Capability,
          ),
          isTrue,
        );

        // Valid for ID3v2.4 but not ID3v1
        expect(
          NumericNormalization.isValidForContainer(
            TagKey.trackNumber,
            300,
            id3v1Capability,
          ),
          isFalse,
        );
        expect(
          NumericNormalization.isValidForContainer(
            TagKey.trackNumber,
            300,
            id3v24Capability,
          ),
          isTrue,
        );
      });
    });

    group('Edge Cases', () {
      test('handles boundary values correctly', () {
        // Test exact boundary values
        expect(NumericNormalization.clampTrackNumber(1), equals(1));
        expect(NumericNormalization.clampTrackNumber(9999), equals(9999));
        expect(NumericNormalization.clampBpm(1), equals(1));
        expect(NumericNormalization.clampBpm(999), equals(999));
        expect(NumericNormalization.clampRating(0), equals(0));
        expect(NumericNormalization.clampRating(100), equals(100));
        expect(NumericNormalization.clampYear(1900), equals(1900));
        expect(NumericNormalization.clampYear(2100), equals(2100));
      });

      test('handles extreme values', () {
        // Test very large values
        expect(
          NumericNormalization.clampTrackNumber(1000000),
          equals(9999),
        );
        expect(
          NumericNormalization.clampBpm(50000),
          equals(999),
        );

        // Test very small values
        expect(
          NumericNormalization.clampTrackNumber(-1000000),
          equals(1),
        );
        expect(
          NumericNormalization.clampYear(-5000),
          equals(1900),
        );
      });

      test('validates argument error messages', () {
        try {
          NumericNormalization.validateTrackNumber(0);
          fail('Expected ArgumentError');
        } on ArgumentError catch (e) {
          expect(e.message, contains('Track number must be between 1 and 9999'));
        }

        try {
          NumericNormalization.validateBpm(1000);
          fail('Expected ArgumentError');
        } on ArgumentError catch (e) {
          expect(e.message, contains('BPM must be between 1 and 999'));
        }

        try {
          NumericNormalization.validateRating(150);
          fail('Expected ArgumentError');
        } on ArgumentError catch (e) {
          expect(e.message, contains('Rating must be between 0 and 100'));
        }
      });
    });

    group('Constants', () {
      test('has correct constant values', () {
        expect(NumericNormalization.minTrackNumber, equals(1));
        expect(NumericNormalization.maxTrackNumber, equals(9999));
        expect(NumericNormalization.minDiscNumber, equals(1));
        expect(NumericNormalization.maxDiscNumber, equals(999));
        expect(NumericNormalization.minBpm, equals(1));
        expect(NumericNormalization.maxBpm, equals(999));
        expect(NumericNormalization.minRating, equals(0));
        expect(NumericNormalization.maxRating, equals(100));
        expect(NumericNormalization.minYear, equals(1900));
        expect(NumericNormalization.maxYear, equals(2100));
        expect(NumericNormalization.id3v1MaxTrackNumber, equals(255));
        expect(NumericNormalization.id3v1MaxYear, equals(2155));
      });
    });
  });
}
