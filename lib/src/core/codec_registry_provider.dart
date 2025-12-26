import '../formats/id3/id3v1_codec.dart';
import '../formats/id3/id3v22_codec.dart';
import '../formats/id3/id3v23_codec.dart';
import '../formats/id3/id3v24_codec.dart';
import '../formats/mp4/mp4_atoms_codec.dart';
import '../formats/vorbis/vorbis_comments_codec.dart';
import '../utils/locators/id3v1_locator.dart';
import '../utils/locators/id3v2_locator.dart';
import '../utils/locators/mp4_locator.dart';
import '../utils/locators/ogg_vorbis_locator.dart';
import '../utils/locators/vorbis_locator.dart';
import 'codec_registry.dart';
import 'container_locator.dart';
import 'format_strategy.dart';
import 'tag_codec.dart';

/// Provides cached [CodecRegistry] instances for resolved [FormatStrategy] types.
///
/// `Phonic` needs a [CodecRegistry] to locate and decode containers. This class
/// centralizes registry creation and caching so the public factory stays small.
final class CodecRegistryProvider {
  /// Creates a new provider.
  ///
  /// This type is stateless aside from its internal static cache.
  const CodecRegistryProvider();

  /// Cache of codec registries by format strategy runtime type.
  ///
  /// This avoids recreating registries when processing multiple files of the
  /// same format.
  static final Map<Type, CodecRegistry> _codecRegistryCache = <Type, CodecRegistry>{};

  /// Returns a cached [CodecRegistry] for [formatStrategy] or creates one.
  static CodecRegistry getForStrategy(FormatStrategy formatStrategy) {
    final Type strategyType = formatStrategy.runtimeType;

    final CodecRegistry? cachedRegistry = _codecRegistryCache[strategyType];
    if (cachedRegistry != null) {
      return cachedRegistry;
    }

    final CodecRegistry registry = _createCodecRegistryForStrategy(formatStrategy);
    _codecRegistryCache[strategyType] = registry;
    return registry;
  }

  /// Clears the internal registry cache.
  ///
  /// This is primarily useful for test isolation and long-running processes.
  static void clearCache() {
    _codecRegistryCache.clear();
  }

  /// Creates a codec registry configured for the specified [formatStrategy].
  ///
  /// The current implementation uses a comprehensive registry containing all
  /// built-in codecs and locators. This keeps selection logic centralized in
  /// locators/codecs, and allows strategies to evolve without requiring new
  /// registry wiring.
  static CodecRegistry _createCodecRegistryForStrategy(FormatStrategy formatStrategy) {
    return CodecRegistry(
      codecList: <TagCodec>[
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
      containerLocatorList: <ContainerLocator>[
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
}
