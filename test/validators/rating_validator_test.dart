import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('RatingValidator', () {
    const validator = RatingValidator();

    group('validate', () {
      test('returns null for valid ratings within range', () {
        expect(validator.validate(0), isNull);
        expect(validator.validate(50), isNull);
        expect(validator.validate(100), isNull);
        expect(validator.validate(1), isNull);
        expect(validator.validate(99), isNull);
      });

      test('returns null for null values', () {
        expect(validator.validate(null), isNull);
      });

      test('returns error map for ratings below minimum', () {
        final error = validator.validate(-1);
        expect(error, isNotNull);
        expect(error!['outOfRange'], isNotNull);
        final rangeError = error['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['min'], equals(0));
        expect(rangeError['max'], equals(100));
        expect(rangeError['actual'], equals(-1));
      });

      test('returns error map for ratings above maximum', () {
        final error = validator.validate(101);
        expect(error, isNotNull);
        expect(error!['outOfRange'], isNotNull);
        final rangeError = error['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['min'], equals(0));
        expect(rangeError['max'], equals(100));
        expect(rangeError['actual'], equals(101));
      });

      test('returns error map for extremely low values', () {
        final error = validator.validate(-1000);
        expect(error, isNotNull);
        final rangeError = error!['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['actual'], equals(-1000));
      });

      test('returns error map for extremely high values', () {
        final error = validator.validate(1000);
        expect(error, isNotNull);
        final rangeError = error!['outOfRange'] as Map<String, dynamic>;
        expect(rangeError['actual'], equals(1000));
      });
    });

    group('validateOrThrow', () {
      test('returns value for valid ratings', () {
        expect(validator.validateOrThrow(0), equals(0));
        expect(validator.validateOrThrow(50), equals(50));
        expect(validator.validateOrThrow(100), equals(100));
      });

      test('throws ArgumentError for invalid ratings', () {
        expect(
          () => validator.validateOrThrow(-1),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => validator.validateOrThrow(101),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('ArgumentError contains proper error message', () {
        try {
          validator.validateOrThrow(150);
          fail('Should have thrown ArgumentError');
        } on ArgumentError catch (e) {
          expect(e.message, contains('Rating must be between 0 and 100'));
        }
      });
    });

    group('formatErrorMessage', () {
      test('formats error message correctly', () {
        final error = {
          'outOfRange': {
            'min': 0,
            'max': 100,
            'actual': 150,
          },
        };
        final message = validator.formatErrorMessage(error);
        expect(message, equals('Rating must be between 0 and 100 (inclusive)'));
      });
    });

    group('isValid static method', () {
      test('returns true for valid ratings', () {
        expect(RatingValidator.isValid(0), isTrue);
        expect(RatingValidator.isValid(50), isTrue);
        expect(RatingValidator.isValid(100), isTrue);
      });

      test('returns true for null values', () {
        expect(RatingValidator.isValid(null), isTrue);
      });

      test('returns false for invalid ratings', () {
        expect(RatingValidator.isValid(-1), isFalse);
        expect(RatingValidator.isValid(101), isFalse);
        expect(RatingValidator.isValid(1000), isFalse);
      });
    });

    group('constants', () {
      test('min constant is correct', () {
        expect(RatingValidator.min, equals(0));
      });

      test('max constant is correct', () {
        expect(RatingValidator.max, equals(100));
      });

      test('outOfRangeError constant is correct', () {
        expect(RatingValidator.outOfRangeError, equals('outOfRange'));
      });
    });

    group('integration with RatingTag', () {
      test('RatingTag uses validator correctly', () {
        expect(() => RatingTag(50), returnsNormally);
        expect(() => RatingTag(0), returnsNormally);
        expect(() => RatingTag(100), returnsNormally);
      });

      test('RatingTag throws same error as validator', () {
        expect(() => RatingTag(101), throwsA(isA<ArgumentError>()));
        expect(() => RatingTag(-1), throwsA(isA<ArgumentError>()));
      });

      test('RatingTag.validator is accessible', () {
        expect(RatingTag.validator, isA<RatingValidator>());
        expect(RatingTag.validator.validate(50), isNull);
        expect(RatingTag.validator.validate(150), isNotNull);
      });
    });

    group('TagValidators convenience class', () {
      test('provides access to rating validator', () {
        expect(TagValidators.rating, isA<RatingValidator>());
        expect(TagValidators.rating.validate(50), isNull);
        expect(TagValidators.rating.validate(150), isNotNull);
      });
    });

    group('boundary conditions', () {
      test('validates exact boundary values', () {
        expect(validator.validate(0), isNull);
        expect(validator.validate(100), isNull);
      });

      test('invalidates values just outside boundaries', () {
        expect(validator.validate(-1), isNotNull);
        expect(validator.validate(101), isNotNull);
      });
    });

    group('error structure', () {
      test('error contains all required fields', () {
        final error = validator.validate(150);
        expect(error, isNotNull);
        expect(error!.containsKey('outOfRange'), isTrue);

        final rangeError = error['outOfRange'] as Map<String, dynamic>;
        expect(rangeError.containsKey('min'), isTrue);
        expect(rangeError.containsKey('max'), isTrue);
        expect(rangeError.containsKey('actual'), isTrue);
      });

      test('error values are correct types', () {
        final error = validator.validate(150);
        final rangeError = error!['outOfRange'] as Map<String, dynamic>;

        expect(rangeError['min'], isA<int>());
        expect(rangeError['max'], isA<int>());
        expect(rangeError['actual'], isA<int>());
      });
    });
  });
}
