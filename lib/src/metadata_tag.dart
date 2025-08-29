import 'package:equatable/equatable.dart';

import 'tag_key.dart';
import 'tag_provenance.dart';

// Test helpers are included as a part file to allow extending the sealed class
// This is necessary for comprehensive testing of the base class functionality
part 'metadata_tag_test_helpers.dart';

// Concrete tag implementations
part 'tags/title_tag.dart';
part 'tags/artist_tag.dart';
part 'tags/album_tag.dart';
part 'tags/album_artist_tag.dart';
part 'tags/genre_tag.dart';
part 'tags/comment_tag.dart';
part 'tags/grouping_tag.dart';
part 'tags/composer_tag.dart';
part 'tags/encoder_tag.dart';
part 'tags/isrc_tag.dart';
part 'tags/lyrics_tag.dart';
part 'tags/musical_key_tag.dart';
part 'tags/track_number_tag.dart';
part 'tags/disc_number_tag.dart';
part 'tags/year_tag.dart';
part 'tags/date_recorded_tag.dart';
part 'tags/bpm_tag.dart';
part 'tags/rating_tag.dart';

/// Base sealed class for all metadata tags in the unified tagging system.
///
/// MetadataTag provides a type-safe, immutable representation of metadata
/// values with full provenance tracking. The sealed class design ensures
/// that all tag types are known at compile time and enables exhaustive
/// pattern matching.
///
/// Each tag contains three essential pieces of information:
/// - [value]: The actual metadata content (typed according to the tag type)
/// - [key]: The semantic field type this tag represents
/// - [provenance]: Information about where this tag value originated from
///
/// The generic type parameter [T] ensures type safety for tag values:
/// - String for text fields (title, artist, album, etc.)
/// - int for numeric fields (trackNumber, year, rating, etc.)
/// - List<String> for multi-valued text fields (genre)
/// - ArtworkData for artwork fields
/// - Other specialized types as needed
///
/// Example usage:
/// ```dart
/// // Creating a title tag
/// final titleTag = TitleTag('My Song');
///
/// // Creating a tag with provenance
/// final artistTag = ArtistTag(
///   'Artist Name',
///   provenance: TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
/// );
///
/// // Creating multi-genre tags with automatic delimiter detection
/// final genreTag = GenreTag.fromString('Rock;Alternative;Indie');
/// final genreFromSlash = GenreTag.fromString('Rock/Alternative/Indie');
/// final genreFromComma = GenreTag.fromString('Rock, Alternative, Indie');
/// // All result in: ['Rock', 'Alternative', 'Indie']
///
/// // Creating single genre tags
/// final singleGenre = GenreTag.single('Jazz');
/// final multiGenre = GenreTag(['Electronic', 'Ambient', 'Downtempo']);
///
/// // Format-specific genre parsing for container compatibility
/// final id3v24Genre = GenreTag.fromId3v24String('Rock\0Alternative\0Indie');
/// final id3v23Genre = GenreTag.fromId3v23String('Rock/Alternative/Indie');
///
/// // Updating provenance immutably
/// final updatedTag = titleTag.withProvenance(
///   TagProvenance(ContainerKind.vorbis, '', TagConfidence.certain),
/// );
/// ```
///
/// The sealed design ensures that:
/// - All possible tag types are known at compile time
/// - Pattern matching can be exhaustive
/// - New tag types require explicit handling in switch statements
/// - Type safety is maintained throughout the system
///
/// Memory efficiency considerations:
/// - Tags are immutable and can be safely shared
/// - Large payloads (like artwork) use lazy loading patterns
/// - Provenance information is lightweight and cached
/// - String interning may be used for common values
sealed class MetadataTag<T> extends Equatable {
  /// The actual metadata value stored in this tag.
  ///
  /// The type of this value is determined by the generic parameter [T]
  /// and corresponds to the semantic meaning of the tag key:
  /// - Text fields use String values (title, artist, album, etc.)
  /// - Numeric fields use int values (trackNumber, year, rating, etc.)
  /// - Multi-valued text fields use List<String> values (genre)
  /// - Artwork fields use ArtworkData values
  /// - Custom fields may use specialized types
  ///
  /// For List<String> values like GenreTag, the list is made immutable
  /// to ensure thread safety and prevent accidental modifications.
  ///
  /// Values are immutable once created. To change a value, create a new
  /// tag instance or use transformation methods like [withProvenance].
  final T value;

  /// The semantic field type that this tag represents.
  ///
  /// This key identifies what kind of metadata this tag contains,
  /// such as title, artist, album, etc. The key determines:
  /// - How the tag is mapped to container-specific formats
  /// - What validation rules apply to the value
  /// - How the tag participates in merge operations
  /// - What capabilities are required from target containers
  ///
  /// The key is immutable and must match the tag's concrete type.
  /// For example, a TitleTag must always have TagKey.title.
  final TagKey key;

  /// Provenance information tracking the origin and reliability of this tag.
  ///
  /// Provenance provides essential context about where this tag value
  /// came from and how reliable it is. This information is used for:
  /// - Determining precedence during merge operations
  /// - Providing transparency about data sources
  /// - Enabling auditing of metadata transformations
  /// - Supporting debugging of parsing issues
  ///
  /// If no specific provenance is provided, [TagProvenance.none] is used
  /// as a sensible default for user-created or synthetic tags.
  final TagProvenance provenance;

  /// Creates a new MetadataTag with the specified value, key, and provenance.
  ///
  /// This constructor is used by concrete tag implementations to create
  /// properly typed and validated tag instances. All parameters are required
  /// to ensure complete tag information.
  ///
  /// @param value The metadata value to store in this tag
  /// @param key The semantic field type this tag represents
  /// @param provenance The origin and reliability information for this tag
  const MetadataTag({
    required this.value,
    required this.key,
    this.provenance = const TagProvenance.none(),
  });

  /// Creates a new tag instance with updated provenance information.
  ///
  /// This method provides an immutable way to update the provenance
  /// of a tag while preserving the value and key. This is commonly
  /// used during tag processing operations where the same logical
  /// value needs to be associated with different source information.
  ///
  /// The returned tag will have the same value and key as the original,
  /// but with the new provenance information. The original tag is
  /// not modified.
  ///
  /// @param newProvenance The new provenance information to associate with this tag
  /// @returns A new tag instance with updated provenance
  ///
  /// Example:
  /// ```dart
  /// final originalTag = TitleTag('Song Title');
  /// final tagWithProvenance = originalTag.withProvenance(
  ///   TagProvenance(ContainerKind.id3v2, '2.4', TagConfidence.certain),
  /// );
  /// ```
  ///
  /// This method must be implemented by all concrete tag classes to
  /// return the appropriate concrete type rather than the base type.
  MetadataTag<T> withProvenance(TagProvenance newProvenance);

  @override
  List<Object?> get props => [value, key, provenance];

  @override
  String toString() {
    final valueStr = value.toString();
    final provenanceStr = provenance.toString();
    return '${runtimeType}($valueStr, provenance: $provenanceStr)';
  }
}
