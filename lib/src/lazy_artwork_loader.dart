import 'dart:typed_data';

/// A lazy loader for artwork data that extracts image bytes from container data on demand.
///
/// LazyArtworkLoader provides memory-efficient artwork loading by deferring the
/// extraction of image data until it's actually needed. This is particularly
/// important when working with large audio collections where loading all artwork
/// data upfront would consume excessive memory.
///
/// The loader works with a slice of container bytes defined by an offset and length,
/// allowing it to extract artwork data from various audio container formats without
/// loading the entire file into memory.
///
/// ## Memory Efficiency
///
/// The lazy loading approach provides several benefits:
/// - Reduced memory usage when scanning large collections
/// - Faster initial metadata loading (artwork metadata without image data)
/// - On-demand data access only when artwork is actually displayed or processed
/// - Ability to work with large container files without loading everything
///
/// ## Container Format Support
///
/// LazyArtworkLoader is designed to work with artwork embedded in various
/// audio container formats:
/// - **ID3v2**: APIC frame image data within ID3v2 tags
/// - **MP4**: covr atom image data within MP4 ilst atoms
/// - **Vorbis**: METADATA_BLOCK_PICTURE image data within Vorbis comments
/// - **FLAC**: METADATA_BLOCK_PICTURE blocks within FLAC metadata
///
/// ## Usage Examples
///
/// ```dart
/// // Create a lazy loader for artwork at specific offset in container
/// final loader = LazyArtworkLoader(
///   containerBytes: id3v2TagBytes,
///   offset: 45,        // Start of APIC frame image data
///   length: 12580,     // Length of image data
/// );
///
/// // Load the artwork data when needed
/// final imageBytes = await loader.load();
/// print('Loaded ${imageBytes.length} bytes of image data');
///
/// // Use with ArtworkData for complete lazy loading
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'Album cover',
///   dataLoader: () => loader.load(),
/// );
/// ```
///
/// ## Performance Considerations
///
/// - The container bytes are held in memory, so this is most efficient when
///   the container data is already loaded (e.g., ID3v2 tags, MP4 atoms)
/// - Each call to [load] creates a new sublist, so consider caching results
///   if the same artwork will be accessed multiple times
/// - The offset and length are validated on construction to prevent runtime errors
/// - Large artwork images may still cause memory pressure when loaded
///
/// ## Error Handling
///
/// The loader validates parameters during construction and will throw:
/// - [ArgumentError] if offset is negative
/// - [ArgumentError] if length is negative or zero
/// - [RangeError] if offset + length exceeds container bytes length
///
/// ## Thread Safety
///
/// LazyArtworkLoader instances are immutable after construction and safe to
/// share across threads. The [load] method is also thread-safe as it only
/// performs read operations on the container bytes.
class LazyArtworkLoader {
  /// The container bytes containing the artwork data.
  ///
  /// This should be the raw bytes of the audio container (or container section)
  /// that contains the embedded artwork. For example:
  /// - ID3v2 tag bytes for APIC frames
  /// - MP4 ilst atom bytes for covr atoms
  /// - FLAC metadata block bytes for METADATA_BLOCK_PICTURE
  /// - Vorbis comment block bytes with embedded pictures
  ///
  /// The container bytes are stored as a reference, not copied, so modifications
  /// to the original bytes will affect the loader's behavior.
  final Uint8List _containerBytes;

  /// The byte offset within the container where the artwork data begins.
  ///
  /// This offset points to the start of the actual image data within the
  /// container bytes, skipping any container-specific headers, metadata,
  /// or frame information. The offset must be:
  /// - Non-negative
  /// - Less than the container bytes length
  /// - Such that offset + length does not exceed container bounds
  ///
  /// Examples:
  /// - In ID3v2 APIC frames: offset to image data after MIME type and description
  /// - In MP4 covr atoms: offset to image data after atom headers
  /// - In FLAC pictures: offset to image data after picture metadata
  final int _offset;

  /// The length in bytes of the artwork data.
  ///
  /// Specifies exactly how many bytes to extract starting from the offset.
  /// This length should correspond to the complete image file data and must be:
  /// - Positive (greater than zero)
  /// - Such that offset + length does not exceed container bytes length
  ///
  /// The length is typically determined by parsing the container format's
  /// metadata structures (frame headers, atom sizes, block lengths, etc.).
  final int _length;

  /// Creates a new LazyArtworkLoader with the specified container data and bounds.
  ///
  /// The loader will extract artwork data from the container bytes starting at
  /// the given offset and continuing for the specified length when [load] is called.
  ///
  /// @param containerBytes The raw container bytes containing artwork data
  /// @param offset The byte offset where artwork data begins (must be >= 0)
  /// @param length The number of bytes of artwork data (must be > 0)
  ///
  /// @throws ArgumentError if offset is negative
  /// @throws ArgumentError if length is negative or zero
  /// @throws RangeError if offset + length exceeds containerBytes length
  ///
  /// Example:
  /// ```dart
  /// final loader = LazyArtworkLoader(
  ///   containerBytes: id3TagBytes,
  ///   offset: 128,     // Start of image data in APIC frame
  ///   length: 45672,   // Size of JPEG image
  /// );
  /// ```
  LazyArtworkLoader(
    Uint8List containerBytes,
    int offset,
    int length,
  ) : _containerBytes = containerBytes,
      _offset = offset,
      _length = length {
    // Validate parameters to ensure safe extraction
    if (offset < 0) {
      throw ArgumentError.value(
        offset,
        'offset',
        'Offset must be non-negative',
      );
    }

    if (length <= 0) {
      throw ArgumentError.value(
        length,
        'length',
        'Length must be positive',
      );
    }

    if (offset + length > containerBytes.length) {
      throw RangeError.range(
        offset + length,
        0,
        containerBytes.length,
        'offset + length',
        'Artwork data bounds exceed container size '
            '(offset: $offset, length: $length, container: ${containerBytes.length})',
      );
    }
  }

  /// Extracts and returns the artwork data from the container bytes.
  ///
  /// This method performs the actual extraction of image data by creating
  /// a sublist of the container bytes starting at the configured offset
  /// and continuing for the configured length.
  ///
  /// ## Performance Notes
  ///
  /// - Creates a new [Uint8List] containing only the artwork data
  /// - The extraction is a memory copy operation, not a view
  /// - Multiple calls will create multiple copies of the same data
  /// - Consider caching the result if accessed frequently
  ///
  /// ## Memory Usage
  ///
  /// The returned [Uint8List] contains only the artwork image data,
  /// not the entire container. This helps minimize memory usage compared
  /// to keeping references to large container files.
  ///
  /// ## Error Handling
  ///
  /// This method should not throw exceptions under normal circumstances
  /// since bounds checking is performed during construction. However,
  /// if the container bytes are modified after construction, unexpected
  /// behavior may occur.
  ///
  /// Example:
  /// ```dart
  /// final loader = LazyArtworkLoader(containerBytes, 100, 5000);
  ///
  /// // Load artwork when needed (e.g., for display)
  /// final imageData = await loader.load();
  ///
  /// // Use the image data
  /// final image = decodeImage(imageData);
  /// displayImage(image);
  /// ```
  ///
  /// @returns A future that completes with the extracted artwork bytes
  Future<Uint8List> load() async {
    // Extract the artwork data as a sublist
    // Using sublist creates a new list containing only the artwork bytes
    return _containerBytes.sublist(_offset, _offset + _length);
  }

  /// Gets the byte offset where artwork data begins in the container.
  ///
  /// This getter provides read-only access to the offset for debugging,
  /// logging, or informational purposes. The offset cannot be modified
  /// after construction to ensure loader consistency.
  ///
  /// Example:
  /// ```dart
  /// print('Artwork starts at byte ${loader.offset}');
  /// ```
  int get offset => _offset;

  /// Gets the length in bytes of the artwork data.
  ///
  /// This getter provides read-only access to the length for debugging,
  /// logging, or informational purposes. The length cannot be modified
  /// after construction to ensure loader consistency.
  ///
  /// Example:
  /// ```dart
  /// print('Artwork is ${loader.length} bytes long');
  /// ```
  int get length => _length;

  /// Returns a string representation of this lazy artwork loader.
  ///
  /// The string includes the offset, length, and container size for
  /// debugging and logging purposes. The actual container bytes are
  /// not included to avoid large output and potential security issues.
  ///
  /// Format: `LazyArtworkLoader(offset: ..., length: ..., containerSize: ...)`
  ///
  /// Example output:
  /// ```
  /// LazyArtworkLoader(offset: 128, length: 45672, containerSize: 2048576)
  /// ```
  @override
  String toString() {
    return 'LazyArtworkLoader(offset: $_offset, length: $_length, containerSize: ${_containerBytes.length})';
  }
}
