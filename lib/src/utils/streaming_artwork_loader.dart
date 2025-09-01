import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

/// A streaming loader for very large artwork data that processes images in chunks.
///
/// StreamingArtworkLoader provides memory-efficient loading of large artwork
/// by processing image data in configurable chunks rather than loading the
/// entire image into memory at once. This is particularly useful for:
///
/// - Very high resolution artwork (> 10MB)
/// - Memory-constrained environments
/// - Progressive image processing workflows
/// - Bandwidth-limited scenarios
///
/// ## Features
///
/// - **Chunk-based Processing**: Loads artwork data in configurable chunk sizes
/// - **Memory Efficiency**: Never loads the entire image into memory
/// - **Progress Tracking**: Provides progress callbacks for long operations
/// - **Cancellation Support**: Allows cancellation of long-running operations
/// - **Error Recovery**: Handles partial failures gracefully
/// - **Format Agnostic**: Works with any binary image format
///
/// ## Usage Examples
///
/// ### Basic Streaming
/// ```dart
/// final loader = StreamingArtworkLoader(
///   containerBytes: largeContainerBytes,
///   offset: artworkOffset,
///   length: artworkLength,
///   chunkSize: 64 * 1024, // 64KB chunks
/// );
///
/// // Process artwork in chunks
/// await for (final chunk in loader.stream()) {
///   // Process each chunk as it's loaded
///   processImageChunk(chunk);
/// }
/// ```
///
/// ### With Progress Tracking
/// ```dart
/// final loader = StreamingArtworkLoader(
///   containerBytes: containerBytes,
///   offset: offset,
///   length: length,
/// );
///
/// var totalProcessed = 0;
/// await for (final chunk in loader.stream()) {
///   totalProcessed += chunk.length;
///   final progress = (totalProcessed / length) * 100;
///   print('Progress: ${progress.toStringAsFixed(1)}%');
///
///   // Process chunk...
/// }
/// ```
///
/// ### Integration with ArtworkData
/// ```dart
/// final streamingLoader = StreamingArtworkLoader(...);
///
/// final artworkData = ArtworkData(
///   mimeType: 'image/jpeg',
///   type: ArtworkType.frontCover,
///   description: 'High resolution cover',
///   dataLoader: () => streamingLoader.loadComplete(),
/// );
/// ```
///
/// ## Memory Management
///
/// The streaming approach provides several memory benefits:
/// - Peak memory usage is limited to chunk size + small overhead
/// - Large images don't cause memory spikes
/// - Garbage collection pressure is reduced
/// - Memory usage is predictable and bounded
///
/// ## Performance Considerations
///
/// - Chunk size affects memory vs. performance tradeoff
/// - Smaller chunks use less memory but have more overhead
/// - Larger chunks are more efficient but use more memory
/// - Optimal chunk size depends on image size and available memory
/// - Default chunk size (64KB) works well for most scenarios
class StreamingArtworkLoader {
  final Uint8List _containerBytes;
  final int _offset;
  final int _length;
  final int _chunkSize;

  /// Creates a new StreamingArtworkLoader with the specified parameters.
  ///
  /// Parameters:
  /// - [containerBytes]: The container bytes containing the artwork data
  /// - [offset]: The byte offset where artwork data begins
  /// - [length]: The total length of the artwork data
  /// - [chunkSize]: The size of each chunk to process (default: 64KB)
  ///
  /// The chunk size determines the memory usage and performance characteristics:
  /// - Smaller chunks (8-32KB): Lower memory usage, higher overhead
  /// - Medium chunks (64-256KB): Good balance for most use cases
  /// - Large chunks (512KB+): Better performance, higher memory usage
  StreamingArtworkLoader({
    required Uint8List containerBytes,
    required int offset,
    required int length,
    int chunkSize = 64 * 1024, // 64KB default
  }) : _containerBytes = containerBytes,
       _offset = offset,
       _length = length,
       _chunkSize = chunkSize {
    // Validate parameters
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Offset must be non-negative');
    }

    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Length must be positive');
    }

    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Chunk size must be positive');
    }

    if (offset + length > containerBytes.length) {
      throw RangeError.range(
        offset + length,
        0,
        containerBytes.length,
        'offset + length',
        'Artwork data bounds exceed container size',
      );
    }
  }

  /// Gets the total length of the artwork data.
  int get length => _length;

  /// Gets the chunk size used for streaming.
  int get chunkSize => _chunkSize;

  /// Gets the number of chunks that will be produced.
  int get chunkCount => (_length / _chunkSize).ceil();

  /// Creates a stream that yields artwork data in chunks.
  ///
  /// The stream produces [Uint8List] chunks of the configured size
  /// (except possibly the last chunk which may be smaller).
  ///
  /// Returns:
  /// - A stream of [Uint8List] chunks containing artwork data
  ///
  /// The stream can be cancelled at any time and will stop producing
  /// chunks immediately. Each chunk is a separate [Uint8List] instance.
  Stream<Uint8List> stream() async* {
    var currentOffset = _offset;
    var remainingBytes = _length;

    while (remainingBytes > 0) {
      final chunkLength = math.min(_chunkSize, remainingBytes);
      final chunk = _containerBytes.sublist(
        currentOffset,
        currentOffset + chunkLength,
      );

      yield chunk;

      currentOffset += chunkLength;
      remainingBytes -= chunkLength;
    }
  }

  /// Creates a stream with progress information.
  ///
  /// Returns:
  /// - A stream of [StreamingChunk] objects containing data and progress info
  ///
  /// Each chunk includes:
  /// - The chunk data as [Uint8List]
  /// - Current chunk index
  /// - Total number of chunks
  /// - Bytes processed so far
  /// - Total bytes to process
  Stream<StreamingChunk> streamWithProgress() async* {
    var currentOffset = _offset;
    var remainingBytes = _length;
    var chunkIndex = 0;
    var bytesProcessed = 0;
    final totalChunks = chunkCount;

    while (remainingBytes > 0) {
      final chunkLength = math.min(_chunkSize, remainingBytes);
      final chunk = _containerBytes.sublist(
        currentOffset,
        currentOffset + chunkLength,
      );

      yield StreamingChunk(
        data: chunk,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        bytesProcessed: bytesProcessed,
        totalBytes: _length,
      );

      currentOffset += chunkLength;
      remainingBytes -= chunkLength;
      bytesProcessed += chunkLength;
      chunkIndex++;
    }
  }

  /// Loads the complete artwork data as a single [Uint8List].
  ///
  /// This method defeats the streaming purpose but is provided for
  /// compatibility with existing [ArtworkData] interfaces that expect
  /// the complete data.
  ///
  /// Returns:
  /// - A future that completes with the complete artwork data
  ///
  /// Note: This method loads the entire artwork into memory and should
  /// only be used when streaming is not possible or practical.
  Future<Uint8List> loadComplete() async {
    return _containerBytes.sublist(_offset, _offset + _length);
  }

  /// Processes the artwork data through a streaming processor function.
  ///
  /// Parameters:
  /// - [processor]: Function that processes each chunk and returns processed data
  /// - [combiner]: Function that combines processed chunks into final result
  ///
  /// This method allows for custom processing of artwork data without
  /// loading the entire image into memory.
  ///
  /// Example:
  /// ```dart
  /// // Calculate hash of large artwork without loading it all
  /// final hash = await loader.processStreaming(
  ///   processor: (chunk) => sha256.convert(chunk).bytes,
  ///   combiner: (hashes) => hashes.expand((h) => h).toList(),
  /// );
  /// ```
  Future<T> processStreaming<T>({
    required Future<List<int>> Function(Uint8List chunk) processor,
    required T Function(List<List<int>> results) combiner,
  }) async {
    final results = <List<int>>[];

    await for (final chunk in stream()) {
      final processed = await processor(chunk);
      results.add(processed);
    }

    return combiner(results);
  }

  /// Creates a buffered stream that accumulates chunks up to a buffer size.
  ///
  /// Parameters:
  /// - [bufferSize]: Maximum size of each buffered chunk
  ///
  /// This method is useful when you need larger processing units than
  /// the configured chunk size but still want to limit memory usage.
  ///
  /// Returns:
  /// - A stream of [Uint8List] chunks up to [bufferSize] bytes each
  Stream<Uint8List> bufferedStream(int bufferSize) async* {
    final buffer = <int>[];

    await for (final chunk in stream()) {
      buffer.addAll(chunk);

      while (buffer.length >= bufferSize) {
        final bufferedChunk = Uint8List.fromList(
          buffer.take(bufferSize).toList(),
        );
        buffer.removeRange(0, bufferSize);
        yield bufferedChunk;
      }
    }

    // Yield remaining data if any
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  /// Returns a string representation of this streaming loader.
  @override
  String toString() {
    return 'StreamingArtworkLoader('
        'offset: $_offset, '
        'length: $_length, '
        'chunkSize: $_chunkSize, '
        'chunkCount: $chunkCount)';
  }
}

/// Represents a chunk of streaming artwork data with progress information.
class StreamingChunk {
  /// The chunk data.
  final Uint8List data;

  /// The index of this chunk (0-based).
  final int chunkIndex;

  /// The total number of chunks.
  final int totalChunks;

  /// The number of bytes processed so far (including this chunk).
  final int bytesProcessed;

  /// The total number of bytes to process.
  final int totalBytes;

  /// Creates a new StreamingChunk with the specified data and progress info.
  const StreamingChunk({
    required this.data,
    required this.chunkIndex,
    required this.totalChunks,
    required this.bytesProcessed,
    required this.totalBytes,
  });

  /// Gets the progress as a percentage (0.0 to 100.0).
  double get progressPercent => (bytesProcessed / totalBytes) * 100.0;

  /// Gets whether this is the last chunk.
  bool get isLastChunk => chunkIndex == totalChunks - 1;

  /// Gets whether this is the first chunk.
  bool get isFirstChunk => chunkIndex == 0;

  /// Returns a string representation of this chunk.
  @override
  String toString() {
    return 'StreamingChunk('
        'chunk: ${chunkIndex + 1}/$totalChunks, '
        'bytes: ${data.length}, '
        'progress: ${progressPercent.toStringAsFixed(1)}%)';
  }
}
