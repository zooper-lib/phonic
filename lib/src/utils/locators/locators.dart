/// Container locator implementations for different metadata formats.
///
/// This module contains concrete implementations of [ContainerLocator] for
/// various audio metadata container types (ID3v2, ID3v1, Vorbis Comments, MP4 atoms).
///
/// Each locator is responsible for:
/// - Detecting the presence of its container type in audio files
/// - Extracting container bytes for parsing by codecs
/// - Injecting new or modified container data back into files
///
/// ## Available Locators
///
/// - [Id3v2Locator]: Handles ID3v2 tags at the beginning of files
/// - [Id3v1Locator]: Handles ID3v1 tags at the end of files
/// - [VorbisLocator]: Handles Vorbis Comments in FLAC metadata blocks
/// - [OggVorbisLocator]: Handles Vorbis Comments in OGG Vorbis streams
/// - More locators will be added as they are implemented
///
/// ## Usage
///
/// ```dart
/// import 'package:phonic/src/utils/locators/locators.dart';
///
/// final locator = Id3v2Locator();
/// if (locator.fileMatches(fileBytes)) {
///   final containerBytes = locator.extract(fileBytes);
///   // Parse with appropriate codec...
/// }
/// ```
library phonic.locators;

export 'id3v1_locator.dart';
export 'id3v2_locator.dart';
export 'mp4_locator.dart';
export 'ogg_vorbis_locator.dart';
export 'vorbis_locator.dart';
