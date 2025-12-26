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
/// final audioFile = await Phonic.fromFileAsync('song.mp3');
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
library;

export 'src/capabilities/id3v1_capability.dart';
export 'src/capabilities/id3v22_capability.dart';
export 'src/capabilities/id3v23_capability.dart';
export 'src/capabilities/id3v24_capability.dart';
export 'src/capabilities/mp4_capability.dart';
export 'src/capabilities/vorbis_capability.dart';
export 'src/core/artwork_cache.dart';
export 'src/core/artwork_data.dart';
export 'src/core/artwork_type.dart';
export 'src/core/container_kind.dart';
export 'src/core/encoding_options.dart';
export 'src/core/metadata_tag.dart';
export 'src/core/mime_type.dart';
export 'src/core/optimized_artwork_data.dart';
export 'src/core/phonic.dart';
export 'src/core/phonic_audio_file.dart';
export 'src/core/tag_capability.dart';
export 'src/core/tag_confidence.dart';
export 'src/core/tag_key.dart';
export 'src/core/tag_provenance.dart';
export 'src/core/tag_semantics.dart';
export 'src/core/text_encoding.dart';
export 'src/exceptions/corrupted_container_exception.dart';
export 'src/exceptions/phonic_exception.dart';
export 'src/exceptions/tag_validation_exception.dart';
export 'src/exceptions/unsupported_format_exception.dart';
export 'src/performance/memory/memory_efficient_tag_storage.dart';
export 'src/performance/memory/string_interning.dart';
export 'src/performance/monitoring/batch_memory_monitor.dart';
export 'src/performance/monitoring/memory_usage_monitor.dart';
export 'src/streaming/batch_audio_processor.dart';
export 'src/streaming/cancellation_token.dart';
export 'src/streaming/collection_analyzer.dart';
export 'src/streaming/processing_result.dart';
export 'src/streaming/streaming_audio_processor.dart';
export 'src/streaming/streaming_config.dart';
export 'src/streaming/streaming_progress.dart';
export 'src/utils/lazy_artwork_loader.dart';
export 'src/validators/album_validator.dart';
export 'src/validators/artist_validator.dart';
export 'src/validators/bpm_validator.dart';
export 'src/validators/date_recorded_validator.dart';
export 'src/validators/disc_number_validator.dart';
export 'src/validators/rating_validator.dart';
export 'src/validators/tag_validator.dart';
export 'src/validators/tag_validators.dart';
export 'src/validators/text_validator.dart';
export 'src/validators/title_validator.dart';
export 'src/validators/track_number_validator.dart';
export 'src/validators/year_validator.dart';
