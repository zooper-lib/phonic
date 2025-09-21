import 'dart:typed_data';

import '../../core/container_kind.dart';
import '../../core/container_locator.dart';

/// Container locator for MP4 metadata atoms in MP4/M4A audio files.
///
/// MP4 files store metadata in iTunes-style atoms within a hierarchical structure:
/// moov (movie) → udta (user data) → meta (metadata) → ilst (item list).
/// The ilst atom contains individual metadata atoms like ©nam (title), ©ART (artist), etc.
///
/// ## MP4 Atom Structure
///
/// MP4 files are organized as a sequence of atoms (boxes), each with:
/// ```
/// Atom Header (8+ bytes):
/// - Size (4 bytes): Total atom size including header (big-endian)
/// - Type (4 bytes): 4-character atom type identifier
/// - Data (variable): Atom-specific content
/// ```
///
/// For 64-bit sizes (when size field is 1), an additional 8-byte extended size follows.
///
/// ## Metadata Atom Hierarchy
///
/// The metadata structure follows this path:
/// ```
/// ftyp (file type)
/// moov (movie atom)
/// ├── mvhd (movie header)
/// ├── trak (track atoms)
/// └── udta (user data atom)
///     └── meta (metadata atom)
///         ├── hdlr (handler reference)
///         └── ilst (item list atom) ← Target for extraction
///             ├── ©nam (title atom)
///             ├── ©ART (artist atom)
///             ├── covr (artwork atom)
///             └── ... (other metadata atoms)
/// ```
///
/// ## Usage Examples
///
/// ```dart
/// final locator = Mp4Locator();
/// final fileBytes = await File('song.m4a').readAsBytes();
///
/// // Check if file contains MP4 metadata
/// if (locator.fileMatches(fileBytes)) {
///   // Extract the ilst atom for parsing
///   final ilstBytes = locator.extract(fileBytes);
///
///   if (ilstBytes != null) {
///     // Parse with appropriate codec...
///     final codec = Mp4AtomsCodec();
///     final tags = codec.readFromContainer(ilstBytes);
///   }
/// }
///
/// // Inject new MP4 metadata
/// final newIlstBytes = codec.writeToContainer(tags: updatedTags);
/// final updatedFile = locator.inject(fileBytes, newIlstBytes);
/// ```
///
/// ## Memory Efficiency
///
/// The locator minimizes memory usage by:
/// - Only parsing atom headers to navigate the hierarchy
/// - Extracting only the ilst atom data, not the entire file
/// - Validating MP4 structure before attempting full extraction
/// - Using streaming approaches for large files when possible
///
/// ## Error Handling
///
/// The locator handles various error conditions gracefully:
/// - Files without MP4 signature (ftyp atom)
/// - Missing moov, udta, meta, or ilst atoms
/// - Corrupted atom headers or invalid sizes
/// - Truncated files where declared atom sizes exceed available data
/// - Invalid atom hierarchies or unexpected structures
///
/// ## MP4 Specification Compliance
///
/// This implementation follows the ISO/IEC 14496-12 specification for:
/// - Atom header parsing (size and type fields)
/// - Big-endian integer encoding
/// - Extended size handling for large atoms
/// - Proper navigation of the moov.udta.meta.ilst hierarchy
/// - iTunes-style metadata atom conventions
///
/// See also:
/// - [Mp4AtomsCodec] for parsing extracted ilst data
/// - [Mp4FormatStrategy] for MP4 format detection
/// - [Mp4AtomMap] for atom identifier mappings
/// - [ContainerLocator] for the base interface
class Mp4Locator extends ContainerLocator {
  /// Common MP4 file type brands that indicate MP4/M4A compatibility.
  static const List<String> mp4Brands = [
    'M4A ', 'M4B ', 'M4P ', 'M4V ', // iTunes formats
    'mp41', 'mp42', 'mp71', // MPEG-4 versions
    'isom', 'iso2', // ISO Base Media
    'avc1', 'qt  ', 'dash', // Other compatible formats
  ];

  /// The minimum size for a valid MP4 atom header (8 bytes).
  static const int atomHeaderSize = 8;

  /// The minimum size for an ftyp atom (16 bytes: header + major brand + minor version).
  static const int minimumFtypSize = 16;

  @override
  ContainerKind get containerKind => ContainerKind.mp4;

  @override
  bool fileMatches(Uint8List fileBytes) {
    // Check minimum file size for ftyp atom
    if (fileBytes.length < minimumFtypSize) {
      return false;
    }

    // Check for ftyp atom at file start
    return _hasFtypAtom(fileBytes) && _hasCompatibleBrands(fileBytes);
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    // Verify file contains MP4 signature
    if (!fileMatches(fileBytes)) {
      return null;
    }

    try {
      // Navigate the atom hierarchy to find ilst atom
      final ilstAtom = _findIlstAtom(fileBytes);
      return ilstAtom;
    } catch (e) {
      // Handle any parsing errors
      return null;
    }
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    // Verify this is an MP4 file
    if (!fileMatches(fileBytes)) {
      return fileBytes; // Return original if not MP4
    }

    try {
      // Parse the existing MP4 structure
      final mp4Structure = _parseMp4Structure(fileBytes);
      if (mp4Structure == null) {
        return fileBytes; // Return original if parsing fails
      }

      // Build new MP4 file with updated/removed ilst atom
      return _rebuildMp4File(mp4Structure, containerBytes);
    } catch (e) {
      // If injection fails, return original file
      return fileBytes;
    }
  }

  /// Checks if the file starts with a valid ftyp atom.
  ///
  /// The ftyp atom is the first atom in MP4 files and contains file type information.
  /// It has the structure: size (4 bytes) + "ftyp" (4 bytes) + major brand + minor version + compatible brands.
  ///
  /// Parameters:
  /// - [fileBytes]: File data to examine (at least 8 bytes needed)
  ///
  /// Returns:
  /// - `true` if valid ftyp atom is found at file start
  /// - `false` if no ftyp atom is present or invalid
  bool _hasFtypAtom(Uint8List fileBytes) {
    if (fileBytes.length < atomHeaderSize) return false;

    // Read atom size (big-endian 32-bit integer)
    final atomSize = _readUint32BigEndian(fileBytes, 0);

    // Validate reasonable atom size
    if (atomSize < minimumFtypSize || atomSize > fileBytes.length) {
      return false;
    }

    // Check for "ftyp" type at bytes 4-7
    return fileBytes[4] == 0x66 && // 'f'
        fileBytes[5] == 0x74 && // 't'
        fileBytes[6] == 0x79 && // 'y'
        fileBytes[7] == 0x70; // 'p'
  }

  /// Checks for MP4-compatible brands in the ftyp atom.
  ///
  /// This method examines the major brand and compatible brands to ensure
  /// this is a valid MP4/M4A file that supports iTunes-style metadata.
  ///
  /// Parameters:
  /// - [fileBytes]: File data containing ftyp atom
  ///
  /// Returns:
  /// - `true` if compatible MP4/M4A brands are found
  /// - `false` if no compatible brands are detected
  bool _hasCompatibleBrands(Uint8List fileBytes) {
    if (fileBytes.length < 12) return false;

    try {
      // Read ftyp atom size
      final ftypSize = _readUint32BigEndian(fileBytes, 0);
      if (ftypSize < minimumFtypSize || ftypSize > fileBytes.length) {
        return false;
      }

      // Extract major brand (bytes 8-11)
      final majorBrand = String.fromCharCodes(fileBytes.sublist(8, 12));
      if (mp4Brands.contains(majorBrand)) return true;

      // Check compatible brands (starting at byte 16)
      for (int i = 16; i + 4 <= ftypSize && i + 4 <= fileBytes.length; i += 4) {
        final compatibleBrand = String.fromCharCodes(fileBytes.sublist(i, i + 4));
        if (mp4Brands.contains(compatibleBrand)) return true;
      }
    } catch (e) {
      return false;
    }

    return false;
  }

  /// Navigates the MP4 atom hierarchy to find the ilst atom.
  ///
  /// This method follows the path: moov → udta → meta → ilst
  /// and returns the ilst atom data if found.
  ///
  /// Parameters:
  /// - [fileBytes]: Complete MP4 file data
  ///
  /// Returns:
  /// - The ilst atom data (including header) if found
  /// - `null` if ilst atom is not found or hierarchy is invalid
  Uint8List? _findIlstAtom(Uint8List fileBytes) {
    // Find moov atom
    final moovAtom = _findAtom(fileBytes, 'moov');
    if (moovAtom == null) return null;

    // Find udta atom within moov
    final udtaAtom = _findAtom(moovAtom.data, 'udta');
    if (udtaAtom == null) return null;

    // Find meta atom within udta
    final metaAtom = _findAtom(udtaAtom.data, 'meta');
    if (metaAtom == null) return null;

    // Meta atom has a 4-byte version/flags field before its content
    if (metaAtom.data.length < 4) return null;
    final metaContent = metaAtom.data.sublist(4);

    // Find ilst atom within meta content
    final ilstAtom = _findAtom(metaContent, 'ilst');
    if (ilstAtom == null) return null;

    // Return the complete ilst atom (header + data)
    return ilstAtom.fullAtom;
  }

  /// Finds a specific atom type within the given data.
  ///
  /// This method searches for an atom with the specified type identifier
  /// within the provided data, which may contain multiple atoms.
  ///
  /// Parameters:
  /// - [data]: Data containing atoms to search
  /// - [atomType]: 4-character atom type to find
  ///
  /// Returns:
  /// - [_AtomInfo] containing atom details if found
  /// - `null` if atom type is not found
  _AtomInfo? _findAtom(Uint8List data, String atomType) {
    int offset = 0;

    while (offset + atomHeaderSize <= data.length) {
      // Read atom header
      final atomSize = _readUint32BigEndian(data, offset);
      final atomTypeBytes = data.sublist(offset + 4, offset + 8);
      final currentAtomType = String.fromCharCodes(atomTypeBytes);

      // Handle extended size (64-bit) atoms
      int actualHeaderSize = atomHeaderSize;
      int actualAtomSize = atomSize;

      if (atomSize == 1) {
        // Extended size atom (64-bit size follows header)
        if (offset + 16 > data.length) break;
        actualHeaderSize = 16;
        actualAtomSize = _readUint64BigEndian(data, offset + 8);
      } else if (atomSize == 0) {
        // Atom extends to end of file
        actualAtomSize = data.length - offset;
      }

      // Validate atom size
      if (actualAtomSize < actualHeaderSize || offset + actualAtomSize > data.length) {
        break;
      }

      // Check if this is the atom we're looking for
      if (currentAtomType == atomType) {
        final atomData = data.sublist(offset + actualHeaderSize, offset + actualAtomSize);
        final fullAtom = data.sublist(offset, offset + actualAtomSize);
        return _AtomInfo(currentAtomType, atomData, fullAtom);
      }

      // Move to next atom
      offset += actualAtomSize;
    }

    return null;
  }

  /// Parses the complete MP4 file structure for reconstruction.
  ///
  /// This method analyzes the MP4 file structure to identify all atoms
  /// and their relationships, enabling proper reconstruction during injection.
  ///
  /// Parameters:
  /// - [fileBytes]: Complete MP4 file data
  ///
  /// Returns:
  /// - [_Mp4Structure] containing file structure information
  /// - `null` if parsing fails
  _Mp4Structure? _parseMp4Structure(Uint8List fileBytes) {
    final atoms = <_AtomInfo>[];
    int offset = 0;

    // Parse top-level atoms
    while (offset + atomHeaderSize <= fileBytes.length) {
      final atomSize = _readUint32BigEndian(fileBytes, offset);
      final atomTypeBytes = fileBytes.sublist(offset + 4, offset + 8);
      final atomType = String.fromCharCodes(atomTypeBytes);

      int actualHeaderSize = atomHeaderSize;
      int actualAtomSize = atomSize;

      if (atomSize == 1) {
        if (offset + 16 > fileBytes.length) break;
        actualHeaderSize = 16;
        actualAtomSize = _readUint64BigEndian(fileBytes, offset + 8);
      } else if (atomSize == 0) {
        actualAtomSize = fileBytes.length - offset;
      }

      if (actualAtomSize < actualHeaderSize || offset + actualAtomSize > fileBytes.length) {
        break;
      }

      final atomData = fileBytes.sublist(offset + actualHeaderSize, offset + actualAtomSize);
      final fullAtom = fileBytes.sublist(offset, offset + actualAtomSize);
      atoms.add(_AtomInfo(atomType, atomData, fullAtom));

      offset += actualAtomSize;
    }

    return _Mp4Structure(atoms);
  }

  /// Rebuilds the MP4 file with updated ilst atom.
  ///
  /// This method reconstructs the MP4 file structure, replacing the ilst atom
  /// with new metadata or removing it entirely if containerBytes is null.
  ///
  /// Parameters:
  /// - [structure]: Parsed MP4 file structure
  /// - [containerBytes]: New ilst atom data, or null to remove
  ///
  /// Returns:
  /// - Rebuilt MP4 file bytes with updated metadata
  Uint8List _rebuildMp4File(_Mp4Structure structure, Uint8List? containerBytes) {
    final result = <int>[];

    for (final atom in structure.atoms) {
      if (atom.type == 'moov') {
        // Rebuild moov atom with updated ilst
        final newMoovData = _rebuildMoovAtom(atom.data, containerBytes);
        final newMoovSize = atomHeaderSize + newMoovData.length;

        // Write moov atom header
        result.addAll(_writeUint32BigEndian(newMoovSize));
        result.addAll('moov'.codeUnits);
        result.addAll(newMoovData);
      } else {
        // Copy other atoms unchanged
        result.addAll(atom.fullAtom);
      }
    }

    return Uint8List.fromList(result);
  }

  /// Rebuilds the moov atom with updated ilst atom.
  ///
  /// This method reconstructs the moov atom structure, navigating through
  /// udta and meta atoms to update or remove the ilst atom.
  ///
  /// Parameters:
  /// - [moovData]: Original moov atom data
  /// - [containerBytes]: New ilst atom data, or null to remove
  ///
  /// Returns:
  /// - Rebuilt moov atom data with updated metadata structure
  Uint8List _rebuildMoovAtom(Uint8List moovData, Uint8List? containerBytes) {
    final result = <int>[];
    int offset = 0;

    while (offset + atomHeaderSize <= moovData.length) {
      final atomSize = _readUint32BigEndian(moovData, offset);
      final atomTypeBytes = moovData.sublist(offset + 4, offset + 8);
      final atomType = String.fromCharCodes(atomTypeBytes);

      int actualHeaderSize = atomHeaderSize;
      int actualAtomSize = atomSize;

      if (atomSize == 1) {
        if (offset + 16 > moovData.length) break;
        actualHeaderSize = 16;
        actualAtomSize = _readUint64BigEndian(moovData, offset + 8);
      } else if (atomSize == 0) {
        actualAtomSize = moovData.length - offset;
      }

      if (actualAtomSize < actualHeaderSize || offset + actualAtomSize > moovData.length) {
        break;
      }

      if (atomType == 'udta') {
        // Rebuild udta atom with updated meta/ilst
        final atomData = moovData.sublist(offset + actualHeaderSize, offset + actualAtomSize);
        final newUdtaData = _rebuildUdtaAtom(atomData, containerBytes);
        final newUdtaSize = atomHeaderSize + newUdtaData.length;

        result.addAll(_writeUint32BigEndian(newUdtaSize));
        result.addAll('udta'.codeUnits);
        result.addAll(newUdtaData);
      } else {
        // Copy other atoms unchanged
        final fullAtom = moovData.sublist(offset, offset + actualAtomSize);
        result.addAll(fullAtom);
      }

      offset += actualAtomSize;
    }

    return Uint8List.fromList(result);
  }

  /// Rebuilds the udta atom with updated meta/ilst atoms.
  ///
  /// Parameters:
  /// - [udtaData]: Original udta atom data
  /// - [containerBytes]: New ilst atom data, or null to remove
  ///
  /// Returns:
  /// - Rebuilt udta atom data
  Uint8List _rebuildUdtaAtom(Uint8List udtaData, Uint8List? containerBytes) {
    final result = <int>[];
    int offset = 0;

    while (offset + atomHeaderSize <= udtaData.length) {
      final atomSize = _readUint32BigEndian(udtaData, offset);
      final atomTypeBytes = udtaData.sublist(offset + 4, offset + 8);
      final atomType = String.fromCharCodes(atomTypeBytes);

      int actualHeaderSize = atomHeaderSize;
      int actualAtomSize = atomSize;

      if (atomSize == 1) {
        if (offset + 16 > udtaData.length) break;
        actualHeaderSize = 16;
        actualAtomSize = _readUint64BigEndian(udtaData, offset + 8);
      } else if (atomSize == 0) {
        actualAtomSize = udtaData.length - offset;
      }

      if (actualAtomSize < actualHeaderSize || offset + actualAtomSize > udtaData.length) {
        break;
      }

      if (atomType == 'meta') {
        // Rebuild meta atom with updated ilst
        final atomData = udtaData.sublist(offset + actualHeaderSize, offset + actualAtomSize);
        final newMetaData = _rebuildMetaAtom(atomData, containerBytes);
        final newMetaSize = atomHeaderSize + newMetaData.length;

        result.addAll(_writeUint32BigEndian(newMetaSize));
        result.addAll('meta'.codeUnits);
        result.addAll(newMetaData);
      } else {
        // Copy other atoms unchanged
        final fullAtom = udtaData.sublist(offset, offset + actualAtomSize);
        result.addAll(fullAtom);
      }

      offset += actualAtomSize;
    }

    return Uint8List.fromList(result);
  }

  /// Rebuilds the meta atom with updated ilst atom.
  ///
  /// Parameters:
  /// - [metaData]: Original meta atom data (including version/flags)
  /// - [containerBytes]: New ilst atom data, or null to remove
  ///
  /// Returns:
  /// - Rebuilt meta atom data
  Uint8List _rebuildMetaAtom(Uint8List metaData, Uint8List? containerBytes) {
    final result = <int>[];

    // Meta atom starts with 4-byte version/flags field
    if (metaData.length < 4) {
      // Invalid meta atom, create minimal structure
      result.addAll([0, 0, 0, 0]); // version/flags
      if (containerBytes != null) {
        result.addAll(containerBytes);
      }
      return Uint8List.fromList(result);
    }

    // Copy version/flags
    result.addAll(metaData.sublist(0, 4));

    // Process remaining atoms in meta
    final metaContent = metaData.sublist(4);
    int offset = 0;
    bool ilstFound = false;

    while (offset + atomHeaderSize <= metaContent.length) {
      final atomSize = _readUint32BigEndian(metaContent, offset);
      final atomTypeBytes = metaContent.sublist(offset + 4, offset + 8);
      final atomType = String.fromCharCodes(atomTypeBytes);

      int actualHeaderSize = atomHeaderSize;
      int actualAtomSize = atomSize;

      if (atomSize == 1) {
        if (offset + 16 > metaContent.length) break;
        actualHeaderSize = 16;
        actualAtomSize = _readUint64BigEndian(metaContent, offset + 8);
      } else if (atomSize == 0) {
        actualAtomSize = metaContent.length - offset;
      }

      if (actualAtomSize < actualHeaderSize || offset + actualAtomSize > metaContent.length) {
        break;
      }

      if (atomType == 'ilst') {
        // Replace with new ilst atom (if provided)
        if (containerBytes != null) {
          result.addAll(containerBytes);
        }
        ilstFound = true;
      } else {
        // Copy other atoms unchanged
        final fullAtom = metaContent.sublist(offset, offset + actualAtomSize);
        result.addAll(fullAtom);
      }

      offset += actualAtomSize;
    }

    // If no existing ilst was found and we have new data, add it
    if (!ilstFound && containerBytes != null) {
      result.addAll(containerBytes);
    }

    return Uint8List.fromList(result);
  }

  /// Reads a 32-bit big-endian unsigned integer from the data.
  int _readUint32BigEndian(Uint8List data, int offset) {
    return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
  }

  /// Reads a 64-bit big-endian unsigned integer from the data.
  int _readUint64BigEndian(Uint8List data, int offset) {
    // For Dart, we'll use the lower 32 bits since int is 64-bit signed
    // This should be sufficient for most MP4 files
    final high = _readUint32BigEndian(data, offset);
    final low = _readUint32BigEndian(data, offset + 4);
    return (high << 32) | low;
  }

  /// Writes a 32-bit big-endian unsigned integer to bytes.
  List<int> _writeUint32BigEndian(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}

/// Internal class representing an MP4 atom with its data.
class _AtomInfo {
  final String type;
  final Uint8List data;
  final Uint8List fullAtom;

  const _AtomInfo(this.type, this.data, this.fullAtom);
}

/// Internal class representing the parsed MP4 file structure.
class _Mp4Structure {
  final List<_AtomInfo> atoms;

  const _Mp4Structure(this.atoms);
}
