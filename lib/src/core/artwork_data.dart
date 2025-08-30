import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'artwork_type.dart';
import 'mime_type.dart';

/// Represents artwork data embedded in audio metadata with lazy loading support.
///
/// ArtworkData encapsulates all information about an artwork image including
/// its MIME type, artwork type classification, optional description, and the
/// actual image data through a lazy loading mechanism. This design enables
/// efficient memory usage when working with large audio collections.
///
/// The class implements [Equatable] for proper comparison, but excludes the
/// data loader from equality checks to ensure that two artwork instances with
/// the same metadata but different loading mechanisms are considered equal.
///
/// ## Memory Efficiency
///
/// The artwork data itself is loaded lazily through a [Future<Uint8List>]
/// loader function. This means:
/// - Metadata can be examined without loading the full image data
/// - Memory usage remains low when scanning large collections
/// - Image data is only loaded when actually needed
/// - Multiple references to the same artwork share the same loader
///
/// ## Container Format Support
///
/// ArtworkData is designed to work across different audio container formats:
/// - **ID3v2**: APIC frames with MIME type, picture type, and description
/// - **MP4**: covr atoms with type detection and optional descriptions
/// - **Vorbis**: METADATA_BLOCK_PICTURE blocks with full metadata
/// - **ID3v1**: Not supported (no artwork capability)
///
/// ## Usage Examples
///
/// ```dart
/// // Creating artwork data with a lazy loader
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'Album front cover',
///   dataLoader: () async {
///     // Load image data from file, network, or container
///     return await loadImageBytes();
///   },
/// );
///
/// // Examining metadata without loading image data
/// print('MIME Type: ${artworkData.mimeType}');
/// print('Type: ${artworkData.type}');
/// print('Description: ${artworkData.description}');
///
/// // Loading the actual image data when needed
/// final imageBytes = await artworkData.data;
/// print('Image size: ${imageBytes.length} bytes');
///
/// // Comparing artwork instances (excludes data loader)
/// final artwork1 = ArtworkData(
///   mimeType: 'image/png',
///   type: ArtworkType.backCover,
///   dataLoader: loader1,
/// );
/// final artwork2 = ArtworkData(
///   mimeType: 'image/png',
///   type: ArtworkType.backCover,
///   dataLoader: loader2,
/// );
/// print(artwork1 == artwork2); // true - same metadata, different loaders
/// ```
///
/// ## MIME Type Guidelines
///
/// Common MIME types for audio artwork:
/// - `image/jpeg` - JPEG images (most common, good compression)
/// - `image/png` - PNG images (lossless, supports transparency)
/// - `image/gif` - GIF images (rare, limited color palette)
/// - `image/bmp` - Bitmap images (rare, large file sizes)
/// - `image/webp` - WebP images (modern, good compression)
///
/// ## Performance Considerations
///
/// - Metadata access is immediate and lightweight
/// - Image data loading is deferred until [data] getter is called
/// - Multiple calls to [data] may trigger multiple loads (no caching)
/// - Consider caching loaded data at the application level if needed
/// - Large artwork collections should use streaming or pagination
///
/// ## Thread Safety
///
/// ArtworkData instances are immutable after construction, making them
/// safe to share across threads. However, the lazy loading mechanism
/// may not be thread-safe depending on the implementation of the
/// data loader function.
class ArtworkData extends Equatable {
  /// The MIME type of the artwork image.
  ///
  /// Specifies the format of the image data, such as 'image/jpeg',
  /// 'image/png', etc. This information is essential for:
  /// - Proper image decoding and display
  /// - Container format compatibility checking
  /// - File extension determination when extracting artwork
  /// - Content type validation
  ///
  /// The MIME type should follow standard internet media type conventions
  /// and be consistent with the actual image format of the data.
  ///
  /// Common values:
  /// - `image/jpeg` - JPEG format (most widely supported)
  /// - `image/png` - PNG format (supports transparency)
  /// - `image/gif` - GIF format (animated images, limited colors)
  /// - `image/bmp` - Windows Bitmap format (uncompressed)
  /// - `image/webp` - WebP format (modern, efficient compression)
  final String mimeType;

  /// The type/category of this artwork image.
  ///
  /// Classifies the artwork according to its purpose and content,
  /// such as front cover, back cover, artist photo, etc. This
  /// classification helps applications:
  /// - Display appropriate artwork in different contexts
  /// - Organize and filter artwork collections
  /// - Apply format-specific handling rules
  /// - Maintain compatibility with container format specifications
  ///
  /// The type corresponds to standard artwork classifications used
  /// across different audio container formats, particularly the
  /// ID3v2 APIC frame picture type field.
  ///
  /// See [ArtworkType] for available classifications and their meanings.
  final ArtworkType type;

  /// Optional human-readable description of the artwork.
  ///
  /// Provides additional context about the artwork content, such as
  /// "Album front cover", "Band photo from 2023 tour", or "Studio
  /// recording session". This description:
  /// - Helps users identify artwork content
  /// - Provides accessibility information
  /// - Supports detailed metadata cataloging
  /// - May be displayed in media player interfaces
  ///
  /// The description is optional and may be null if no description
  /// was provided in the source container or if the container format
  /// doesn't support artwork descriptions.
  ///
  /// Container format support:
  /// - ID3v2: Supported via APIC frame description field
  /// - MP4: Limited support, may be stored in custom atoms
  /// - Vorbis: Supported via METADATA_BLOCK_PICTURE description
  /// - ID3v1: Not applicable (no artwork support)
  final String? description;

  /// Lazy loader function for the actual image data.
  ///
  /// This function is called when the [data] getter is accessed and
  /// should return the raw bytes of the artwork image. The lazy loading
  /// approach provides several benefits:
  /// - Reduced memory usage when scanning large collections
  /// - Faster initial metadata loading
  /// - On-demand data access only when needed
  /// - Flexibility in data source (file, network, container bytes)
  ///
  /// The loader function should:
  /// - Return the complete image data as [Uint8List]
  /// - Handle any necessary decoding or extraction
  /// - Throw appropriate exceptions for loading failures
  /// - Be idempotent (safe to call multiple times)
  ///
  /// Note: The loader is excluded from equality comparisons, so two
  /// ArtworkData instances with the same metadata but different loaders
  /// are considered equal.
  final Future<Uint8List> Function() _dataLoader;

  /// Creates a new ArtworkData instance with the specified metadata and loader.
  ///
  /// All parameters except [description] are required to ensure complete
  /// artwork metadata. The [dataLoader] function will be called lazily
  /// when the actual image data is needed.
  ///
  /// @param mimeType The MIME type of the image (e.g., 'image/jpeg').
  ///                 Consider using [MimeType] enum values for type safety.
  /// @param type The classification of this artwork image
  /// @param description Optional human-readable description
  /// @param dataLoader Function that returns the image data when called
  ///
  /// Example:
  /// ```dart
  /// // Using string MIME type
  /// final artwork1 = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   description: 'Album cover art',
  ///   dataLoader: () async => await File('cover.jpg').readAsBytes(),
  /// );
  ///
  /// // Using MimeType enum for type safety
  /// final artwork2 = ArtworkData(
  ///   mimeType: MimeType.png.standardName,
  ///   type: ArtworkType.frontCover,
  ///   description: 'Album cover art',
  ///   dataLoader: () async => await File('cover.png').readAsBytes(),
  /// );
  /// ```
  const ArtworkData({
    required this.mimeType,
    required this.type,
    this.description,
    required Future<Uint8List> Function() dataLoader,
  }) : _dataLoader = dataLoader;

  /// Gets the actual image data by calling the lazy loader.
  ///
  /// This getter triggers the loading of the artwork image data from
  /// its source (file, container bytes, network, etc.). The data is
  /// returned as a [Future<Uint8List>] containing the raw image bytes.
  ///
  /// ## Performance Notes
  ///
  /// - This may be an expensive operation depending on the data source
  /// - No caching is performed - each call may reload the data
  /// - Consider caching the result at the application level if needed
  /// - Large images may cause memory pressure
  ///
  /// ## Error Handling
  ///
  /// The returned future may complete with an error if:
  /// - The source file or container is corrupted or missing
  /// - Network requests fail (for remote artwork)
  /// - Insufficient memory for large images
  /// - Permission issues accessing the data source
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final imageBytes = await artworkData.data;
  ///   // Process or display the image
  ///   displayImage(imageBytes);
  /// } catch (e) {
  ///   print('Failed to load artwork: $e');
  ///   // Handle loading error appropriately
  /// }
  /// ```
  ///
  /// @returns A future that completes with the raw image data
  /// @throws Various exceptions depending on the loader implementation
  Future<Uint8List> get data => _dataLoader();

  /// Returns the [MimeType] enum value for this artwork's MIME type.
  ///
  /// This is a convenience method that converts the string-based [mimeType]
  /// to the corresponding [MimeType] enum value. Returns null if the MIME
  /// type is not recognized or supported by the enum.
  ///
  /// This method is useful for:
  /// - Type-safe MIME type checking
  /// - Accessing MIME type properties (transparency, compression, etc.)
  /// - Format-specific processing logic
  /// - Validation and compatibility checking
  ///
  /// Example:
  /// ```dart
  /// final artwork = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   dataLoader: () async => imageBytes,
  /// );
  ///
  /// final mimeTypeEnum = artwork.mimeTypeEnum;
  /// if (mimeTypeEnum != null) {
  ///   print('Supports transparency: ${mimeTypeEnum.supportsTransparency}');
  ///   print('Is lossy: ${mimeTypeEnum.isLossy}');
  ///   print('File extension: ${mimeTypeEnum.fileExtension}');
  /// }
  /// ```
  MimeType? get mimeTypeEnum => MimeType.fromName(mimeType);

  /// Returns true if this artwork's MIME type supports transparency.
  ///
  /// This is a convenience method that checks if the artwork format
  /// supports alpha channel transparency. Useful for determining
  /// display behavior and format compatibility.
  ///
  /// Returns false if the MIME type is not recognized.
  bool get supportsTransparency => mimeTypeEnum?.supportsTransparency ?? false;

  /// Returns true if this artwork's MIME type uses lossy compression.
  ///
  /// This is a convenience method that checks if the artwork format
  /// uses lossy compression, which may affect quality but provides
  /// better file size reduction.
  ///
  /// Returns false if the MIME type is not recognized.
  bool get isLossy => mimeTypeEnum?.isLossy ?? false;

  /// Returns true if this artwork's MIME type is vector-based.
  ///
  /// This is a convenience method that checks if the artwork format
  /// is vector-based and can scale without quality loss.
  ///
  /// Returns false if the MIME type is not recognized.
  bool get isVector => mimeTypeEnum?.isVector ?? false;

  /// Returns the typical file extension for this artwork's MIME type.
  ///
  /// This is a convenience method that returns the most common file
  /// extension for the artwork format, without the leading dot.
  ///
  /// Returns null if the MIME type is not recognized.
  ///
  /// Example:
  /// ```dart
  /// final artwork = ArtworkData(mimeType: 'image/jpeg', ...);
  /// print(artwork.fileExtension); // 'jpg'
  /// ```
  String? get fileExtension => mimeTypeEnum?.fileExtension;

  /// Returns a human-readable description of this artwork's format.
  ///
  /// This is a convenience method that returns a user-friendly
  /// description of the artwork format.
  ///
  /// Returns the raw MIME type string if not recognized.
  ///
  /// Example:
  /// ```dart
  /// final artwork = ArtworkData(mimeType: 'image/png', ...);
  /// print(artwork.formatDescription); // 'PNG Image'
  /// ```
  String get formatDescription => mimeTypeEnum?.description ?? mimeType;

  /// Returns a list of properties used for equality comparison.
  ///
  /// The equality comparison includes [mimeType], [type], and [description]
  /// but explicitly excludes the [_dataLoader] function. This design ensures
  /// that two artwork instances with identical metadata are considered equal
  /// regardless of how or where their data is loaded from.
  ///
  /// This is particularly important for:
  /// - Deduplicating artwork across different sources
  /// - Comparing artwork metadata without loading image data
  /// - Maintaining consistent equality semantics in collections
  /// - Supporting artwork replacement and update operations
  ///
  /// Example:
  /// ```dart
  /// final artwork1 = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   description: 'Cover',
  ///   dataLoader: () => loadFromFile('path1.jpg'),
  /// );
  ///
  /// final artwork2 = ArtworkData(
  ///   mimeType: 'image/jpeg',
  ///   type: ArtworkType.frontCover,
  ///   description: 'Cover',
  ///   dataLoader: () => loadFromFile('path2.jpg'),
  /// );
  ///
  /// print(artwork1 == artwork2); // true - same metadata, different loaders
  /// ```
  @override
  List<Object?> get props => [mimeType, type, description];

  /// Returns a string representation of this artwork data.
  ///
  /// The string includes the MIME type, artwork type, and description
  /// (if present) but excludes the data loader for privacy and brevity.
  /// This representation is useful for debugging, logging, and display
  /// purposes.
  ///
  /// Format: `ArtworkData(mimeType: ..., type: ..., description: ...)`
  ///
  /// Example output:
  /// ```
  /// ArtworkData(mimeType: image/jpeg, type: ArtworkType.frontCover, description: Album cover)
  /// ArtworkData(mimeType: image/png, type: ArtworkType.backCover, description: null)
  /// ```
  @override
  String toString() {
    return 'ArtworkData(mimeType: $mimeType, type: $type, description: $description)';
  }
}
