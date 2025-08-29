part of '../metadata_tag.dart';

/// Represents an encoder metadata tag for audio files.
///
/// EncoderTag contains information about the software or hardware used
/// to encode the audio file, including the encoder name, version, and
/// sometimes encoding settings. This information is useful for debugging
/// audio quality issues and understanding the encoding history of a file.
///
/// Format mappings:
/// - ID3v2: TSSE frame
/// - Vorbis: ENCODER field
/// - MP4: ©too atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic encoder tag
/// final encoderTag = EncoderTag('LAME 3.100');
///
/// // Create with provenance information
/// final encoderWithProvenance = EncoderTag(
///   'Fraunhofer FDK AAC',
///   provenance: TagProvenance(
///     ContainerKind.mp4,
///     '',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = encoderTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The encoder value should be a non-empty string containing the encoder
/// information. Different container formats may have length limitations
/// that are handled automatically during encoding operations.
final class EncoderTag extends MetadataTag<String> {
  /// Creates a new EncoderTag with the specified encoder value.
  ///
  /// @param value The name and version of the encoder software/hardware, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = EncoderTag('LAME 3.100');
  /// ```
  const EncoderTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.encoder,
         provenance: provenance,
       );

  /// Creates a new EncoderTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the encoder tag while preserving the encoder value. This is commonly
  /// used during tag processing operations where the same encoder needs
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new EncoderTag instance with the same encoder but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = EncoderTag('LAME 3.100');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  EncoderTag withProvenance(TagProvenance newProvenance) {
    return EncoderTag(value, provenance: newProvenance);
  }
}
