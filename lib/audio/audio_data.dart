/// Stores the actual audio data, excluding ID3v2Tag and ID3v1Tag
class AudioData {
  late List<int> _audioData;

  List<int> get audioData => _audioData;

  AudioData.fromList(List<int> bytes) {
    _audioData = bytes;
  }

  AudioData.sublist(List<int> bytes, int start, int end) {
    _audioData = bytes.sublist(start, end);
  }
}