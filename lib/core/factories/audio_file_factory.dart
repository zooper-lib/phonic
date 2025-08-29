import 'dart:typed_data';
import 'package:phonic/core/models/phonic_audio_file.dart';
import 'package:phonic/core/models/phonic_mp3_audio_file.dart';
import 'package:phonic/id3/tags/id3v1_tag.dart';
import 'package:phonic/id3/tags/id3v2_tag.dart';
import 'package:phonic/audio/audio_data.dart';

/// Factory for creating audio files from raw bytes
class AudioFileFactory {
  /// Creates an appropriate audio file instance from raw bytes
  ///
  /// Automatically detects the format and creates the appropriate implementation
  static Future<PhonicAudioFile?> fromBytes(Uint8List bytes) async {
    // Try MP3/ID3 first
    var mp3File = await _tryCreateMp3File(bytes);
    if (mp3File != null) {
      return mp3File;
    }

    // TODO: Add support for other formats (FLAC, OGG, MP4, etc.)

    return null;
  }

  /// Creates an audio file from a file path
  static Future<PhonicAudioFile?> fromFile(String filePath) async {
    // TODO: Implement file reading
    throw UnimplementedError('File reading not yet implemented');
  }

  /// Attempts to create an MP3 file with ID3 tags
  static Future<PhonicMp3AudioFile?> _tryCreateMp3File(Uint8List bytes) async {
    try {
      // Try to decode ID3v2 tag first (at the beginning)
      Id3v2Tag? id3v2Tag = Id3v2Tag.decode(bytes.toList(), 0);

      // Try to decode ID3v1 tag (at the end)
      Id3v1Tag? id3v1Tag = Id3v1Tag.decode(bytes.toList());

      // If we found at least one tag, this is likely an MP3 file
      if (id3v2Tag != null || id3v1Tag != null) {
        // Extract audio data
        var audioData = _extractAudioData(bytes, id3v1Tag, id3v2Tag);

        return PhonicMp3AudioFile(id3v1tag: id3v1Tag, id3v2tag: id3v2Tag, audioData: audioData);
      }

      return null;
    } catch (e) {
      // If parsing fails, this might not be an MP3 file or might be corrupted
      return null;
    }
  }

  /// Extracts audio data from the file, excluding ID3 tags
  static AudioData _extractAudioData(Uint8List bytes, Id3v1Tag? id3v1Tag, Id3v2Tag? id3v2Tag) {
    var start = id3v2Tag?.fullSize ?? 0;
    var end = id3v1Tag == null ? bytes.length : bytes.length - Id3v1Tag.tagLength;

    return AudioData.sublist(bytes.toList(), start, end);
  }
}
