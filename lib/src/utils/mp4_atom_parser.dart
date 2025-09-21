import 'dart:typed_data';

import '../exceptions/corrupted_container_exception.dart';
import 'byte_reader.dart';

/// Represents an MP4 atom header with size and type information.
///
/// MP4 atoms (also called boxes) are the fundamental building blocks of MP4 files.
/// Each atom consists of a header followed by data. The header contains the size
/// of the entire atom (including the header) and a 4-character type identifier.
///
/// ## Atom Header Structure
///
/// Standard header (8 bytes):
/// - size (4 bytes): Total size of atom including header (big-endian)
/// - type (4 bytes): 4-character atom type identifier
///
/// Extended header (16 bytes, when size == 1):
/// - size (4 bytes): Value of 1 indicating extended size
/// - type (4 bytes): 4-character atom type identifier
/// - extended_size (8 bytes): Actual 64-bit size (big-endian)
///
/// ## Usage Example
///
/// ```dart
/// final bytes = Uint8List.fromList([
///   0x00, 0x00, 0x00, 0x20, // size: 32 bytes
///   0x66, 0x74, 0x79, 0x70, // type: "ftyp"
///   // ... atom data follows
/// ]);
///
/// final reader = ByteReader(bytes);
/// final header = Mp4AtomHeader.parse(reader);
/// print('Type: ${header.type}'); // "ftyp"
/// print('Size: ${header.size}'); // 32
/// print('Data size: ${header.dataSize}'); // 24
/// ```
class Mp4AtomHeader {
  /// The total size of the atom including the header.
  ///
  /// For standard atoms, this is a 32-bit value. For extended atoms,
  /// this represents the full 64-bit size. The minimum valid size
  /// is 8 bytes (header only).
  final int size;

  /// The 4-character atom type identifier.
  ///
  /// Common atom types include:
  /// - "ftyp": File type box
  /// - "moov": Movie box
  /// - "mdat": Media data box
  /// - "udta": User data box
  /// - "meta": Metadata box
  /// - "ilst": Item list box
  final String type;

  /// The byte offset where this atom's header starts.
  ///
  /// This is useful for navigation and error reporting when parsing
  /// hierarchical atom structures.
  final int offset;

  /// Whether this atom uses the extended size format.
  ///
  /// Extended size is used when the atom size exceeds 32-bit limits.
  /// In this case, the standard size field contains 1, and the actual
  /// size is stored in an 8-byte extended size field.
  final bool isExtendedSize;

  /// Optional override for data offset calculation.
  ///
  /// When provided, this value is used instead of calculating
  /// dataOffset from offset + headerSize. This is useful for
  /// testing or when the data offset needs to be explicitly set.
  final int? _dataOffset;

  /// Creates an MP4 atom header.
  ///
  /// Parameters:
  /// - [size]: Total atom size including header
  /// - [type]: 4-character atom type identifier
  /// - [offset]: Byte offset of atom header start
  /// - [isExtendedSize]: Whether extended size format is used
  /// - [dataOffset]: Optional override for data offset calculation
  const Mp4AtomHeader({
    required this.size,
    required this.type,
    required this.offset,
    this.isExtendedSize = false,
    int? dataOffset,
  }) : _dataOffset = dataOffset;

  /// The size of the atom header in bytes.
  ///
  /// Standard headers are 8 bytes, extended headers are 16 bytes.
  int get headerSize => isExtendedSize ? 16 : 8;

  /// The size of the atom's data payload (excluding header).
  ///
  /// This is calculated as total size minus header size.
  int get dataSize => size - headerSize;

  /// The byte offset where the atom's data starts.
  ///
  /// This is the offset plus the header size, or the explicitly
  /// provided dataOffset if one was given during construction.
  int get dataOffset => _dataOffset ?? (offset + headerSize);

  /// The byte offset where the next atom starts.
  ///
  /// This is the current atom's offset plus its total size.
  int get nextAtomOffset => offset + size;

  /// Parses an MP4 atom header from the given byte reader.
  ///
  /// The reader's position will be advanced past the atom header.
  /// For extended size atoms, both the standard and extended headers
  /// are parsed automatically.
  ///
  /// Parameters:
  /// - [reader]: ByteReader positioned at the start of an atom header
  ///
  /// Returns:
  /// - [Mp4AtomHeader] containing the parsed header information
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the header is malformed
  /// - [RangeError] if insufficient bytes are available
  ///
  /// Example:
  /// ```dart
  /// final reader = ByteReader(mp4FileBytes);
  /// final header = Mp4AtomHeader.parse(reader);
  /// final atomData = reader.readBytes(header.dataSize);
  /// ```
  static Mp4AtomHeader parse(ByteReader reader) {
    final startOffset = reader.position;

    if (reader.remaining < 8) {
      throw CorruptedContainerException(
        'Insufficient bytes for MP4 atom header: need 8, got ${reader.remaining}',
        byteOffset: startOffset,
      );
    }

    // Read standard header
    final standardSize = reader.readUint32();
    final typeBytes = reader.readBytes(4);

    // Validate type contains printable ASCII characters
    final type = _parseAtomType(typeBytes, startOffset);

    // Handle extended size format
    if (standardSize == 1) {
      if (reader.remaining < 8) {
        throw CorruptedContainerException(
          'Insufficient bytes for extended MP4 atom size: need 8, got ${reader.remaining}',
          byteOffset: reader.position,
        );
      }

      final extendedSize = reader.readUint64();

      // Validate extended size is reasonable
      if (extendedSize < 16) {
        throw CorruptedContainerException(
          'Invalid extended MP4 atom size: $extendedSize (minimum 16 bytes)',
          byteOffset: startOffset,
        );
      }

      return Mp4AtomHeader(
        size: extendedSize,
        type: type,
        offset: startOffset,
        isExtendedSize: true,
      );
    }

    // Validate standard size is reasonable
    if (standardSize < 8) {
      throw CorruptedContainerException(
        'Invalid MP4 atom size: $standardSize (minimum 8 bytes)',
        byteOffset: startOffset,
      );
    }

    return Mp4AtomHeader(
      size: standardSize,
      type: type,
      offset: startOffset,
      isExtendedSize: false,
    );
  }

  /// Parses atom type from 4 bytes, validating it contains reasonable characters.
  ///
  /// MP4 atom types should generally contain printable ASCII characters,
  /// though some may contain non-printable bytes for specific purposes.
  static String _parseAtomType(Uint8List typeBytes, int offset) {
    if (typeBytes.length != 4) {
      throw CorruptedContainerException(
        'Invalid atom type length: expected 4 bytes, got ${typeBytes.length}',
        byteOffset: offset,
      );
    }

    // Convert bytes to string, handling potential non-printable characters
    final type = String.fromCharCodes(typeBytes);

    // Basic validation - atom type should not be all zeros
    if (type == '\x00\x00\x00\x00') {
      throw CorruptedContainerException(
        'Invalid atom type: all zero bytes',
        byteOffset: offset,
      );
    }

    return type;
  }

  @override
  String toString() {
    return 'Mp4AtomHeader(type: "$type", size: $size, offset: $offset, '
        'isExtended: $isExtendedSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mp4AtomHeader &&
        other.size == size &&
        other.type == type &&
        other.offset == offset &&
        other.isExtendedSize == isExtendedSize &&
        other._dataOffset == _dataOffset;
  }

  @override
  int get hashCode {
    return Object.hash(size, type, offset, isExtendedSize, _dataOffset);
  }
}

/// Represents a parsed MP4 atom with header and data.
///
/// This class combines an atom header with its data payload, providing
/// convenient access to both the structural information and content.
/// The data is stored as a view into the original byte buffer for
/// memory efficiency.
///
/// ## Usage Example
///
/// ```dart
/// final atom = Mp4Atom.parse(reader);
/// print('Atom type: ${atom.header.type}');
/// print('Data size: ${atom.data.length}');
///
/// // Access nested atoms for container types
/// if (atom.header.type == 'moov') {
///   final childAtoms = Mp4AtomParser.parseChildAtoms(atom.data);
///   for (final child in childAtoms) {
///     print('Child atom: ${child.header.type}');
///   }
/// }
/// ```
class Mp4Atom {
  /// The atom header containing size, type, and offset information.
  final Mp4AtomHeader header;

  /// The atom's data payload as a byte array.
  ///
  /// This excludes the atom header and contains only the payload data.
  /// For container atoms, this data contains child atoms that can be
  /// parsed using [Mp4AtomParser.parseChildAtoms].
  final Uint8List data;

  /// Creates an MP4 atom with the given header and data.
  ///
  /// Parameters:
  /// - [header]: The parsed atom header
  /// - [data]: The atom's data payload (excluding header)
  const Mp4Atom({
    required this.header,
    required this.data,
  });

  /// Parses an MP4 atom from the given byte reader.
  ///
  /// This method parses both the header and data payload, advancing
  /// the reader's position past the entire atom.
  ///
  /// Parameters:
  /// - [reader]: ByteReader positioned at the start of an atom
  ///
  /// Returns:
  /// - [Mp4Atom] containing the parsed header and data
  ///
  /// Throws:
  /// - [CorruptedContainerException] if the atom is malformed
  /// - [RangeError] if insufficient bytes are available
  ///
  /// Example:
  /// ```dart
  /// final reader = ByteReader(mp4FileBytes);
  /// final atom = Mp4Atom.parse(reader);
  /// ```
  static Mp4Atom parse(ByteReader reader) {
    final header = Mp4AtomHeader.parse(reader);

    // Validate that enough data remains for the atom payload
    if (reader.remaining < header.dataSize) {
      throw CorruptedContainerException(
        'Insufficient bytes for MP4 atom data: need ${header.dataSize}, '
        'got ${reader.remaining}',
        byteOffset: reader.position,
      );
    }

    final data = reader.readBytes(header.dataSize);

    return Mp4Atom(
      header: header,
      data: data,
    );
  }

  /// Whether this atom is a container type that may contain child atoms.
  ///
  /// Container atoms have structured data that consists of child atoms
  /// rather than raw payload data. Common container types include:
  /// - moov, trak, mdia, minf, stbl (media structure)
  /// - udta, meta, ilst (metadata structure)
  /// - edts, mvex (editing and fragmentation)
  bool get isContainer => _containerAtomTypes.contains(header.type);

  /// Whether this atom is a leaf type that contains raw data.
  ///
  /// Leaf atoms contain actual payload data rather than child atoms.
  /// Examples include text atoms, binary data, and media samples.
  bool get isLeaf => !isContainer;

  /// Set of known container atom types.
  ///
  /// This list includes the most common container atoms found in MP4 files.
  /// Container atoms contain child atoms rather than raw data.
  static const Set<String> _containerAtomTypes = {
    'moov', // Movie box
    'trak', // Track box
    'mdia', // Media box
    'minf', // Media information box
    'dinf', // Data information box
    'stbl', // Sample table box
    'udta', // User data box
    'meta', // Metadata box
    'ilst', // Item list box
    'edts', // Edit box
    'mvex', // Movie extends box
    'moof', // Movie fragment box
    'traf', // Track fragment box
    'mfra', // Movie fragment random access box
    'skip', // Skip box (container variant)
    'wide', // Wide box (legacy container)
  };

  @override
  String toString() {
    return 'Mp4Atom(type: "${header.type}", size: ${header.size}, '
        'dataSize: ${data.length}, isContainer: $isContainer)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mp4Atom && other.header == header && _listEquals(other.data, data);
  }

  @override
  int get hashCode {
    return Object.hash(header, Object.hashAll(data));
  }

  /// Helper method to compare Uint8List for equality.
  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Utility class for parsing and navigating MP4 atom hierarchies.
///
/// This class provides methods for parsing MP4 files and navigating their
/// hierarchical atom structure. It handles both individual atom parsing
/// and bulk operations for finding specific atoms within containers.
///
/// ## Usage Examples
///
/// ```dart
/// // Parse all top-level atoms
/// final atoms = Mp4AtomParser.parseAtoms(fileBytes);
/// for (final atom in atoms) {
///   print('Found atom: ${atom.header.type}');
/// }
///
/// // Find specific atom by path
/// final ilst = Mp4AtomParser.findAtomByPath(fileBytes, ['moov', 'udta', 'meta', 'ilst']);
/// if (ilst != null) {
///   print('Found metadata: ${ilst.data.length} bytes');
/// }
///
/// // Navigate atom hierarchy
/// final moovAtom = Mp4AtomParser.findAtom(fileBytes, 'moov');
/// if (moovAtom != null) {
///   final childAtoms = Mp4AtomParser.parseChildAtoms(moovAtom.data);
///   final udta = childAtoms.where((a) => a.header.type == 'udta').firstOrNull;
/// }
/// ```
class Mp4AtomParser {
  /// Parses all atoms from the given byte data.
  ///
  /// This method parses atoms sequentially from the beginning of the data
  /// until all bytes are consumed or an error occurs. It's suitable for
  /// parsing top-level atoms in an MP4 file.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data or atom container data
  ///
  /// Returns:
  /// - List of [Mp4Atom] objects in the order they appear
  ///
  /// Throws:
  /// - [CorruptedContainerException] if any atom is malformed
  ///
  /// Example:
  /// ```dart
  /// final fileBytes = await File('movie.mp4').readAsBytes();
  /// final atoms = Mp4AtomParser.parseAtoms(fileBytes);
  /// ```
  static List<Mp4Atom> parseAtoms(Uint8List bytes) {
    final reader = ByteReader(bytes);
    final atoms = <Mp4Atom>[];

    while (reader.hasRemaining) {
      try {
        final atom = Mp4Atom.parse(reader);
        atoms.add(atom);
      } catch (e) {
        // Re-throw with additional context
        if (e is CorruptedContainerException) {
          rethrow;
        } else {
          throw CorruptedContainerException(
            'Failed to parse MP4 atom: $e',
            byteOffset: reader.position,
          );
        }
      }
    }

    return atoms;
  }

  /// Parses child atoms from container atom data.
  ///
  /// This method is used to parse atoms contained within a parent container
  /// atom. The input data should be the payload of a container atom, not
  /// including the container's header.
  ///
  /// Parameters:
  /// - [containerData]: Data payload of a container atom
  ///
  /// Returns:
  /// - List of child [Mp4Atom] objects
  ///
  /// Throws:
  /// - [CorruptedContainerException] if any child atom is malformed
  ///
  /// Example:
  /// ```dart
  /// final moovAtom = Mp4AtomParser.findAtom(fileBytes, 'moov');
  /// final childAtoms = Mp4AtomParser.parseChildAtoms(moovAtom!.data);
  /// ```
  static List<Mp4Atom> parseChildAtoms(Uint8List containerData) {
    return parseAtoms(containerData);
  }

  /// Finds the first atom with the specified type.
  ///
  /// This method searches through the top-level atoms in the given data
  /// and returns the first atom matching the specified type.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data or container data to search
  /// - [atomType]: 4-character atom type to find
  ///
  /// Returns:
  /// - [Mp4Atom] if found, null otherwise
  ///
  /// Example:
  /// ```dart
  /// final moovAtom = Mp4AtomParser.findAtom(fileBytes, 'moov');
  /// final ftypAtom = Mp4AtomParser.findAtom(fileBytes, 'ftyp');
  /// ```
  static Mp4Atom? findAtom(Uint8List bytes, String atomType) {
    try {
      final atoms = parseAtoms(bytes);
      return atoms.where((atom) => atom.header.type == atomType).firstOrNull;
    } catch (e) {
      // Return null if parsing fails
      return null;
    }
  }

  /// Finds all atoms with the specified type.
  ///
  /// This method searches through the top-level atoms and returns all
  /// atoms matching the specified type. Useful for atoms that can appear
  /// multiple times, such as 'trak' atoms.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data or container data to search
  /// - [atomType]: 4-character atom type to find
  ///
  /// Returns:
  /// - List of [Mp4Atom] objects matching the type
  ///
  /// Example:
  /// ```dart
  /// final trakAtoms = Mp4AtomParser.findAtoms(fileBytes, 'trak');
  /// print('Found ${trakAtoms.length} tracks');
  /// ```
  static List<Mp4Atom> findAtoms(Uint8List bytes, String atomType) {
    try {
      final atoms = parseAtoms(bytes);
      return atoms.where((atom) => atom.header.type == atomType).toList();
    } catch (e) {
      // Return empty list if parsing fails
      return [];
    }
  }

  /// Finds an atom by following a hierarchical path.
  ///
  /// This method navigates through nested container atoms following the
  /// specified path. Each element in the path represents an atom type
  /// to find at that level of the hierarchy.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data to search
  /// - [path]: List of atom types representing the path to follow
  ///
  /// Returns:
  /// - [Mp4Atom] if the complete path is found, null otherwise
  ///
  /// Example:
  /// ```dart
  /// // Find metadata: moov -> udta -> meta -> ilst
  /// final ilst = Mp4AtomParser.findAtomByPath(
  ///   fileBytes,
  ///   ['moov', 'udta', 'meta', 'ilst']
  /// );
  /// ```
  static Mp4Atom? findAtomByPath(Uint8List bytes, List<String> path) {
    if (path.isEmpty) return null;

    try {
      Uint8List currentData = bytes;
      Mp4Atom? currentAtom;

      for (final atomType in path) {
        currentAtom = findAtom(currentData, atomType);
        if (currentAtom == null) {
          return null; // Path not found
        }
        currentData = currentAtom.data;
      }

      return currentAtom;
    } catch (e) {
      // Return null if navigation fails
      return null;
    }
  }

  /// Extracts atom data by following a hierarchical path.
  ///
  /// This is a convenience method that combines [findAtomByPath] with
  /// data extraction, returning just the atom's payload data.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data to search
  /// - [path]: List of atom types representing the path to follow
  ///
  /// Returns:
  /// - [Uint8List] containing the atom's data, or null if not found
  ///
  /// Example:
  /// ```dart
  /// final metadataData = Mp4AtomParser.extractAtomData(
  ///   fileBytes,
  ///   ['moov', 'udta', 'meta', 'ilst']
  /// );
  /// ```
  static Uint8List? extractAtomData(Uint8List bytes, List<String> path) {
    final atom = findAtomByPath(bytes, path);
    return atom?.data;
  }

  /// Gets information about all atoms in the data without parsing payloads.
  ///
  /// This method provides a lightweight way to inspect the atom structure
  /// without loading all atom data into memory. It returns only the headers
  /// for efficient structure analysis.
  ///
  /// Parameters:
  /// - [bytes]: MP4 file data or container data
  ///
  /// Returns:
  /// - List of [Mp4AtomHeader] objects
  ///
  /// Example:
  /// ```dart
  /// final headers = Mp4AtomParser.getAtomHeaders(fileBytes);
  /// for (final header in headers) {
  ///   print('${header.type}: ${header.size} bytes at offset ${header.offset}');
  /// }
  /// ```
  static List<Mp4AtomHeader> getAtomHeaders(Uint8List bytes) {
    final reader = ByteReader(bytes);
    final headers = <Mp4AtomHeader>[];

    while (reader.hasRemaining) {
      try {
        final header = Mp4AtomHeader.parse(reader);
        headers.add(header);

        // Skip the atom data
        reader.skip(header.dataSize);
      } catch (e) {
        // Stop parsing on error
        break;
      }
    }

    return headers;
  }

  /// Validates the basic structure of MP4 atom data.
  ///
  /// This method performs basic validation to ensure the data contains
  /// valid MP4 atoms without fully parsing them. It's useful for quick
  /// format validation.
  ///
  /// Parameters:
  /// - [bytes]: Data to validate
  ///
  /// Returns:
  /// - true if the data appears to contain valid MP4 atoms
  ///
  /// Example:
  /// ```dart
  /// if (Mp4AtomParser.isValidAtomData(fileBytes)) {
  ///   final atoms = Mp4AtomParser.parseAtoms(fileBytes);
  /// }
  /// ```
  static bool isValidAtomData(Uint8List bytes) {
    if (bytes.length < 8) return false;

    try {
      final reader = ByteReader(bytes);

      // Try to parse at least one atom header
      while (reader.hasRemaining) {
        final header = Mp4AtomHeader.parse(reader);

        // Validate atom size is reasonable
        if (header.size > bytes.length || header.size < 8) {
          return false;
        }

        // Skip to next atom
        reader.seek(header.nextAtomOffset);

        // If we successfully parsed one atom, consider it valid
        if (reader.position > 8) {
          return true;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a freeform atom (----) into its domain and name components.
  ///
  /// Freeform atoms use the format ----:domain:name and contain custom metadata
  /// fields that aren't covered by standard iTunes atoms. The atom structure is:
  ///
  /// ```
  /// [---- atom header: 8 bytes]
  /// [mean atom: variable] - contains domain string
  /// [name atom: variable] - contains field name string
  /// [data atom: variable] - contains the actual field value
  /// ```
  ///
  /// Each sub-atom has its own header with size and type fields.
  ///
  /// Parameters:
  /// - [atom]: The ---- atom containing freeform metadata
  ///
  /// Returns:
  /// - [FreeformAtomData] containing parsed domain, name, and data, or null if malformed
  ///
  /// Example:
  /// ```dart
  /// final freeformAtom = Mp4Atom.parse(reader);
  /// final parsed = Mp4AtomParser.parseFreeformAtom(freeformAtom);
  /// if (parsed != null) {
  ///   print('Domain: ${parsed.domain}');
  ///   print('Name: ${parsed.name}');
  ///   print('Data: ${parsed.data}');
  /// }
  /// ```
  static FreeformAtomData? parseFreeformAtom(Mp4Atom atom) {
    if (atom.header.type != '----') {
      return null;
    }

    try {
      final reader = ByteReader(atom.data);
      String? domain;
      String? name;
      Uint8List? data;

      // Parse child atoms within the freeform atom
      while (reader.hasRemaining) {
        final childHeader = Mp4AtomHeader.parse(reader);
        final childData = reader.readBytes(childHeader.dataSize);

        switch (childHeader.type) {
          case 'mean':
            domain = _parseFreeformMeanAtom(childData);
            break;
          case 'name':
            name = _parseFreeformNameAtom(childData);
            break;
          case 'data':
            data = _parseFreeformDataAtom(childData);
            break;
          default:
            // Skip unknown child atoms
            break;
        }
      }

      // All components are required for a valid freeform atom
      if (domain != null && name != null && data != null) {
        return FreeformAtomData(
          domain: domain,
          name: name,
          data: data,
        );
      }

      return null;
    } catch (e) {
      // Return null if parsing fails
      return null;
    }
  }

  /// Parses the 'mean' atom within a freeform atom to extract the domain.
  ///
  /// The mean atom contains the domain string with a 4-byte version/flags prefix:
  /// [version/flags: 4 bytes][domain string: UTF-8]
  static String? _parseFreeformMeanAtom(Uint8List meanData) {
    if (meanData.length < 4) return null;

    try {
      final reader = ByteReader(meanData);

      // Skip version/flags (4 bytes)
      reader.skip(4);

      // Read domain string
      final domainBytes = reader.readRemainingBytes();
      return String.fromCharCodes(domainBytes).trim();
    } catch (e) {
      return null;
    }
  }

  /// Parses the 'name' atom within a freeform atom to extract the field name.
  ///
  /// The name atom contains the field name string with a 4-byte version/flags prefix:
  /// [version/flags: 4 bytes][name string: UTF-8]
  static String? _parseFreeformNameAtom(Uint8List nameData) {
    if (nameData.length < 4) return null;

    try {
      final reader = ByteReader(nameData);

      // Skip version/flags (4 bytes)
      reader.skip(4);

      // Read name string
      final nameBytes = reader.readRemainingBytes();
      return String.fromCharCodes(nameBytes).trim();
    } catch (e) {
      return null;
    }
  }

  /// Parses the 'data' atom within a freeform atom to extract the field value.
  ///
  /// The data atom contains the actual field value with type information:
  /// [type/flags: 4 bytes][locale: 4 bytes][data: variable]
  ///
  /// Common type values:
  /// - 0x00000001: UTF-8 text
  /// - 0x00000015: Signed integer (big-endian)
  /// - 0x00000016: Unsigned integer (big-endian)
  /// - 0x00000000: Binary data
  static Uint8List? _parseFreeformDataAtom(Uint8List dataAtomData) {
    if (dataAtomData.length < 8) return null;

    try {
      final reader = ByteReader(dataAtomData);

      // Skip type/flags and locale (8 bytes total)
      reader.skip(8);

      // Return the actual data payload
      return reader.readRemainingBytes();
    } catch (e) {
      return null;
    }
  }

  /// Detects the data type of a freeform atom's data payload.
  ///
  /// Examines the type field in the data atom to determine how the
  /// payload should be interpreted.
  ///
  /// Parameters:
  /// - [dataAtomData]: Raw data atom bytes including type/flags header
  ///
  /// Returns:
  /// - [FreeformDataType] indicating how to interpret the data
  static FreeformDataType detectFreeformDataType(Uint8List dataAtomData) {
    if (dataAtomData.length < 4) {
      return FreeformDataType.binary;
    }

    try {
      final reader = ByteReader(dataAtomData);
      final typeValue = reader.readUint32();

      switch (typeValue) {
        case 0x00000001:
          return FreeformDataType.utf8Text;
        case 0x00000015:
          return FreeformDataType.signedInteger;
        case 0x00000016:
          return FreeformDataType.unsignedInteger;
        case 0x00000000:
        default:
          return FreeformDataType.binary;
      }
    } catch (e) {
      return FreeformDataType.binary;
    }
  }

  /// Converts freeform atom data to a typed value based on its data type.
  ///
  /// This method interprets the raw data bytes according to the detected
  /// or specified data type, returning an appropriate Dart value.
  ///
  /// Parameters:
  /// - [data]: Raw data bytes from the freeform atom
  /// - [dataType]: How to interpret the data
  ///
  /// Returns:
  /// - Typed value (String, int, or Uint8List)
  static dynamic convertFreeformData(Uint8List data, FreeformDataType dataType) {
    try {
      switch (dataType) {
        case FreeformDataType.utf8Text:
          return String.fromCharCodes(data).trim();

        case FreeformDataType.signedInteger:
          if (data.length >= 4) {
            final reader = ByteReader(data);
            return reader.readInt32();
          } else if (data.length >= 2) {
            final reader = ByteReader(data);
            return reader.readInt16();
          } else if (data.isNotEmpty) {
            return data[0] > 127 ? data[0] - 256 : data[0];
          }
          return 0;

        case FreeformDataType.unsignedInteger:
          if (data.length >= 4) {
            final reader = ByteReader(data);
            return reader.readUint32();
          } else if (data.length >= 2) {
            final reader = ByteReader(data);
            return reader.readUint16();
          } else if (data.isNotEmpty) {
            return data[0];
          }
          return 0;

        case FreeformDataType.binary:
          return data;
      }
    } catch (e) {
      // Return raw data if conversion fails
      return data;
    }
  }

  /// Private constructor to prevent instantiation.
  Mp4AtomParser._();
}

/// Represents parsed data from a freeform MP4 atom.
///
/// Freeform atoms use the format ----:domain:name and allow custom metadata
/// fields beyond the standard iTunes atom set. This class holds the parsed
/// components of such an atom.
class FreeformAtomData {
  /// The domain portion of the freeform atom (e.g., "com.example.app").
  final String domain;

  /// The field name portion of the freeform atom (e.g., "CUSTOM_FIELD").
  final String name;

  /// The raw data payload of the freeform atom.
  final Uint8List data;

  /// Creates a freeform atom data container.
  const FreeformAtomData({
    required this.domain,
    required this.name,
    required this.data,
  });

  /// Returns the full freeform atom identifier in ----:domain:name format.
  String get fullIdentifier => '----:$domain:$name';

  @override
  String toString() {
    return 'FreeformAtomData(domain: "$domain", name: "$name", '
        'dataLength: ${data.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FreeformAtomData && other.domain == domain && other.name == name && _listEquals(other.data, data);
  }

  @override
  int get hashCode {
    return Object.hash(domain, name, Object.hashAll(data));
  }

  /// Helper method to compare Uint8List for equality.
  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Enumeration of data types supported in freeform MP4 atoms.
///
/// These types correspond to the type field in the data atom within
/// a freeform atom structure.
enum FreeformDataType {
  /// UTF-8 encoded text string (type 0x00000001).
  utf8Text,

  /// Signed integer in big-endian format (type 0x00000015).
  signedInteger,

  /// Unsigned integer in big-endian format (type 0x00000016).
  unsignedInteger,

  /// Binary data or unknown format (type 0x00000000 or others).
  binary,
}
