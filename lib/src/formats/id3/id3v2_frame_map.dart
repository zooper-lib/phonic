import '../../core/tag_key.dart';

/// Mapping tables for ID3v2 frame identifiers across different versions.
///
/// This class provides static mappings between unified [TagKey] values and
/// their corresponding ID3v2 frame identifiers for versions 2.2, 2.3, and 2.4.
/// The mappings handle the evolution of frame IDs across ID3v2 versions:
///
/// - **ID3v2.2**: Uses 3-character frame IDs (TT2, TP1, TAL, etc.)
/// - **ID3v2.3**: Uses 4-character frame IDs (TIT2, TPE1, TALB, etc.)
/// - **ID3v2.4**: Same 4-character IDs as v2.3 with some additions (TDRC, etc.)
///
/// Example usage:
/// ```dart
/// // Get frame ID for title in different versions
/// final v22TitleFrame = Id3v2FrameMap.v22[TagKey.title]; // "TT2"
/// final v23TitleFrame = Id3v2FrameMap.v23[TagKey.title]; // "TIT2"
/// final v24TitleFrame = Id3v2FrameMap.v24[TagKey.title]; // "TIT2"
///
/// // Check if a tag is supported in a specific version
/// final supportsRating = Id3v2FrameMap.v22.containsKey(TagKey.rating); // true
/// final supportsDateRecorded = Id3v2FrameMap.v22.containsKey(TagKey.dateRecorded); // false
/// ```
///
/// The mappings are based on the official ID3v2 specifications and common
/// implementations. Not all tags are supported in all versions - for example,
/// ID3v2.2 has more limited field support compared to later versions.
class Id3v2FrameMap {
  /// Frame ID mappings for ID3v2.4.
  ///
  /// ID3v2.4 uses 4-character frame IDs and includes the most comprehensive
  /// set of supported fields. Notable features:
  /// - Uses TDRC for recording date (replaces TYER/TDAT/TIME from v2.3)
  /// - Supports UTF-8 encoding
  /// - All standard metadata fields are supported
  static const Map<TagKey, String> v24 = {
    TagKey.title: 'TIT2',
    TagKey.artist: 'TPE1',
    TagKey.album: 'TALB',
    TagKey.albumArtist: 'TPE2',
    TagKey.trackNumber: 'TRCK',
    TagKey.discNumber: 'TPOS',
    TagKey.dateRecorded: 'TDRC',
    TagKey.year: 'TDRC', // ID3v2.4 uses TDRC for both dateRecorded and year
    TagKey.genre: 'TCON',
    TagKey.comment: 'COMM',
    TagKey.bpm: 'TBPM',
    TagKey.musicalKey: 'TKEY',
    TagKey.rating: 'POPM',
    TagKey.lyrics: 'USLT',
    TagKey.artwork: 'APIC',
    TagKey.grouping: 'TIT1',
    TagKey.composer: 'TCOM',
    TagKey.encoder: 'TSSE',
    TagKey.isrc: 'TSRC',
    TagKey.custom: 'TXXX',
  };

  /// Frame ID mappings for ID3v2.3.
  ///
  /// ID3v2.3 uses 4-character frame IDs similar to v2.4 but with some differences:
  /// - Uses TYER for year instead of TDRC for full date
  /// - No UTF-8 encoding support (ISO-8859-1 and UTF-16 only)
  /// - Most standard metadata fields are supported
  static const Map<TagKey, String> v23 = {
    TagKey.title: 'TIT2',
    TagKey.artist: 'TPE1',
    TagKey.album: 'TALB',
    TagKey.albumArtist: 'TPE2',
    TagKey.trackNumber: 'TRCK',
    TagKey.discNumber: 'TPOS',
    TagKey.year: 'TYER', // v2.3 uses separate year field instead of TDRC
    TagKey.genre: 'TCON',
    TagKey.comment: 'COMM',
    TagKey.bpm: 'TBPM',
    TagKey.musicalKey: 'TKEY',
    TagKey.rating: 'POPM',
    TagKey.lyrics: 'USLT',
    TagKey.artwork: 'APIC',
    TagKey.grouping: 'TIT1',
    TagKey.composer: 'TCOM',
    TagKey.encoder: 'TSSE',
    TagKey.isrc: 'TSRC',
    TagKey.custom: 'TXXX',
  };

  /// Frame ID mappings for ID3v2.2.
  ///
  /// ID3v2.2 uses 3-character frame IDs and has more limited field support:
  /// - 3-character frame IDs (TT2, TP1, TAL, etc.)
  /// - Limited encoding support (ISO-8859-1 primarily)
  /// - Some modern fields are not supported (rating, lyrics, etc.)
  /// - No extended header support
  static const Map<TagKey, String> v22 = {
    TagKey.title: 'TT2',
    TagKey.artist: 'TP1',
    TagKey.album: 'TAL',
    TagKey.albumArtist: 'TP2',
    TagKey.trackNumber: 'TRK',
    TagKey.year: 'TYE',
    TagKey.genre: 'TCO',
    TagKey.comment: 'COM',
    TagKey.bpm: 'TBP',
    TagKey.grouping: 'TT1',
    TagKey.composer: 'TCM',
    TagKey.encoder: 'TSS',
    TagKey.artwork: 'PIC', // Uses PIC instead of APIC
    TagKey.custom: 'TXX',
    // Note: Some fields not supported in v2.2:
    // - discNumber (TPOS/TPA not standardized)
    // - musicalKey (TKEY not available)
    // - rating (POPM not available)
    // - lyrics (USLT not available)
    // - isrc (TSRC not available)
  };

  /// Returns all supported tag keys for the specified ID3v2 version.
  ///
  /// This method provides a convenient way to check which tags are supported
  /// by a specific ID3v2 version without needing to access the maps directly.
  ///
  /// Example:
  /// ```dart
  /// final v22Tags = Id3v2FrameMap.getSupportedTags('2.2');
  /// final supportsRating = v22Tags.contains(TagKey.rating); // false
  /// ```
  static Set<TagKey> getSupportedTags(String version) {
    switch (version) {
      case '2.2':
        return v22.keys.toSet();
      case '2.3':
        return v23.keys.toSet();
      case '2.4':
        return v24.keys.toSet();
      default:
        throw ArgumentError('Unsupported ID3v2 version: $version');
    }
  }

  /// Returns the frame ID for a given tag key and ID3v2 version.
  ///
  /// Returns null if the tag is not supported in the specified version.
  ///
  /// Example:
  /// ```dart
  /// final frameId = Id3v2FrameMap.getFrameId(TagKey.title, '2.2'); // "TT2"
  /// final unsupported = Id3v2FrameMap.getFrameId(TagKey.rating, '2.2'); // null
  /// ```
  static String? getFrameId(TagKey tagKey, String version) {
    switch (version) {
      case '2.2':
        return v22[tagKey];
      case '2.3':
        return v23[tagKey];
      case '2.4':
        return v24[tagKey];
      default:
        throw ArgumentError('Unsupported ID3v2 version: $version');
    }
  }

  /// Returns the tag key for a given frame ID, searching across all versions.
  ///
  /// This method is useful when parsing ID3v2 tags and you need to determine
  /// which unified tag key corresponds to a frame ID. It searches all versions
  /// to handle cases where frame IDs might be ambiguous or version-specific.
  ///
  /// Returns null if the frame ID is not recognized in any version.
  ///
  /// Example:
  /// ```dart
  /// final tagKey = Id3v2FrameMap.getTagKey("TIT2"); // TagKey.title
  /// final v22TagKey = Id3v2FrameMap.getTagKey("TT2"); // TagKey.title
  /// final unknown = Id3v2FrameMap.getTagKey("XXXX"); // null
  /// ```
  static TagKey? getTagKey(String frameId) {
    // Check v2.4 first (most common)
    for (final entry in v24.entries) {
      if (entry.value == frameId) {
        return entry.key;
      }
    }

    // Check v2.3
    for (final entry in v23.entries) {
      if (entry.value == frameId) {
        return entry.key;
      }
    }

    // Check v2.2
    for (final entry in v22.entries) {
      if (entry.value == frameId) {
        return entry.key;
      }
    }

    return null;
  }

  /// Private constructor to prevent instantiation.
  ///
  /// This class only provides static methods and constants, so instantiation
  /// is not needed or allowed.
  Id3v2FrameMap._();
}
