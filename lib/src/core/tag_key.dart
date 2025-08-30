/// Enumeration of all supported unified tag field types.
///
/// This enum defines the complete set of logical tag fields that the Phonic
/// library supports across all audio container formats. Each value represents
/// a semantic field that can be mapped to format-specific implementations
/// (e.g., ID3v2 frames, Vorbis comment keys, MP4 atoms).
///
/// The unified approach allows developers to work with a consistent set of
/// fields regardless of the underlying container format, with the library
/// handling format-specific mapping and normalization automatically.
enum TagKey {
  /// The title or name of the track.
  ///
  /// This represents the primary title of the audio content. In most formats,
  /// this is the most prominent metadata field displayed to users.
  ///
  /// Format mappings:
  /// - ID3v2: TIT2 frame
  /// - Vorbis: TITLE field
  /// - MP4: ©nam atom
  /// - ID3v1: Title field (30 character limit)
  title,

  /// The primary artist or performer of the track.
  ///
  /// This field represents the main artist, band, or performer responsible
  /// for the audio content. For tracks with multiple artists, this typically
  /// contains the primary or lead artist.
  ///
  /// Format mappings:
  /// - ID3v2: TPE1 frame
  /// - Vorbis: ARTIST field
  /// - MP4: ©ART atom
  /// - ID3v1: Artist field (30 character limit)
  artist,

  /// The album or collection name that contains this track.
  ///
  /// This field identifies the album, EP, compilation, or other collection
  /// that the track belongs to. For standalone singles, this may be empty
  /// or contain the single title.
  ///
  /// Format mappings:
  /// - ID3v2: TALB frame
  /// - Vorbis: ALBUM field
  /// - MP4: ©alb atom
  /// - ID3v1: Album field (30 character limit)
  album,

  /// The primary artist of the album (may differ from track artist).
  ///
  /// This field is used when the album artist differs from the track artist,
  /// commonly seen in compilation albums, soundtracks, or albums featuring
  /// guest artists. If not explicitly set, it often defaults to the track artist.
  ///
  /// Format mappings:
  /// - ID3v2: TPE2 frame
  /// - Vorbis: ALBUMARTIST field
  /// - MP4: aART atom
  /// - ID3v1: Not supported (will be omitted)
  albumArtist,

  /// The track number within the album or collection.
  ///
  /// This field indicates the position of the track within its containing
  /// album or playlist. Values should be positive integers starting from 1.
  /// Some formats support "track/total" notation (e.g., "3/12").
  ///
  /// Format mappings:
  /// - ID3v2: TRCK frame
  /// - Vorbis: TRACKNUMBER field
  /// - MP4: trkn atom
  /// - ID3v1: Track field (single byte, 1-255)
  trackNumber,

  /// The disc number for multi-disc releases.
  ///
  /// This field identifies which disc or volume the track belongs to in
  /// multi-disc sets. Values should be positive integers starting from 1.
  /// Single-disc releases typically omit this field or use value 1.
  ///
  /// Format mappings:
  /// - ID3v2: TPOS frame
  /// - Vorbis: DISCNUMBER field
  /// - MP4: disk atom
  /// - ID3v1: Not supported (will be omitted)
  discNumber,

  /// The release year of the track or album.
  ///
  /// This field contains the year when the track or album was originally
  /// released. Should be a four-digit year (e.g., 1995, 2023). For more
  /// precise date information, use [dateRecorded].
  ///
  /// Format mappings:
  /// - ID3v2: TYER frame (v2.3) or extracted from TDRC (v2.4)
  /// - Vorbis: DATE field (year portion)
  /// - MP4: ©day atom (year portion)
  /// - ID3v1: Year field (4 characters)
  year,

  /// The full recording or release date in ISO-8601 format.
  ///
  /// This field contains the complete date when the track was recorded
  /// or released, formatted as ISO-8601 (e.g., "2023-03-15", "2023-03-15T14:30:00Z").
  /// This provides more precision than the [year] field alone.
  ///
  /// Format mappings:
  /// - ID3v2: TDRC frame (v2.4) or TYER/TDAT/TIME combination (v2.3)
  /// - Vorbis: DATE field
  /// - MP4: ©day atom
  /// - ID3v1: Not supported (will extract year only)
  dateRecorded,

  /// The musical genre or style of the track.
  ///
  /// This field describes the musical genre, style, or category of the track.
  /// Can be free-form text or reference standard genre classifications.
  /// ID3v1 uses numeric genre codes, which are automatically converted.
  ///
  /// Format mappings:
  /// - ID3v2: TCON frame
  /// - Vorbis: GENRE field
  /// - MP4: ©gen atom
  /// - ID3v1: Genre field (single byte, 0-255 standard genres)
  genre,

  /// Free-form comment or description text.
  ///
  /// This field contains additional commentary, notes, or description
  /// about the track. Unlike other fields, comments are typically
  /// longer-form text and may include multiple sentences.
  ///
  /// Format mappings:
  /// - ID3v2: COMM frame (with language and description)
  /// - Vorbis: COMMENT field
  /// - MP4: ©cmt atom
  /// - ID3v1: Comment field (30 chars, or 28 if track number present)
  comment,

  /// The tempo of the track in beats per minute.
  ///
  /// This field indicates the musical tempo or BPM (beats per minute) of
  /// the track. Values should be positive integers, typically ranging
  /// from 60 to 200 for most music, though extreme values are possible.
  ///
  /// Format mappings:
  /// - ID3v2: TBPM frame
  /// - Vorbis: BPM field
  /// - MP4: tmpo atom
  /// - ID3v1: Not supported (will be omitted)
  bpm,

  /// The musical key or tonality of the track.
  ///
  /// This field describes the musical key the track is written in,
  /// using standard notation (e.g., "C major", "Am", "F#"). The format
  /// may vary between different tagging systems.
  ///
  /// Format mappings:
  /// - ID3v2: TKEY frame
  /// - Vorbis: KEY field
  /// - MP4: Custom freeform atom
  /// - ID3v1: Not supported (will be omitted)
  musicalKey,

  /// User rating or score for the track (0-100 scale).
  ///
  /// This field contains a numeric rating or score assigned to the track,
  /// normalized to a 0-100 scale internally. Different formats use different
  /// scales (e.g., ID3v2 uses 0-255), but the library handles conversion
  /// automatically.
  ///
  /// Format mappings:
  /// - ID3v2: POPM frame (0-255 scale, converted to 0-100)
  /// - Vorbis: RATING field
  /// - MP4: Custom freeform atom
  /// - ID3v1: Not supported (will be omitted)
  rating,

  /// The lyrics or song text content.
  ///
  /// This field contains the complete lyrics or textual content of the song.
  /// May include timing information in some formats. Large text content
  /// may be subject to format-specific limitations.
  ///
  /// Format mappings:
  /// - ID3v2: USLT frame (with language and description)
  /// - Vorbis: LYRICS field
  /// - MP4: ©lyr atom
  /// - ID3v1: Not supported (will be omitted)
  lyrics,

  /// Album artwork or cover art images.
  ///
  /// This field contains embedded artwork images associated with the track
  /// or album. Multiple images of different types (front cover, back cover,
  /// etc.) may be present. Images are loaded lazily to optimize memory usage.
  ///
  /// Format mappings:
  /// - ID3v2: APIC frame (with picture type and description)
  /// - Vorbis: METADATA_BLOCK_PICTURE (FLAC) or base64 encoded (OGG)
  /// - MP4: covr atom
  /// - ID3v1: Not supported (will be omitted)
  artwork,

  /// Content grouping or work classification.
  ///
  /// This field is used to group related tracks together, such as movements
  /// in a classical work, parts of a suite, or thematic groupings within
  /// an album. Also known as "Content Group" in some formats.
  ///
  /// Format mappings:
  /// - ID3v2: TIT1 frame
  /// - Vorbis: GROUPING field
  /// - MP4: ©grp atom
  /// - ID3v1: Not supported (will be omitted)
  grouping,

  /// The composer or songwriter of the track.
  ///
  /// This field identifies the person or persons who composed the music,
  /// as distinct from the performer ([artist]). Particularly important
  /// for classical music, covers, and tracks where composer differs from performer.
  ///
  /// Format mappings:
  /// - ID3v2: TCOM frame
  /// - Vorbis: COMPOSER field
  /// - MP4: ©wrt atom
  /// - ID3v1: Not supported (will be omitted)
  composer,

  /// The software or hardware used to encode the audio.
  ///
  /// This field identifies the encoder, software, or hardware used to
  /// create or process the audio file. Often automatically set by
  /// encoding software and useful for technical analysis.
  ///
  /// Format mappings:
  /// - ID3v2: TSSE frame
  /// - Vorbis: ENCODER field
  /// - MP4: ©too atom
  /// - ID3v1: Not supported (will be omitted)
  encoder,

  /// International Standard Recording Code.
  ///
  /// This field contains the ISRC (International Standard Recording Code),
  /// a unique identifier for sound recordings and music videos. Format
  /// is typically "CC-XXX-YY-NNNNN" where CC is country, XXX is registrant, etc.
  ///
  /// Format mappings:
  /// - ID3v2: TSRC frame
  /// - Vorbis: ISRC field
  /// - MP4: Custom freeform atom
  /// - ID3v1: Not supported (will be omitted)
  isrc,

  /// Custom or non-standard tag fields.
  ///
  /// This field represents custom, proprietary, or non-standard metadata
  /// that doesn't fit into the other predefined categories. The actual
  /// field name and meaning depend on the specific implementation and
  /// container format capabilities.
  ///
  /// Format mappings:
  /// - ID3v2: TXXX frames (user-defined text)
  /// - Vorbis: Any non-standard field name
  /// - MP4: Freeform atoms (----:domain:name format)
  /// - ID3v1: Not supported (will be omitted)
  custom,
}
