import 'container_kind.dart';

/// Options for controlling metadata encoding behavior and validation.
///
/// Provides fine-grained control over how metadata is written to audio files,
/// including target container selection, validation levels, and format optimization.
class EncodingOptions {
  /// Strategy for determining which containers to write metadata to.
  final EncodingStrategy strategy;

  /// Level of validation to apply during and after encoding.
  final ValidationLevel validationLevel;

  /// Specific target containers (overrides strategy when provided).
  ///
  /// When specified, only these containers will be written to, regardless
  /// of the encoding strategy. Format: [(ContainerKind, version), ...]
  final List<(ContainerKind, String)>? targetContainers;

  /// Whether to preserve unknown metadata from existing containers.
  ///
  /// When true (default), unknown tags and data in existing containers
  /// are preserved during encoding. When false, only known tags are written.
  final bool preserveUnknownMetadata;

  const EncodingOptions({
    this.strategy = EncodingStrategy.preserveExisting,
    this.validationLevel = ValidationLevel.basic,
    this.targetContainers,
    this.preserveUnknownMetadata = true,
  });

  /// Creates encoding options that preserve existing container formats.
  ///
  /// This is the safest approach - writes only to containers that already
  /// exist in the file, maintaining the original format mix.
  const EncodingOptions.preserveExisting({
    ValidationLevel validationLevel = ValidationLevel.basic,
    bool preserveUnknownMetadata = true,
  }) : this(
         strategy: EncodingStrategy.preserveExisting,
         validationLevel: validationLevel,
         preserveUnknownMetadata: preserveUnknownMetadata,
       );

  /// Creates encoding options that optimize container formats.
  ///
  /// Updates to the latest container versions and removes legacy formats:
  /// - MP3: Updates to ID3v2.4 only, removes ID3v1
  /// - FLAC: Uses latest Vorbis Comments format
  /// - MP4: Uses latest iTunes-style atoms
  const EncodingOptions.optimized({
    ValidationLevel validationLevel = ValidationLevel.standard,
    bool preserveUnknownMetadata = true,
  }) : this(
         strategy: EncodingStrategy.optimized,
         validationLevel: validationLevel,
         preserveUnknownMetadata: preserveUnknownMetadata,
       );

  /// Creates encoding options with explicit target containers.
  ///
  /// Writes to exactly the specified containers, ignoring existing formats.
  /// Use with caution as this can result in metadata loss if not all
  /// existing containers are specified.
  const EncodingOptions.explicit({
    required List<(ContainerKind, String)> targetContainers,
    ValidationLevel validationLevel = ValidationLevel.standard,
    bool preserveUnknownMetadata = true,
  }) : this(
         strategy: EncodingStrategy.explicit,
         targetContainers: targetContainers,
         validationLevel: validationLevel,
         preserveUnknownMetadata: preserveUnknownMetadata,
       );
}

/// Strategy for determining which metadata containers to write to.
enum EncodingStrategy {
  /// Write only to containers that already exist in the file.
  ///
  /// This is the safest approach as it preserves the existing format mix
  /// and doesn't introduce new container types. If a file has ID3v2.3 + ID3v1,
  /// it will continue to have ID3v2.3 + ID3v1 after encoding.
  preserveExisting,

  /// Optimize container formats by updating to latest versions.
  ///
  /// Updates containers to their latest, most capable versions while
  /// removing legacy formats that provide limited value:
  /// - MP3: ID3v2.4 only (removes ID3v1, updates older ID3v2 versions)
  /// - FLAC: Latest Vorbis Comments format
  /// - OGG: Latest Vorbis Comments format
  /// - MP4: Latest iTunes-style metadata atoms
  optimized,

  /// Write to explicitly specified target containers.
  ///
  /// Ignores existing containers and writes only to the containers
  /// specified in targetContainers. Provides complete control but
  /// requires careful consideration of metadata compatibility.
  explicit,
}

/// Level of validation to apply during encoding operations.
enum ValidationLevel {
  /// Minimal validation - only check critical structural issues.
  ///
  /// Performs only essential validation to prevent file corruption:
  /// - Container structural integrity
  /// - Required fields presence
  /// - Basic format compliance
  basic,

  /// Standard validation - includes tag consistency and format compliance.
  ///
  /// Adds validation for metadata quality and consistency:
  /// - Tag value constraints (ranges, lengths)
  /// - Cross-container consistency checks
  /// - Format-specific compliance rules
  standard,

  /// Strict validation - comprehensive validation including round-trip testing.
  ///
  /// Performs exhaustive validation to ensure highest quality:
  /// - Full round-trip validation (write + read + compare)
  /// - Advanced consistency checks across all containers
  /// - Performance and quality metrics validation
  /// - Future compatibility validation
  strict,
}
