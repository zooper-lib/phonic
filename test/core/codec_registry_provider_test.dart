import 'package:phonic/src/core/codec_registry_provider.dart';
import 'package:phonic/src/formats/flac/flac_format_strategy.dart';
import 'package:phonic/src/formats/id3/mp3_format_strategy.dart';
import 'package:test/test.dart';

void main() {
  group('CodecRegistryProvider', () {
    tearDown(() {
      // Ensure cache isolation between tests so ordering and previous runs
      // cannot influence outcomes.
      CodecRegistryProvider.clearCache();
    });

    group('getForStrategy', () {
      test('returns the same cached registry for the same strategy runtime type', () {
        // Arrange: two different instances of the same strategy type.
        const Mp3FormatStrategy mp3StrategyA = Mp3FormatStrategy();
        const Mp3FormatStrategy mp3StrategyB = Mp3FormatStrategy();

        // Act: request registries twice.
        final registryA = CodecRegistryProvider.getForStrategy(mp3StrategyA);
        final registryB = CodecRegistryProvider.getForStrategy(mp3StrategyB);

        // Assert: caching avoids repeated registry construction.
        expect(identical(registryA, registryB), isTrue);
      });

      test('returns different registries for different strategy runtime types', () {
        // Arrange: two different strategy types.
        const Mp3FormatStrategy mp3Strategy = Mp3FormatStrategy();
        const FlacFormatStrategy flacStrategy = FlacFormatStrategy();

        // Act.
        final mp3Registry = CodecRegistryProvider.getForStrategy(mp3Strategy);
        final flacRegistry = CodecRegistryProvider.getForStrategy(flacStrategy);

        // Assert: per-type caching prevents accidental cross-format sharing.
        expect(identical(mp3Registry, flacRegistry), isFalse);
      });
    });

    group('clearCache', () {
      test('clears the cache so a subsequent request returns a new instance', () {
        // Arrange.
        const Mp3FormatStrategy mp3Strategy = Mp3FormatStrategy();
        final firstRegistry = CodecRegistryProvider.getForStrategy(mp3Strategy);

        // Act: clear, then request again.
        CodecRegistryProvider.clearCache();
        final secondRegistry = CodecRegistryProvider.getForStrategy(mp3Strategy);

        // Assert: clearing cache must actually drop previous registry instance.
        expect(identical(firstRegistry, secondRegistry), isFalse);
      });
    });
  });
}
