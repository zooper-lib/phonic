import 'dart:convert';
import 'dart:typed_data';

/// Configuration for unknown frame/atom preservation behavior.
///
/// This class controls how unknown or unrecognized frames and atoms are handled
/// during metadata read/write operations. Unknown data preservation helps maintain
/// compatibility with files that contain metadata not directly supported by the
/// unified tagging API, preventing data loss during round-trip operations.
///
/// ## Key Features
///
/// - **Configurable preservation**: Enable/disable preservation per container type
/// - **Safe preservation rules**: Avoid corrupting known structures
/// - **Memory management**: Control memory usage for preserved data
/// - **Selective preservation**: Filter which unknown data to preserve
/// - **Round-trip compatibility**: Maintain file integrity across read/write cycles
///
/// ## Usage Examples
///
/// ### Basic Preservation
/// ```dart
/// final config = UnknownDataPreservationConfig(
///   preserveUnknownFrames: true,
///   preserveUnknownAtoms: true,
/// );
///
/// final codec = Id3v24Codec(preservationConfig: config);
/// ```
///
/// ### Conservative Preservation
/// ```dart
/// final config = UnknownDataPreservationConfig.conservative();
/// // Only preserves well-known safe frame types
/// ```
///
/// ### Aggressive Preservation
/// ```dart
/// final config = UnknownDataPreservationConfig.aggressive();
/// // Preserves all unknown data with minimal filtering
/// ```
class UnknownDataPreservationConfig {
  /// Whether to preserve unknown ID3v2 frames during write operations.
  final bool preserveUnknownFrames;

  /// Whether to preserve unknown MP4 atoms during write operations.
  final bool preserveUnknownAtoms;

  /// Whether to preserve unknown Vorbis comment fields.
  final bool preserveUnknownVorbisFields;

  /// Maximum size in bytes for preserved unknown data per container.
  ///
  /// This prevents excessive memory usage from large unknown frames/atoms.
  /// Set to null for no limit (use with caution).
  final int? maxPreservedDataSize;

  /// Maximum number of unknown frames/atoms to preserve per container.
  ///
  /// This prevents excessive memory usage from many small unknown items.
  /// Set to null for no limit (use with caution).
  final int? maxPreservedItemCount;

  /// Frame IDs that should never be preserved (security/corruption risk).
  ///
  /// These frames are considered potentially dangerous or likely to cause
  /// corruption if preserved without proper understanding.
  final Set<String> blacklistedFrameIds;

  /// Atom types that should never be preserved (security/corruption risk).
  ///
  /// These atoms are considered potentially dangerous or likely to cause
  /// corruption if preserved without proper understanding.
  final Set<String> blacklistedAtomTypes;

  /// Whether to preserve frames/atoms that failed to parse.
  ///
  /// When false, only frames/atoms that are unknown (not in our mapping)
  /// are preserved. When true, also preserves frames/atoms that we recognize
  /// but failed to parse due to corruption or format issues.
  final bool preserveCorruptedData;

  /// Whether to validate preserved data before writing.
  ///
  /// When true, performs basic validation on preserved data to ensure it
  /// won't corrupt the container structure. Recommended for production use.
  final bool validatePreservedData;

  const UnknownDataPreservationConfig({
    this.preserveUnknownFrames = true,
    this.preserveUnknownAtoms = true,
    this.preserveUnknownVorbisFields = true,
    this.maxPreservedDataSize = 1024 * 1024, // 1MB default
    this.maxPreservedItemCount = 100,
    this.blacklistedFrameIds = const {
      'PRIV', // Private frame - could contain sensitive data
      'ENCR', // Encryption method registration - could break encryption
      'GRID', // Group identification registration - could break grouping
      'SIGN', // Signature frame - could break signature validation
    },
    this.blacklistedAtomTypes = const {
      'free', // Free space atom - could break file structure
      'skip', // Skip atom - could break file structure
      'mdat', // Media data atom - contains actual audio/video data
      'moov', // Movie atom - contains file structure
    },
    this.preserveCorruptedData = false,
    this.validatePreservedData = true,
  });

  /// Creates a conservative preservation configuration.
  ///
  /// This configuration prioritizes safety and compatibility over completeness,
  /// only preserving data that is very likely to be safe.
  factory UnknownDataPreservationConfig.conservative() {
    return const UnknownDataPreservationConfig(
      preserveUnknownFrames: true,
      preserveUnknownAtoms: true,
      preserveUnknownVorbisFields: true,
      maxPreservedDataSize: 256 * 1024, // 256KB limit
      maxPreservedItemCount: 50,
      blacklistedFrameIds: {
        'PRIV',
        'ENCR',
        'GRID',
        'SIGN',
        'OWNE',
        'COMR',
        'ETCO',
        'MLLT',
        'SYTC',
        'RVAD',
        'EQUA',
        'RVRB',
        'PCNT',
        'RBUF',
        'AENC',
        'LINK',
      },
      blacklistedAtomTypes: {
        'free',
        'skip',
        'mdat',
        'moov',
        'ftyp',
        'styp',
        'sidx',
        'ssix',
        'prft',
        'uuid',
        'moof',
        'mfra',
        'mfro',
        'tfra',
        'mfhd',
        'traf',
      },
      preserveCorruptedData: false,
      validatePreservedData: true,
    );
  }

  /// Creates an aggressive preservation configuration.
  ///
  /// This configuration prioritizes completeness over safety, preserving
  /// as much unknown data as possible. Use with caution in production.
  factory UnknownDataPreservationConfig.aggressive() {
    return const UnknownDataPreservationConfig(
      preserveUnknownFrames: true,
      preserveUnknownAtoms: true,
      preserveUnknownVorbisFields: true,
      maxPreservedDataSize: 10 * 1024 * 1024, // 10MB limit
      maxPreservedItemCount: 500,
      blacklistedFrameIds: {
        'ENCR', 'SIGN', // Only critical security frames
      },
      blacklistedAtomTypes: {
        'mdat', 'moov', // Only critical structure atoms
      },
      preserveCorruptedData: true,
      validatePreservedData: false, // Skip validation for speed
    );
  }

  /// Creates a disabled preservation configuration.
  ///
  /// This configuration disables all unknown data preservation, providing
  /// the fastest performance but potentially losing unknown metadata.
  factory UnknownDataPreservationConfig.disabled() {
    return const UnknownDataPreservationConfig(
      preserveUnknownFrames: false,
      preserveUnknownAtoms: false,
      preserveUnknownVorbisFields: false,
      maxPreservedDataSize: 0,
      maxPreservedItemCount: 0,
      blacklistedFrameIds: {},
      blacklistedAtomTypes: {},
      preserveCorruptedData: false,
      validatePreservedData: false,
    );
  }

  /// Checks if a frame ID should be preserved.
  bool shouldPreserveFrame(String frameId) {
    if (!preserveUnknownFrames) return false;
    if (blacklistedFrameIds.contains(frameId)) return false;
    return true;
  }

  /// Checks if an atom type should be preserved.
  bool shouldPreserveAtom(String atomType) {
    if (!preserveUnknownAtoms) return false;
    if (blacklistedAtomTypes.contains(atomType)) return false;
    return true;
  }

  /// Checks if a Vorbis comment field should be preserved.
  bool shouldPreserveVorbisField(String fieldName) {
    if (!preserveUnknownVorbisFields) return false;
    // Vorbis comments are generally safe, so no blacklist by default
    return true;
  }

  /// Checks if the preserved data size is within limits.
  bool isWithinSizeLimit(int currentSize, int additionalSize) {
    if (maxPreservedDataSize == null) return true;
    return (currentSize + additionalSize) <= maxPreservedDataSize!;
  }

  /// Checks if the preserved item count is within limits.
  bool isWithinItemLimit(int currentCount) {
    if (maxPreservedItemCount == null) return true;
    return currentCount < maxPreservedItemCount!;
  }
}

/// Represents preserved unknown data from a container.
///
/// This class holds the raw bytes and metadata for unknown frames, atoms,
/// or other container-specific data that should be preserved during
/// read/write operations.
class PreservedUnknownData {
  /// The type of unknown data (frame ID, atom type, field name, etc.).
  final String type;

  /// The raw bytes of the unknown data.
  final Uint8List data;

  /// The container format this data came from.
  final String containerFormat;

  /// Additional metadata about the preserved data.
  final Map<String, dynamic> metadata;

  /// Byte offset where this data was found in the original container.
  final int? originalOffset;

  /// Size of the data in bytes.
  int get size => data.length;

  const PreservedUnknownData({
    required this.type,
    required this.data,
    required this.containerFormat,
    this.metadata = const {},
    this.originalOffset,
  });

  /// Creates preserved data for an ID3v2 frame.
  factory PreservedUnknownData.id3v2Frame({
    required String frameId,
    required Uint8List frameData,
    required int frameFlags,
    int? originalOffset,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return PreservedUnknownData(
      type: frameId,
      data: frameData,
      containerFormat: 'id3v2',
      originalOffset: originalOffset,
      metadata: {
        'frame_flags': frameFlags,
        'frame_size': frameData.length,
        ...?additionalMetadata,
      },
    );
  }

  /// Creates preserved data for an MP4 atom.
  factory PreservedUnknownData.mp4Atom({
    required String atomType,
    required Uint8List atomData,
    int? originalOffset,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return PreservedUnknownData(
      type: atomType,
      data: atomData,
      containerFormat: 'mp4',
      originalOffset: originalOffset,
      metadata: {
        'atom_size': atomData.length,
        ...?additionalMetadata,
      },
    );
  }

  /// Creates preserved data for a Vorbis comment field.
  factory PreservedUnknownData.vorbisField({
    required String fieldName,
    required String fieldValue,
    int? originalOffset,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final fieldBytes = Uint8List.fromList('$fieldName=$fieldValue'.codeUnits);
    return PreservedUnknownData(
      type: fieldName,
      data: fieldBytes,
      containerFormat: 'vorbis',
      originalOffset: originalOffset,
      metadata: {
        'field_value': fieldValue,
        'field_length': fieldBytes.length,
        ...?additionalMetadata,
      },
    );
  }

  /// Validates that this preserved data is safe to write.
  ///
  /// Performs basic validation to ensure the preserved data won't corrupt
  /// the container structure when written back.
  bool isValidForWriting() {
    // Basic size validation
    if (data.isEmpty || data.length > 16 * 1024 * 1024) {
      return false; // Empty or too large (>16MB)
    }

    // Container-specific validation
    switch (containerFormat) {
      case 'id3v2':
        return _validateId3v2Frame();
      case 'mp4':
        return _validateMp4Atom();
      case 'vorbis':
        return _validateVorbisField();
      default:
        return false; // Unknown container format
    }
  }

  /// Validates ID3v2 frame data.
  bool _validateId3v2Frame() {
    // Frame ID should be 4 characters, all uppercase letters or digits
    if (type.length != 4) return false;

    for (int i = 0; i < type.length; i++) {
      final char = type.codeUnitAt(i);
      if (!((char >= 0x41 && char <= 0x5A) || (char >= 0x30 && char <= 0x39))) {
        return false; // Not A-Z or 0-9
      }
    }

    // Data should have reasonable size for a frame
    if (data.length > 1024 * 1024) return false; // >1MB is suspicious

    return true;
  }

  /// Validates MP4 atom data.
  bool _validateMp4Atom() {
    // Atom type should be 4 characters, printable ASCII
    if (type.length != 4) return false;

    for (int i = 0; i < type.length; i++) {
      final char = type.codeUnitAt(i);
      if (char < 0x20 || char > 0x7E) {
        return false; // Not printable ASCII
      }
    }

    // Data should have reasonable size for an atom
    if (data.length > 1024 * 1024) return false; // >1MB is suspicious

    return true;
  }

  /// Validates Vorbis comment field data.
  bool _validateVorbisField() {
    // Field name should be reasonable length and contain valid characters
    if (type.isEmpty || type.length > 255) return false;

    // Field name should be uppercase letters, digits, or underscore
    for (int i = 0; i < type.length; i++) {
      final char = type.codeUnitAt(i);
      if (!((char >= 0x41 && char <= 0x5A) || (char >= 0x30 && char <= 0x39) || char == 0x5F)) {
        return false; // Not A-Z, 0-9, or _
      }
    }

    // Data should be valid UTF-8 and reasonable size
    try {
      utf8.decode(data);
    } catch (e) {
      return false; // Invalid UTF-8
    }

    if (data.length > 64 * 1024) return false; // >64KB is suspicious for text

    return true;
  }

  @override
  String toString() {
    return 'PreservedUnknownData(type: $type, size: ${data.length}, format: $containerFormat)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreservedUnknownData &&
        other.type == type &&
        other.containerFormat == containerFormat &&
        other.data.length == data.length &&
        _bytesEqual(other.data, data);
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      containerFormat,
      data.length,
      data.isNotEmpty ? data[0] : 0,
    );
  }

  /// Compares two Uint8List for equality.
  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Manager for handling unknown data preservation across different container formats.
///
/// This class provides a unified interface for preserving and restoring unknown
/// metadata across read/write operations, ensuring that unsupported metadata
/// is not lost during file processing.
class UnknownDataPreservationManager {
  final UnknownDataPreservationConfig _config;
  final Map<String, List<PreservedUnknownData>> _preservedData = {};
  int _totalPreservedSize = 0;

  /// Creates a new preservation manager with the given configuration.
  UnknownDataPreservationManager(this._config);

  /// Adds unknown data to be preserved.
  ///
  /// Returns true if the data was added, false if it was rejected due to
  /// configuration limits or blacklisting.
  bool addPreservedData(PreservedUnknownData data) {
    // Check configuration limits
    if (!_config.isWithinItemLimit(_getTotalItemCount())) {
      return false;
    }

    if (!_config.isWithinSizeLimit(_totalPreservedSize, data.size)) {
      return false;
    }

    // Check container-specific rules
    bool shouldPreserve = false;
    switch (data.containerFormat) {
      case 'id3v2':
        shouldPreserve = _config.shouldPreserveFrame(data.type);
        break;
      case 'mp4':
        shouldPreserve = _config.shouldPreserveAtom(data.type);
        break;
      case 'vorbis':
        shouldPreserve = _config.shouldPreserveVorbisField(data.type);
        break;
    }

    if (!shouldPreserve) return false;

    // Validate data if required
    if (_config.validatePreservedData && !data.isValidForWriting()) {
      return false;
    }

    // Add to preserved data
    final key = '${data.containerFormat}:${data.type}';
    _preservedData.putIfAbsent(key, () => []).add(data);
    _totalPreservedSize += data.size;

    return true;
  }

  /// Gets all preserved data for a specific container format.
  List<PreservedUnknownData> getPreservedData(String containerFormat) {
    final result = <PreservedUnknownData>[];

    for (final entry in _preservedData.entries) {
      if (entry.key.startsWith('$containerFormat:')) {
        result.addAll(entry.value);
      }
    }

    return result;
  }

  /// Gets preserved data for a specific type within a container format.
  List<PreservedUnknownData> getPreservedDataByType(
    String containerFormat,
    String type,
  ) {
    final key = '$containerFormat:$type';
    return _preservedData[key] ?? [];
  }

  /// Clears all preserved data.
  void clear() {
    _preservedData.clear();
    _totalPreservedSize = 0;
  }

  /// Clears preserved data for a specific container format.
  void clearForContainer(String containerFormat) {
    final keysToRemove = <String>[];

    for (final key in _preservedData.keys) {
      if (key.startsWith('$containerFormat:')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      final data = _preservedData.remove(key);
      if (data != null) {
        for (final item in data) {
          _totalPreservedSize -= item.size;
        }
      }
    }
  }

  /// Gets the total number of preserved items across all containers.
  int _getTotalItemCount() {
    return _preservedData.values.fold(0, (sum, list) => sum + list.length);
  }

  /// Gets statistics about preserved data.
  Map<String, dynamic> getStatistics() {
    final containerCounts = <String, int>{};
    final containerSizes = <String, int>{};

    for (final entry in _preservedData.entries) {
      final containerFormat = entry.key.split(':')[0];
      final items = entry.value;

      containerCounts[containerFormat] = (containerCounts[containerFormat] ?? 0) + items.length;

      final size = items.fold(0, (sum, item) => sum + item.size);
      containerSizes[containerFormat] = (containerSizes[containerFormat] ?? 0) + size;
    }

    return {
      'total_items': _getTotalItemCount(),
      'total_size': _totalPreservedSize,
      'container_counts': containerCounts,
      'container_sizes': containerSizes,
      'config': {
        'preserve_frames': _config.preserveUnknownFrames,
        'preserve_atoms': _config.preserveUnknownAtoms,
        'preserve_vorbis': _config.preserveUnknownVorbisFields,
        'max_size': _config.maxPreservedDataSize,
        'max_items': _config.maxPreservedItemCount,
      },
    };
  }

  /// Checks if preservation is enabled for any container format.
  bool get isEnabled {
    return _config.preserveUnknownFrames || _config.preserveUnknownAtoms || _config.preserveUnknownVorbisFields;
  }

  @override
  String toString() {
    final stats = getStatistics();
    return 'UnknownDataPreservationManager(items: ${stats['total_items']}, '
        'size: ${stats['total_size']} bytes, enabled: $isEnabled)';
  }
}
