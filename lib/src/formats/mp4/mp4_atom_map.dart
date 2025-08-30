import '../../core/tag_key.dart';

/// Mapping table for MP4 atom identifiers.
///
/// This class provides static mappings between unified [TagKey] values and
/// their corresponding MP4 atom identifiers used in MP4, M4A, and other
/// MPEG-4 container formats. MP4 metadata is stored in atoms within the
/// 'ilst' (item list) atom inside the 'moov' (movie) atom.
///
/// The mappings handle both standard iTunes-style atoms and freeform atoms:
///
/// - **Standard atoms**: Use 4-character identifiers like ©nam, ©ART, etc.
/// - **Freeform atoms**: Use the format ----:domain:name for custom fields
/// - **Artwork atoms**: Use 'covr' atom with type-specific data
///
/// Example usage:
/// ```dart
/// // Get atom identifier for a tag key
/// final titleAtom = Mp4AtomMap.atoms[TagKey.title]; // "©nam"
/// final artistAtom = Mp4AtomMap.atoms[TagKey.artist]; // "©ART"
///
/// // Check if a tag is supported
/// final supportsRating = Mp4AtomMap.atoms.containsKey(TagKey.rating); // false (freeform)
/// final supportsTitle = Mp4AtomMap.atoms.containsKey(TagKey.title); // true
///
/// // Get all supported tag keys
/// final supportedTags = Mp4AtomMap.getSupportedTags();
///
/// // Work with freeform atoms
/// final customDomain = Mp4AtomMap.freeformDomain; // "com.phonic.tags"
/// final ratingAtom = Mp4AtomMap.getFreeformAtomName(TagKey.rating); // "RATING"
/// ```
///
/// Notable characteristics of MP4 atoms:
/// - Atom names are case-sensitive 4-character identifiers
/// - Standard iTunes atoms use © prefix for text fields
/// - Numeric fields use specific atom names (trkn, disk, tmpo, etc.)
/// - Artwork uses 'covr' atom with JPEG or PNG data
/// - Freeform atoms allow custom fields with domain namespacing
/// - UTF-8 encoding is standard for text fields
/// - Multiple values are supported for some atom types
class Mp4AtomMap {
  /// Standard atom mappings for MP4 metadata.
  ///
  /// Maps unified [TagKey] values to their corresponding standard MP4 atom
  /// identifiers. These atoms are widely supported across MP4-compatible
  /// players and follow iTunes metadata conventions.
  ///
  /// Standard atom conventions:
  /// - Text atoms typically use © prefix (©nam, ©ART, ©alb, etc.)
  /// - Numeric atoms use specific identifiers (trkn, disk, tmpo, etc.)
  /// - Some atoms have alternative names in different implementations
  /// - Atom names are exactly 4 characters and case-sensitive
  static const Map<TagKey, String> atoms = {
    TagKey.title: '©nam', // Title/Name
    TagKey.artist: '©ART', // Artist
    TagKey.album: '©alb', // Album
    TagKey.albumArtist: 'aART', // Album Artist
    TagKey.trackNumber: 'trkn', // Track Number (binary format: track/total)
    TagKey.discNumber: 'disk', // Disc Number (binary format: disc/total)
    TagKey.dateRecorded: '©day', // Release Date
    TagKey.genre: '©gen', // Genre
    TagKey.comment: '©cmt', // Comment
    TagKey.bpm: 'tmpo', // Tempo/BPM (16-bit integer)
    TagKey.lyrics: '©lyr', // Lyrics
    TagKey.artwork: 'covr', // Cover Art (JPEG/PNG data)
    TagKey.grouping: '©grp', // Grouping
    TagKey.composer: '©wrt', // Writer/Composer
    TagKey.encoder: '©too', // Encoding Tool
    // Note: Some fields use freeform atoms (see freeformAtoms map)
    // Note: year is derived from dateRecorded (©day atom)
  };

  /// Freeform atom mappings for fields not supported by standard atoms.
  ///
  /// These fields are stored as freeform atoms using the format:
  /// ----:domain:name where domain is [freeformDomain] and name is the field name.
  ///
  /// Freeform atoms allow custom metadata fields while maintaining compatibility
  /// with MP4 specifications. They are supported by most modern MP4 players
  /// but may not be recognized by older or simpler implementations.
  static const Map<TagKey, String> freeformAtoms = {
    TagKey.musicalKey: 'MUSICAL_KEY', // Musical Key
    TagKey.rating: 'RATING', // User Rating (0-100)
    TagKey.isrc: 'ISRC', // International Standard Recording Code
    TagKey.custom: 'CUSTOM', // Custom fields (domain varies)
  };

  /// Domain name used for freeform atoms.
  ///
  /// This domain is used in the freeform atom format ----:domain:name
  /// to namespace custom fields. Using a consistent domain helps avoid
  /// conflicts with other applications' custom fields.
  static const String freeformDomain = 'com.phonic.tags';

  /// Alternative atom names that may be encountered in MP4 files.
  ///
  /// Some MP4 files may use alternative or legacy atom names for the same
  /// semantic fields. This map helps with parsing files created by different
  /// software that may use non-standard atom names.
  static const Map<String, TagKey> alternativeAtoms = {
    // Standard atoms (included for reverse lookup)
    '©nam': TagKey.title,
    '©ART': TagKey.artist,
    '©alb': TagKey.album,
    'aART': TagKey.albumArtist,
    '©day': TagKey.dateRecorded,
    '©gen': TagKey.genre,
    '©cmt': TagKey.comment,
    '©lyr': TagKey.lyrics,
    '©grp': TagKey.grouping,
    '©wrt': TagKey.composer,
    '©too': TagKey.encoder,
    'trkn': TagKey.trackNumber,
    'disk': TagKey.discNumber,
    'tmpo': TagKey.bpm,
    'covr': TagKey.artwork,

    // Legacy or alternative atom names (uppercase variants)
    'TRKN': TagKey.trackNumber, // Some encoders use uppercase
    'DISK': TagKey.discNumber, // Some encoders use uppercase
    'TMPO': TagKey.bpm, // Some encoders use uppercase
    'COVR': TagKey.artwork, // Some encoders use uppercase
    // Additional legacy variants
    '©NAM': TagKey.title, // Uppercase variant
    '©ALB': TagKey.album, // Uppercase variant
    '©DAY': TagKey.dateRecorded, // Uppercase variant
    '©GEN': TagKey.genre, // Uppercase variant
    '©CMT': TagKey.comment, // Uppercase variant
    '©LYR': TagKey.lyrics, // Uppercase variant
    '©GRP': TagKey.grouping, // Uppercase variant
    '©WRT': TagKey.composer, // Uppercase variant
    '©TOO': TagKey.encoder, // Uppercase variant
  };

  /// Returns all supported tag keys for standard MP4 atoms.
  ///
  /// This method provides a convenient way to check which tags are supported
  /// by standard MP4 atoms without needing to access the map directly.
  /// Freeform atoms are not included in this list.
  ///
  /// Example:
  /// ```dart
  /// final standardTags = Mp4AtomMap.getSupportedTags();
  /// final supportsTitle = standardTags.contains(TagKey.title); // true
  /// final supportsRating = standardTags.contains(TagKey.rating); // false
  /// ```
  static Set<TagKey> getSupportedTags() {
    return atoms.keys.toSet();
  }

  /// Returns all tag keys supported by either standard or freeform atoms.
  ///
  /// This includes both standard iTunes-style atoms and custom freeform atoms,
  /// providing the complete set of tags that can be stored in MP4 files.
  ///
  /// Example:
  /// ```dart
  /// final allTags = Mp4AtomMap.getAllSupportedTags();
  /// final supportsRating = allTags.contains(TagKey.rating); // true (freeform)
  /// ```
  static Set<TagKey> getAllSupportedTags() {
    return {...atoms.keys, ...freeformAtoms.keys};
  }

  /// Returns the standard atom identifier for a given tag key.
  ///
  /// Returns null if the tag is not supported by standard MP4 atoms.
  /// Use [getFreeformAtomName] for tags that require freeform atoms.
  ///
  /// Example:
  /// ```dart
  /// final atomId = Mp4AtomMap.getAtomId(TagKey.title); // "©nam"
  /// final unsupported = Mp4AtomMap.getAtomId(TagKey.rating); // null
  /// ```
  static String? getAtomId(TagKey tagKey) {
    return atoms[tagKey];
  }

  /// Returns the freeform atom name for a given tag key.
  ///
  /// Returns null if the tag is not supported by freeform atoms.
  /// The returned name should be used with [freeformDomain] to construct
  /// the full freeform atom identifier: ----:domain:name
  ///
  /// Example:
  /// ```dart
  /// final atomName = Mp4AtomMap.getFreeformAtomName(TagKey.rating); // "RATING"
  /// final fullAtom = "----:${Mp4AtomMap.freeformDomain}:$atomName";
  /// ```
  static String? getFreeformAtomName(TagKey tagKey) {
    return freeformAtoms[tagKey];
  }

  /// Returns the tag key for a given atom identifier.
  ///
  /// This method searches both standard atoms and alternative atom names
  /// to handle files created by different MP4 implementations. Returns null
  /// if the atom identifier is not recognized.
  ///
  /// Example:
  /// ```dart
  /// final tagKey = Mp4AtomMap.getTagKey("©nam"); // TagKey.title
  /// final legacy = Mp4AtomMap.getTagKey("TRKN"); // TagKey.trackNumber
  /// final unknown = Mp4AtomMap.getTagKey("XXXX"); // null
  /// ```
  static TagKey? getTagKey(String atomId) {
    // Check standard atoms first
    for (final entry in atoms.entries) {
      if (entry.value == atomId) {
        return entry.key;
      }
    }

    // Check alternative atoms
    return alternativeAtoms[atomId];
  }

  /// Returns the tag key for a freeform atom name.
  ///
  /// This method looks up tag keys based on the name portion of freeform atoms
  /// (the part after ----:domain:). Returns null if the name is not recognized
  /// as a standard freeform field.
  ///
  /// Example:
  /// ```dart
  /// final tagKey = Mp4AtomMap.getTagKeyFromFreeform("RATING"); // TagKey.rating
  /// final unknown = Mp4AtomMap.getTagKeyFromFreeform("CUSTOM_FIELD"); // null
  /// ```
  static TagKey? getTagKeyFromFreeform(String atomName) {
    for (final entry in freeformAtoms.entries) {
      if (entry.value == atomName) {
        return entry.key;
      }
    }
    return null;
  }

  /// Returns whether an atom identifier is a standard MP4 atom.
  ///
  /// This method checks if the given atom identifier is recognized as a
  /// standard iTunes-style atom, including alternative names. Freeform
  /// atoms will return false.
  ///
  /// Example:
  /// ```dart
  /// final isStandard = Mp4AtomMap.isStandardAtom("©nam"); // true
  /// final isFreeform = Mp4AtomMap.isStandardAtom("----"); // false
  /// ```
  static bool isStandardAtom(String atomId) {
    return getTagKey(atomId) != null;
  }

  /// Returns whether an atom identifier represents a freeform atom.
  ///
  /// Freeform atoms use the format ----:domain:name and allow custom
  /// metadata fields. This method checks for the freeform atom prefix.
  ///
  /// Example:
  /// ```dart
  /// final isFreeform = Mp4AtomMap.isFreeformAtom("----:com.example:FIELD"); // true
  /// final isStandard = Mp4AtomMap.isFreeformAtom("©nam"); // false
  /// ```
  static bool isFreeformAtom(String atomId) {
    return atomId.startsWith('----:');
  }

  /// Parses a freeform atom identifier into its components.
  ///
  /// Returns a record with domain and name components, or null if the
  /// atom identifier is not a valid freeform atom format.
  ///
  /// Example:
  /// ```dart
  /// final parsed = Mp4AtomMap.parseFreeformAtom("----:com.example:FIELD");
  /// // Returns: (domain: "com.example", name: "FIELD")
  ///
  /// final invalid = Mp4AtomMap.parseFreeformAtom("©nam"); // null
  /// ```
  static ({String domain, String name})? parseFreeformAtom(String atomId) {
    if (!isFreeformAtom(atomId)) {
      return null;
    }

    final parts = atomId.split(':');
    if (parts.length != 3 || parts[0] != '----') {
      return null;
    }

    return (domain: parts[1], name: parts[2]);
  }

  /// Constructs a freeform atom identifier from domain and name.
  ///
  /// Creates a properly formatted freeform atom identifier using the
  /// ----:domain:name format required by MP4 specifications.
  ///
  /// Example:
  /// ```dart
  /// final atomId = Mp4AtomMap.buildFreeformAtom("com.example", "FIELD");
  /// // Returns: "----:com.example:FIELD"
  /// ```
  static String buildFreeformAtom(String domain, String name) {
    return '----:$domain:$name';
  }

  /// Private constructor to prevent instantiation.
  ///
  /// This class only provides static methods and constants, so instantiation
  /// is not needed or allowed.
  Mp4AtomMap._();
}
