import 'dart:convert';
import 'dart:typed_data';

import '../core/tag_key.dart';
import '../formats/vorbis/vorbis_comment_map.dart';
import 'byte_reader.dart';

/// Utilities for parsing Vorbis comment key=value pairs.
///
/// This class provides methods for parsing Vorbis comment structures used in
/// FLAC, OGG Vorbis, and Opus audio files. Vorbis comments use a simple
/// key=value format with UTF-8 encoding and native multi-value support.
///
/// ## Key Features
///
/// - **UTF-8 decoding**: All text fields are decoded using UTF-8 encoding
/// - **Case-insensitive keys**: Field names are matched case-insensitively
/// - **Multi-valued fields**: Native support for multiple values per field name
/// - **Key standardization**: Normalizes field names to uppercase for consistency
/// - **Robust parsing**: Handles malformed comments gracefully with error recovery
///
/// ## Vorbis Comment Structure
///
/// Vorbis comments follow this binary structure:
/// ```
/// [vendor_length][vendor_string][user_comment_list_length]
/// [user_comment_0_length][user_comment_0]
/// [user_comment_1_length][user_comment_1]
/// ...
/// [framing_bit]
/// ```
///
/// Each user comment is a UTF-8 encoded string in "KEY=VALUE" format.
///
/// ## Usage Example
///
/// ```dart
/// final parser = VorbisCommentParser();
/// final commentBytes = getVorbisCommentBlock();
///
/// // Parse all comments
/// final comments = parser.parseComments(commentBytes);
/// for (final comment in comments) {
///   print('${comment.key}: ${comment.value}');
/// }
///
/// // Get values for specific field
/// final titles = parser.getFieldValues(comments, 'TITLE');
/// final genres = parser.getFieldValues(comments, 'GENRE');
///
/// // Group by field name
/// final grouped = parser.groupCommentsByField(comments);
/// final allGenres = grouped['GENRE'] ?? [];
/// ```
class VorbisCommentParser {
  /// Creates a new Vorbis comment parser instance.
  ///
  /// The parser is stateless and thread-safe, suitable for concurrent use
  /// across multiple files and operations.
  const VorbisCommentParser();

  /// Parses Vorbis comment block from binary data.
  ///
  /// This method parses the complete Vorbis comment structure including
  /// the vendor string and all user comments. It handles the binary format
  /// with proper length prefixes and UTF-8 decoding.
  ///
  /// Parameters:
  /// - [commentBytes]: The raw Vorbis comment block bytes
  /// - [skipVendor]: Whether to skip parsing the vendor string (default: true)
  /// - [validateFraming]: Whether to validate the framing bit (default: false)
  ///
  /// Returns a list of [VorbisComment] objects representing all parsed comments.
  ///
  /// Throws [FormatException] if the comment block is malformed or cannot be parsed.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  ///
  /// for (final comment in comments) {
  ///   print('Field: ${comment.key}, Value: ${comment.value}');
  /// }
  /// ```
  List<VorbisComment> parseComments(
    Uint8List commentBytes, {
    bool skipVendor = true,
    bool validateFraming = false,
  }) {
    if (commentBytes.isEmpty) {
      return [];
    }

    final reader = ByteReader(commentBytes);
    final comments = <VorbisComment>[];

    try {
      // Parse vendor string
      final vendorLength = reader.readUint32(Endian.little);
      if (vendorLength > reader.remaining) {
        throw FormatException('Invalid vendor length: $vendorLength exceeds remaining bytes');
      }

      if (skipVendor) {
        reader.skip(vendorLength);
      } else {
        reader.readString(vendorLength, utf8); // Read vendor string but don't store it
      }

      // Parse user comment list length
      if (reader.remaining < 4) {
        throw const FormatException('Insufficient bytes for user comment list length');
      }

      final userCommentListLength = reader.readUint32(Endian.little);

      // Parse each user comment
      for (int i = 0; i < userCommentListLength; i++) {
        if (reader.remaining < 4) {
          // Graceful handling of truncated comment blocks
          break;
        }

        final commentLength = reader.readUint32(Endian.little);
        if (commentLength > reader.remaining) {
          // Skip malformed comment and continue
          break;
        }

        if (commentLength == 0) {
          // Skip empty comments
          continue;
        }

        try {
          final commentString = reader.readString(commentLength, utf8);
          final comment = _parseCommentString(commentString);
          if (comment != null) {
            comments.add(comment);
          }
        } catch (e) {
          // Skip malformed comment and continue parsing
          reader.skip(commentLength);
          continue;
        }
      }

      // Optionally validate framing bit (OGG specific)
      if (validateFraming && reader.hasRemaining) {
        final framingBit = reader.readUint8();
        if (framingBit != 1) {
          throw FormatException('Invalid framing bit: expected 1, got $framingBit');
        }
      }
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      throw FormatException('Failed to parse Vorbis comments: $e');
    }

    return comments;
  }

  /// Parses a single comment string in "KEY=VALUE" format.
  ///
  /// This method handles the parsing of individual comment strings, performing
  /// key normalization and validation. It supports empty values and handles
  /// edge cases gracefully.
  ///
  /// Parameters:
  /// - [commentString]: The comment string to parse
  /// - [normalizeKey]: Whether to normalize the key to uppercase (default: true)
  ///
  /// Returns a [VorbisComment] object, or null if the comment is invalid.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comment = parser.parseCommentString('TITLE=My Song');
  /// print('${comment?.key}: ${comment?.value}'); // TITLE: My Song
  /// ```
  VorbisComment? parseCommentString(
    String commentString, {
    bool normalizeKey = true,
  }) {
    return _parseCommentString(commentString, normalizeKey: normalizeKey);
  }

  /// Internal method to parse a comment string.
  VorbisComment? _parseCommentString(
    String commentString, {
    bool normalizeKey = true,
  }) {
    if (commentString.isEmpty) {
      return null;
    }

    final equalIndex = commentString.indexOf('=');
    if (equalIndex == -1 || equalIndex == 0) {
      // Invalid format: no equals sign or empty key
      return null;
    }

    final key = commentString.substring(0, equalIndex);
    final value = commentString.substring(equalIndex + 1);

    // Normalize key to uppercase for consistency
    final normalizedKey = normalizeKey ? key.toUpperCase() : key;

    // Validate key format (should contain only ASCII letters, numbers, and underscores)
    if (!_isValidFieldName(normalizedKey)) {
      return null;
    }

    return VorbisComment(
      key: normalizedKey,
      value: value,
      originalKey: key,
    );
  }

  /// Validates if a field name follows Vorbis comment conventions.
  ///
  /// Vorbis comment field names should contain only ASCII letters, numbers,
  /// and underscores. They should not start with a number.
  bool _isValidFieldName(String fieldName) {
    if (fieldName.isEmpty) {
      return false;
    }

    // Check if first character is a letter or underscore
    final firstChar = fieldName.codeUnitAt(0);
    if (!((firstChar >= 65 && firstChar <= 90) || // A-Z
        (firstChar >= 97 && firstChar <= 122) || // a-z
        firstChar == 95)) {
      // underscore
      return false;
    }

    // Check remaining characters
    for (int i = 1; i < fieldName.length; i++) {
      final char = fieldName.codeUnitAt(i);
      if (!((char >= 65 && char <= 90) || // A-Z
          (char >= 97 && char <= 122) || // a-z
          (char >= 48 && char <= 57) || // 0-9
          char == 95)) {
        // underscore
        return false;
      }
    }

    return true;
  }

  /// Gets all values for a specific field name from a list of comments.
  ///
  /// This method performs case-insensitive matching and returns all values
  /// associated with the specified field name. This is useful for multi-valued
  /// fields like GENRE or ARTIST.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  /// - [fieldName]: The field name to search for (case-insensitive)
  ///
  /// Returns a list of values for the specified field.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final genres = parser.getFieldValues(comments, 'GENRE');
  /// final artists = parser.getFieldValues(comments, 'artist'); // case-insensitive
  /// ```
  List<String> getFieldValues(List<VorbisComment> comments, String fieldName) {
    final normalizedFieldName = fieldName.toUpperCase();
    return comments.where((comment) => comment.key == normalizedFieldName).map((comment) => comment.value).toList();
  }

  /// Groups comments by field name for easier access.
  ///
  /// This method creates a map where keys are normalized field names and
  /// values are lists of all values for that field. This is particularly
  /// useful for handling multi-valued fields.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  ///
  /// Returns a map of field names to their values.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final grouped = parser.groupCommentsByField(comments);
  ///
  /// final title = grouped['TITLE']?.first;
  /// final genres = grouped['GENRE'] ?? [];
  /// ```
  Map<String, List<String>> groupCommentsByField(List<VorbisComment> comments) {
    final grouped = <String, List<String>>{};

    for (final comment in comments) {
      grouped.putIfAbsent(comment.key, () => []).add(comment.value);
    }

    return grouped;
  }

  /// Filters comments to only include standard Vorbis comment fields.
  ///
  /// This method uses the [VorbisCommentMap] to identify standard fields
  /// and filters out custom or non-standard fields. Useful when you only
  /// want to process known metadata fields.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  ///
  /// Returns a list containing only standard field comments.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final standardComments = parser.filterStandardFields(comments);
  /// ```
  List<VorbisComment> filterStandardFields(List<VorbisComment> comments) {
    return comments.where((comment) => VorbisCommentMap.isStandardField(comment.key)).toList();
  }

  /// Filters comments to only include custom (non-standard) fields.
  ///
  /// This method returns comments that are not part of the standard
  /// Vorbis comment field set. Useful for handling application-specific
  /// metadata.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  ///
  /// Returns a list containing only custom field comments.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final customComments = parser.filterCustomFields(comments);
  /// ```
  List<VorbisComment> filterCustomFields(List<VorbisComment> comments) {
    return comments.where((comment) => !VorbisCommentMap.isStandardField(comment.key)).toList();
  }

  /// Gets the first value for a specific field name.
  ///
  /// This is a convenience method for single-valued fields where you only
  /// need the first occurrence. Returns null if the field is not found.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  /// - [fieldName]: The field name to search for (case-insensitive)
  ///
  /// Returns the first value for the field, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final title = parser.getFirstFieldValue(comments, 'TITLE');
  /// final album = parser.getFirstFieldValue(comments, 'album'); // case-insensitive
  /// ```
  String? getFirstFieldValue(List<VorbisComment> comments, String fieldName) {
    final values = getFieldValues(comments, fieldName);
    return values.isEmpty ? null : values.first;
  }

  /// Checks if a specific field exists in the comments.
  ///
  /// This method performs case-insensitive matching to check if any comment
  /// with the specified field name exists.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  /// - [fieldName]: The field name to search for (case-insensitive)
  ///
  /// Returns true if the field exists, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final hasTitle = parser.hasField(comments, 'TITLE');
  /// final hasGenre = parser.hasField(comments, 'genre'); // case-insensitive
  /// ```
  bool hasField(List<VorbisComment> comments, String fieldName) {
    final normalizedFieldName = fieldName.toUpperCase();
    return comments.any((comment) => comment.key == normalizedFieldName);
  }

  /// Gets statistics about the parsed comments.
  ///
  /// This method provides useful information about the comment structure,
  /// including field counts and multi-value statistics.
  ///
  /// Parameters:
  /// - [comments]: List of parsed comments
  ///
  /// Returns a [VorbisCommentStats] object with parsing statistics.
  ///
  /// Example:
  /// ```dart
  /// final parser = VorbisCommentParser();
  /// final comments = parser.parseComments(commentBytes);
  /// final stats = parser.getCommentStats(comments);
  /// print('Total comments: ${stats.totalComments}');
  /// print('Unique fields: ${stats.uniqueFields}');
  /// ```
  VorbisCommentStats getCommentStats(List<VorbisComment> comments) {
    final grouped = groupCommentsByField(comments);
    final standardFields = filterStandardFields(comments);
    final customFields = filterCustomFields(comments);

    final multiValuedFields = grouped.entries.where((entry) => entry.value.length > 1).map((entry) => entry.key).toList();

    return VorbisCommentStats(
      totalComments: comments.length,
      uniqueFields: grouped.keys.length,
      standardFields: standardFields.length,
      customFields: customFields.length,
      multiValuedFields: multiValuedFields,
      fieldCounts: grouped.map((key, values) => MapEntry(key, values.length)),
    );
  }
}

/// Represents a single Vorbis comment key-value pair.
///
/// This class encapsulates a parsed Vorbis comment with normalized key
/// handling and preservation of the original key case for round-trip
/// compatibility.
class VorbisComment {
  /// The normalized field name (typically uppercase).
  final String key;

  /// The field value (UTF-8 decoded).
  final String value;

  /// The original field name as it appeared in the comment block.
  final String originalKey;

  /// Creates a new Vorbis comment.
  ///
  /// Parameters:
  /// - [key]: The normalized field name
  /// - [value]: The field value
  /// - [originalKey]: The original field name (defaults to [key])
  const VorbisComment({
    required this.key,
    required this.value,
    String? originalKey,
  }) : originalKey = originalKey ?? key;

  /// Returns the corresponding [TagKey] for this comment, if it's a standard field.
  ///
  /// Returns null for custom fields that don't map to standard tag keys.
  TagKey? get tagKey => VorbisCommentMap.getTagKey(key);

  /// Returns whether this is a standard Vorbis comment field.
  bool get isStandardField => VorbisCommentMap.isStandardField(key);

  /// Returns whether this is a custom (non-standard) field.
  bool get isCustomField => !isStandardField;

  @override
  String toString() => '$key=$value';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VorbisComment && other.key == key && other.value == value && other.originalKey == originalKey;
  }

  @override
  int get hashCode => Object.hash(key, value, originalKey);
}

/// Statistics about parsed Vorbis comments.
///
/// This class provides useful information about the structure and content
/// of parsed Vorbis comments, including field counts and multi-value analysis.
class VorbisCommentStats {
  /// Total number of comments parsed.
  final int totalComments;

  /// Number of unique field names.
  final int uniqueFields;

  /// Number of standard field comments.
  final int standardFields;

  /// Number of custom field comments.
  final int customFields;

  /// List of field names that have multiple values.
  final List<String> multiValuedFields;

  /// Map of field names to their value counts.
  final Map<String, int> fieldCounts;

  /// Creates new comment statistics.
  const VorbisCommentStats({
    required this.totalComments,
    required this.uniqueFields,
    required this.standardFields,
    required this.customFields,
    required this.multiValuedFields,
    required this.fieldCounts,
  });

  @override
  String toString() {
    return 'VorbisCommentStats('
        'total: $totalComments, '
        'unique: $uniqueFields, '
        'standard: $standardFields, '
        'custom: $customFields, '
        'multiValued: ${multiValuedFields.length}'
        ')';
  }
}
