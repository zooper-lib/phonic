import 'dart:convert';
import 'dart:typed_data';

import 'package:phonic/src/capabilities/mp4_capability.dart';
import 'package:phonic/src/core/container_kind.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/core/tag_capability.dart';
import 'package:phonic/src/core/tag_codec.dart';
import 'package:phonic/src/core/tag_confidence.dart';
import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/core/tag_provenance.dart';
import 'package:phonic/src/exceptions/corrupted_container_exception.dart';
import 'package:phonic/src/utils/byte_reader.dart';
import 'package:phonic/src/utils/mp4_atom_parser.dart';
import 'package:phonic/src/utils/mp4_standard_atom_parser.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

import 'mp4_atom_map.dart';

/// MP4 atoms metadata codec for reading and writing MP4 ilst atom metadata.
///
/// This codec handles the MP4 metadata format, which uses iTunes-style atoms
/// within the ilst container for metadata storage in MP4, M4A, M4V, and similar
/// container formats. The MP4 format provides comprehensive metadata support
/// through a hierarchical atom structure with both standardized iTunes-compatible
/// atoms and extensible freeform atoms for custom metadata.
///
/// ## Key Features
///
/// - **UTF-8 encoding**: Exclusive use of UTF-8 for all text atoms
/// - **Hierarchical structure**: moov.udta.meta.ilst atom hierarchy
/// - **iTunes compatibility**: Standard atoms (©nam, ©ART, trkn, disk, etc.)
/// - **Freeform atoms**: Custom metadata (----:domain:name format)
/// - **Type-aware storage**: Text, integers, and binary data support
/// - **Multiple artwork**: covr atoms with type classification
/// - **Efficient binary**: Atom size headers and clear boundaries
///
/// ## Atom Mappings
///
/// The codec maps unified tag keys to MP4 atom identifiers:
/// - [TagKey.title] → ©nam (Title)
/// - [TagKey.artist] → ©ART (Artist)
/// - [TagKey.album] → ©alb (Album)
/// - [TagKey.albumArtist] → aART (Album Artist)
/// - [TagKey.genre] → ©gen (Genre, semicolon-separated for multiple values)
/// - [TagKey.comment] → ©cmt (Comment)
/// - [TagKey.grouping] → ©grp (Grouping)
/// - [TagKey.composer] → ©wrt (Composer)
/// - [TagKey.encoder] → ©too (Encoder)
/// - [TagKey.isrc] → ----:com.apple.iTunes:ISRC (ISRC freeform)
/// - [TagKey.musicalKey] → ----:com.apple.iTunes:initialkey (Musical Key freeform)
/// - [TagKey.lyrics] → ©lyr (Lyrics)
/// - [TagKey.trackNumber] → trkn (Track Number, binary format)
/// - [TagKey.discNumber] → disk (Disc Number, binary format)
/// - [TagKey.year] → ©day (Year/Date)
/// - [TagKey.dateRecorded] → ©day (Date Recorded)
/// - [TagKey.bpm] → tmpo (BPM, 16-bit integer)
/// - [TagKey.rating] → rtng (Rating, 8-bit integer 0-100)
/// - [TagKey.artwork] → covr (Artwork, binary data with MIME type)
/// - [TagKey.custom] → ----:domain:name (Freeform atoms)
///
/// ## Genre Handling
///
/// MP4 uses semicolon-separated strings in the ©gen atom for multiple genres:
/// ```
/// Single genre: "Rock"
/// Multiple genres: "Rock;Alternative;Indie"
/// ```
///
/// This follows iTunes conventions and provides compatibility with most
/// MP4-compatible media players and tagging applications.
///
/// ## Binary Data Formats
///
/// ### Track/Disc Numbers
/// MP4 uses binary format for track and disc numbers:
/// - trkn: [padding][track][total][padding] (2 bytes each, big-endian)
/// - disk: [padding][disc][total][padding] (2 bytes each, big-endian)
///
/// ### BPM and Rating
/// - tmpo: 16-bit big-endian integer
/// - rtng: 8-bit integer (0-100 scale)
///
/// ## Usage Example
///
/// ```dart
/// final codec = Mp4AtomsCodec();
///
/// // Reading tags
/// final containerBytes = await locator.extract(fileBytes);
/// final tags = codec.readFromContainer(containerBytes);
///
/// // Writing tags
/// final tagsToWrite = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']),
/// ];
/// final newContainer = codec.writeToContainer(tagsToWrite: tagsToWrite);
/// ```
///
/// ## Error Handling
///
/// The codec handles various error conditions gracefully:
/// - **Corrupted atoms**: Skips corrupted atoms, continues parsing others
/// - **Unknown atoms**: Preserves unknown atoms for round-trip compatibility
/// - **Type mismatches**: Uses fallback parsing when atom types don't match expectations
/// - **Structural damage**: Parses recoverable data, reports issues
///
/// ## Performance Considerations
///
/// - **Lazy loading**: Artwork data is loaded on-demand using [LazyArtworkLoader]
/// - **Memory efficiency**: Avoids copying large byte arrays unnecessarily
/// - **Atom navigation**: Efficient hierarchical parsing of atom structure
/// - **Caching**: Atom parsing results can be cached for repeated access
class Mp4AtomsCodec implements TagCodec {
  /// Creates a new MP4 atoms codec instance.
  ///
  /// The codec is stateless and thread-safe, so a single instance can be
  /// reused across multiple files and threads.
  const Mp4AtomsCodec();

  @override
  ContainerKind get containerKind => ContainerKind.mp4;

  @override
  String get containerVersion => '';

  @override
  TagCapability get capability => mp4Capability;

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (containerBytes.isEmpty) {
      return <MetadataTag>[];
    }

    try {
      final tags = <MetadataTag>[];
      final provenance = TagProvenance(
        ContainerKind.mp4,
        containerVersion,
        TagConfidence.certain,
      );

      // Parse all atoms in the ilst container
      final atoms = Mp4AtomParser.parseAtoms(containerBytes);

      for (final atom in atoms) {
        final parsedTag = _parseAtom(atom, provenance, containerBytes);
        if (parsedTag != null) {
          tags.add(parsedTag);
        } else if (preservationManager != null) {
          // Preserve unknown atom for round-trip compatibility
          _preserveUnknownAtom(atom, preservationManager, containerBytes);
        }
      }

      return tags;
    } catch (e) {
      // Re-throw with additional context for debugging
      throw CorruptedContainerException(
        'Failed to parse MP4 ilst atoms: $e',
        context: 'MP4 atoms codec readFromContainer',
      );
    }
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    if (tagsToWrite.isEmpty) {
      // Return empty ilst atom structure
      return _buildEmptyIlstContainer();
    }

    // Build atoms from tags
    final atoms = <Uint8List>[];

    for (final tag in tagsToWrite) {
      final atomData = _buildAtomFromTag(tag);
      if (atomData != null) {
        atoms.add(atomData);
      }
    }

    // Add preserved unknown atoms if preservation is enabled
    if (preservationManager != null) {
      final preservedAtoms = _restorePreservedAtoms(preservationManager);
      atoms.addAll(preservedAtoms);
    }

    // Combine all atoms into a single container
    return _combineAtoms(atoms);
  }

  /// Parses a single MP4 atom into a MetadataTag.
  ///
  /// This method handles both standard iTunes-style atoms and freeform atoms,
  /// routing them to the appropriate parsing logic based on the atom type.
  ///
  /// Parameters:
  /// - [atom]: The MP4 atom to parse
  /// - [provenance]: Provenance information for the resulting tag
  /// - [containerBytes]: Full container bytes for lazy loading (artwork only)
  ///
  /// Returns:
  /// - [MetadataTag] if the atom was successfully parsed, null otherwise
  MetadataTag? _parseAtom(
    Mp4Atom atom,
    TagProvenance provenance,
    Uint8List containerBytes,
  ) {
    final atomType = atom.header.type;

    // Handle freeform atoms (----:domain:name format)
    if (atomType == '----') {
      return _parseFreeformAtom(atom, provenance);
    }

    // Handle standard atoms using the standard atom parser
    return Mp4StandardAtomParser.parseStandardAtom(
      atom,
      provenance,
      containerBytes,
    );
  }

  /// Parses a freeform MP4 atom into a MetadataTag.
  ///
  /// Freeform atoms use the format ----:domain:name and contain custom metadata
  /// fields that aren't covered by standard iTunes atoms. This method extracts
  /// the domain, name, and data components and creates appropriate tags.
  ///
  /// Parameters:
  /// - [atom]: The ---- atom containing freeform metadata
  /// - [provenance]: Provenance information for the resulting tag
  ///
  /// Returns:
  /// - [MetadataTag] if the freeform atom was successfully parsed, null otherwise
  MetadataTag? _parseFreeformAtom(
    Mp4Atom atom,
    TagProvenance provenance,
  ) {
    try {
      final reader = ByteReader(atom.data);
      String? domain;
      String? name;
      Uint8List? fullDataAtom;

      // Parse child atoms within the freeform atom to get full data atom
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
            fullDataAtom = childData; // Keep the full data atom with type/flags
            break;
          default:
            // Skip unknown child atoms
            break;
        }
      }

      // All components are required for a valid freeform atom
      if (domain == null || name == null || fullDataAtom == null) {
        return null;
      }

      // Check if this is a known freeform field
      final tagKey = Mp4AtomMap.getTagKeyFromFreeform(name);
      if (tagKey == null) {
        // Unknown freeform field, treat as custom tag
        final dataType = Mp4AtomParser.detectFreeformDataType(fullDataAtom);
        final payloadData = _extractFreeformPayload(fullDataAtom);
        final value = Mp4AtomParser.convertFreeformData(payloadData, dataType);

        // Convert to string for CustomTag
        final stringValue = value is String ? value : value.toString();
        return CustomTag(stringValue, provenance: provenance);
      }

      // Handle known freeform fields
      return _createTagFromFreeformData(tagKey, fullDataAtom, provenance);
    } catch (e) {
      return null; // Malformed freeform atom
    }
  }

  /// Creates a MetadataTag from parsed freeform atom data.
  ///
  /// This method handles the conversion of freeform atom data to the appropriate
  /// tag type based on the unified tag key.
  ///
  /// Parameters:
  /// - [tagKey]: The unified tag key for this field
  /// - [fullDataAtom]: The full data atom bytes including type/flags
  /// - [provenance]: Provenance information for the resulting tag
  ///
  /// Returns:
  /// - [MetadataTag] containing the parsed freeform data
  MetadataTag _createTagFromFreeformData(
    TagKey tagKey,
    Uint8List fullDataAtom,
    TagProvenance provenance,
  ) {
    final dataType = Mp4AtomParser.detectFreeformDataType(fullDataAtom);
    final payloadData = _extractFreeformPayload(fullDataAtom);
    final value = Mp4AtomParser.convertFreeformData(payloadData, dataType);

    switch (tagKey) {
      case TagKey.musicalKey:
        final stringValue = value is String ? value : value.toString();
        return MusicalKeyTag(stringValue, provenance: provenance);

      case TagKey.rating:
        // Rating should be an integer 0-100
        int ratingValue;
        if (value is int) {
          ratingValue = value.clamp(0, 100);
        } else if (value is String) {
          ratingValue = int.tryParse(value)?.clamp(0, 100) ?? 0;
        } else {
          ratingValue = 0;
        }
        return RatingTag(ratingValue, provenance: provenance);

      case TagKey.isrc:
        final stringValue = value is String ? value : value.toString();
        return IsrcTag(stringValue, provenance: provenance);

      case TagKey.custom:
        final stringValue = value is String ? value : value.toString();
        return CustomTag(stringValue, provenance: provenance);

      default:
        // Fallback to custom tag for unexpected freeform fields
        final stringValue = value is String ? value : value.toString();
        return CustomTag(stringValue, provenance: provenance);
    }
  }

  /// Parses the 'mean' atom within a freeform atom to extract the domain.
  String? _parseFreeformMeanAtom(Uint8List meanData) {
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
  String? _parseFreeformNameAtom(Uint8List nameData) {
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

  /// Extracts the payload data from a freeform data atom.
  Uint8List _extractFreeformPayload(Uint8List fullDataAtom) {
    if (fullDataAtom.length < 8) return Uint8List(0);

    try {
      final reader = ByteReader(fullDataAtom);
      // Skip type/flags and locale (8 bytes total)
      reader.skip(8);
      // Return the actual data payload
      return reader.readRemainingBytes();
    } catch (e) {
      return Uint8List(0);
    }
  }

  /// Builds an empty ilst container for when no tags are provided.
  Uint8List _buildEmptyIlstContainer() {
    // Return minimal empty container (just the header)
    const atomSize = 8; // Just the header, no data
    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header for empty ilst
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'ilst'.codeUnits); // type

    return result;
  }

  /// Builds an MP4 atom from a MetadataTag.
  Uint8List? _buildAtomFromTag(MetadataTag tag) {
    switch (tag.key) {
      // Standard text atoms
      case TagKey.title:
        return _buildTextAtom('©nam', tag.value as String);
      case TagKey.artist:
        return _buildTextAtom('©ART', tag.value as String);
      case TagKey.album:
        return _buildTextAtom('©alb', tag.value as String);
      case TagKey.albumArtist:
        return _buildTextAtom('aART', tag.value as String);
      case TagKey.comment:
        return _buildTextAtom('©cmt', tag.value as String);
      case TagKey.grouping:
        return _buildTextAtom('©grp', tag.value as String);
      case TagKey.composer:
        return _buildTextAtom('©wrt', tag.value as String);
      case TagKey.encoder:
        return _buildTextAtom('©too', tag.value as String);
      case TagKey.lyrics:
        return _buildTextAtom('©lyr', tag.value as String);
      case TagKey.dateRecorded:
        return _buildTextAtom('©day', tag.value as String);
      case TagKey.year:
        // Convert year to date string
        final yearValue = tag.value as int;
        return _buildTextAtom('©day', yearValue.toString());
      case TagKey.genre:
        // Handle GenreTag with semicolon separation for MP4
        final genreTag = tag as GenreTag;
        final genreString = genreTag.toEncodedString(';');
        return _buildTextAtom('©gen', genreString);

      // Binary number atoms
      case TagKey.trackNumber:
        return _buildTrackNumberAtom(tag.value as int);
      case TagKey.discNumber:
        return _buildDiscNumberAtom(tag.value as int);
      case TagKey.bpm:
        return _buildBpmAtom(tag.value as int);

      // Artwork atoms
      case TagKey.artwork:
        return _buildArtworkAtom(tag as ArtworkTag);

      // Freeform atoms
      case TagKey.musicalKey:
        return _buildFreeformAtom(
          Mp4AtomMap.freeformDomain,
          Mp4AtomMap.getFreeformAtomName(TagKey.musicalKey)!,
          0x00000001, // UTF-8 text
          Uint8List.fromList(utf8.encode(tag.value as String)),
        );
      case TagKey.rating:
        return _buildFreeformAtom(
          Mp4AtomMap.freeformDomain,
          Mp4AtomMap.getFreeformAtomName(TagKey.rating)!,
          0x00000016, // Unsigned integer
          _buildIntegerData(tag.value as int),
        );
      case TagKey.isrc:
        return _buildFreeformAtom(
          Mp4AtomMap.freeformDomain,
          Mp4AtomMap.getFreeformAtomName(TagKey.isrc)!,
          0x00000001, // UTF-8 text
          Uint8List.fromList(utf8.encode(tag.value as String)),
        );
      case TagKey.custom:
        return _buildFreeformAtom(
          Mp4AtomMap.freeformDomain,
          Mp4AtomMap.getFreeformAtomName(TagKey.custom)!,
          0x00000001, // UTF-8 text
          Uint8List.fromList(utf8.encode(tag.value as String)),
        );
    }
  }

  /// Builds a text atom (©nam, ©ART, etc.)
  Uint8List _buildTextAtom(String atomType, String text) {
    final textBytes = Uint8List.fromList(utf8.encode(text));
    final dataSize = 4 + textBytes.length; // type field + text
    final atomSize = 8 + dataSize; // header + data

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, atomType.codeUnits); // type

    // Data type (UTF-8 text)
    view.setUint32(8, 0x00000001, Endian.big);

    // Text data
    result.setRange(12, 12 + textBytes.length, textBytes);

    return result;
  }

  /// Builds a track number atom (trkn)
  Uint8List _buildTrackNumberAtom(int trackNumber) {
    const atomSize = 20; // 8 byte header + 4 byte type + 8 byte track data
    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'trkn'.codeUnits); // type

    // Data type (binary)
    view.setUint32(8, 0x00000000, Endian.big);

    // Track data: [padding][track][total][padding]
    view.setUint16(12, 0, Endian.big); // padding
    view.setUint16(14, trackNumber, Endian.big); // track number
    view.setUint16(16, 0, Endian.big); // total tracks (unknown)
    view.setUint16(18, 0, Endian.big); // padding

    return result;
  }

  /// Builds a disc number atom (disk)
  Uint8List _buildDiscNumberAtom(int discNumber) {
    const atomSize = 20; // 8 byte header + 4 byte type + 8 byte disc data
    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'disk'.codeUnits); // type

    // Data type (binary)
    view.setUint32(8, 0x00000000, Endian.big);

    // Disc data: [padding][disc][total][padding]
    view.setUint16(12, 0, Endian.big); // padding
    view.setUint16(14, discNumber, Endian.big); // disc number
    view.setUint16(16, 0, Endian.big); // total discs (unknown)
    view.setUint16(18, 0, Endian.big); // padding

    return result;
  }

  /// Builds a BPM atom (tmpo)
  Uint8List _buildBpmAtom(int bpm) {
    const atomSize = 16; // 8 byte header + 4 byte type + 4 byte data
    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'tmpo'.codeUnits); // type

    // Data type (16-bit integer)
    view.setUint32(8, 0x00000015, Endian.big);

    // BPM value (16-bit) with padding
    view.setUint16(12, bpm, Endian.big);
    view.setUint16(14, 0, Endian.big); // padding

    return result;
  }

  /// Builds an artwork atom (covr)
  Uint8List _buildArtworkAtom(ArtworkTag artworkTag) {
    // For now, we'll create a placeholder since artwork data is lazy-loaded
    // In a real implementation, we'd need to load the artwork data
    final artworkData = artworkTag.value;

    // Create a simple placeholder atom structure
    // In practice, this would need to load the actual image data
    final imageData = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG signature as placeholder
    ]);

    final dataSize = 4 + imageData.length; // type field + image data
    final atomSize = 8 + dataSize; // header + data

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'covr'.codeUnits); // type

    // Data type (JPEG by default)
    final dataType = artworkData.mimeType == 'image/png' ? 0x0000000E : 0x0000000D;
    view.setUint32(8, dataType, Endian.big);

    // Image data (placeholder)
    result.setRange(12, 12 + imageData.length, imageData);

    return result;
  }

  /// Builds a freeform atom (----)
  Uint8List _buildFreeformAtom(
    String domain,
    String name,
    int dataType,
    Uint8List data,
  ) {
    final meanAtom = _buildMeanAtom(domain);
    final nameAtom = _buildNameAtom(name);
    final dataAtom = _buildDataAtom(dataType, data);

    final totalDataSize = meanAtom.length + nameAtom.length + dataAtom.length;
    final atomSize = 8 + totalDataSize; // header + sub-atoms

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, '----'.codeUnits); // type

    // Sub-atoms
    int offset = 8;
    result.setRange(offset, offset + meanAtom.length, meanAtom);
    offset += meanAtom.length;

    result.setRange(offset, offset + nameAtom.length, nameAtom);
    offset += nameAtom.length;

    result.setRange(offset, offset + dataAtom.length, dataAtom);

    return result;
  }

  /// Builds a 'mean' sub-atom for freeform atoms
  Uint8List _buildMeanAtom(String domain) {
    final domainBytes = Uint8List.fromList(utf8.encode(domain));
    final atomSize = 8 + 4 + domainBytes.length; // header + version/flags + domain

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'mean'.codeUnits); // type

    // Version/flags (4 bytes of zeros)
    view.setUint32(8, 0, Endian.big);

    // Domain string
    result.setRange(12, 12 + domainBytes.length, domainBytes);

    return result;
  }

  /// Builds a 'name' sub-atom for freeform atoms
  Uint8List _buildNameAtom(String name) {
    final nameBytes = Uint8List.fromList(utf8.encode(name));
    final atomSize = 8 + 4 + nameBytes.length; // header + version/flags + name

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'name'.codeUnits); // type

    // Version/flags (4 bytes of zeros)
    view.setUint32(8, 0, Endian.big);

    // Name string
    result.setRange(12, 12 + nameBytes.length, nameBytes);

    return result;
  }

  /// Builds a 'data' sub-atom for freeform atoms
  Uint8List _buildDataAtom(int dataType, Uint8List data) {
    final atomSize = 8 + 8 + data.length; // header + type/flags + locale + data

    final result = Uint8List(atomSize);
    final view = ByteData.sublistView(result);

    // Atom header
    view.setUint32(0, atomSize, Endian.big); // size
    result.setRange(4, 8, 'data'.codeUnits); // type

    // Type/flags
    view.setUint32(8, dataType, Endian.big);

    // Locale (4 bytes of zeros)
    view.setUint32(12, 0, Endian.big);

    // Data payload
    result.setRange(16, 16 + data.length, data);

    return result;
  }

  /// Builds integer data for freeform atoms
  Uint8List _buildIntegerData(int value) {
    final result = Uint8List(4);
    final view = ByteData.sublistView(result);
    view.setUint32(0, value, Endian.big);
    return result;
  }

  /// Combines multiple atoms into a single container
  Uint8List _combineAtoms(List<Uint8List> atoms) {
    if (atoms.isEmpty) {
      return _buildEmptyIlstContainer();
    }

    // Calculate total size
    final totalDataSize = atoms.fold<int>(0, (sum, atom) => sum + atom.length);
    final containerSize = totalDataSize; // No additional container header needed

    final result = Uint8List(containerSize);
    int offset = 0;

    // Copy all atoms
    for (final atom in atoms) {
      result.setRange(offset, offset + atom.length, atom);
      offset += atom.length;
    }

    return result;
  }

  /// Preserves an unknown atom for round-trip compatibility.
  ///
  /// This method stores unknown atoms in the preservation manager so they
  /// can be restored during write operations, maintaining file integrity.
  void _preserveUnknownAtom(
    Mp4Atom atom,
    UnknownDataPreservationManager preservationManager,
    Uint8List containerBytes,
  ) {
    // Extract the complete atom data including header
    final atomStart = atom.header.offset;
    final atomEnd = atomStart + atom.header.size;

    if (atomEnd <= containerBytes.length) {
      final atomData = containerBytes.sublist(atomStart, atomEnd.toInt());

      // Create preserved data for this unknown atom
      final preservedData = PreservedUnknownData.mp4Atom(
        atomType: atom.header.type,
        atomData: atomData,
        originalOffset: atomStart,
        additionalMetadata: {
          'atom_size': atom.header.size,
          'data_size': atom.header.dataSize,
          'is_extended': atom.header.isExtendedSize,
        },
      );

      // Add to preservation manager
      preservationManager.addPreservedData(preservedData);
    }
  }

  /// Restores preserved unknown atoms during write operations.
  ///
  /// This method retrieves unknown atoms from the preservation manager
  /// and converts them back to MP4 atom format for inclusion in
  /// the output container.
  List<Uint8List> _restorePreservedAtoms(
    UnknownDataPreservationManager preservationManager,
  ) {
    final preservedAtoms = <Uint8List>[];
    final preservedData = preservationManager.getPreservedData('mp4');

    for (final data in preservedData) {
      // Validate that this is safe to restore
      if (!data.isValidForWriting()) {
        continue; // Skip invalid data
      }

      // The preserved data already contains the complete atom with header
      preservedAtoms.add(data.data);
    }

    return preservedAtoms;
  }
}
