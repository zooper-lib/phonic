// Core API
export "core/models/phonic_audio_file.dart";
export "core/models/metadata/audio_metadata.dart";
export "core/factories/audio_file_factory.dart";

// For advanced users who need format-specific features
export "core/models/phonic_mp3_audio_file.dart";

// Common exceptions
export "id3/exceptions/id3_exception.dart";
export "id3/exceptions/tag_not_found_exception.dart";
export "id3/exceptions/unsupported_version_exception.dart";
