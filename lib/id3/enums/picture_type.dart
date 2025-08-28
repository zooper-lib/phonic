/// Represents the type of the attached picture.
enum PictureType {
  /// Everything that doesn't fit the other categories.
  ///
  /// Used by default when the type of the picture
  other,

  /// A 32x32 pixels icon, `png` only (v2.3.0, 4.15).
  fileIcon,

  /// Another [fileIcon].
  otherFileIcon,

  /// The front cover of the album.
  frontCover,

  /// The back cover of the album.
  backCover,

  /// The leaflet page.
  leafletPage,
  // e.g. label side of CD
  media,

  /// Lead artist/lead performer/soloist.
  soloist,

  /// Artist or performer.
  artist,

  /// Conductor.
  conductor,

  /// Band or orchestra.
  band,

  /// Composer.
  composer,

  /// Lyricist.
  lyricist,

  /// Recording Location.
  location,

  /// During recording.
  recording,

  /// During performance.
  performance,

  /// Movie/video screen capture.
  screenCapture,

  /// A bright coloured fish, I guess. It's in the doc.
  brightColouredFish,

  /// An illustration.
  illustration,

  /// Band/artist logotype.
  artistLogotype,

  /// Publisher/Studio logotype.
  studioLogotype,
}

const pictureTypes = PictureTypes();

class PictureTypes {
  const PictureTypes();

  /// The [PictureType] used when it cannot be determined.
  final fallback = PictureType.other;

  final count = 0x15;

  /// Picture types for ID3v2.3
  operator [](int code) => {
    0x00: PictureType.other,
    0x01: PictureType.fileIcon, // 32x32 pixels, `png` only (v2.3.0, 4.15)
    0x02: PictureType.otherFileIcon,
    0x03: PictureType.frontCover,
    0x04: PictureType.backCover,
    0x05: PictureType.leafletPage,
    0x06: PictureType.media, // e.g. label side of CD
    0x07: PictureType.soloist, // Lead artist/lead performer/soloist
    0x08: PictureType.artist, // Artist or performer
    0x09: PictureType.conductor,
    0x0A: PictureType.band, // Band or orchestra
    0x0B: PictureType.composer,
    0x0C: PictureType.lyricist,
    0x0D: PictureType.location, // Recording Location
    0x0E: PictureType.recording, // During recording
    0x0F: PictureType.performance, // During performance
    0x10: PictureType.screenCapture,
    0x11: PictureType.brightColouredFish, // What the heck?
    0x12: PictureType.illustration,
    0x13: PictureType.artistLogotype, // Band/artist logotype
    0x14: PictureType.studioLogotype, // Publisher/Studio logotype
  }[code];
}
