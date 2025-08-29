/// MIME type enumeration for artwork and media content.
///
/// This enum defines the standard MIME types supported for artwork images
/// in audio metadata containers. Using an enum provides better type safety,
/// IDE support, and validation compared to string constants.
///
/// The enum focuses on image MIME types commonly used in audio metadata,
/// particularly for artwork embedded in ID3v2, MP4, Vorbis, and other
/// container formats.
///
/// Usage:
/// ```dart
/// // Check MIME type support
/// if (container.supportsMimeType(MimeType.jpeg)) {
///   // JPEG is supported
/// }
///
/// // Get MIME type string
/// final mimeString = MimeType.png.standardName;
///
/// // Create artwork with type-safe MIME type
/// final artwork = ArtworkData(
///   mimeType: MimeType.jpeg.standardName,
///   type: ArtworkType.frontCover,
///   dataLoader: () async => imageBytes,
/// );
/// ```
enum MimeType {
  /// JPEG image format (image/jpeg).
  ///
  /// JPEG (Joint Photographic Experts Group) is the most commonly used
  /// image format for audio artwork due to its excellent compression ratio
  /// and widespread support across all audio container formats.
  ///
  /// Characteristics:
  /// - Lossy compression with adjustable quality
  /// - Excellent for photographic content
  /// - Small file sizes with good visual quality
  /// - No transparency support
  /// - Universal support across all audio formats
  ///
  /// Used by:
  /// - ID3v2: Primary format for APIC frames
  /// - MP4: Standard format for covr atoms
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Most audio players and software
  ///
  /// File extensions: .jpg, .jpeg
  jpeg('image/jpeg'),

  /// PNG image format (image/png).
  ///
  /// PNG (Portable Network Graphics) is a lossless image format that
  /// supports transparency and is well-suited for artwork with sharp
  /// edges, text, or areas of solid color.
  ///
  /// Characteristics:
  /// - Lossless compression
  /// - Supports transparency (alpha channel)
  /// - Larger file sizes than JPEG for photos
  /// - Excellent for graphics, logos, and text
  /// - Wide support across audio formats
  ///
  /// Used by:
  /// - ID3v2: Supported in APIC frames
  /// - MP4: Supported in covr atoms
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Modern audio players and software
  ///
  /// File extensions: .png
  png('image/png'),

  /// GIF image format (image/gif).
  ///
  /// GIF (Graphics Interchange Format) is a legacy format with limited
  /// color palette support. Rarely used for audio artwork due to quality
  /// limitations, but supported for compatibility.
  ///
  /// Characteristics:
  /// - Lossless compression with 256-color limit
  /// - Supports simple transparency
  /// - Supports animation (though not typically used in audio)
  /// - Small file sizes for simple graphics
  /// - Limited color reproduction
  ///
  /// Used by:
  /// - ID3v2: Supported in APIC frames (legacy)
  /// - MP4: Limited support
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Older audio software
  ///
  /// File extensions: .gif
  gif('image/gif'),

  /// BMP image format (image/bmp).
  ///
  /// BMP (Bitmap) is an uncompressed raster format primarily used on
  /// Windows systems. Rarely used for audio artwork due to large file
  /// sizes, but included for compatibility with legacy systems.
  ///
  /// Characteristics:
  /// - Uncompressed or simple RLE compression
  /// - Large file sizes
  /// - Lossless quality
  /// - Limited transparency support
  /// - Platform-specific (Windows-centric)
  ///
  /// Used by:
  /// - ID3v2: Supported in APIC frames (rare)
  /// - MP4: Limited support
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Windows-based audio software
  ///
  /// File extensions: .bmp
  bmp('image/bmp'),

  /// WebP image format (image/webp).
  ///
  /// WebP is a modern image format developed by Google that provides
  /// superior compression compared to JPEG and PNG while supporting
  /// both lossy and lossless compression modes.
  ///
  /// Characteristics:
  /// - Superior compression efficiency
  /// - Supports both lossy and lossless modes
  /// - Supports transparency
  /// - Supports animation
  /// - Growing support in audio software
  ///
  /// Used by:
  /// - ID3v2: Limited support (newer implementations)
  /// - MP4: Limited support
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Modern audio players and web-based software
  ///
  /// File extensions: .webp
  webp('image/webp'),

  /// TIFF image format (image/tiff).
  ///
  /// TIFF (Tagged Image File Format) is a flexible format that supports
  /// various compression methods and color depths. Rarely used for audio
  /// artwork due to complexity and large file sizes.
  ///
  /// Characteristics:
  /// - Multiple compression options
  /// - High quality and color depth support
  /// - Large file sizes
  /// - Complex format specification
  /// - Limited support in audio software
  ///
  /// Used by:
  /// - ID3v2: Rarely supported
  /// - MP4: Very limited support
  /// - Vorbis: Supported in METADATA_BLOCK_PICTURE
  /// - Professional audio software
  ///
  /// File extensions: .tiff, .tif
  tiff('image/tiff'),

  /// SVG image format (image/svg+xml).
  ///
  /// SVG (Scalable Vector Graphics) is a vector-based format that can
  /// scale to any size without quality loss. Rarely used for audio
  /// artwork but supported by some modern systems.
  ///
  /// Characteristics:
  /// - Vector-based (scalable)
  /// - XML-based format
  /// - Small file sizes for simple graphics
  /// - Supports interactivity and animation
  /// - Limited support in audio software
  ///
  /// Used by:
  /// - ID3v2: Very limited support
  /// - MP4: Not typically supported
  /// - Vorbis: Limited support
  /// - Web-based and modern audio players
  ///
  /// File extensions: .svg
  svg('image/svg+xml');

  /// Creates a MimeType with the specified standard name.
  const MimeType(this.standardName);

  /// The standard MIME type string (e.g., 'image/jpeg', 'image/png').
  ///
  /// This name follows the standard internet media type conventions
  /// and is suitable for use with HTTP headers, container format
  /// specifications, and image processing libraries.
  final String standardName;

  /// Returns the standard MIME type string.
  ///
  /// This is equivalent to accessing [standardName] directly but provides
  /// a more explicit method name for clarity.
  String get name => standardName;

  /// Returns a set of all MIME type names as strings.
  ///
  /// This is useful for validation or when working with APIs that expect
  /// string-based MIME type names.
  static Set<String> get allNames => values.map((e) => e.standardName).toSet();

  /// Returns a set of MIME type names for the given MimeType values.
  ///
  /// This is a convenience method for creating MIME type sets from MimeType
  /// enum values instead of hardcoding string literals.
  ///
  /// Example:
  /// ```dart
  /// final supportedTypes = MimeType.namesFor({
  ///   MimeType.jpeg,
  ///   MimeType.png,
  ///   MimeType.webp,
  /// });
  /// // Returns: {'image/jpeg', 'image/png', 'image/webp'}
  /// ```
  static Set<String> namesFor(Set<MimeType> mimeTypes) {
    return mimeTypes.map((e) => e.standardName).toSet();
  }

  /// Finds a MimeType by its standard name.
  ///
  /// Returns the matching MimeType enum value, or null if no match is found.
  /// The comparison is case-sensitive and must match exactly.
  ///
  /// Example:
  /// ```dart
  /// final mimeType = MimeType.fromName('image/jpeg'); // Returns MimeType.jpeg
  /// final invalid = MimeType.fromName('image/jpg');   // Returns null (not standard)
  /// final caseIssue = MimeType.fromName('IMAGE/JPEG'); // Returns null (case sensitive)
  /// ```
  static MimeType? fromName(String name) {
    for (final mimeType in values) {
      if (mimeType.standardName == name) {
        return mimeType;
      }
    }
    return null;
  }

  /// Returns true if this MIME type supports transparency.
  ///
  /// Transparency support is important for artwork that needs to blend
  /// with different background colors or for overlay effects.
  bool get supportsTransparency {
    switch (this) {
      case MimeType.png:
      case MimeType.gif:
      case MimeType.webp:
      case MimeType.svg:
        return true;
      case MimeType.jpeg:
      case MimeType.bmp:
      case MimeType.tiff:
        return false;
    }
  }

  /// Returns true if this MIME type uses lossy compression.
  ///
  /// Lossy compression reduces file size by discarding some image
  /// information, which may affect quality but provides better compression.
  bool get isLossy {
    switch (this) {
      case MimeType.jpeg:
        return true;
      case MimeType.png:
      case MimeType.gif:
      case MimeType.bmp:
      case MimeType.tiff:
      case MimeType.svg:
        return false;
      case MimeType.webp:
        return false; // Can be both, but defaults to lossless
    }
  }

  /// Returns true if this MIME type is vector-based.
  ///
  /// Vector formats can scale to any size without quality loss,
  /// unlike raster formats which have fixed pixel dimensions.
  bool get isVector {
    switch (this) {
      case MimeType.svg:
        return true;
      case MimeType.jpeg:
      case MimeType.png:
      case MimeType.gif:
      case MimeType.bmp:
      case MimeType.webp:
      case MimeType.tiff:
        return false;
    }
  }

  /// Returns true if this MIME type supports animation.
  ///
  /// Animated formats can contain multiple frames or sequences,
  /// though animation is rarely used in audio artwork.
  bool get supportsAnimation {
    switch (this) {
      case MimeType.gif:
      case MimeType.webp:
      case MimeType.svg:
        return true;
      case MimeType.jpeg:
      case MimeType.png:
      case MimeType.bmp:
      case MimeType.tiff:
        return false;
    }
  }

  /// Returns the typical file extension for this MIME type.
  ///
  /// Returns the most common file extension associated with this
  /// MIME type, without the leading dot.
  String get fileExtension {
    switch (this) {
      case MimeType.jpeg:
        return 'jpg';
      case MimeType.png:
        return 'png';
      case MimeType.gif:
        return 'gif';
      case MimeType.bmp:
        return 'bmp';
      case MimeType.webp:
        return 'webp';
      case MimeType.tiff:
        return 'tiff';
      case MimeType.svg:
        return 'svg';
    }
  }

  /// Returns all possible file extensions for this MIME type.
  ///
  /// Some MIME types have multiple valid file extensions.
  /// Returns a set of extensions without the leading dot.
  Set<String> get fileExtensions {
    switch (this) {
      case MimeType.jpeg:
        return {'jpg', 'jpeg'};
      case MimeType.tiff:
        return {'tiff', 'tif'};
      case MimeType.png:
      case MimeType.gif:
      case MimeType.bmp:
      case MimeType.webp:
      case MimeType.svg:
        return {fileExtension};
    }
  }

  /// Returns a human-readable description of this MIME type.
  ///
  /// Provides a user-friendly description that can be displayed
  /// in user interfaces or documentation.
  String get description {
    switch (this) {
      case MimeType.jpeg:
        return 'JPEG Image';
      case MimeType.png:
        return 'PNG Image';
      case MimeType.gif:
        return 'GIF Image';
      case MimeType.bmp:
        return 'Bitmap Image';
      case MimeType.webp:
        return 'WebP Image';
      case MimeType.tiff:
        return 'TIFF Image';
      case MimeType.svg:
        return 'SVG Vector Image';
    }
  }

  @override
  String toString() => standardName;
}
