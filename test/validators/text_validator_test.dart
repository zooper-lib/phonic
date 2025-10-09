import 'package:phonic/phonic.dart';
import 'package:test/test.dart';

void main() {
  group('TitleValidator', () {
    late TitleValidator validator;

    setUp(() {
      validator = const TitleValidator();
    });

    group('validate()', () {
      test('returns null for valid non-empty title', () {
        expect(validator.validate('My Song'), isNull);
      });

      test('returns null for title with leading/trailing whitespace', () {
        expect(validator.validate('  My Song  '), isNull);
      });

      test('returns null for title with special characters', () {
        expect(validator.validate('Song #1 (Live)'), isNull);
      });

      test('returns null for title with unicode characters', () {
        expect(validator.validate('Café Müller'), isNull);
      });

      test('returns null for single character title', () {
        expect(validator.validate('A'), isNull);
      });

      test('returns error map for empty title', () {
        final result = validator.validate('');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Title'));
        expect(errorDetails['actual'], equals(''));
      });

      test('returns error map for whitespace-only title', () {
        final result = validator.validate('   ');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Title'));
        expect(errorDetails['actual'], equals('   '));
      });

      test('returns error map for tab-only title', () {
        final result = validator.validate('\t\t');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
      });

      test('returns error map for newline-only title', () {
        final result = validator.validate('\n');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
      });
    });

    group('validateOrThrow()', () {
      test('returns trimmed value for valid title', () {
        expect(validator.validateOrThrow('My Song'), equals('My Song'));
      });

      test('trims leading whitespace', () {
        expect(validator.validateOrThrow('  My Song'), equals('My Song'));
      });

      test('trims trailing whitespace', () {
        expect(validator.validateOrThrow('My Song  '), equals('My Song'));
      });

      test('trims both leading and trailing whitespace', () {
        expect(validator.validateOrThrow('  My Song  '), equals('My Song'));
      });

      test('throws ArgumentError for empty title', () {
        expect(
          () => validator.validateOrThrow(''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Title cannot be empty'),
            ),
          ),
        );
      });

      test('throws ArgumentError for whitespace-only title', () {
        expect(
          () => validator.validateOrThrow('   '),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Title cannot be empty'),
            ),
          ),
        );
      });
    });

    group('formatErrorMessage()', () {
      test('formats empty error message correctly', () {
        final error = validator.validate('');
        final message = validator.formatErrorMessage(error!);
        expect(message, equals('Title cannot be empty. Actual: ""'));
      });

      test('formats whitespace error message correctly', () {
        final error = validator.validate('   ');
        final message = validator.formatErrorMessage(error!);
        expect(message, equals('Title cannot be empty. Actual: "   "'));
      });
    });

    group('isValid()', () {
      test('returns true for valid title', () {
        expect(TitleValidator.isValid('My Song'), isTrue);
      });

      test('returns true for title with whitespace', () {
        expect(TitleValidator.isValid('  My Song  '), isTrue);
      });

      test('returns false for empty title', () {
        expect(TitleValidator.isValid(''), isFalse);
      });

      test('returns false for whitespace-only title', () {
        expect(TitleValidator.isValid('   '), isFalse);
      });
    });
  });

  group('ArtistValidator', () {
    late ArtistValidator validator;

    setUp(() {
      validator = const ArtistValidator();
    });

    group('validate()', () {
      test('returns null for valid non-empty artist', () {
        expect(validator.validate('The Beatles'), isNull);
      });

      test('returns null for artist with leading/trailing whitespace', () {
        expect(validator.validate('  The Beatles  '), isNull);
      });

      test('returns null for artist with special characters', () {
        expect(validator.validate('AC/DC'), isNull);
      });

      test('returns null for single character artist', () {
        expect(validator.validate('A'), isNull);
      });

      test('returns error map for empty artist', () {
        final result = validator.validate('');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Artist'));
        expect(errorDetails['actual'], equals(''));
      });

      test('returns error map for whitespace-only artist', () {
        final result = validator.validate('   ');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Artist'));
      });
    });

    group('validateOrThrow()', () {
      test('returns trimmed value for valid artist', () {
        expect(validator.validateOrThrow('The Beatles'), equals('The Beatles'));
      });

      test('trims whitespace', () {
        expect(
          validator.validateOrThrow('  The Beatles  '),
          equals('The Beatles'),
        );
      });

      test('throws ArgumentError for empty artist', () {
        expect(
          () => validator.validateOrThrow(''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Artist cannot be empty'),
            ),
          ),
        );
      });
    });

    group('formatErrorMessage()', () {
      test('formats empty error message correctly', () {
        final error = validator.validate('');
        final message = validator.formatErrorMessage(error!);
        expect(message, equals('Artist cannot be empty. Actual: ""'));
      });
    });

    group('isValid()', () {
      test('returns true for valid artist', () {
        expect(ArtistValidator.isValid('The Beatles'), isTrue);
      });

      test('returns false for empty artist', () {
        expect(ArtistValidator.isValid(''), isFalse);
      });
    });
  });

  group('AlbumValidator', () {
    late AlbumValidator validator;

    setUp(() {
      validator = const AlbumValidator();
    });

    group('validate()', () {
      test('returns null for valid non-empty album', () {
        expect(validator.validate('Abbey Road'), isNull);
      });

      test('returns null for album with leading/trailing whitespace', () {
        expect(validator.validate('  Abbey Road  '), isNull);
      });

      test('returns null for album with special characters', () {
        expect(validator.validate('Album #1 (Deluxe Edition)'), isNull);
      });

      test('returns null for single character album', () {
        expect(validator.validate('A'), isNull);
      });

      test('returns error map for empty album', () {
        final result = validator.validate('');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Album'));
        expect(errorDetails['actual'], equals(''));
      });

      test('returns error map for whitespace-only album', () {
        final result = validator.validate('   ');
        expect(result, isNotNull);
        expect(result!.keys.single, equals('empty'));
        final errorDetails = result['empty']! as Map<String, dynamic>;
        expect(errorDetails['fieldName'], equals('Album'));
      });
    });

    group('validateOrThrow()', () {
      test('returns trimmed value for valid album', () {
        expect(validator.validateOrThrow('Abbey Road'), equals('Abbey Road'));
      });

      test('trims whitespace', () {
        expect(
          validator.validateOrThrow('  Abbey Road  '),
          equals('Abbey Road'),
        );
      });

      test('throws ArgumentError for empty album', () {
        expect(
          () => validator.validateOrThrow(''),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Album cannot be empty'),
            ),
          ),
        );
      });
    });

    group('formatErrorMessage()', () {
      test('formats empty error message correctly', () {
        final error = validator.validate('');
        final message = validator.formatErrorMessage(error!);
        expect(message, equals('Album cannot be empty. Actual: ""'));
      });
    });

    group('isValid()', () {
      test('returns true for valid album', () {
        expect(AlbumValidator.isValid('Abbey Road'), isTrue);
      });

      test('returns false for empty album', () {
        expect(AlbumValidator.isValid(''), isFalse);
      });
    });
  });

  group('TagValidators convenience access', () {
    test('provides access to TitleValidator', () {
      expect(TagValidators.title, isA<TitleValidator>());
      expect(TagValidators.title.validate('My Song'), isNull);
      expect(TagValidators.title.validate(''), isNotNull);
    });

    test('provides access to ArtistValidator', () {
      expect(TagValidators.artist, isA<ArtistValidator>());
      expect(TagValidators.artist.validate('The Beatles'), isNull);
      expect(TagValidators.artist.validate(''), isNotNull);
    });

    test('provides access to AlbumValidator', () {
      expect(TagValidators.album, isA<AlbumValidator>());
      expect(TagValidators.album.validate('Abbey Road'), isNull);
      expect(TagValidators.album.validate(''), isNotNull);
    });
  });

  group('Tag static validator access', () {
    test('TitleTag provides static validator', () {
      expect(TitleTag.validator, isA<TitleValidator>());
      expect(TitleTag.validator.validate('My Song'), isNull);
    });

    test('ArtistTag provides static validator', () {
      expect(ArtistTag.validator, isA<ArtistValidator>());
      expect(ArtistTag.validator.validate('The Beatles'), isNull);
    });

    test('AlbumTag provides static validator', () {
      expect(AlbumTag.validator, isA<AlbumValidator>());
      expect(AlbumTag.validator.validate('Abbey Road'), isNull);
    });
  });
}
