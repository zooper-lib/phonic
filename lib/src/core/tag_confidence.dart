/// Confidence level indicating the reliability of tag data.
///
/// This enum helps distinguish between explicitly stored values and
/// values that have been inferred or derived from other sources.
/// Understanding confidence levels is crucial for making informed
/// decisions about data quality and merge operations.
///
/// The confidence level affects how tags are prioritized during
/// merge operations and helps users understand the provenance
/// and reliability of metadata values.
enum TagConfidence {
  /// The tag was explicitly found and parsed from a container.
  ///
  /// This represents the highest confidence level, indicating that
  /// the tag value was directly read from the audio file's metadata
  /// container without any transformation or inference. These values
  /// should be considered authoritative and take precedence during
  /// merge operations.
  ///
  /// Examples:
  /// - A title tag read directly from an ID3v2 TIT2 frame
  /// - An artist name parsed from a Vorbis ARTIST comment
  /// - Album artwork extracted from an MP4 covr atom
  certain,

  /// The tag value was inferred from other available information.
  ///
  /// This confidence level indicates that the tag value was not
  /// explicitly present in the metadata but was logically derived
  /// from other available fields using reasonable assumptions.
  /// These values are likely correct but should be treated with
  /// lower priority than certain values.
  ///
  /// Examples:
  /// - AlbumArtist inferred from Artist when AlbumArtist is missing
  /// - Genre inferred from similar tracks in the same album
  /// - Track number inferred from filename patterns
  ///
  /// Inferred values are useful for filling gaps in metadata but
  /// should be clearly marked to allow users to distinguish them
  /// from explicitly stored values.
  inferred,

  /// The tag value was calculated or transformed from other data.
  ///
  /// This confidence level indicates that the tag value was computed
  /// or extracted through transformation of existing data. While these
  /// values are mechanically derived and should be accurate, they
  /// represent a processing step rather than direct storage.
  ///
  /// Examples:
  /// - Year extracted from a full ISO-8601 dateRecorded field
  /// - Rating converted from a 0-255 scale to 0-100 scale
  /// - BPM calculated from audio analysis of tempo
  /// - Text encoding converted from Latin-1 to UTF-8
  ///
  /// Derived values maintain accuracy but indicate that some
  /// transformation or calculation was applied to produce the
  /// final result.
  derived,
}
