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

  test('TitleTag is exported from main library', () {
    const tag = TitleTag('Test Title');

    expect(tag.value, equals('Test Title'));
    expect(tag.key, equals(TagKey.title));
    expect(tag.provenance, equals(const TagProvenance.none()));
  });

  test('ArtistTag is exported from main library', () {
    const tag = ArtistTag('Test Artist');

    expect(tag.value, equals('Test Artist'));
    expect(tag.key, equals(TagKey.artist));
    expect(tag.provenance, equals(const TagProvenance.none()));
  });

  test('TagCapability is exported from main library', () {
    const capability = TagCapability(
      containerKind: ContainerKind.id3v1,
      containerVersion: 'v1',
      semanticsByKey: {
        TagKey.title: TagSemantics(maxTextLength: 30),
        TagKey.artist: TagSemantics(maxTextLength: 30),
      },
    );

    expect(capability.containerKind, equals(ContainerKind.id3v1));
    expect(capability.containerVersion, equals('v1'));
    expect(capability.supports(TagKey.title), equals(true));
    expect(capability.supports(TagKey.artwork), equals(false));
    expect(capability.supportedFieldCount, equals(2));
  });

  test('TagSemantics is exported from main library', () {
    const semantics = TagSemantics(
      maxTextLength: 30,
      minValue: 0,
      maxValue: 100,
    );

    expect(semantics.maxTextLength, equals(30));
    expect(semantics.minValue, equals(0));
    expect(semantics.maxValue, equals(100));
    expect(semantics.isValidTextLength(25), equals(true));
    expect(semantics.isValidTextLength(35), equals(false));
  });

  test('CorruptedContainerException is exported from main library', () {
    const exception = CorruptedContainerException(
      'Test corruption message',
      byteOffset: 1024,
      context: 'test context',
    );

    expect(exception.message, equals('Test corruption message'));
    expect(exception.byteOffset, equals(1024));
    expect(exception.context, equals('test context'));
    expect(exception, isA<PhonicException>());
    expect(exception, isA<Exception>());
  });
}
