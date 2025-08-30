/// Enumeration of standard artwork types for audio metadata.
///
/// This enum defines the standard artwork types that can be embedded in audio
/// files across different container formats. The types are based on the ID3v2
/// APIC frame specification and are widely supported across formats.
///
/// Each artwork type represents a specific category of image that may be
/// associated with an audio track or album. Multiple artwork images of
/// different types can be present in a single audio file.
///
/// Example usage:
/// ```dart
/// final frontCover = ArtworkType.frontCover;
/// final backCover = ArtworkType.backCover;
///
/// // Check if artwork is a cover image
/// final isCover = frontCover == ArtworkType.frontCover ||
///                 frontCover == ArtworkType.backCover;
/// ```
///
/// Container format support:
/// - ID3v2: All types supported via APIC frame picture type field
/// - MP4: Supported via covr atom with type classification
/// - Vorbis: Supported via METADATA_BLOCK_PICTURE with picture type
/// - ID3v1: Not supported (no artwork capability)
enum ArtworkType {
  /// Front cover image of the album or single.
  ///
  /// This is the most common artwork type, typically displayed as the main
  /// album cover in music players and media libraries. Usually a square image
  /// showing the album artwork as it appears on physical releases.
  ///
  /// ID3v2 APIC type: 0x03
  /// Common usage: Primary album artwork, thumbnail generation
  frontCover,

  /// Back cover image of the album or single.
  ///
  /// Shows the back side of the album artwork, often containing track listings,
  /// credits, barcodes, and additional artwork. Less commonly used than front
  /// cover but valuable for complete album documentation.
  ///
  /// ID3v2 APIC type: 0x04
  /// Common usage: Complete album documentation, collector information
  backCover,

  /// Leaflet or booklet pages from the album packaging.
  ///
  /// Contains images of liner notes, lyrics, credits, or additional artwork
  /// from album booklets or inserts. May include multiple pages of content
  /// that accompanies the physical release.
  ///
  /// ID3v2 APIC type: 0x05
  /// Common usage: Liner notes, lyrics display, extended credits
  leaflet,

  /// Media image showing the physical disc, vinyl, or tape.
  ///
  /// Displays the actual storage medium (CD, vinyl record, cassette tape)
  /// including any artwork printed directly on the media surface. Often
  /// shows disc labels, vinyl center labels, or cassette shell designs.
  ///
  /// ID3v2 APIC type: 0x06
  /// Common usage: Physical media documentation, collector reference
  media,

  /// Lead artist or performer portrait.
  ///
  /// Primary artist photograph or portrait, typically the main performer
  /// or band leader. Distinguished from general artist photos by being
  /// the primary or featured artist representation.
  ///
  /// ID3v2 APIC type: 0x07
  /// Common usage: Artist identification, biography illustrations
  leadArtist,

  /// Artist or performer photograph.
  ///
  /// General artist photographs including band photos, performance shots,
  /// or promotional images. May include multiple band members or supporting
  /// artists beyond the lead performer.
  ///
  /// ID3v2 APIC type: 0x08
  /// Common usage: Artist galleries, promotional materials
  artist,

  /// Conductor photograph or portrait.
  ///
  /// Specific to classical music or orchestral recordings, showing the
  /// conductor who directed the performance. Important for classical
  /// music cataloging and attribution.
  ///
  /// ID3v2 APIC type: 0x09
  /// Common usage: Classical music metadata, conductor identification
  conductor,

  /// Band or group photograph.
  ///
  /// Group photos showing all band members together, distinct from
  /// individual artist photos. Useful for band identification and
  /// promotional purposes.
  ///
  /// ID3v2 APIC type: 0x0A
  /// Common usage: Band identification, group promotional materials
  band,

  /// Composer photograph or portrait.
  ///
  /// Image of the music composer, particularly relevant for classical
  /// music, film scores, or songwriter documentation. Separate from
  /// performer images when composer and performer differ.
  ///
  /// ID3v2 APIC type: 0x0B
  /// Common usage: Classical music, songwriter attribution
  composer,

  /// Lyricist photograph or portrait.
  ///
  /// Image of the person who wrote the song lyrics, when different from
  /// the composer or performer. Important for complete songwriting
  /// attribution and credits.
  ///
  /// ID3v2 APIC type: 0x0C
  /// Common usage: Songwriter credits, lyricist attribution
  lyricist,

  /// Recording location or studio photograph.
  ///
  /// Images of the recording studio, venue, or location where the music
  /// was recorded. Provides context about the recording environment and
  /// can be valuable for music history documentation.
  ///
  /// ID3v2 APIC type: 0x0D
  /// Common usage: Recording documentation, studio history
  recordingLocation,

  /// Photograph taken during the recording session.
  ///
  /// Behind-the-scenes images captured while the music was being recorded,
  /// showing artists and equipment in the studio environment. Provides
  /// insight into the creative process.
  ///
  /// ID3v2 APIC type: 0x0E
  /// Common usage: Recording process documentation, behind-the-scenes content
  duringRecording,

  /// Photograph taken during a live performance.
  ///
  /// Live performance images showing artists performing the music on stage
  /// or in concert settings. Captures the energy and atmosphere of live
  /// presentations of the recorded material.
  ///
  /// ID3v2 APIC type: 0x0F
  /// Common usage: Concert documentation, live performance archives
  duringPerformance,

  /// Movie or video screen capture.
  ///
  /// Still images from music videos, concert films, or other video content
  /// associated with the audio. Useful for multimedia presentations and
  /// video-related metadata.
  ///
  /// ID3v2 APIC type: 0x10
  /// Common usage: Music video stills, multimedia content
  movieScreenCapture,

  /// Bright colored fish (humorous ID3v2 specification entry).
  ///
  /// An intentionally humorous entry in the ID3v2 specification, included
  /// for completeness and compatibility. Rarely used in practice but
  /// maintained for full specification compliance.
  ///
  /// ID3v2 APIC type: 0x11
  /// Common usage: Novelty, specification compliance testing
  brightColoredFish,

  /// Illustration or artistic rendering.
  ///
  /// Artistic illustrations, drawings, or rendered artwork that accompanies
  /// the music but isn't a photograph. May include concept art, fan art,
  /// or commissioned illustrations related to the album or songs.
  ///
  /// ID3v2 APIC type: 0x12
  /// Common usage: Artistic content, concept illustrations
  illustration,

  /// Band or artist logotype.
  ///
  /// Official band logo, artist name styling, or branded imagery that
  /// represents the musical act. Important for brand recognition and
  /// consistent visual identity across releases.
  ///
  /// ID3v2 APIC type: 0x13
  /// Common usage: Branding, artist identity, logo display
  bandLogotype,

  /// Publisher or record label logotype.
  ///
  /// Record label logos, publisher branding, or distribution company
  /// imagery. Useful for label identification and music industry
  /// relationship documentation.
  ///
  /// ID3v2 APIC type: 0x14
  /// Common usage: Label identification, publisher branding
  publisherLogotype,
}
