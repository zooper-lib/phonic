/// Capability definitions for all supported container formats.
///
/// This library provides pre-defined capability constants for each supported
/// metadata container format. These capabilities define the constraints,
/// limitations, and supported fields for each format, enabling the library
/// to validate tags before writing and normalize values during reading.
///
/// Available capabilities:
/// - [id3v1Capability]: ID3v1 format with strict length and field limitations
/// - Additional format capabilities will be added in future tasks
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
