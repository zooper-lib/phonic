part of 'metadata_tag.dart';

// IMPORTANT: This file contains test helper classes only.
// These classes should NOT be used in production code.
// They exist solely to enable comprehensive testing of the sealed MetadataTag base class.

/// Test implementation of MetadataTag for string values.
///
/// This class is used internally for testing the base MetadataTag functionality.
/// It should not be used in production code and will be removed when concrete
/// tag implementations are available.
final class TestStringTag extends MetadataTag<String> {
  const TestStringTag(
    String value, {
    TagKey key = TagKey.title,
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(value: value, key: key, provenance: provenance);

  @override
  TestStringTag withProvenance(TagProvenance newProvenance) => TestStringTag(value, key: key, provenance: newProvenance);
}

/// Test implementation of MetadataTag for integer values.
///
/// This class is used internally for testing the base MetadataTag functionality.
/// It should not be used in production code and will be removed when concrete
/// tag implementations are available.
final class TestIntTag extends MetadataTag<int> {
  const TestIntTag(
    int value, {
    TagKey key = TagKey.trackNumber,
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(value: value, key: key, provenance: provenance);

  @override
  TestIntTag withProvenance(TagProvenance newProvenance) => TestIntTag(value, key: key, provenance: newProvenance);
}
