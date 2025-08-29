/// Capability definitions for all supported container formats.
///
/// This library provides pre-defined capability constants for each supported
/// metadata container format. These capabilities define the constraints,
/// limitations, and supported fields for each format, enabling the library
/// to validate tags before writing and normalize values during reading.
///
/// Available capabilities:
/// - [id3v1Capability]: ID3v1 format with strict length and field limitations
/// - [id3v23Capability]: ID3v2.3 format with UTF-16 support and separate date frames
/// - [id3v24Capability]: ID3v2.4 format with UTF-8 support and unified TDRC frame
/// - [vorbisCapability]: Vorbis Comments format with UTF-8 and multi-valued field support
/// - [mp4Capability]: MP4 format with iTunes-style atoms and freeform atom support
///
/// Usage:
/// ```dart
/// import 'package:phonic/src/capabilities/capabilities.dart';
///
/// // Check format support
/// if (id3v1Capability.supports(TagKey.title)) {
///   // ID3v1 supports title field
/// }
///
/// // Get field constraints
/// final semantics = id3v1Capability.semantics(TagKey.title);
/// final maxLength = semantics.maxTextLength; // 30 for ID3v1
/// ```
library capabilities;

export 'id3v1_capability.dart';
export 'id3v23_capability.dart';
export 'id3v24_capability.dart';
export 'mp4_capability.dart';
export 'vorbis_capability.dart';
