/// Base class for all metadata tags
abstract class MetadataTag {
  /// Whether this tag has any meaningful content
  bool get hasContent;

  /// Clear all content from this tag
  void clear();

  /// Validate the tag content
  bool get isValid;

  /// Get validation errors if any
  List<String> get validationErrors;
}
