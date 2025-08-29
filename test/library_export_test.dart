import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/phonic.dart';

void main() {
  test('TagProvenance is exported from main library', () {
    // This test verifies that TagProvenance can be imported from the main library
    const provenance = TagProvenance(
      ContainerKind.id3v2,
      '2.4',
      TagConfidence.certain,
    );

    expect(provenance.containerKind, equals(ContainerKind.id3v2));
    expect(provenance.containerVersion, equals('2.4'));
    expect(provenance.confidence, equals(TagConfidence.certain));
  });

  test('TagProvenance.none() is accessible', () {
    const provenance = TagProvenance.none();

    expect(provenance.containerKind, equals(ContainerKind.none));
    expect(provenance.containerVersion, equals(''));
    expect(provenance.confidence, equals(TagConfidence.certain));
  });
}
