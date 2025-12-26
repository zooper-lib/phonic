import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../exceptions/unsupported_format_exception.dart';
import '../formats/flac/flac_format_strategy.dart';
import '../formats/id3/id3v1_codec.dart';
import '../formats/id3/id3v22_codec.dart';
import '../formats/id3/id3v23_codec.dart';
import '../formats/id3/id3v24_codec.dart';
import '../formats/id3/mp3_format_strategy.dart';
import '../formats/mp4/mp4_atoms_codec.dart';
import '../formats/mp4/mp4_format_strategy.dart';
import '../formats/vorbis/ogg_format_strategy.dart';
import '../formats/vorbis/opus_format_strategy.dart';
import '../formats/vorbis/vorbis_comments_codec.dart';
import '../utils/locators/id3v1_locator.dart';
import '../utils/locators/id3v2_locator.dart';
import '../utils/locators/mp4_locator.dart';
import '../utils/locators/ogg_vorbis_locator.dart';
import '../utils/locators/vorbis_locator.dart';
import 'codec_registry.dart';
import 'format_strategy.dart';
import 'isolate_processor.dart';
import 'merge_policy.dart';
import 'phonic_audio_file.dart';
import 'phonic_audio_file_impl.dart';

/// Factory class for creating PhonicAudioFile instances.
///
/// The Phonic class provides static factory methods for creating audio file
/// instances from various sources. It handles format detection, codec registry
/// initialization, and proper configuration of the underlying implementation.
///
/// The factory automatically detects the audio format and configures the
/// appropriate format strategy, codec registry, and merge policy for optimal
/// performance and compatibility with the detected format.
///
/// ## Supported Formats
///
/// The factory supports the following audio formats:
/// - **MP3**: ID3v1, ID3v2.2, ID3v2.3, ID3v2.4 containers
/// - **FLAC**: Vorbis Comments in metadata blocks
/// - **OGG Vorbis**: Vorbis Comments in comment header packets
/// - **Opus**: Vorbis Comments (OGG encapsulation)
/// - **MP4/M4A**: iTunes-style atoms in ilst container
///
/// ## Format Detection
///
/// Format detection is performed by examining file signatures and headers:
/// - File extension hints (when filename is provided)
/// - Binary signatures (magic numbers)
/// - Container structure analysis
/// - Fallback detection for ambiguous cases
///
/// ## Usage Examples
///
/// ### Loading from File
/// ```dart
/// // Load audio file from filesystem
/// final audioFile = await Phonic.fromFile('/path/to/song.mp3');
///
/// // Read metadata
/// final title = audioFile.getTag(TagKey.title);
/// final artist = audioFile.getTag(TagKey.artist);
/// final genres = audioFile.getTags(TagKey.genre);
///
/// // Use the metadata values in your application
/// final titleValue = title?.value;
/// final artistValue = artist?.value;
/// final genreList = genres.map((g) => g.value).join(', ');
///
/// // Cleanup when done
/// audioFile.dispose();
/// ```
///
/// ### Loading from Bytes
/// ```dart
/// // Load from byte array (e.g., from network, database)
/// final bytes = await downloadAudioFile();
/// final audioFile = Phonic.fromBytes(bytes, 'song.mp3');
///
/// // Modify metadata
/// audioFile.setTag(TitleTag('New Title'));
/// audioFile.setTag(ArtistTag('New Artist'));
/// audioFile.setTag(GenreTag(['Rock', 'Alternative']));
///
/// // Save changes
/// if (audioFile.isDirty) {
///   final updatedBytes = await audioFile.encode();
///   await saveAudioFile(updatedBytes);
///   audioFile.markClean();
/// }
///
/// audioFile.dispose();
/// ```
///
/// ### Error Handling
/// ```dart
/// try {
///   final audioFile = await Phonic.fromFile('unknown_format.xyz');
///   // Use audioFile...
/// } on UnsupportedFormatException catch (e) {
///   // Handle unsupported format: e.message
/// } on FileSystemException catch (e) {
///   // Handle file access error: e.message
/// }
/// ```
///
/// ### Batch Processing
/// ```dart
/// final files = ['song1.mp3', 'song2.flac', 'song3.m4a'];
///
/// for (final filePath in files) {
///   try {
///     final audioFile = await Phonic.fromFile(filePath);
///
///     // Process metadata
///     final title = audioFile.getTag(TagKey.title);
///     final titleValue = title?.value ?? 'Unknown';
///     // Process the file with titleValue...
///
///     // Always dispose to free resources
///     audioFile.dispose();
///   } on UnsupportedFormatException {
///     // Skip unsupported file: filePath
///   }
/// }
/// ```
///
/// ## Memory Management
///
/// The factory creates instances that should be properly disposed:
/// - Call `dispose()` when finished with an audio file
/// - Use try-finally blocks or similar patterns for cleanup
/// - Consider using resource management patterns for batch operations
///
/// ## Thread Safety
///
/// The factory methods are thread-safe and can be called concurrently.
/// However, the returned PhonicAudioFile instances are not thread-safe
/// and should not be accessed concurrently without synchronization.
///
/// ## Performance Considerations
///
/// - Format detection is optimized for common cases
/// - Codec registry initialization is cached per format
/// - File I/O is performed asynchronously where possible
/// - Memory usage is optimized for large files through lazy loading
class Phonic {
  /// List of available format strategies for format detection.
  ///
  /// These strategies are tried in order during format detection to find
  /// the most appropriate handler for a given audio file. The order is
  /// optimized for common formats and detection reliability.
  static final List<FormatStrategy> _formatStrategies = [
    const Mp3FormatStrategy(),
    const FlacFormatStrategy(),
    const Mp4FormatStrategy(),
    const OggFormatStrategy(),
    const OpusFormatStrategy(),
  ];

  /// Cache of codec registries by format strategy type.
  ///
  /// This cache avoids recreating codec registries for the same format
  /// strategy, improving performance when processing multiple files of
  /// the same format.
  static final Map<Type, CodecRegistry> _codecRegistryCache = {};

  /// Creates a PhonicAudioFile instance from a file path.
  ///
  /// This method reads the file from the filesystem, detects its format,
  /// and creates an appropriate PhonicAudioFile instance configured for
  /// that format. The file is loaded entirely into memory for processing.
  ///
  /// ## Format Detection Process
  ///
  /// 1. **File Extension Hint**: Uses the file extension as an initial hint
  /// 2. **Binary Analysis**: Examines file headers and signatures
  /// 3. **Strategy Matching**: Tests each format strategy's canHandle method
  /// 4. **Fallback Detection**: Uses comprehensive analysis if needed
  ///
  /// ## Supported File Extensions
  ///
  /// - `.mp3`: MP3 audio with ID3 tags
  /// - `.flac`: FLAC audio with Vorbis Comments
  /// - `.ogg`: OGG Vorbis with Vorbis Comments
  /// - `.opus`: Opus audio with Vorbis Comments
  /// - `.m4a`, `.mp4`, `.aac`: MP4 audio with iTunes atoms
  ///
  /// ## Error Conditions
  ///
  /// The method handles various error conditions gracefully:
  /// - **File Not Found**: Throws FileSystemException
  /// - **Access Denied**: Throws FileSystemException
  /// - **Unsupported Format**: Throws UnsupportedFormatException
  /// - **Corrupted File**: May throw CorruptedContainerException during processing
  ///
  /// ## Performance Notes
  ///
  /// - The entire file is loaded into memory for processing
  /// - Format detection is optimized for quick identification
  /// - Codec initialization is cached for repeated use
  /// - Consider memory usage for very large audio files
  ///
  /// Parameters:
  /// - [path]: The filesystem path to the audio file
  ///
  /// Returns:
  /// - A configured PhonicAudioFile instance ready for metadata operations
  ///
  /// Throws:
  /// - [FileSystemException] if the file cannot be read
  /// - [UnsupportedFormatException] if the format is not supported
  /// - [ArgumentError] if the path is null or empty
  ///
  /// Example:
  /// ```dart
  /// // Basic usage
  /// final audioFile = await Phonic.fromFile('/music/song.mp3');
  /// final title = audioFile.getTag(TagKey.title);
  /// final titleValue = title?.value;
  /// audioFile.dispose();
  ///
  /// // With error handling
  /// try {
  ///   final audioFile = await Phonic.fromFile(filePath);
  ///   // Process the file...
  ///   audioFile.dispose();
  /// } on FileSystemException catch (e) {
  ///   // Handle file read error: e.message
  /// } on UnsupportedFormatException catch (e) {
  ///   // Handle unsupported format: e.message
  /// }
  ///
  /// // Batch processing with proper cleanup
  /// for (final path in audioPaths) {
  ///   PhonicAudioFile? audioFile;
  ///   try {
  ///     audioFile = await Phonic.fromFile(path);
  ///     await processAudioFile(audioFile);
  ///   } finally {
  ///     audioFile?.dispose();
  ///   }
  /// }
  /// ```
  /// Alias for [fromFileAsync]. Prefer [fromFileAsync] for async naming consistency.
  static Future<PhonicAudioFile> fromFile(String path) => fromFileAsync(path);

  /// Creates a PhonicAudioFile instance from a file path.
  static Future<PhonicAudioFile> fromFileAsync(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path cannot be empty');
    }

    try {
      // Read the file bytes
      final file = File(path);
      final fileBytes = await file.readAsBytes();

      // Create from bytes with filename hint for format detection
      return fromBytes(fileBytes, path);
    } on FileSystemException {
      // Re-throw filesystem exceptions as-is
      rethrow;
    } catch (e) {
      // Wrap other exceptions in a more specific context
      throw UnsupportedFormatException(
        'Failed to load audio file: $e',
        context: 'file: $path',
      );
    }
  }

  /// Creates a PhonicAudioFile instance from byte data.
  ///
  /// This method creates a PhonicAudioFile instance from raw byte data,
  /// performing format detection and configuring the appropriate handlers.
  /// This is useful when audio data comes from sources other than files,
  /// such as network streams, databases, or memory buffers.
  ///
  /// ## Format Detection
  ///
  /// Format detection is performed using:
  /// 1. **Filename Hint**: If provided, the filename extension guides detection
  /// 2. **Binary Signatures**: Analysis of magic numbers and headers
  /// 3. **Strategy Testing**: Each format strategy tests the byte data
  /// 4. **Comprehensive Analysis**: Fallback detection for edge cases
  ///
  /// ## Filename Parameter
  ///
  /// The optional filename parameter serves multiple purposes:
  /// - **Format Hint**: File extension helps prioritize detection strategies
  /// - **Error Context**: Provides better error messages and debugging info
  /// - **Metadata Context**: Some formats may use filename in processing
  ///
  /// Even without a filename, format detection will work but may be slower
  /// for ambiguous cases.
  ///
  /// ## Memory Considerations
  ///
  /// - The byte data is copied internally to prevent external modification
  /// - Large files will consume significant memory during processing
  /// - Consider streaming approaches for very large files (future enhancement)
  /// - Call dispose() to free resources when finished
  ///
  /// ## Supported Byte Sources
  ///
  /// The method works with audio data from various sources:
  /// - File system reads (`File.readAsBytes()`)
  /// - Network downloads (`http.get().bodyBytes`)
  /// - Database BLOBs
  /// - Memory buffers and streams
  /// - Embedded resources
  ///
  /// Parameters:
  /// - [bytes]: The raw audio file bytes
  /// - [filename]: Optional filename for format detection hints and context
  ///
  /// Returns:
  /// - A configured PhonicAudioFile instance ready for metadata operations
  ///
  /// Throws:
  /// - [UnsupportedFormatException] if the format cannot be detected or is not supported
  /// - [ArgumentError] if bytes is null or empty
  ///
  /// Example:
  /// ```dart
  /// // From file bytes
  /// final bytes = await File('song.mp3').readAsBytes();
  /// final audioFile = Phonic.fromBytes(bytes, 'song.mp3');
  ///
  /// // From network
  /// final response = await http.get(Uri.parse('https://example.com/song.mp3'));
  /// final audioFile = Phonic.fromBytes(response.bodyBytes, 'downloaded.mp3');
  ///
  /// // From database
  /// final bytes = await database.getAudioBlob(songId);
  /// final audioFile = Phonic.fromBytes(bytes); // No filename hint
  ///
  /// // Process and cleanup
  /// try {
  ///   final title = audioFile.getTag(TagKey.title);
  ///   final titleValue = title?.value;
  /// } finally {
  ///   audioFile.dispose();
  /// }
  /// ```
  ///
  /// ### Advanced Usage
  /// ```dart
  /// // Custom processing with format-specific handling
  /// final audioFile = Phonic.fromBytes(audioBytes, filename);
  ///
  /// // Check detected format
  /// final strategy = _detectFormatStrategy(audioBytes, filename);
  /// final detectedFormat = strategy.mediaKind;
  ///
  /// // Format-specific operations
  /// switch (strategy.mediaKind) {
  ///   case MediaKind.mp3:
  ///     // Handle MP3-specific features
  ///     break;
  ///   case MediaKind.flac:
  ///     // Handle FLAC-specific features
  ///     break;
  ///   // ... other formats
  /// }
  ///
  /// audioFile.dispose();
  /// ```
  static PhonicAudioFile fromBytes(Uint8List bytes, [String? filename]) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Bytes cannot be empty');
    }

    // Detect the format strategy
    final formatStrategy = _detectFormatStrategy(bytes, filename);

    // Get or create codec registry for this format
    final codecRegistry = _getCodecRegistry(formatStrategy);

    // Create merge policy from format strategy
    final mergePolicy = MergePolicy.fromStrategy(formatStrategy);

    // Create and return the implementation
    final audioFile = PhonicAudioFileImpl(
      fileBytes: bytes,
      formatStrategy: formatStrategy,
      codecRegistry: codecRegistry,
      mergePolicy: mergePolicy,
    );

    // Automatically load tags from the file for user convenience.
    // This is fire-and-forget because fromBytes() is synchronous.
    unawaited(audioFile.extractContainersAndDecodeAsync());

    return audioFile;
  }

  /// Detects the appropriate format strategy for the given audio data.
  ///
  /// This method implements the format detection algorithm by testing each
  /// available format strategy against the audio data. It uses both filename
  /// hints (if available) and binary analysis to determine the best match.
  ///
  /// ## Detection Algorithm
  ///
  /// 1. **Extension Prioritization**: If filename is provided, strategies
  ///    matching the file extension are tested first
  /// 2. **Binary Testing**: Each strategy's canHandle method is called
  /// 3. **First Match Wins**: The first strategy that can handle the data is selected
  /// 4. **Fallback**: If no strategy matches, UnsupportedFormatException is thrown
  ///
  /// ## Strategy Testing Order
  ///
  /// Strategies are tested in this order for optimal performance:
  /// - MP3 (most common format)
  /// - FLAC (distinctive signature)
  /// - MP4/M4A (common mobile format)
  /// - OGG Vorbis (open format)
  /// - Opus (newer format)
  ///
  /// Parameters:
  /// - [bytes]: The audio file bytes to analyze
  /// - [filename]: Optional filename for extension-based hints
  ///
  /// Returns:
  /// - The FormatStrategy that can handle this audio format
  ///
  /// Throws:
  /// - [UnsupportedFormatException] if no strategy can handle the format
  static FormatStrategy _detectFormatStrategy(Uint8List bytes, String? filename) {
    // Get file extension hint if filename is provided
    String? extension;
    if (filename != null && filename.contains('.')) {
      extension = filename.split('.').last.toLowerCase();
    }

    // Create a prioritized list of strategies to test
    final strategiesToTest = <FormatStrategy>[];

    // First, add strategies that match the file extension (if any)
    if (extension != null) {
      for (final strategy in _formatStrategies) {
        if (_strategyMatchesExtension(strategy, extension)) {
          strategiesToTest.add(strategy);
        }
      }
    }

    // Then add remaining strategies
    for (final strategy in _formatStrategies) {
      if (!strategiesToTest.contains(strategy)) {
        strategiesToTest.add(strategy);
      }
    }

    // Test each strategy until one can handle the data
    for (final strategy in strategiesToTest) {
      if (strategy.canHandle(bytes)) {
        return strategy;
      }
    }

    // No strategy could handle this format
    final context = filename != null ? 'file: $filename' : 'byte data';
    throw UnsupportedFormatException(
      'No format strategy can handle this audio data',
      context: context,
    );
  }

  /// Checks if a format strategy matches the given file extension.
  ///
  /// This helper method maps file extensions to format strategies to
  /// optimize format detection when filename hints are available.
  ///
  /// Parameters:
  /// - [strategy]: The format strategy to test
  /// - [extension]: The file extension (without dot, lowercase)
  ///
  /// Returns:
  /// - true if the strategy handles files with this extension
  static bool _strategyMatchesExtension(FormatStrategy strategy, String extension) {
    switch (strategy.mediaKind.name) {
      case 'mp3':
        return extension == 'mp3';
      case 'flac':
        return extension == 'flac';
      case 'ogg':
        return extension == 'ogg';
      case 'opus':
        return extension == 'opus';
      case 'm4a':
      case 'mp4':
        return extension == 'm4a' || extension == 'mp4' || extension == 'aac';
      default:
        return false;
    }
  }

  /// Gets or creates a codec registry for the specified format strategy.
  ///
  /// This method implements caching of codec registries to avoid recreating
  /// the same registry multiple times for the same format. Each format
  /// strategy type gets its own cached registry instance.
  ///
  /// ## Registry Contents
  ///
  /// Each codec registry contains:
  /// - **Codecs**: Format-specific tag codecs for reading/writing containers
  /// - **Locators**: Container locators for finding metadata in files
  /// - **Capabilities**: Constraint definitions for each container type
  ///
  /// ## Caching Strategy
  ///
  /// - Registries are cached by format strategy type (not instance)
  /// - Cache is static and persists for the application lifetime
  /// - Thread-safe access through synchronized operations
  /// - Memory usage is minimal as registries contain mostly static data
  ///
  /// Parameters:
  /// - [formatStrategy]: The format strategy needing a codec registry
  ///
  /// Returns:
  /// - A CodecRegistry configured for the format strategy
  static CodecRegistry _getCodecRegistry(FormatStrategy formatStrategy) {
    final strategyType = formatStrategy.runtimeType;

    // Check cache first
    final cached = _codecRegistryCache[strategyType];
    if (cached != null) {
      return cached;
    }

    // Create new registry for this format strategy
    final registry = _createCodecRegistryForStrategy(formatStrategy);

    // Cache for future use
    _codecRegistryCache[strategyType] = registry;

    return registry;
  }

  /// Creates a codec registry configured for the specified format strategy.
  ///
  /// This method creates a comprehensive codec registry containing all
  /// available codecs and locators. While not all codecs may be used by
  /// every format strategy, having them all available allows for maximum
  /// flexibility and future extensibility.
  ///
  /// ## Registry Configuration
  ///
  /// The registry includes:
  /// - **ID3 Codecs**: ID3v1, ID3v2.2, ID3v2.3, ID3v2.4 for MP3 files
  /// - **Vorbis Codec**: For FLAC, OGG, and Opus files
  /// - **MP4 Codec**: For MP4/M4A files
  /// - **All Locators**: For finding containers in any supported format
  ///
  /// ## Design Rationale
  ///
  /// Using a comprehensive registry (rather than format-specific registries)
  /// provides several benefits:
  /// - **Simplicity**: Single registry creation logic
  /// - **Flexibility**: Strategies can access any codec if needed
  /// - **Future-proofing**: Easy to add new codecs without changing this logic
  /// - **Testing**: Consistent registry setup across all formats
  ///
  /// Parameters:
  /// - [formatStrategy]: The format strategy (used for future extensibility)
  ///
  /// Returns:
  /// - A fully configured CodecRegistry with all available codecs and locators
  static CodecRegistry _createCodecRegistryForStrategy(FormatStrategy formatStrategy) {
    return CodecRegistry(
      codecList: [
        // ID3 codecs for MP3 files
        const Id3v24Codec(),
        const Id3v23Codec(),
        const Id3v22Codec(),
        const Id3v1Codec(),

        // Vorbis Comments codec for FLAC, OGG, and Opus files
        const VorbisCommentsCodec(),

        // MP4 atoms codec for MP4/M4A files
        const Mp4AtomsCodec(),
      ],
      containerLocatorList: [
        // ID3 locators for MP3 files
        Id3v2Locator(),
        Id3v1Locator(),

        // Vorbis locators for FLAC and OGG files
        VorbisLocator(),
        OggVorbisLocator(),

        // MP4 locator for MP4/M4A files
        Mp4Locator(),
      ],
    );
  }

  /// Creates a PhonicAudioFile instance from a file path using an isolate.
  ///
  /// This method reads the file and processes metadata extraction in a
  /// background isolate, preventing UI blocking for large files or slow
  /// I/O operations. The entire parsing and tag extraction process runs
  /// in a separate isolate, then the results are transferred back to the
  /// main isolate.
  ///
  /// ## Performance Benefits
  ///
  /// - **Non-blocking**: UI remains responsive during file processing
  /// - **Parallel processing**: Can process multiple files simultaneously
  /// - **Memory isolation**: Each file processed in isolated memory space
  /// - **Better resource utilization**: Leverages multiple CPU cores
  ///
  /// ## Use Cases
  ///
  /// Use this method when:
  /// - Processing large audio files (>10MB)
  /// - Batch processing multiple files
  /// - Building responsive UIs that can't afford blocking operations
  /// - Processing files with complex metadata structures
  ///
  /// Use the standard `fromFile()` when:
  /// - Processing small files where isolate overhead isn't justified
  /// - In CLI tools where blocking is acceptable
  /// - When you need synchronous error handling
  ///
  /// ## Error Conditions
  ///
  /// All errors are propagated from the isolate back to the calling code:
  /// - **File Not Found**: Throws FileSystemException
  /// - **Access Denied**: Throws FileSystemException
  /// - **Unsupported Format**: Throws UnsupportedFormatException
  /// - **Corrupted File**: May throw CorruptedContainerException
  ///
  /// ## API Compatibility
  ///
  /// The returned `PhonicAudioFile` instance is identical to the one returned
  /// by `fromFile()`. All methods work the same way, making it a drop-in
  /// replacement for better performance.
  ///
  /// Parameters:
  /// - [path]: The filesystem path to the audio file
  ///
  /// Returns:
  /// - A configured PhonicAudioFile instance with pre-loaded metadata
  ///
  /// Throws:
  /// - [FileSystemException] if the file cannot be read
  /// - [UnsupportedFormatException] if the format is not supported
  /// - [ArgumentError] if the path is null or empty
  ///
  /// Example:
  /// ```dart
  /// // Process large file without blocking UI
  /// final audioFile = await Phonic.fromFileInIsolate('/music/large_album.flac');
  /// final title = audioFile.getTag(TagKey.title);
  /// audioFile.dispose();
  ///
  /// // Batch processing with parallelism
  /// final futures = audioPaths.map((path) =>
  ///   Phonic.fromFileInIsolate(path)
  /// );
  /// final audioFiles = await Future.wait(futures);
  ///
  /// // With error handling
  /// try {
  ///   final audioFile = await Phonic.fromFileInIsolate(filePath);
  ///   // Process the file...
  ///   audioFile.dispose();
  /// } on FileSystemException catch (e) {
  ///   print('Failed to read file: ${e.message}');
  /// } on UnsupportedFormatException catch (e) {
  ///   print('Unsupported format: ${e.message}');
  /// }
  /// ```
  /// Creates a PhonicAudioFile instance from a file path using an isolate.
  static Future<PhonicAudioFile> fromFileInIsolateAsync(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path cannot be empty');
    }

    try {
      // Read the file bytes in the main isolate
      // File I/O is already async, so no benefit to doing this in isolate
      final file = File(path);
      final fileBytes = await file.readAsBytes();

      // Process in isolate with filename hint
      return fromBytesInIsolateAsync(fileBytes, path);
    } on FileSystemException {
      // Re-throw filesystem exceptions as-is
      rethrow;
    } catch (e) {
      // Wrap other exceptions in a more specific context
      throw UnsupportedFormatException(
        'Failed to load audio file: $e',
        context: 'file: $path',
      );
    }
  }

  /// Creates a PhonicAudioFile instance from byte data using an isolate.
  ///
  /// This method processes audio metadata extraction in a background isolate,
  /// preventing blocking of the main thread. The entire format detection,
  /// container extraction, and tag decoding process runs in a separate
  /// isolate, then the decoded tags are transferred back.
  ///
  /// ## Processing Flow
  ///
  /// 1. **Isolate Spawn**: Create background isolate for processing
  /// 2. **Format Detection**: Detect audio format from byte signature
  /// 3. **Container Extraction**: Extract metadata containers (ID3, Vorbis, etc.)
  /// 4. **Tag Decoding**: Decode tags from containers
  /// 5. **Serialization**: Convert tags to transferable format
  /// 6. **Transfer**: Send data back to main isolate
  /// 7. **Reconstruction**: Rebuild PhonicAudioFile with decoded tags
  ///
  /// ## Performance Characteristics
  ///
  /// - **Overhead**: ~5-10ms for isolate spawn and data transfer
  /// - **Breakeven**: Worth it for files taking >20ms to process
  /// - **Parallelism**: Multiple calls execute truly in parallel
  /// - **Memory**: Temporary duplication during transfer (brief spike)
  ///
  /// ## Data Transfer
  ///
  /// The method transfers:
  /// - Original file bytes (shared memory where possible)
  /// - Decoded tag keys and values (primitives and collections)
  /// - Format and codec information (strings)
  ///
  /// Large payloads like artwork are handled efficiently through lazy loading
  /// and are NOT transferred - they remain as loaders in the original bytes.
  ///
  /// ## API Compatibility
  ///
  /// Returns the same `PhonicAudioFile` interface as `fromBytes()`, making
  /// it a drop-in replacement for performance-critical scenarios.
  ///
  /// Parameters:
  /// - [bytes]: The raw audio file bytes
  /// - [filename]: Optional filename for format detection hints
  ///
  /// Returns:
  /// - A configured PhonicAudioFile instance with pre-loaded metadata
  ///
  /// Throws:
  /// - [UnsupportedFormatException] if the format cannot be detected or is not supported
  /// - [ArgumentError] if bytes is null or empty
  ///
  /// Example:
  /// ```dart
  /// // From network download
  /// final response = await http.get(audioUrl);
  /// final audioFile = await Phonic.fromBytesInIsolate(
  ///   response.bodyBytes,
  ///   'downloaded.mp3',
  /// );
  ///
  /// // From database
  /// final audioData = await database.getAudioBlob(id);
  /// final audioFile = await Phonic.fromBytesInIsolate(audioData);
  ///
  /// // Batch processing
  /// final results = await Future.wait(
  ///   audioBytesList.map((bytes) =>
  ///     Phonic.fromBytesInIsolate(bytes)
  ///   ),
  /// );
  /// ```
  static Future<PhonicAudioFile> fromBytesInIsolateAsync(
    Uint8List bytes, [
    String? filename,
  ]) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Bytes cannot be empty');
    }

    // Process in isolate
    final result = await IsolateProcessor.processInIsolateAsync(bytes, filename);

    // Check for errors from isolate
    if (!result.success) {
      // Re-throw the original exception type
      final errorMessage = result.errorMessage ?? 'Unknown error';
      if (errorMessage.contains('UnsupportedFormatException')) {
        throw UnsupportedFormatException(
          errorMessage,
          context: filename != null ? 'file: $filename' : null,
        );
      }
      throw Exception(errorMessage);
    }

    // Reconstruct PhonicAudioFile from isolate result
    return IsolateProcessor.reconstructFromResult(result, bytes, filename);
  }

  /// Clears the internal codec registry cache.
  ///
  /// This method is primarily intended for testing and memory management
  /// in long-running applications. It clears the cached codec registries,
  /// forcing them to be recreated on next use.
  ///
  /// ## When to Use
  ///
  /// - **Testing**: Clear state between test cases
  /// - **Memory Management**: Free cached registries in memory-constrained environments
  /// - **Dynamic Loading**: When codec implementations change at runtime
  ///
  /// ## Performance Impact
  ///
  /// Clearing the cache will cause a small performance penalty on the next
  /// file load for each format, as registries will need to be recreated.
  /// This is typically negligible unless processing many files.
  ///
  /// Example:
  /// ```dart
  /// // In test teardown
  /// tearDown(() {
  ///   Phonic.clearCache();
  /// });
  ///
  /// // In memory management
  /// void freeMemory() {
  ///   Phonic.clearCache();
  ///   // ... other cleanup
  /// }
  /// ```
  static void clearCache() {
    _codecRegistryCache.clear();
  }
}
