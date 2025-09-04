part of '../core/metadata_tag.dart';

/// Represents a lyrics metadata tag for audio files.
///
/// LyricsTag contains the complete lyrics or textual content of the song.
/// This tag provides access to the song's lyrics text, which may include
/// timing information in some formats. The lyrics content is valuable for
/// karaoke applications, music analysis, and accessibility features.
///
/// The lyrics value typically contains the complete song text, which may be:
/// - Plain text lyrics without timing information
/// - Structured lyrics with verse/chorus markers
/// - Timed lyrics with synchronization data (format-dependent)
/// - Multi-language lyrics (format-dependent)
///
/// Format mappings:
/// - ID3v2: USLT frame (with language and description)
/// - Vorbis: LYRICS field
/// - MP4: ©lyr atom
/// - ID3v1: Not supported (will be omitted)
///
/// Example usage:
/// ```dart
/// // Create a basic lyrics tag
/// final lyricsTag = LyricsTag('Verse 1:\nHello world\nThis is my song\n\nChorus:\nSing along with me');
///
/// // Create with simple lyrics
/// final simpleLyrics = LyricsTag('La la la, la la la');
///
/// // Create with provenance information
/// final lyricsWithProvenance = LyricsTag(
///   'Complete song lyrics here...',
///   provenance: TagProvenance(
///     ContainerKind.id3v2,
///     '2.4',
///     TagConfidence.certain,
///   ),
/// );
///
/// // Update provenance immutably
/// final updatedTag = lyricsTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The lyrics value should be a string containing the song's textual content.
/// Different container formats may have length limitations or encoding
/// restrictions that are handled automatically during encoding operations.
/// Large lyrics content may be subject to format-specific constraints.
final class LyricsTag extends MetadataTag<String> {
  /// Creates a new LyricsTag with the specified lyrics content.
  ///
  /// @param value The lyrics or textual content of the song, must not be null
  /// @param provenance Optional provenance information about the tag source
  ///
  /// Example:
  /// ```dart
  /// final tag = LyricsTag('Verse 1:\nHello world\nThis is my song');
  /// final simpleTag = LyricsTag('La la la');
  /// ```
  const LyricsTag(
    String value, {
    TagProvenance provenance = const TagProvenance.none(),
  }) : super(
         value: value,
         key: TagKey.lyrics,
         provenance: provenance,
       );

  /// Creates a new LyricsTag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of the lyrics tag while preserving the lyrics content. This is commonly
  /// used during tag processing operations where the same lyrics need
  /// to be associated with different source information.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new LyricsTag instance with the same lyrics but updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = LyricsTag('Song lyrics here...');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  @override
  LyricsTag withProvenance(TagProvenance newProvenance) {
    return LyricsTag(value, provenance: newProvenance);
  }

  /// Converts this LyricsTag to a JSON-serializable Map.
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'provenance': provenance.toJson(),
    };
  }

  /// Creates a LyricsTag from a JSON Map.
  static LyricsTag fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String?;
    final provenanceJson = json['provenance'] as Map<String, dynamic>?;

    if (value == null || provenanceJson == null) {
      throw ArgumentError('Invalid JSON format: missing required fields');
    }

    final provenance = TagProvenance.fromJson(provenanceJson);
    return LyricsTag(value, provenance: provenance);
  }
}
