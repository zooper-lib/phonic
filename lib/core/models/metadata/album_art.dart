import 'dart:typed_data';
import 'metadata_tag.dart';

/// Types of album artwork
enum AlbumArtType {
  other,
  fileIcon,
  otherFileIcon,
  frontCover,
  backCover,
  leafletPage,
  media,
  leadArtist,
  artist,
  conductor,
  band,
  composer,
  lyricist,
  recordingLocation,
  duringRecording,
  duringPerformance,
  movieScreenCapture,
  coloredFish,
  illustration,
  bandLogo,
  publisherLogo,
}

/// AlbumArt - represents image data associated with the track/album
class AlbumArt extends MetadataTag {
  String _mimeType;
  AlbumArtType _artType;
  String _description;
  Uint8List _data;
  
  AlbumArt({
    required String mimeType,
    required AlbumArtType artType,
    required String description,
    required Uint8List data,
  })  : _mimeType = mimeType,
        _artType = artType,
        _description = description,
        _data = data;
  
  String get mimeType => _mimeType;
  set mimeType(String value) => _mimeType = value;
  
  AlbumArtType get artType => _artType;
  set artType(AlbumArtType value) => _artType = value;
  
  String get description => _description;
  set description(String value) => _description = value;
  
  Uint8List get data => _data;
  set data(Uint8List value) => _data = value;
  
  @override
  bool get hasContent => data.isNotEmpty;
  
  @override
  void clear() => data = Uint8List(0);
  
  /// Maximum allowed size for artwork data at domain level
  int? get maxDataSize => null; // No limit at domain level
  
  @override
  bool get isValid {
    if (maxDataSize != null && data.length > maxDataSize!) return false;
    return _isMimeTypeValid(mimeType) && _isDataValid(data);
  }
  
  @override
  List<String> get validationErrors {
    final errors = <String>[];
    if (maxDataSize != null && data.length > maxDataSize!) {
      errors.add('Image data exceeds maximum size of $maxDataSize bytes');
    }
    if (!_isMimeTypeValid(mimeType)) {
      errors.add('Invalid MIME type: $mimeType');
    }
    if (!_isDataValid(data)) {
      errors.add('Invalid image data');
    }
    return errors;
  }
  
  bool _isMimeTypeValid(String mimeType) {
    const validTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/bmp'];
    return validTypes.contains(mimeType.toLowerCase());
  }
  
  bool _isDataValid(Uint8List data) {
    if (data.isEmpty) return false;
    // Basic validation - check for common image format headers
    if (data.length < 4) return false;
    
    // JPEG
    if (data[0] == 0xFF && data[1] == 0xD8) return true;
    // PNG
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) return true;
    // GIF
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) return true;
    // BMP
    if (data[0] == 0x42 && data[1] == 0x4D) return true;
    
    return false; // Unknown format
  }
}
