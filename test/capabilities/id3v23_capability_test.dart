import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/capabilities/id3v23_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/format_constraints.dart';
import 'package:phonic/src/core/tag_key.dart';

void main() {
  group('ID3v2.3 Capability Tests', () {
    test('capability has correct properties', () {
      expect(id3v23Capability.containerKind, equals(ContainerKind.id3v2));
      expect(id3v23Capability.containerVersion, equals('2.3'));
      expect(id3v23Capability.supports(TagKey.title), isTrue);
      expect(id3v23Capability.supports(TagKey.rating), isTrue);
    });

    test('constraints work correctly', () {
      expect(ID3v23Constraints.convertRatingFromPopm(0), equals(0));
      expect(ID3v23Constraints.convertRatingFromPopm(255), equals(100));
      expect(ID3v23Constraints.convertRatingToPopm(0), equals(0));
      expect(ID3v23Constraints.convertRatingToPopm(100), equals(255));
      expect(ID3v23Constraints.isValidYear(1995), isTrue);
      expect(ID3v23Constraints.isValidYear(999), isFalse);
    });
  });
}
