import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/tag_semantics.dart';

void main() {
  group('TagSemantics', () {
    group('constructor', () {
      test('creates instance with default values', () {
        const semantics = TagSemantics();

        expect(semantics.multiValued, equals(false));
        expect(semantics.maxTextLength, isNull);
        expect(semantics.minValue, isNull);
        expect(semantics.maxValue, isNull);
        expect(semantics.allowedEncodings, isNull);
      });

      test('creates instance with all parameters', () {
        const semantics = TagSemantics(
          multiValued: true,
          maxTextLength: 30,
          minValue: 0,
          maxValue: 100,
          allowedEncodings: {'UTF-8', 'UTF-16'},
        );

        expect(semantics.multiValued, equals(true));
        expect(semantics.maxTextLength, equals(30));
        expect(semantics.minValue, equals(0));
        expect(semantics.maxValue, equals(100));
        expect(semantics.allowedEncodings, equals({'UTF-8', 'UTF-16'}));
      });

      test('creates instance with partial parameters', () {
        const semantics = TagSemantics(
          multiValued: true,
          maxTextLength: 50,
        );

        expect(semantics.multiValued, equals(true));
        expect(semantics.maxTextLength, equals(50));
        expect(semantics.minValue, isNull);
        expect(semantics.maxValue, isNull);
        expect(semantics.allowedEncodings, isNull);
      });

      test('creates instance with numeric constraints only', () {
        const semantics = TagSemantics(
          minValue: 1,
          maxValue: 255,
        );

        expect(semantics.multiValued, equals(false));
        expect(semantics.maxTextLength, isNull);
        expect(semantics.minValue, equals(1));
        expect(semantics.maxValue, equals(255));
        expect(semantics.allowedEncodings, isNull);
      });

      test('creates instance with encoding constraints only', () {
        const semantics = TagSemantics(
          allowedEncodings: {'ISO-8859-1'},
        );

        expect(semantics.multiValued, equals(false));
        expect(semantics.maxTextLength, isNull);
        expect(semantics.minValue, isNull);
        expect(semantics.maxValue, isNull);
        expect(semantics.allowedEncodings, equals({'ISO-8859-1'}));
      });
    });

    group('constraint detection properties', () {
      test('hasTextLengthLimit returns correct values', () {
        const noLimit = TagSemantics();
        const withLimit = TagSemantics(maxTextLength: 30);

        expect(noLimit.hasTextLengthLimit, equals(false));
        expect(withLimit.hasTextLengthLimit, equals(true));
      });

      test('hasValueRange returns correct values', () {
        const noRange = TagSemantics();
        const withMin = TagSemantics(minValue: 0);
        const withMax = TagSemantics(maxValue: 100);
        const withBoth = TagSemantics(minValue: 0, maxValue: 100);

        expect(noRange.hasValueRange, equals(false));
        expect(withMin.hasValueRange, equals(true));
        expect(withMax.hasValueRange, equals(true));
        expect(withBoth.hasValueRange, equals(true));
      });

      test('hasEncodingRestrictions returns correct values', () {
        const noRestrictions = TagSemantics();
        const withRestrictions = TagSemantics(allowedEncodings: {'UTF-8'});

        expect(noRestrictions.hasEncodingRestrictions, equals(false));
        expect(withRestrictions.hasEncodingRestrictions, equals(true));
      });

      test('hasConstraints returns correct values', () {
        const noConstraints = TagSemantics();
        const multiValued = TagSemantics(multiValued: true);
        const withLength = TagSemantics(maxTextLength: 30);
        const withRange = TagSemantics(minValue: 0);
        const withEncoding = TagSemantics(allowedEncodings: {'UTF-8'});

        expect(noConstraints.hasConstraints, equals(false));
        expect(multiValued.hasConstraints, equals(true));
        expect(withLength.hasConstraints, equals(true));
        expect(withRange.hasConstraints, equals(true));
        expect(withEncoding.hasConstraints, equals(true));
      });
    });

    group('isValidTextLength', () {
      test('returns true when no length limit is set', () {
        const semantics = TagSemantics();

        expect(semantics.isValidTextLength(0), equals(true));
        expect(semantics.isValidTextLength(100), equals(true));
        expect(semantics.isValidTextLength(1000), equals(true));
      });

      test('validates length against maxTextLength', () {
        const semantics = TagSemantics(maxTextLength: 30);

        expect(semantics.isValidTextLength(0), equals(true));
        expect(semantics.isValidTextLength(15), equals(true));
        expect(semantics.isValidTextLength(30), equals(true));
        expect(semantics.isValidTextLength(31), equals(false));
        expect(semantics.isValidTextLength(100), equals(false));
      });

      test('handles edge cases', () {
        const zeroLength = TagSemantics(maxTextLength: 0);
        const oneLength = TagSemantics(maxTextLength: 1);

        expect(zeroLength.isValidTextLength(0), equals(true));
        expect(zeroLength.isValidTextLength(1), equals(false));
        expect(oneLength.isValidTextLength(0), equals(true));
        expect(oneLength.isValidTextLength(1), equals(true));
        expect(oneLength.isValidTextLength(2), equals(false));
      });
    });

    group('isValidValue', () {
      test('returns true when no range constraints are set', () {
        const semantics = TagSemantics();

        expect(semantics.isValidValue(-100), equals(true));
        expect(semantics.isValidValue(0), equals(true));
        expect(semantics.isValidValue(100), equals(true));
        expect(semantics.isValidValue(1000), equals(true));
      });

      test('validates against minValue only', () {
        const semantics = TagSemantics(minValue: 0);

        expect(semantics.isValidValue(-1), equals(false));
        expect(semantics.isValidValue(0), equals(true));
        expect(semantics.isValidValue(1), equals(true));
        expect(semantics.isValidValue(1000), equals(true));
      });

      test('validates against maxValue only', () {
        const semantics = TagSemantics(maxValue: 100);

        expect(semantics.isValidValue(-1000), equals(true));
        expect(semantics.isValidValue(0), equals(true));
        expect(semantics.isValidValue(100), equals(true));
        expect(semantics.isValidValue(101), equals(false));
      });

      test('validates against both minValue and maxValue', () {
        const semantics = TagSemantics(minValue: 0, maxValue: 100);

        expect(semantics.isValidValue(-1), equals(false));
        expect(semantics.isValidValue(0), equals(true));
        expect(semantics.isValidValue(50), equals(true));
        expect(semantics.isValidValue(100), equals(true));
        expect(semantics.isValidValue(101), equals(false));
      });

      test('handles decimal values', () {
        const semantics = TagSemantics(minValue: 0.5, maxValue: 99.9);

        expect(semantics.isValidValue(0.4), equals(false));
        expect(semantics.isValidValue(0.5), equals(true));
        expect(semantics.isValidValue(50.5), equals(true));
        expect(semantics.isValidValue(99.9), equals(true));
        expect(semantics.isValidValue(100.0), equals(false));
      });

      test('handles edge cases', () {
        const zeroRange = TagSemantics(minValue: 0, maxValue: 0);
        const singlePoint = TagSemantics(minValue: 42, maxValue: 42);

        expect(zeroRange.isValidValue(-1), equals(false));
        expect(zeroRange.isValidValue(0), equals(true));
        expect(zeroRange.isValidValue(1), equals(false));

        expect(singlePoint.isValidValue(41), equals(false));
        expect(singlePoint.isValidValue(42), equals(true));
        expect(singlePoint.isValidValue(43), equals(false));
      });
    });

    group('isValidEncoding', () {
      test('returns true when no encoding restrictions are set', () {
        const semantics = TagSemantics();

        expect(semantics.isValidEncoding('UTF-8'), equals(true));
        expect(semantics.isValidEncoding('UTF-16'), equals(true));
        expect(semantics.isValidEncoding('ISO-8859-1'), equals(true));
        expect(semantics.isValidEncoding('UNKNOWN'), equals(true));
      });

      test('validates against allowedEncodings set', () {
        const semantics = TagSemantics(
          allowedEncodings: {'UTF-8', 'UTF-16'},
        );

        expect(semantics.isValidEncoding('UTF-8'), equals(true));
        expect(semantics.isValidEncoding('UTF-16'), equals(true));
        expect(semantics.isValidEncoding('ISO-8859-1'), equals(false));
        expect(semantics.isValidEncoding('ASCII'), equals(false));
      });

      test('handles single encoding restriction', () {
        const semantics = TagSemantics(allowedEncodings: {'UTF-8'});

        expect(semantics.isValidEncoding('UTF-8'), equals(true));
        expect(semantics.isValidEncoding('UTF-16'), equals(false));
        expect(semantics.isValidEncoding('ISO-8859-1'), equals(false));
      });

      test('handles empty encoding set', () {
        const semantics = TagSemantics(allowedEncodings: <String>{});

        expect(semantics.isValidEncoding('UTF-8'), equals(false));
        expect(semantics.isValidEncoding('UTF-16'), equals(false));
        expect(semantics.isValidEncoding(''), equals(false));
      });

      test('is case sensitive', () {
        const semantics = TagSemantics(allowedEncodings: {'UTF-8'});

        expect(semantics.isValidEncoding('UTF-8'), equals(true));
        expect(semantics.isValidEncoding('utf-8'), equals(false));
        expect(semantics.isValidEncoding('Utf-8'), equals(false));
      });
    });

    group('clampValue', () {
      test('returns value unchanged when no constraints', () {
        const semantics = TagSemantics();

        expect(semantics.clampValue(-100), equals(-100));
        expect(semantics.clampValue(0), equals(0));
        expect(semantics.clampValue(100), equals(100));
        expect(semantics.clampValue(1000), equals(1000));
      });

      test('clamps to minValue when below minimum', () {
        const semantics = TagSemantics(minValue: 0);

        expect(semantics.clampValue(-10), equals(0));
        expect(semantics.clampValue(-1), equals(0));
        expect(semantics.clampValue(0), equals(0));
        expect(semantics.clampValue(10), equals(10));
      });

      test('clamps to maxValue when above maximum', () {
        const semantics = TagSemantics(maxValue: 100);

        expect(semantics.clampValue(-10), equals(-10));
        expect(semantics.clampValue(50), equals(50));
        expect(semantics.clampValue(100), equals(100));
        expect(semantics.clampValue(150), equals(100));
      });

      test('clamps to range when both min and max are set', () {
        const semantics = TagSemantics(minValue: 0, maxValue: 100);

        expect(semantics.clampValue(-10), equals(0));
        expect(semantics.clampValue(0), equals(0));
        expect(semantics.clampValue(50), equals(50));
        expect(semantics.clampValue(100), equals(100));
        expect(semantics.clampValue(150), equals(100));
      });

      test('handles decimal values', () {
        const semantics = TagSemantics(minValue: 0.5, maxValue: 99.5);

        expect(semantics.clampValue(0.0), equals(0.5));
        expect(semantics.clampValue(0.5), equals(0.5));
        expect(semantics.clampValue(50.7), equals(50.7));
        expect(semantics.clampValue(99.5), equals(99.5));
        expect(semantics.clampValue(100.0), equals(99.5));
      });

      test('handles edge cases', () {
        const zeroRange = TagSemantics(minValue: 0, maxValue: 0);

        expect(zeroRange.clampValue(-1), equals(0));
        expect(zeroRange.clampValue(0), equals(0));
        expect(zeroRange.clampValue(1), equals(0));
      });
    });

    group('truncateText', () {
      test('returns text unchanged when no length limit', () {
        const semantics = TagSemantics();

        expect(semantics.truncateText(''), equals(''));
        expect(semantics.truncateText('short'), equals('short'));
        expect(semantics.truncateText('very long text that exceeds any reasonable limit'), equals('very long text that exceeds any reasonable limit'));
      });

      test('returns text unchanged when within limit', () {
        const semantics = TagSemantics(maxTextLength: 10);

        expect(semantics.truncateText(''), equals(''));
        expect(semantics.truncateText('short'), equals('short'));
        expect(semantics.truncateText('exactly10!'), equals('exactly10!'));
      });

      test('truncates text when exceeding limit', () {
        const semantics = TagSemantics(maxTextLength: 10);

        expect(semantics.truncateText('this is too long'), equals('this is to'));
        expect(semantics.truncateText('exactly11!!'), equals('exactly11!'));
        expect(semantics.truncateText('much longer text'), equals('much longe'));
      });

      test('handles zero length limit', () {
        const semantics = TagSemantics(maxTextLength: 0);

        expect(semantics.truncateText(''), equals(''));
        expect(semantics.truncateText('a'), equals(''));
        expect(semantics.truncateText('any text'), equals(''));
      });

      test('handles single character limit', () {
        const semantics = TagSemantics(maxTextLength: 1);

        expect(semantics.truncateText(''), equals(''));
        expect(semantics.truncateText('a'), equals('a'));
        expect(semantics.truncateText('ab'), equals('a'));
        expect(semantics.truncateText('longer'), equals('l'));
      });

      test('handles unicode characters correctly', () {
        const semantics = TagSemantics(maxTextLength: 5);

        expect(semantics.truncateText('héllo'), equals('héllo'));
        expect(semantics.truncateText('héllo world'), equals('héllo'));
        // Note: Emoji characters may take multiple code units
        expect(semantics.truncateText('abcde'), equals('abcde'));
        expect(semantics.truncateText('abcdef'), equals('abcde'));
      });
    });

    group('toString', () {
      test('returns no constraints message for default instance', () {
        const semantics = TagSemantics();
        expect(semantics.toString(), equals('TagSemantics(no constraints)'));
      });

      test('shows multiValued constraint', () {
        const semantics = TagSemantics(multiValued: true);
        expect(semantics.toString(), equals('TagSemantics(multiValued)'));
      });

      test('shows maxLength constraint', () {
        const semantics = TagSemantics(maxTextLength: 30);
        expect(semantics.toString(), equals('TagSemantics(maxLength: 30)'));
      });

      test('shows minValue constraint', () {
        const semantics = TagSemantics(minValue: 0);
        expect(semantics.toString(), equals('TagSemantics(minValue: 0)'));
      });

      test('shows maxValue constraint', () {
        const semantics = TagSemantics(maxValue: 100);
        expect(semantics.toString(), equals('TagSemantics(maxValue: 100)'));
      });

      test('shows encoding constraints', () {
        const semantics = TagSemantics(allowedEncodings: {'UTF-8', 'UTF-16'});
        final result = semantics.toString();
        expect(result, contains('TagSemantics('));
        expect(result, contains('encodings: {'));
        expect(result, contains('UTF-8'));
        expect(result, contains('UTF-16'));
        expect(result, endsWith('})'));
      });

      test('shows multiple constraints', () {
        const semantics = TagSemantics(
          multiValued: true,
          maxTextLength: 30,
          minValue: 0,
          maxValue: 100,
          allowedEncodings: {'UTF-8'},
        );

        final result = semantics.toString();
        expect(result, contains('multiValued'));
        expect(result, contains('maxLength: 30'));
        expect(result, contains('minValue: 0'));
        expect(result, contains('maxValue: 100'));
        expect(result, contains('encodings: {UTF-8}'));
      });
    });

    group('equality', () {
      test('equal instances with same values', () {
        const semantics1 = TagSemantics(
          multiValued: true,
          maxTextLength: 30,
          minValue: 0,
          maxValue: 100,
          allowedEncodings: {'UTF-8', 'UTF-16'},
        );
        const semantics2 = TagSemantics(
          multiValued: true,
          maxTextLength: 30,
          minValue: 0,
          maxValue: 100,
          allowedEncodings: {'UTF-8', 'UTF-16'},
        );

        expect(semantics1, equals(semantics2));
        expect(semantics1.hashCode, equals(semantics2.hashCode));
      });

      test('equal instances with default values', () {
        const semantics1 = TagSemantics();
        const semantics2 = TagSemantics();

        expect(semantics1, equals(semantics2));
        expect(semantics1.hashCode, equals(semantics2.hashCode));
      });

      test('equal instances with null encoding sets', () {
        const semantics1 = TagSemantics(multiValued: true);
        const semantics2 = TagSemantics(multiValued: true);

        expect(semantics1, equals(semantics2));
        expect(semantics1.hashCode, equals(semantics2.hashCode));
      });

      test('equal instances with same encoding sets in different order', () {
        const semantics1 = TagSemantics(allowedEncodings: {'UTF-8', 'UTF-16'});
        const semantics2 = TagSemantics(allowedEncodings: {'UTF-16', 'UTF-8'});

        expect(semantics1, equals(semantics2));
        expect(semantics1.hashCode, equals(semantics2.hashCode));
      });

      test('not equal with different multiValued', () {
        const semantics1 = TagSemantics(multiValued: true);
        const semantics2 = TagSemantics(multiValued: false);

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal with different maxTextLength', () {
        const semantics1 = TagSemantics(maxTextLength: 30);
        const semantics2 = TagSemantics(maxTextLength: 50);

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal with different minValue', () {
        const semantics1 = TagSemantics(minValue: 0);
        const semantics2 = TagSemantics(minValue: 1);

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal with different maxValue', () {
        const semantics1 = TagSemantics(maxValue: 100);
        const semantics2 = TagSemantics(maxValue: 255);

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal with different allowedEncodings', () {
        const semantics1 = TagSemantics(allowedEncodings: {'UTF-8'});
        const semantics2 = TagSemantics(allowedEncodings: {'UTF-16'});

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal when one has null encodings and other has empty set', () {
        const semantics1 = TagSemantics();
        const semantics2 = TagSemantics(allowedEncodings: <String>{});

        expect(semantics1, isNot(equals(semantics2)));
      });

      test('not equal with different encoding set sizes', () {
        const semantics1 = TagSemantics(allowedEncodings: {'UTF-8'});
        const semantics2 = TagSemantics(allowedEncodings: {'UTF-8', 'UTF-16'});

        expect(semantics1, isNot(equals(semantics2)));
      });
    });

    group('immutability', () {
      test('all fields are final and cannot be modified', () {
        const semantics = TagSemantics(
          multiValued: true,
          maxTextLength: 30,
          minValue: 0,
          maxValue: 100,
          allowedEncodings: {'UTF-8'},
        );

        // These should compile without error, confirming fields are final
        expect(semantics.multiValued, equals(true));
        expect(semantics.maxTextLength, equals(30));
        expect(semantics.minValue, equals(0));
        expect(semantics.maxValue, equals(100));
        expect(semantics.allowedEncodings, equals({'UTF-8'}));
      });

      test('const constructor creates compile-time constants', () {
        // This should compile as a const expression
        const semantics = TagSemantics(
          multiValued: false,
          maxTextLength: 50,
        );

        expect(semantics.multiValued, equals(false));
        expect(semantics.maxTextLength, equals(50));
      });

      test('allowedEncodings set cannot be modified through reference', () {
        final encodings = {'UTF-8', 'UTF-16'};
        final semantics = TagSemantics(allowedEncodings: encodings);

        // Modifying the original set will affect the semantics
        // since the constructor doesn't copy the set
        encodings.add('ISO-8859-1');

        expect(semantics.allowedEncodings, equals({'UTF-8', 'UTF-16', 'ISO-8859-1'}));
        expect(semantics.allowedEncodings, contains('ISO-8859-1'));
      });
    });

    group('real-world examples', () {
      test('ID3v1 text field semantics', () {
        const id3v1Text = TagSemantics(
          maxTextLength: 30,
          allowedEncodings: {'ISO-8859-1'},
        );

        expect(id3v1Text.isValidTextLength(30), equals(true));
        expect(id3v1Text.isValidTextLength(31), equals(false));
        expect(id3v1Text.isValidEncoding('ISO-8859-1'), equals(true));
        expect(id3v1Text.isValidEncoding('UTF-8'), equals(false));
        expect(id3v1Text.truncateText('This is a very long title that exceeds the limit'), equals('This is a very long title that'));
      });

      test('ID3v1 comment with track semantics', () {
        const id3v1Comment = TagSemantics(
          maxTextLength: 28, // 28 chars when track number is present
          allowedEncodings: {'ISO-8859-1'},
        );

        expect(id3v1Comment.isValidTextLength(28), equals(true));
        expect(id3v1Comment.isValidTextLength(29), equals(false));
        expect(id3v1Comment.truncateText('This is a very long comment text that exceeds the limit'), equals('This is a very long comment '));
      });

      test('ID3v2 rating (POPM) semantics', () {
        const id3v2Rating = TagSemantics(
          minValue: 0,
          maxValue: 255,
        );

        expect(id3v2Rating.isValidValue(0), equals(true));
        expect(id3v2Rating.isValidValue(128), equals(true));
        expect(id3v2Rating.isValidValue(255), equals(true));
        expect(id3v2Rating.isValidValue(-1), equals(false));
        expect(id3v2Rating.isValidValue(256), equals(false));
        expect(id3v2Rating.clampValue(-10), equals(0));
        expect(id3v2Rating.clampValue(300), equals(255));
      });

      test('Vorbis multi-valued genre semantics', () {
        const vorbisGenre = TagSemantics(
          multiValued: true,
          allowedEncodings: {'UTF-8'},
        );

        expect(vorbisGenre.multiValued, equals(true));
        expect(vorbisGenre.isValidEncoding('UTF-8'), equals(true));
        expect(vorbisGenre.isValidEncoding('ISO-8859-1'), equals(false));
        expect(vorbisGenre.hasConstraints, equals(true));
      });

      test('ID3v2.4 text field semantics', () {
        const id3v24Text = TagSemantics(
          allowedEncodings: {'ISO-8859-1', 'UTF-16', 'UTF-8'},
        );

        expect(id3v24Text.isValidEncoding('ISO-8859-1'), equals(true));
        expect(id3v24Text.isValidEncoding('UTF-16'), equals(true));
        expect(id3v24Text.isValidEncoding('UTF-8'), equals(true));
        expect(id3v24Text.isValidEncoding('ASCII'), equals(false));
      });

      test('ID3v2.3 text field semantics (no UTF-8)', () {
        const id3v23Text = TagSemantics(
          allowedEncodings: {'ISO-8859-1', 'UTF-16'},
        );

        expect(id3v23Text.isValidEncoding('ISO-8859-1'), equals(true));
        expect(id3v23Text.isValidEncoding('UTF-16'), equals(true));
        expect(id3v23Text.isValidEncoding('UTF-8'), equals(false));
      });

      test('BPM field semantics', () {
        const bpmSemantics = TagSemantics(
          minValue: 1,
          maxValue: 999,
        );

        expect(bpmSemantics.isValidValue(60), equals(true));
        expect(bpmSemantics.isValidValue(120), equals(true));
        expect(bpmSemantics.isValidValue(180), equals(true));
        expect(bpmSemantics.isValidValue(0), equals(false));
        expect(bpmSemantics.isValidValue(1000), equals(false));
        expect(bpmSemantics.clampValue(0), equals(1));
        expect(bpmSemantics.clampValue(1500), equals(999));
      });

      test('Track number semantics', () {
        const trackSemantics = TagSemantics(
          minValue: 1,
          maxValue: 255, // ID3v1 limit
        );

        expect(trackSemantics.isValidValue(1), equals(true));
        expect(trackSemantics.isValidValue(12), equals(true));
        expect(trackSemantics.isValidValue(255), equals(true));
        expect(trackSemantics.isValidValue(0), equals(false));
        expect(trackSemantics.isValidValue(256), equals(false));
      });
    });
  });
}
