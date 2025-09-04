import 'dart:typed_data';

import 'byte_reader.dart';

/// Utility class for detecting audio file formats based on file signatures and headers.
///
/// This class provides static methods for identifying different audio file formats
/// by examining their binary signatures, magic bytes, and structural patterns.
/// The detection methods are designed to be fast and reliable, suitable for
/// format detection during file processing.
///
/// ## Supported Formats
///
/// - **MP3**: ID3v2 headers and MPEG frame sync patterns
/// - **FLAC**: "fLaC" signature and metadata block structure
/// - **OGG**: "OggS" page headers for Vorbis and Opus streams
/// - **MP4/M4A**: File type box (ftyp) with brand identification
///
/// ## Usage Example
///
/// ```dart
/// final fileBytes = await File('audio.mp3').readAsBytes();
///
/// if (FormatDetection.isMp3(fileBytes)) {
///   print('MP3 file detected');
/// } else if (FormatDetection.isFlac(fileBytes)) {
///   print('FLAC file detected');
/// } else if (FormatDetection.isOgg(fileBytes)) {
///   print('OGG file detected');
/// } else if (FormatDetection.isMp4(fileBytes)) {
///   print('MP4/M4A file detected');
/// }
/// ```
///
/// ## Performance Considerations
///
/// All detection methods are optimized for speed:
/// - Check minimum required bytes before processing
/// - Use efficient byte pattern matching
/// - Avoid expensive string operations
/// - Return early for non-matching patterns
/// - Limit the amount of data examined
class FormatDetection {
  /// Private constructor to prevent instantiation.
  FormatDetection._();

  // Format signatures and magic bytes
  static const List<int> _id3v2Signature = [0x49, 0x44, 0x33]; // "ID3"
  static const List<int> _flacSignature = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"
  static const List<int> _oggSignature = [0x4F, 0x67, 0x67, 0x53]; // "OggS"
  static const List<int> _mp4Signature = [0x66, 0x74, 0x79, 0x70]; // "ftyp"

  // MP3 frame sync patterns
  static const int _mp3FrameSyncMask = 0xFFE0; // 11111111 11100000
  static const int _mp3FrameSync = 0xFFE0; // Frame sync pattern

  // MP4 brand identifiers
  static const List<String> _m4aBrands = ['M4A '];
  static const List<String> _mp4Brands = ['mp41', 'mp42', 'isom', 'avc1'];

  /// Detects if the given file data represents an MP3 file.
  ///
  /// This method checks for:
  /// 1. ID3v2 header signature at the beginning of the file
  /// 2. MPEG frame sync patterns indicating MP3 audio data
  ///
  /// The detection is performed by examining the first few bytes of the file
  /// for known MP3 signatures and structural patterns.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine (typically first few KB)
  ///
  /// Returns:
  /// - `true` if the file appears to be an MP3 file
  /// - `false` if the format is not recognized as MP3
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.mp3').readAsBytes();
  /// if (FormatDetection.isMp3(bytes)) {
  ///   print('MP3 file detected');
  /// }
  /// ```
  static bool isMp3(Uint8List fileBytes) {
    if (fileBytes.length < 4) return false;

    // Check for ID3v2 header at the beginning
    if (_hasId3v2Header(fileBytes)) {
      return true;
    }

    // Check for MP3 frame sync patterns
    return _hasMp3FrameSync(fileBytes);
  }

  /// Detects if the given file data represents a FLAC file.
  ///
  /// This method checks for the FLAC signature ("fLaC") at the beginning
  /// of the file, which is the standard identifier for FLAC audio files.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be a FLAC file
  /// - `false` if the format is not recognized as FLAC
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.flac').readAsBytes();
  /// if (FormatDetection.isFlac(bytes)) {
  ///   print('FLAC file detected');
  /// }
  /// ```
  static bool isFlac(Uint8List fileBytes) {
    if (fileBytes.length < _flacSignature.length) return false;

    // Check for "fLaC" signature at the beginning
    for (int i = 0; i < _flacSignature.length; i++) {
      if (fileBytes[i] != _flacSignature[i]) {
        return false;
      }
    }
    return true;
  }

  /// Detects if the given file data represents an OGG file (Vorbis or Opus).
  ///
  /// This method checks for the OGG page signature ("OggS") which is used
  /// by both OGG Vorbis and Opus files. Additional codec-specific detection
  /// can be performed using [isOggVorbis] and [isOggOpus] methods.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be an OGG container file
  /// - `false` if the format is not recognized as OGG
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.ogg').readAsBytes();
  /// if (FormatDetection.isOgg(bytes)) {
  ///   print('OGG file detected');
  /// }
  /// ```
  static bool isOgg(Uint8List fileBytes) {
    if (fileBytes.length < _oggSignature.length) return false;

    // Check for "OggS" signature at the beginning
    for (int i = 0; i < _oggSignature.length; i++) {
      if (fileBytes[i] != _oggSignature[i]) {
        return false;
      }
    }
    return true;
  }

  /// Detects if the given file data represents an OGG Vorbis file.
  ///
  /// This method first checks for the OGG container signature, then examines
  /// the stream headers to identify the Vorbis codec specifically.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be an OGG Vorbis file
  /// - `false` if the format is not OGG Vorbis
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.ogg').readAsBytes();
  /// if (FormatDetection.isOggVorbis(bytes)) {
  ///   print('OGG Vorbis file detected');
  /// }
  /// ```
  static bool isOggVorbis(Uint8List fileBytes) {
    if (!isOgg(fileBytes)) return false;

    // Look for Vorbis identification header
    return _hasVorbisIdentificationHeader(fileBytes);
  }

  /// Detects if the given file data represents an Opus file.
  ///
  /// This method first checks for the OGG container signature, then examines
  /// the stream headers to identify the Opus codec specifically.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be an Opus file
  /// - `false` if the format is not Opus
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.opus').readAsBytes();
  /// if (FormatDetection.isOpus(bytes)) {
  ///   print('Opus file detected');
  /// }
  /// ```
  static bool isOpus(Uint8List fileBytes) {
    if (!isOgg(fileBytes)) return false;

    // Look for Opus identification header
    return _hasOpusIdentificationHeader(fileBytes);
  }

  /// Detects if the given file data represents an MP4 container file.
  ///
  /// This method checks for the MP4 file type box (ftyp) signature and
  /// examines the brand identifiers to determine if it's an MP4 or M4A file.
  /// It validates that the file contains recognized MP4 brands.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be an MP4 container file
  /// - `false` if the format is not recognized as MP4
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.m4a').readAsBytes();
  /// if (FormatDetection.isMp4(bytes)) {
  ///   print('MP4/M4A file detected');
  /// }
  /// ```
  static bool isMp4(Uint8List fileBytes) {
    if (fileBytes.length < 16) return false; // Minimum for ftyp box with brands

    try {
      final reader = ByteReader(fileBytes);

      // Read box size
      final boxSize = reader.readUint32();
      if (boxSize < 16) return false; // Minimum ftyp box size

      // Check for "ftyp" signature
      if (!reader.matchesPattern(_mp4Signature)) {
        return false;
      }
      reader.skip(4); // Skip past "ftyp"

      // Read major brand (4 bytes)
      final majorBrand = reader.readString(4);

      // Check if major brand is recognized
      if (_mp4Brands.contains(majorBrand) || _m4aBrands.contains(majorBrand)) {
        return true;
      }

      // Check compatible brands
      final remainingBytes = (boxSize - 16) ~/ 4; // Each brand is 4 bytes
      for (int i = 0; i < remainingBytes && reader.hasRemaining; i++) {
        final compatibleBrand = reader.readString(4);
        if (_mp4Brands.contains(compatibleBrand) || _m4aBrands.contains(compatibleBrand)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Detects if the given file data represents an M4A audio file specifically.
  ///
  /// This method checks for MP4 container format and then examines the brand
  /// identifiers to determine if it's specifically an M4A audio file rather
  /// than a general MP4 video file.
  ///
  /// Parameters:
  /// - [fileBytes]: The file data to examine
  ///
  /// Returns:
  /// - `true` if the file appears to be an M4A audio file
  /// - `false` if the format is not M4A
  ///
  /// Example:
  /// ```dart
  /// final bytes = await File('song.m4a').readAsBytes();
  /// if (FormatDetection.isM4a(bytes)) {
  ///   print('M4A audio file detected');
  /// }
  /// ```
  static bool isM4a(Uint8List fileBytes) {
    if (!isMp4(fileBytes)) return false;

    try {
      final reader = ByteReader(fileBytes);

      // Read box size
      final boxSize = reader.readUint32();
      if (boxSize < 16) return false; // Minimum ftyp box size

      // Skip "ftyp" signature (already verified)
      reader.skip(4);

      // Read major brand (4 bytes)
      final majorBrand = reader.readString(4);

      // Check if major brand indicates M4A
      if (_m4aBrands.contains(majorBrand)) {
        return true;
      }

      // Check compatible brands
      final remainingBytes = (boxSize - 16) ~/ 4; // Each brand is 4 bytes
      for (int i = 0; i < remainingBytes && reader.hasRemaining; i++) {
        final compatibleBrand = reader.readString(4);
        if (_m4aBrands.contains(compatibleBrand)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the file data contains an ID3v2 header.
  ///
  /// ID3v2 headers start with the signature "ID3" followed by version bytes.
  /// This is a reliable indicator of MP3 files with ID3v2 metadata.
  static bool _hasId3v2Header(Uint8List fileBytes) {
    if (fileBytes.length < _id3v2Signature.length) return false;

    for (int i = 0; i < _id3v2Signature.length; i++) {
      if (fileBytes[i] != _id3v2Signature[i]) {
        return false;
      }
    }
    return true;
  }

  /// Checks if the file data contains MP3 frame sync patterns.
  ///
  /// MP3 frames begin with a sync pattern (11 consecutive 1 bits) followed
  /// by format information. This method scans the beginning of the file
  /// looking for valid MP3 frame headers.
  static bool _hasMp3FrameSync(Uint8List fileBytes) {
    if (fileBytes.length < 4) return false;

    // Scan the first few KB for MP3 frame sync patterns
    final scanLimit = (fileBytes.length < 8192) ? fileBytes.length : 8192;

    for (int i = 0; i <= scanLimit - 4; i++) {
      // Check for frame sync pattern (0xFFE0 or higher)
      final syncWord = (fileBytes[i] << 8) | fileBytes[i + 1];
      if ((syncWord & _mp3FrameSyncMask) == _mp3FrameSync) {
        // Additional validation: check if this looks like a valid MP3 header
        if (_isValidMp3Header(fileBytes, i)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Validates if the bytes at the given position represent a valid MP3 frame header.
  ///
  /// This method performs additional checks beyond the sync pattern to ensure
  /// the header contains valid MP3 format information.
  static bool _isValidMp3Header(Uint8List fileBytes, int position) {
    if (position + 4 > fileBytes.length) return false;

    final header = (fileBytes[position] << 24) | (fileBytes[position + 1] << 16) | (fileBytes[position + 2] << 8) | fileBytes[position + 3];

    // Extract version bits (bits 19-20)
    final version = (header >> 19) & 0x3;
    if (version == 1) return false; // Reserved version

    // Extract layer bits (bits 17-18)
    final layer = (header >> 17) & 0x3;
    if (layer == 0) return false; // Reserved layer

    // Extract bitrate index (bits 12-15)
    final bitrateIndex = (header >> 12) & 0xF;
    if (bitrateIndex == 0 || bitrateIndex == 15) return false; // Invalid bitrate

    // Extract sampling rate index (bits 10-11)
    final samplingRateIndex = (header >> 10) & 0x3;
    if (samplingRateIndex == 3) return false; // Reserved sampling rate

    return true;
  }

  /// Checks if the OGG file contains a Vorbis identification header.
  ///
  /// Vorbis streams in OGG containers have a specific identification header
  /// that begins with the string "vorbis".
  static bool _hasVorbisIdentificationHeader(Uint8List fileBytes) {
    try {
      final reader = ByteReader(fileBytes);

      // Skip OGG page header (minimum 27 bytes)
      if (fileBytes.length < 35) return false; // Need space for OGG header + vorbis check

      // Skip to OGG page data (after basic header)
      reader.seek(27);

      // Read segment table length
      final segmentCount = fileBytes[26];
      reader.skip(segmentCount);

      // Check for Vorbis identification packet
      // Vorbis identification starts with packet type (0x01) + "vorbis"
      if (reader.remaining < 7) return false;

      final packetType = reader.readUint8();
      if (packetType != 0x01) return false;

      final vorbisString = reader.readString(6);
      return vorbisString == 'vorbis';
    } catch (e) {
      return false;
    }
  }

  /// Checks if the OGG file contains an Opus identification header.
  ///
  /// Opus streams in OGG containers have a specific identification header
  /// that begins with the string "OpusHead".
  static bool _hasOpusIdentificationHeader(Uint8List fileBytes) {
    try {
      final reader = ByteReader(fileBytes);

      // Skip OGG page header (minimum 27 bytes)
      if (fileBytes.length < 35) return false; // Need space for OGG header + opus check

      // Skip to OGG page data (after basic header)
      reader.seek(27);

      // Read segment table length
      final segmentCount = fileBytes[26];
      reader.skip(segmentCount);

      // Check for Opus identification packet
      // Opus identification starts with "OpusHead"
      if (reader.remaining < 8) return false;

      final opusString = reader.readString(8);
      return opusString == 'OpusHead';
    } catch (e) {
      return false;
    }
  }
}
