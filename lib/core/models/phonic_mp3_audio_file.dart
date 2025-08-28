import 'package:phonic/audio/audio_data.dart';
import 'package:phonic/core/models/phonic_audio_file.dart';
import 'package:phonic/id3/tags/id3v1_tag.dart';
import 'package:phonic/id3/tags/id3v2_tag.dart';

class PhonicMp3AudioFile extends PhonicAudioFile {
  Id3v1Tag? _id3v1tag;
  Id3v2Tag? _id3v2tag;
  AudioData _audioData;

  PhonicMp3AudioFile({required Id3v1Tag id3v1tag, required Id3v2Tag id3v2tag, required AudioData audioData})
    : _id3v1tag = id3v1tag,
      _id3v2tag = id3v2tag,
      _audioData = audioData;

  /// Encodes the [PhonicMp3AudioFile] to a [List] of [int]
  List<int> encode() {
    return <int>[..._id3v2tag?.encode() ?? [], ..._audioData.audioData, ..._id3v1tag?.encode() ?? []];
  }

  /// Deletes the ID3v1 tag
  void deleteId3v1Tag() {
    _id3v1tag = null;
  }

  /// Deletes the ID3v2 tag
  void deleteId3v2Tag() {
    _id3v2tag = null;
  }

  AudioData _getAudioData(List<int> bytes, Id3v1Tag? v1, Id3v2Tag? v2) {
    var start = v2?.fullSize ?? 0;
    var end = v1 == null ? bytes.length : bytes.length - Id3v1Tag.tagLength;

    return AudioData.sublist(bytes, start, end);
  }
}
