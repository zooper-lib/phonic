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

  test('MetadataTag is exported from main library', () {
    // This test verifies that MetadataTag and its test implementations can be imported
    const tag = TestStringTag('Test Value');

    expect(tag.value, equals('Test Value'));
    expect(tag.key, equals(TagKey.title));
    expect(tag.provenance, equals(const TagProvenance.none()));
  });

  test('MetadataTag withProvenance works through main library', () {
    const originalTag = TestStringTag('Test');
    const newProvenance = TagProvenance(
      ContainerKind.vorbis,
      '',
      TagConfidence.inferred,
    );

    final updatedTag = originalTag.withProvenance(newProvenance);

    expect(updatedTag.value, equals('Test'));
    expect(updatedTag.provenance, equals(newProvenance));
    expect(updatedTag, isA<TestStringTag>());
  });
}
