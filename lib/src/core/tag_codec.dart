import 'dart:typed_data';

import '../utils/unknown_data_preservation.dart';
import 'container_kind.dart';
import 'metadata_tag.dart';
import 'tag_capability.dart';

/// Abstract interface for reading and writing metadata tags from container formats.
///
/// [TagCodec] defines the contract for converting between raw container bytes
/// and the unified [MetadataTag] representation. Each codec implementation
/// handles a specific container format and version, providing format-specific
/// parsing and encoding logic while maintaining a consistent interface.
///
/// The codec system enables the library to:
/// - Parse metadata from different container formats uniformly
/// - Write metadata to containers with format-specific encoding
/// - Validate tag operations against container capabilities
/// - Maintain provenance information during conversions
/// - Handle format-specific constraints and normalization
///
/// ## Codec Responsibilities
///
/// Each codec implementation must:
/// 1. **Parse container bytes** into [MetadataTag] instances with proper provenance
/// 2. **Encode tag collections** into valid container byte sequences
/// 3. **Validate tag compatibility** against the container's capabilities
/// 4. **Handle format-specific constraints** (length limits, encoding, etc.)
/// 5. **Preserve unknown data** when possible to avoid data loss
/// 6. **Provide error recovery** for corrupted or partial containers
///
/// ## Container Format Examples
///
/// ### ID3v2 Codec Implementation
/// ```dart
/// class Id3v24Codec implements TagCodec {
///   @override
///   ContainerKind get containerKind => ContainerKind.id3v2;
///
///   @override
///   String get containerVersion => '2.4';
///
///   @override
///   TagCapability get capability => id3v24Capability;
///
///   @override
///   List<MetadataTag> readFromContainer(Uint8List containerBytes) {
///     final reader = ByteReader(containerBytes);
///     final header = _parseId3v2Header(reader);
///     final frames = _parseFrames(reader, header);
///
///     return frames.map((frame) {
///       switch (frame.id) {
///         case 'TIT2':
///           return TitleTag(
///             _parseTextFrame(frame),
///             provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
///           );
///         case 'TCON':
///           // ID3v2.4 uses null-terminated strings for genres
///           final genreString = _parseTextFrame(frame);
///           return GenreTag.fromId3v24String(
///             genreString,
///             provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
///           );
///         case 'APIC':
///           return ArtworkTag(
///             _parseArtworkFrame(frame),
///             provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
///           );
///         // ... handle other frames
///         default:
///           return null; // Unknown frame, skip or preserve
///       }
///     }).whereType<MetadataTag>().toList();
///   }
///
///   @override
///   Uint8List writeToContainer({
///     required List<MetadataTag> tagsToWrite,
///     Uint8List? existingContainerBytes,
///   }) {
///     final frames = <Id3v2Frame>[];
///
///     for (final tag in tagsToWrite) {
///       if (!capability.supports(tag.key)) continue;
///
///       switch (tag.key) {
///         case TagKey.title:
///           frames.add(_buildTextFrame('TIT2', tag.value as String));
///           break;
///         case TagKey.genre:
///           // ID3v2.4 encodes multiple genres with null terminators
///           final genreTag = tag as GenreTag;
///           final encodedGenres = genreTag.toId3v24String();
///           frames.add(_buildTextFrame('TCON', encodedGenres));
///           break;
///         case TagKey.artwork:
///           final artworkTag = tag as ArtworkTag;
///           frames.add(await _buildArtworkFrame('APIC', artworkTag.value));
///           break;
///         // ... handle other tag types
///       }
///     }
///
///     return _buildId3v2Container(frames);
///   }
/// }
/// ```
///
/// ### Vorbis Comments Codec Implementation
/// ```dart
/// class VorbisCommentsCodec implements TagCodec {
///   @override
///   ContainerKind get containerKind => ContainerKind.vorbis;
///
///   @override
///   String get containerVersion => '';
///
///   @override
///   TagCapability get capability => vorbisCapability;
///
///   @override
///   List<MetadataTag> readFromContainer(Uint8List containerBytes) {
///     final comments = _parseVorbisComments(containerBytes);
///     final tags = <MetadataTag>[];
///
///     // Group comments by field name for multi-valued fields
///     final commentsByKey = <String, List<String>>{};
///     for (final comment in comments) {
///       final key = comment.key.toUpperCase();
///       commentsByKey.putIfAbsent(key, () => []).add(comment.value);
///     }
///
///     for (final entry in commentsByKey.entries) {
///       final tagKey = _vorbisKeyToTagKey(entry.key);
///       if (tagKey == null) continue;
///
///       final provenance = TagProvenance(containerKind, containerVersion, TagConfidence.certain);
///
///       switch (tagKey) {
///         case TagKey.genre:
///           // Vorbis supports multiple GENRE fields natively
///           // Also handle cases where some fields contain delimited values
///           final allGenres = <String>[];
///           for (final genreField in entry.value) {
///             if (_containsDelimiters(genreField)) {
///               allGenres.addAll(GenreTag.fromString(genreField).value);
///             } else {
///               allGenres.add(genreField);
///             }
///           }
///           tags.add(GenreTag(allGenres, provenance: provenance));
///           break;
///         case TagKey.title:
///           // Use first value for single-valued fields
///           tags.add(TitleTag(entry.value.first, provenance: provenance));
///           break;
///         // ... handle other fields
///       }
///     }
///
///     return tags;
///   }
///
///   @override
///   Uint8List writeToContainer({
///     required List<MetadataTag> tagsToWrite,
///     Uint8List? existingContainerBytes,
///   }) {
///     final comments = <VorbisComment>[];
///
///     for (final tag in tagsToWrite) {
///       if (!capability.supports(tag.key)) continue;
///
///       final vorbisKey = _tagKeyToVorbisKey(tag.key);
///       if (vorbisKey == null) continue;
///
///       switch (tag.key) {
///         case TagKey.genre:
///           // Write multiple GENRE fields for Vorbis native multi-value support
///           final genreTag = tag as GenreTag;
///           for (final genre in genreTag.value) {
///             comments.add(VorbisComment(vorbisKey, genre));
///           }
///           break;
///         default:
///           // Single-valued fields
///           comments.add(VorbisComment(vorbisKey, tag.value.toString()));
///           break;
///       }
///     }
///
///     return _buildVorbisCommentBlock(comments);
///   }
/// }
/// ```
///
/// ## Usage Patterns
///
/// ### Reading Tags from Container
/// ```dart
/// final codec = Id3v24Codec();
/// final containerBytes = await locator.extract(fileBytes);
/// final tags = codec.readFromContainer(containerBytes);
///
/// // Tags now have proper provenance information
/// for (final tag in tags) {
///   print('${tag.key}: ${tag.value} (from ${tag.provenance})');
/// }
/// ```
///
/// ### Writing Tags to Container
/// ```dart
/// final codec = VorbisCommentsCodec();
/// final tagsToWrite = [
///   TitleTag('Song Title'),
///   ArtistTag('Artist Name'),
///   GenreTag(['Rock', 'Alternative']), // Multi-genre support
/// ];
///
/// // Validate tags against codec capabilities
/// final supportedTags = tagsToWrite.where((tag) =>
///   codec.capability.supports(tag.key)).toList();
///
/// final containerBytes = codec.writeToContainer(tagsToWrite: supportedTags);
/// ```
///
/// ### Codec Selection and Registry
/// ```dart
/// final registry = CodecRegistry();
/// final codec = registry.getCodec(ContainerKind.id3v2, '2.4');
///
/// if (codec != null) {
///   final tags = codec.readFromContainer(containerBytes);
///   // Process tags...
/// }
/// ```
///
/// ## Error Handling
///
/// Codecs should handle errors gracefully:
/// - **Corrupted data**: Skip corrupted frames/fields, continue parsing others
/// - **Unknown fields**: Preserve unknown data when possible
/// - **Validation failures**: Apply format-specific constraints and normalization
/// - **Version mismatches**: Handle minor version differences gracefully
///
/// ## Performance Considerations
///
/// - **Lazy loading**: Large payloads (artwork) should use lazy loading patterns
/// - **Streaming**: Support incremental parsing for large containers
/// - **Memory efficiency**: Avoid loading entire files into memory
/// - **Caching**: Cache parsed structures for repeated access
///
/// ## Thread Safety
///
/// Codec instances should be stateless and thread-safe:
/// - No mutable instance state
/// - Pure functions for parsing and encoding
/// - Immutable return values
/// - Safe for concurrent use across multiple files
abstract class TagCodec {
  /// The container format type that this codec handles.
  ///
  /// This identifies which metadata container format this codec can read
  /// from and write to. The container kind is used for:
  /// - Codec selection during format detection
  /// - Provenance tracking in parsed tags
  /// - Capability validation before writing
  /// - Format-specific precedence rules
  ///
  /// Examples:
  /// - [ContainerKind.id3v2] for ID3v2 formats
  /// - [ContainerKind.vorbis] for Vorbis Comments
  /// - [ContainerKind.mp4] for MP4 atom metadata
  /// - [ContainerKind.id3v1] for legacy ID3v1 tags
  ContainerKind get containerKind;

  /// The specific version of the container format this codec handles.
  ///
  /// Container formats often have multiple versions with different capabilities
  /// and encoding rules. The version string helps distinguish between these
  /// variants and enables version-specific processing.
  ///
  /// Version examples:
  /// - ID3v2: "2.2", "2.3", "2.4" (major differences in structure and encoding)
  /// - MP4: "" (generally unversioned, but implementations may vary)
  /// - Vorbis: "" (specification is stable, but extensions exist)
  /// - ID3v1: "v1" (includes v1.1 extensions)
  ///
  /// The version affects:
  /// - Field mapping and encoding rules
  /// - Supported character encodings
  /// - Available metadata fields
  /// - Structural differences in container format
  String get containerVersion;

  /// The capability definition for this container format and version.
  ///
  /// This property provides access to the complete set of supported fields
  /// and their semantic constraints for this specific container format.
  /// The capability is used throughout the library for:
  ///
  /// - **Validation**: Checking if tags can be written to this format
  /// - **Normalization**: Applying format-specific constraints (length limits, value ranges)
  /// - **User feedback**: Informing users about format limitations
  /// - **Fan-out decisions**: Determining which containers can store specific tags
  ///
  /// The capability should be a static constant that defines:
  /// - All supported tag fields for this format/version
  /// - Text length limitations (e.g., ID3v1's 30-character limits)
  /// - Numeric value ranges (e.g., rating scales, track number limits)
  /// - Multi-value support (e.g., Vorbis multi-valued fields)
  /// - Encoding restrictions (e.g., ID3v2.3 lacks UTF-8 support)
  ///
  /// Example capability definitions:
  /// ```dart
  /// // ID3v1 with strict limitations
  /// static const id3v1Capability = TagCapability(
  ///   containerKind: ContainerKind.id3v1,
  ///   containerVersion: 'v1',
  ///   semanticsByKey: {
  ///     TagKey.title: TagSemantics(maxTextLength: 30),
  ///     TagKey.artist: TagSemantics(maxTextLength: 30),
  ///     TagKey.album: TagSemantics(maxTextLength: 30),
  ///     TagKey.year: TagSemantics(maxTextLength: 4),
  ///     TagKey.comment: TagSemantics(maxTextLength: 30), // or 28 with track
  ///     TagKey.trackNumber: TagSemantics(minValue: 1, maxValue: 255),
  ///     TagKey.genre: TagSemantics(minValue: 0, maxValue: 255),
  ///   },
  /// );
  ///
  /// // Vorbis with multi-valued field support
  /// static const vorbisCapability = TagCapability(
  ///   containerKind: ContainerKind.vorbis,
  ///   containerVersion: '',
  ///   semanticsByKey: {
  ///     TagKey.genre: TagSemantics(multiValued: true),
  ///     TagKey.artwork: TagSemantics(multiValued: true),
  ///     // ... other fields with UTF-8 support and no length limits
  ///   },
  /// );
  /// ```
  TagCapability get capability;

  /// Parses metadata tags from raw container bytes.
  ///
  /// This method converts the binary representation of a metadata container
  /// into a list of typed [MetadataTag] instances. Each parsed tag includes
  /// proper provenance information indicating its source container and
  /// confidence level.
  ///
  /// ## Parsing Process
  ///
  /// 1. **Container Structure**: Parse the container's structural elements
  ///    (headers, frames, atoms, comments) according to format specifications
  /// 2. **Field Extraction**: Extract individual metadata fields from the
  ///    container structure, handling format-specific encoding and layout
  /// 3. **Value Conversion**: Convert raw field data to appropriate Dart types
  ///    with proper encoding handling (UTF-8, UTF-16, Latin-1, etc.)
  /// 4. **Tag Creation**: Create strongly-typed [MetadataTag] instances with
  ///    proper provenance information
  /// 5. **Error Recovery**: Handle corrupted or unknown fields gracefully,
  ///    continuing to parse other valid fields
  ///
  /// ## Format-Specific Considerations
  ///
  /// ### ID3v2 Parsing
  /// ```dart
  /// List<MetadataTag> readFromContainer(Uint8List containerBytes) {
  ///   final reader = ByteReader(containerBytes);
  ///   final header = _parseId3v2Header(reader);
  ///   final frames = _parseFrames(reader, header);
  ///
  ///   return frames.map((frame) {
  ///     final provenance = TagProvenance(containerKind, containerVersion, TagConfidence.certain);
  ///
  ///     switch (frame.id) {
  ///       case 'TIT2': return TitleTag(_parseTextFrame(frame), provenance: provenance);
  ///       case 'TCON':
  ///         // Handle version-specific genre encoding
  ///         if (containerVersion == '2.4') {
  ///           return GenreTag.fromId3v24String(_parseTextFrame(frame), provenance: provenance);
  ///         } else {
  ///           return GenreTag.fromId3v23String(_parseTextFrame(frame), provenance: provenance);
  ///         }
  ///       case 'APIC': return ArtworkTag(_parseArtworkFrame(frame), provenance: provenance);
  ///       default: return null; // Unknown frame
  ///     }
  ///   }).whereType<MetadataTag>().toList();
  /// }
  /// ```
  ///
  /// ### Vorbis Comments Parsing
  /// ```dart
  /// List<MetadataTag> readFromContainer(Uint8List containerBytes) {
  ///   final comments = _parseVorbisComments(containerBytes);
  ///   final tags = <MetadataTag>[];
  ///   final provenance = TagProvenance(containerKind, containerVersion, TagConfidence.certain);
  ///
  ///   // Handle multi-valued fields by grouping comments
  ///   final genreComments = comments.where((c) => c.key.toUpperCase() == 'GENRE').toList();
  ///   if (genreComments.isNotEmpty) {
  ///     final genres = genreComments.map((c) => c.value).toList();
  ///     tags.add(GenreTag(genres, provenance: provenance));
  ///   }
  ///
  ///   // Handle single-valued fields
  ///   final titleComment = comments.firstWhereOrNull((c) => c.key.toUpperCase() == 'TITLE');
  ///   if (titleComment != null) {
  ///     tags.add(TitleTag(titleComment.value, provenance: provenance));
  ///   }
  ///
  ///   return tags;
  /// }
  /// ```
  ///
  /// ## Error Handling
  ///
  /// Implementations should handle errors gracefully:
  /// - **Corrupted frames/fields**: Skip corrupted data, continue parsing others
  /// - **Unknown field types**: Ignore unknown fields or preserve for round-trip
  /// - **Encoding errors**: Use fallback encodings or mark as inferred
  /// - **Structural damage**: Parse what's recoverable, report issues
  ///
  /// ## Performance Considerations
  ///
  /// - **Lazy loading**: Use [LazyArtworkLoader] for large artwork data
  /// - **Streaming**: Parse incrementally for large containers when possible
  /// - **Memory efficiency**: Avoid copying large byte arrays unnecessarily
  /// - **Early termination**: Stop parsing on fatal structural errors
  ///
  /// @param containerBytes The raw bytes of the metadata container to parse
  /// @param preservationManager Optional manager for collecting unknown data during reads
  /// @returns List of parsed [MetadataTag] instances with provenance information
  /// @throws [CorruptedContainerException] for unrecoverable parsing errors
  /// @throws [UnsupportedFormatException] if the container format is not supported
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  });

  /// Encodes metadata tags into raw container bytes.
  ///
  /// This method converts a collection of [MetadataTag] instances into the
  /// binary representation required by the container format. The encoding
  /// process applies format-specific constraints, normalization, and
  /// structural requirements.
  ///
  /// ## Encoding Process
  ///
  /// 1. **Capability Validation**: Filter tags to only those supported by
  ///    this container format using the [capability] definition
  /// 2. **Value Normalization**: Apply format-specific constraints such as
  ///    text length limits, value ranges, and encoding requirements
  /// 3. **Structure Building**: Create the container's structural elements
  ///    (frames, atoms, comments) according to format specifications
  /// 4. **Binary Encoding**: Convert the structured data to binary format
  ///    with proper encoding, padding, and checksums as required
  /// 5. **Container Assembly**: Combine all elements into a complete
  ///    container with headers, size information, and metadata
  ///
  /// ## Format-Specific Considerations
  ///
  /// ### ID3v2 Encoding
  /// ```dart
  /// Uint8List writeToContainer({
  ///   required List<MetadataTag> tagsToWrite,
  ///   Uint8List? existingContainerBytes,
  /// }) {
  ///   final frames = <Id3v2Frame>[];
  ///
  ///   for (final tag in tagsToWrite) {
  ///     if (!capability.supports(tag.key)) continue;
  ///
  ///     switch (tag.key) {
  ///       case TagKey.title:
  ///         frames.add(_buildTextFrame('TIT2', tag.value as String));
  ///         break;
  ///       case TagKey.genre:
  ///         final genreTag = tag as GenreTag;
  ///         final encodedGenres = containerVersion == '2.4'
  ///           ? genreTag.toId3v24String()  // null-terminated
  ///           : genreTag.toId3v23String(); // slash-separated
  ///         frames.add(_buildTextFrame('TCON', encodedGenres));
  ///         break;
  ///       case TagKey.artwork:
  ///         final artworkTag = tag as ArtworkTag;
  ///         frames.add(await _buildArtworkFrame('APIC', artworkTag.value));
  ///         break;
  ///     }
  ///   }
  ///
  ///   return _buildId3v2Container(frames);
  /// }
  /// ```
  ///
  /// ### Vorbis Comments Encoding
  /// ```dart
  /// Uint8List writeToContainer({
  ///   required List<MetadataTag> tagsToWrite,
  ///   Uint8List? existingContainerBytes,
  /// }) {
  ///   final comments = <VorbisComment>[];
  ///
  ///   for (final tag in tagsToWrite) {
  ///     if (!capability.supports(tag.key)) continue;
  ///
  ///     final vorbisKey = _tagKeyToVorbisKey(tag.key);
  ///
  ///     switch (tag.key) {
  ///       case TagKey.genre:
  ///         // Use native multi-value support
  ///         final genreTag = tag as GenreTag;
  ///         for (final genre in genreTag.value) {
  ///           comments.add(VorbisComment(vorbisKey, genre));
  ///         }
  ///         break;
  ///       default:
  ///         comments.add(VorbisComment(vorbisKey, tag.value.toString()));
  ///         break;
  ///     }
  ///   }
  ///
  ///   return _buildVorbisCommentBlock(comments);
  /// }
  /// ```
  ///
  /// ## Constraint Handling
  ///
  /// The encoding process must handle format-specific constraints:
  ///
  /// ### Text Length Limits
  /// ```dart
  /// String normalizeText(String text, TagKey key) {
  ///   final semantics = capability.semantics(key);
  ///   if (semantics.maxTextLength != null && text.length > semantics.maxTextLength!) {
  ///     return text.substring(0, semantics.maxTextLength!);
  ///   }
  ///   return text;
  /// }
  /// ```
  ///
  /// ### Value Range Clamping
  /// ```dart
  /// int normalizeNumeric(int value, TagKey key) {
  ///   final semantics = capability.semantics(key);
  ///   if (semantics.minValue != null && value < semantics.minValue!) {
  ///     return semantics.minValue!.toInt();
  ///   }
  ///   if (semantics.maxValue != null && value > semantics.maxValue!) {
  ///     return semantics.maxValue!.toInt();
  ///   }
  ///   return value;
  /// }
  /// ```
  ///
  /// ## Existing Container Handling
  ///
  /// When [existingContainerBytes] is provided, implementations should:
  /// - Preserve unknown fields that aren't being updated
  /// - Maintain container structure and ordering when possible
  /// - Handle version upgrades/downgrades appropriately
  /// - Preserve extended headers, flags, and other metadata
  ///
  /// ## Error Handling
  ///
  /// Encoding operations should handle errors gracefully:
  /// - **Unsupported tags**: Skip tags not supported by the format
  /// - **Value validation**: Apply normalization rather than failing
  /// - **Encoding errors**: Use fallback encodings when possible
  /// - **Size limits**: Truncate or compress data to fit container limits
  ///
  /// @param tagsToWrite The collection of tags to encode into the container
  /// @param existingContainerBytes Optional existing container to update (preserves unknown fields)
  /// @param preservationManager Optional manager for preserving unknown data during writes
  /// @returns Binary representation of the complete metadata container
  /// @throws [TagValidationException] for tags that cannot be normalized to fit format constraints
  /// @throws [UnsupportedFormatException] if the container format cannot be written
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  });
}
