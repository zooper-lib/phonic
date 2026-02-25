import 'dart:typed_data';

import '../exceptions/unsupported_format_exception.dart';
import '../formats/flac/flac_format_strategy.dart';
import '../formats/id3/mp3_format_strategy.dart';
import '../formats/mp4/mp4_format_strategy.dart';
import '../formats/vorbis/ogg_format_strategy.dart';
import '../formats/vorbis/opus_format_strategy.dart';
import 'format_strategy.dart';

/// Resolves the best [FormatStrategy] for a given audio byte payload.
///
/// This is intentionally separated from [Phonic] to keep the public factory
/// focused on wiring (strategy + registry + merge policy) rather than holding
/// all of the selection logic.
///
/// The resolver uses a two-phase approach:
///
/// - First, if a filename is provided, strategies whose [mediaKind] matches the
///   filename extension are tried first.
/// - Second, remaining strategies are tried in a stable default order.
///
/// Detection uses [FormatStrategy.canHandle], which is the single source of
/// truth for format recognition.
final class FormatStrategyResolver {
  /// Creates a new resolver.
  ///
  /// This type is stateless; prefer using the static methods.
  const FormatStrategyResolver();

  /// Resolves the best [FormatStrategy] for [fileBytes].
  ///
  /// Throws an [UnsupportedFormatException] if no strategy can handle
  /// the input.
  static FormatStrategy resolve(Uint8List fileBytes, {String? filename}) {
    final String? extension = _tryExtractLowercaseExtension(filename);

    final List<FormatStrategy> strategiesToTest = <FormatStrategy>[];

    if (extension != null) {
      for (final FormatStrategy strategy in _defaultStrategies) {
        if (_strategyMatchesExtension(strategy, extension)) {
          strategiesToTest.add(strategy);
        }
      }
    }

    for (final FormatStrategy strategy in _defaultStrategies) {
      if (!strategiesToTest.contains(strategy)) {
        strategiesToTest.add(strategy);
      }
    }

    for (final FormatStrategy strategy in strategiesToTest) {
      if (strategy.canHandle(fileBytes)) {
        return strategy;
      }
    }

    final String context = filename != null ? 'file: $filename' : 'byte data';
    throw UnsupportedFormatException(
      'No format strategy can handle this audio data',
      context: context,
    );
  }

  /// Default set of strategies in stable order.
  ///
  /// This order is chosen for a mix of commonality and detection reliability.
  static const List<FormatStrategy> _defaultStrategies = <FormatStrategy>[
    Mp3FormatStrategy(),
    FlacFormatStrategy(),
    Mp4FormatStrategy(),
    OggFormatStrategy(),
    OpusFormatStrategy(),
  ];

  /// Extracts a lowercase extension from [filename] if it looks like it has one.
  ///
  /// Returns null when [filename] is null or does not contain a dot.
  static String? _tryExtractLowercaseExtension(String? filename) {
    if (filename == null) {
      return null;
    }

    if (!filename.contains('.')) {
      return null;
    }

    return filename.split('.').last.toLowerCase();
  }

  /// Checks whether a [strategy] likely matches a given file [extension].
  ///
  /// This is a hint-only optimization. Actual detection is done by
  /// [FormatStrategy.canHandle].
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
}
