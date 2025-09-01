/// Phonic - A unified audio metadata tagging library for Dart.
///
/// This library provides a format-agnostic interface for reading and writing
/// audio metadata tags across different container formats (ID3v1, ID3v2.x,
/// Vorbis Comments, MP4 atoms).
///
/// ## Key Features
///
/// - **Type-safe enums**: [TextEncoding] and [MimeType] enums provide better
///   type safety and IDE support compared to string constants
/// - **Format capabilities**: [TagCapability] system defines what each format supports
/// - **Lazy loading**: [ArtworkData] supports efficient memory usage with lazy image loading
/// - **Unified API**: Consistent interface across different container formats
///
/// ## Example Usage
///
/// ```dart
/// import 'package:phonic/phonic.dart';
///
/// // Load audio file and read metadata
/// final audioFile = await Phonic.fromFile('song.mp3');
/// final title = audioFile.getTag(TagKey.title);
/// final artist = audioFile.getTag(TagKey.artist);
/// final genres = audioFile.getTags(TagKey.genre);
///
/// print('Title: ${title?.value}');
/// print('Artist: ${artist?.value}');
/// print('Genres: ${genres.map((g) => g.value).join(', ')}');
///
/// // Modify metadata
/// audioFile.setTag(TitleTag('New Title'));
/// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
///
/// // Save changes
/// if (audioFile.isDirty) {
///   final updatedBytes = await audioFile.encode();
///   await File('updated_song.mp3').writeAsBytes(updatedBytes);
///   audioFile.markClean();
/// }
///
/// // Cleanup
/// audioFile.dispose();
///
/// // Create artwork with type-safe MIME type
/// final artwork = ArtworkData(
///   mimeType: MimeType.jpeg.standardName,
///   type: ArtworkType.frontCover,
///   description: 'Album cover',
///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
/// );
///
/// // Check format capabilities
/// final capability = id3v24Capability;
/// if (capability.semantics(TagKey.title).supportsEncoding(TextEncoding.utf8)) {
///   // UTF-8 is supported for titles in ID3v2.4
/// }
/// ```
library phonic;

export 'src/capabilities/capabilities.dart';
export 'src/core/core.dart';
export 'src/exceptions/corrupted_container_exception.dart';
export 'src/exceptions/phonic_exception.dart';
export 'src/exceptions/tag_validation_exception.dart';
export 'src/exceptions/unsupported_format_exception.dart';
export 'src/formats/formats.dart';
export 'src/tags/tags.dart';
export 'src/utils/utils.dart';
