import 'package:phonic/audio/audio_data.dart';
import 'package:phonic/core/models/metadata/audio_metadata.dart';
import 'package:phonic/core/models/phonic_audio_file.dart';
import 'package:phonic/id3/tags/id3v1_tag.dart';
import 'package:phonic/id3/tags/id3v2_tag.dart';

class PhonicMp3AudioFile extends PhonicAudioFile {
  Id3v1Tag? _id3v1tag;
  Id3v2Tag? _id3v2tag;
  final AudioData _audioData;
  bool _isDirty = false;

  PhonicMp3AudioFile({required Id3v1Tag? id3v1tag, required Id3v2Tag? id3v2tag, required AudioData audioData})
    : _id3v1tag = id3v1tag,
      _id3v2tag = id3v2tag,
      _audioData = audioData;

  @override
  void setTag(MetadataTag tag) {
    _ensureId3v2Tag();

    // Let the ID3 tags handle the conversion internally
    _id3v2tag?.setTag(tag);
    _id3v1tag?.setTag(tag);

    _isDirty = true;
  }

  @override
  T? getTag<T extends MetadataTag>() {
    // Try ID3v2 first, then ID3v1
    return _id3v2tag?.getTag<T>() ?? _id3v1tag?.getTag<T>();
  }

  @override
  List<T> getTags<T extends MetadataTag>() {
    var tag = getTag<T>();
    return tag != null ? [tag] : [];
  }

  @override
  List<MetadataTag> getAllTags() {
    var tags = <MetadataTag>[];

    // Get all tags from ID3v2, then ID3v1 (avoiding duplicates)
    if (_id3v2tag != null) {
      tags.addAll(_id3v2tag!.getAllTags());
    }
    if (_id3v1tag != null) {
      // Add ID3v1 tags that aren't already present from ID3v2
      final v1Tags = _id3v1tag!.getAllTags();
      for (final v1Tag in v1Tags) {
        if (!tags.any((tag) => tag.runtimeType == v1Tag.runtimeType)) {
          tags.add(v1Tag);
        }
      }
    }

    return tags;
  }

  @override
  void removeTag(MetadataTag tag) {
    _id3v2tag?.removeTag(tag);
    _id3v1tag?.removeTag(tag);
    _isDirty = true;
  }

  @override
  void removeTagsByType<T extends MetadataTag>() {
    _id3v2tag?.removeTagsByType<T>();
    _id3v1tag?.removeTagsByType<T>();
    _isDirty = true;
  }

  @override
  bool get isDirty => _isDirty;

  @override
  void markClean() {
    _isDirty = false;
  }

  @override
  List<int> get audioData => _audioData.audioData;

  /// Encodes the [PhonicMp3AudioFile] to a [List] of [int]
  @override
  List<int> encode() {
    return <int>[..._id3v2tag?.encode() ?? [], ..._audioData.audioData, ..._id3v1tag?.encode() ?? []];
  }

  /// Deletes the ID3v1 tag
  void deleteId3v1Tag() {
    _id3v1tag = null;
    _isDirty = true;
  }

  /// Deletes the ID3v2 tag
  void deleteId3v2Tag() {
    _id3v2tag = null;
    _isDirty = true;
  }

  /// Ensures an ID3v2 tag exists for writing metadata
  void _ensureId3v2Tag() {
    if (_id3v2tag == null) {
      // TODO: Create a new ID3v2 tag
      // This would require implementing tag creation functionality
    }
  }
}
