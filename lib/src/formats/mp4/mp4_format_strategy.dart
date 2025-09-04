import 'dart:typed_data';

import '../../core/container_kind.dart';
import '../../core/format_strategy.dart';
import '../../core/media_kind.dart';
import '../../exceptions/unsupported_format_exception.dart';

/// Format strategy for MP4 and M4A audio files.
///
/// This strategy handles MPEG-4 container files, including both M4A (audio-only)
/// and MP4 (multimedia) files. Both formats use the same MP4 atom structure
/// for metadata storage, with iTunes-style atoms providing rich metadata
/// capabilities within a hierarchical container structure.
///
/// ## Container Precedence
///
/// MP4/M4A files use only MP4 atoms for metadata storage, so there is no
/// precedence hierarchy. All metadata is stored in iTunes-style atoms within
/// the moov.udta.meta.ilst atom hierarchy.
///
/// ## Fan-out Policy
///
/// When writing metadata to MP4/M4A files, this strategy targets only MP4
/// atoms, as this is the standard and only metadata format supported by
/// the MP4 specification for audio metadata.
///
/// ## Format Detection
///
/// MP4/M4A format detection uses the standard MP4 file type box (ftyp) and
/// compatible brand identification:
///
/// 1. **MP4 Signature**: Checks for ftyp box at file start (after size field)
/// 2. **Brand Detection**: Validates major brand and compatible brands
/// 3. **Container Structure**: Confirms basic MP4 box structure
///
/// The detection process distinguishes between M4A (audio-only) and MP4
/// (multimedia) files based on the brand information in the ftyp box, but
/// both are handled by this strategy since they use identical metadata structures.
///
/// ## Usage Example
///
/// ```dart
/// final strategy = Mp4FormatStrategy();
/// final fileBytes = await File('song.m4a').readAsBytes();
///
/// if (strategy.canHandle(fileBytes)) {
///   print('Detected MP4/M4A file');
///   final format = strategy.detectFormat(fileBytes);
///   print('Media kind: $format');
///
///   // Access precedence for reading (MP4 atoms only)
///   for (final (container, version) in strategy.precedence) {
///     print('Read precedence: $container v$version');
///   }
///
///   // Access fan-out for writing (MP4 atoms only)
///   for (final (container, version) in strategy.fanout) {
///     print('Write target: $container v$version');
///   }
/// }
/// ```
///
/// ## MP4 Container Structure
///
/// MP4 files are organized as a hierarchy of boxes (atoms):
/// - **ftyp**: File type box containing brand information
/// - **moov**: Movie box containing metadata and track information
///   - **udta**: User data box
///     - **meta**: Metadata box
///       - **ilst**: iTunes-style metadata list
///
/// For metadata, the key structure is moov.udta.meta.ilst, which contains:
/// - **Standard atoms**: iTunes-compatible fields (©nam, ©ART, trkn, etc.)
/// - **Freeform atoms**: Custom fields with ----:domain:name format
/// - **covr atoms**: Embedded artwork with type information
///
/// ## Performance Characteristics
///
/// - Format detection completes in microseconds for typical files
/// - Minimal memory allocation during detection
/// - Fast-fail for non-MP4 formats
/// - Efficient ftyp box parsing and brand matching
///
/// ## Thread Safety
///
/// This class is stateless and thread-safe. Multiple threads can safely
/// use the same instance concurrently for format detection and strategy
/// information access.
class Mp4FormatStrategy implements FormatStrategy {
  /// Creates a new MP4 format strategy instance.
  ///
  /// The strategy is stateless and can be reused across multiple files
  /// and threads safely. It handles both M4A and MP4 files since they
  /// use identical metadata structures.
  const Mp4FormatStrategy();

  @override
  MediaKind get mediaKind => MediaKind.mp4;

  @override
  List<(ContainerKind, String)> get precedence => const [
    (ContainerKind.mp4, ''), // Only MP4 atoms supported
  ];

  @override
  List<(ContainerKind, String)> get fanout => const [
    (ContainerKind.mp4, ''), // Write to MP4 atoms only
  ];

  @override
  bool canHandle(Uint8List fileBytes) {
    if (fileBytes.length < 8) return false;

    // Check for MP4 file type box (ftyp) signature
    if (!_hasFtypBox(fileBytes)) return false;

    // For more reliable detection, also check for compatible brands
    return _hasCompatibleBrands(fileBytes);
  }

  @override
  MediaKind detectFormat(Uint8List fileBytes) {
    if (!canHandle(fileBytes)) {
      throw const UnsupportedFormatException(
        'File does not appear to be a valid MP4/M4A format',
        context: 'Mp4FormatStrategy.detectFormat',
      );
    }

    // Determine if this is M4A (audio-only) or MP4 (multimedia)
    // by examining the brands in the ftyp box
    if (_isM4aFormat(fileBytes)) {
      return MediaKind.m4a;
    }

    return MediaKind.mp4;
  }

  /// Checks if the file starts with an MP4 file type box (ftyp).
  ///
  /// MP4 files begin with a series of boxes, and the first box is typically
  /// the file type box (ftyp). This box contains a 4-byte size field followed
  /// by the 4-byte type "ftyp".
  ///
  /// The ftyp box structure:
  /// - size (4 bytes): Size of the entire ftyp box
  /// - type (4 bytes): "ftyp" signature (0x66747970)
  /// - major_brand (4 bytes): Primary brand identifier
  /// - minor_version (4 bytes): Version information
  /// - compatible_brands (variable): List of compatible brand identifiers
  ///
  /// Parameters:
  /// - [fileBytes]: File data to examine (at least 8 bytes needed)
  ///
  /// Returns:
  /// - `true` if ftyp box signature is found at expected location
  /// - `false` if no ftyp box is present
  bool _hasFtypBox(Uint8List fileBytes) {
    if (fileBytes.length < 8) return false;

    // Read the first box size (big-endian 32-bit integer)
    final boxSize = (fileBytes[0] << 24) | (fileBytes[1] << 16) | (fileBytes[2] << 8) | fileBytes[3];

    // Validate reasonable box size (should be at least 16 bytes for minimal ftyp)
    if (boxSize < 16 || boxSize > fileBytes.length) return false;

    // Check for "ftyp" signature at bytes 4-7
    return fileBytes[4] == 0x66 && // 'f'
        fileBytes[5] == 0x74 && // 't'
        fileBytes[6] == 0x79 && // 'y'
        fileBytes[7] == 0x70; // 'p'
  }

  /// Checks for MP4-compatible brands in the ftyp box.
  ///
  /// This method examines the major brand and compatible brands within the
  /// ftyp box to determine if this is a valid MP4/M4A file. Different brands
  /// indicate different MP4 variants and capabilities.
  ///
  /// Common MP4/M4A brands:
  /// - M4A : iTunes M4A audio files
  /// - M4B : iTunes M4B audiobook files
  /// - mp41: MPEG-4 version 1
  /// - mp42: MPEG-4 version 2
  /// - isom: ISO Base Media file format
  /// - avc1: H.264/AVC video
  /// - qt  : QuickTime movie files
  ///
  /// Parameters:
  /// - [fileBytes]: File data containing ftyp box
  ///
  /// Returns:
  /// - `true` if compatible MP4/M4A brands are found
  /// - `false` if no compatible brands are detected
  bool _hasCompatibleBrands(Uint8List fileBytes) {
    if (fileBytes.length < 12) return false; // Need at least major brand

    try {
      // Read box size to determine ftyp box boundaries
      final boxSize = (fileBytes[0] << 24) | (fileBytes[1] << 16) | (fileBytes[2] << 8) | fileBytes[3];
      if (boxSize < 16 || boxSize > fileBytes.length) return false;

      // Extract major brand (bytes 8-11)
      final majorBrand = String.fromCharCodes(fileBytes.sublist(8, 12));

      // Check for known MP4/M4A major brands
      if (_isKnownMp4Brand(majorBrand)) return true;

      // Check compatible brands (starting at byte 16)
      final compatibleBrandsStart = 16;
      final compatibleBrandsEnd = boxSize;

      // Each compatible brand is 4 bytes
      for (int i = compatibleBrandsStart; i + 4 <= compatibleBrandsEnd && i + 4 <= fileBytes.length; i += 4) {
        final compatibleBrand = String.fromCharCodes(fileBytes.sublist(i, i + 4));
        if (_isKnownMp4Brand(compatibleBrand)) return true;
      }
    } catch (e) {
      // If parsing fails, fall back to basic ftyp detection
      return false;
    }

    return false;
  }

  /// Determines if this is specifically an M4A (audio-only) file.
  ///
  /// This method examines the brands in the ftyp box to distinguish between
  /// M4A (audio-only) and MP4 (multimedia) files. While both use the same
  /// metadata structure, the distinction helps with format reporting.
  ///
  /// M4A-specific brands:
  /// - M4A : iTunes M4A audio files
  /// - M4B : iTunes M4B audiobook files
  /// - M4P : iTunes M4P protected audio files
  ///
  /// Parameters:
  /// - [fileBytes]: File data containing ftyp box
  ///
  /// Returns:
  /// - `true` if this appears to be an M4A audio-only file
  /// - `false` if this appears to be a general MP4 multimedia file
  bool _isM4aFormat(Uint8List fileBytes) {
    if (fileBytes.length < 12) return false;

    try {
      // Extract major brand (bytes 8-11)
      final majorBrand = String.fromCharCodes(fileBytes.sublist(8, 12));

      // Check for M4A-specific major brands
      if (_isM4aBrand(majorBrand)) return true;

      // Check compatible brands for M4A indicators
      final boxSize = (fileBytes[0] << 24) | (fileBytes[1] << 16) | (fileBytes[2] << 8) | fileBytes[3];
      if (boxSize < 16 || boxSize > fileBytes.length) return false;

      final compatibleBrandsStart = 16;
      final compatibleBrandsEnd = boxSize;

      for (int i = compatibleBrandsStart; i + 4 <= compatibleBrandsEnd && i + 4 <= fileBytes.length; i += 4) {
        final compatibleBrand = String.fromCharCodes(fileBytes.sublist(i, i + 4));
        if (_isM4aBrand(compatibleBrand)) return true;
      }
    } catch (e) {
      // If parsing fails, default to MP4
      return false;
    }

    return false;
  }

  /// Checks if a brand identifier indicates a known MP4-compatible format.
  ///
  /// This method validates brand strings against known MP4 format identifiers
  /// to determine file compatibility with MP4 metadata structures.
  ///
  /// Parameters:
  /// - [brand]: 4-character brand identifier from ftyp box
  ///
  /// Returns:
  /// - `true` if brand indicates MP4 compatibility
  /// - `false` if brand is not recognized as MP4-compatible
  bool _isKnownMp4Brand(String brand) {
    // Known MP4-compatible brands
    const knownBrands = {
      'M4A ', // iTunes M4A audio
      'M4B ', // iTunes M4B audiobook
      'M4P ', // iTunes M4P protected audio
      'M4V ', // iTunes M4V video
      'mp41', // MPEG-4 version 1
      'mp42', // MPEG-4 version 2
      'mp71', // MPEG-4 version 7.1
      'isom', // ISO Base Media file format
      'iso2', // ISO Base Media file format version 2
      'avc1', // H.264/AVC video
      'qt  ', // QuickTime movie files
      'dash', // DASH (Dynamic Adaptive Streaming over HTTP)
    };

    return knownBrands.contains(brand);
  }

  /// Checks if a brand identifier indicates an M4A audio-only format.
  ///
  /// This method specifically identifies brands that indicate audio-only
  /// content, helping distinguish M4A from general MP4 multimedia files.
  ///
  /// Parameters:
  /// - [brand]: 4-character brand identifier from ftyp box
  ///
  /// Returns:
  /// - `true` if brand indicates M4A audio-only format
  /// - `false` if brand indicates general MP4 or other format
  bool _isM4aBrand(String brand) {
    // M4A-specific brands (audio-only indicators)
    const m4aBrands = {
      'M4A ', // iTunes M4A audio
      'M4B ', // iTunes M4B audiobook
      'M4P ', // iTunes M4P protected audio
    };

    return m4aBrands.contains(brand);
  }
}
