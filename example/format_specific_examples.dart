// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:phonic/phonic.dart';

/// Format-specific examples demonstrating Phonic's support for different audio formats.
///
/// This example shows how the unified API works consistently across different
/// audio container formats while handling format-specific features and constraints:
/// - MP3 with ID3v1, ID3v2.2, ID3v2.3, and ID3v2.4 tags
/// - FLAC with Vorbis Comments
/// - OGG Vorbis with Vorbis Comments
/// - Opus with Vorbis Comments
/// - MP4/M4A with iTunes-style atoms
void main() async {
  print('Phonic Format-Specific Examples');
  print('===============================\n');

  // Example 1: MP3 with multiple ID3 versions
  await mp3FormatExample();

  // Example 2: FLAC with Vorbis Comments
  await flacFormatExample();

  // Example 3: OGG Vorbis format
  await oggVorbisFormatExample();

  // Example 4: Opus format
  await opusFormatExample();

  // Example 5: MP4/M4A format
  await mp4FormatExample();

  // Example 6: Format detection and capabilities
  await formatDetectionExample();

  // Example 7: Cross-format compatibility
  await crossFormatCompatibilityExample();
}

/// Demonstrates MP3 format with multiple ID3 versions and precedence rules.
Future<void> mp3FormatExample() async {
  print('1. MP3 Format with ID3 Tags');
  print('---------------------------');

  try {
    // Create MP3 with multiple ID3 versions
    final mp3Bytes = _createMp3WithMultipleId3();
    final audioFile = await Phonic.fromBytesAsync(mp3Bytes, 'sample.mp3');

    print('MP3 format detected');

    // Read tags - should follow precedence: ID3v2.4 > ID3v2.3 > ID3v2.2 > ID3v1
    final titleTag = audioFile.getTag(TagKey.title);
    final artistTag = audioFile.getTag(TagKey.artist);
    final genreTag = audioFile.getTag(TagKey.genre);

    print('Highest precedence tags:');
    print('  Title: ${titleTag?.value} (from ${titleTag?.provenance.containerKind} v${titleTag?.provenance.containerVersion})');
    print('  Artist: ${artistTag?.value} (from ${artistTag?.provenance.containerKind} v${artistTag?.provenance.containerVersion})');

    // Show genre handling across ID3 versions
    if (genreTag != null) {
      final genres = (genreTag as GenreTag).value;
      print('  Genres: ${genres.join(', ')} (from ${genreTag.provenance.containerKind} v${genreTag.provenance.containerVersion})');

      // Demonstrate format-specific encoding
      print('  ID3v2.4 encoding: "${genreTag.toId3v24String()}"');
      print('  ID3v2.3 encoding: "${genreTag.toId3v23String()}"');
    }

    // Get all tags to see values from different containers
    final allTitleTags = audioFile.getTags(TagKey.title);
    print('All title tags found: ${allTitleTags.length}');
    for (final tag in allTitleTags) {
      print('  "${tag.value}" from ${tag.provenance.containerKind} v${tag.provenance.containerVersion}');
    }

    // Modify tags - will be written to ID3v2.4 and ID3v1 (fan-out policy)
    audioFile.setTag(const TitleTag('Updated MP3 Title'));
    audioFile.setTag(GenreTag(const ['Rock', 'Alternative'])); // Multi-genre for ID3v2.4, first genre for ID3v1

    // ID3v1 specific constraints
    audioFile.setTag(const CommentTag('This comment will be truncated to 30 characters in ID3v1'));
    audioFile.setTag(TrackNumberTag(5)); // Will be encoded in ID3v1 comment field

    print('Tags updated with MP3 format-specific handling');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in MP3 format example: $e\n');
  }
}

/// Demonstrates FLAC format with Vorbis Comments.
Future<void> flacFormatExample() async {
  print('2. FLAC Format with Vorbis Comments');
  print('-----------------------------------');

  try {
    final flacBytes = _createFlacWithVorbisComments();
    final audioFile = await Phonic.fromBytesAsync(flacBytes, 'sample.flac');

    print('FLAC format detected');

    // Read Vorbis Comment tags
    final titleTag = audioFile.getTag(TagKey.title);
    final artistTag = audioFile.getTag(TagKey.artist);
    final genreTag = audioFile.getTag(TagKey.genre);

    print('Vorbis Comment tags:');
    print('  Title: ${titleTag?.value}');
    print('  Artist: ${artistTag?.value}');

    // Vorbis Comments natively support multiple values
    if (genreTag != null) {
      final genres = (genreTag as GenreTag).value;
      print('  Genres: ${genres.join(', ')} (native multi-value support)');
    }

    // Set tags - will be written to Vorbis Comments only
    audioFile.setTag(const TitleTag('FLAC Song Title'));
    audioFile.setTag(const ArtistTag('FLAC Artist'));
    audioFile.setTag(const AlbumTag('FLAC Album'));

    // Multiple genres are stored as separate GENRE fields in Vorbis
    audioFile.setTag(GenreTag(const ['Classical', 'Orchestral', 'Symphonic']));

    // FLAC-specific tags
    audioFile.setTag(const CommentTag('Lossless audio with Vorbis Comments'));
    audioFile.setTag(const EncoderTag('FLAC 1.4.0'));

    // Date handling in Vorbis Comments (ISO-8601 format)
    audioFile.setTag(DateRecordedTag('2024-01-15'));

    print('FLAC tags updated');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in FLAC format example: $e\n');
  }
}

/// Demonstrates OGG Vorbis format.
Future<void> oggVorbisFormatExample() async {
  print('3. OGG Vorbis Format');
  print('--------------------');

  try {
    final oggBytes = _createOggVorbis();
    final audioFile = await Phonic.fromBytesAsync(oggBytes, 'sample.ogg');

    print('OGG Vorbis format detected');

    // OGG uses Vorbis Comments like FLAC
    audioFile.setTag(const TitleTag('OGG Vorbis Song'));
    audioFile.setTag(const ArtistTag('OGG Artist'));
    audioFile.setTag(GenreTag(const ['Electronic', 'Ambient']));

    // OGG-specific metadata
    audioFile.setTag(const CommentTag('Compressed with OGG Vorbis'));
    audioFile.setTag(const EncoderTag('libvorbis 1.3.7'));

    // Vorbis Comments support UTF-8 natively
    audioFile.setTag(const ArtistTag('Артист')); // Cyrillic text
    audioFile.setTag(const AlbumTag('专辑')); // Chinese text

    print('OGG Vorbis tags set with UTF-8 support');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in OGG Vorbis format example: $e\n');
  }
}

/// Demonstrates Opus format.
Future<void> opusFormatExample() async {
  print('4. Opus Format');
  print('--------------');

  try {
    final opusBytes = _createOpusFile();
    final audioFile = await Phonic.fromBytesAsync(opusBytes, 'sample.opus');

    print('Opus format detected');

    // Opus uses Vorbis Comments in OGG container
    audioFile.setTag(const TitleTag('Opus Audio Track'));
    audioFile.setTag(const ArtistTag('Opus Artist'));
    audioFile.setTag(GenreTag(const ['Speech', 'Podcast']));

    // Opus-specific metadata
    audioFile.setTag(const CommentTag('High-quality speech codec'));
    audioFile.setTag(const EncoderTag('libopus 1.4'));
    audioFile.setTag(BpmTag(0)); // Not applicable for speech

    print('Opus tags configured');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in Opus format example: $e\n');
  }
}

/// Demonstrates MP4/M4A format with iTunes-style atoms.
Future<void> mp4FormatExample() async {
  print('5. MP4/M4A Format with iTunes Atoms');
  print('-----------------------------------');

  try {
    final mp4Bytes = _createMp4WithAtoms();
    final audioFile = await Phonic.fromBytesAsync(mp4Bytes, 'sample.m4a');

    print('MP4/M4A format detected');

    // Read iTunes-style atoms
    final titleTag = audioFile.getTag(TagKey.title);
    final artistTag = audioFile.getTag(TagKey.artist);

    print('iTunes atom tags:');
    print('  Title: ${titleTag?.value}');
    print('  Artist: ${artistTag?.value}');

    // Set MP4 tags - will be written to ilst atoms
    audioFile.setTag(const TitleTag('M4A Song Title'));
    audioFile.setTag(const ArtistTag('M4A Artist'));
    audioFile.setTag(const AlbumTag('M4A Album'));

    // MP4 genre handling (semicolon-separated)
    final genreTag = GenreTag(const ['Pop', 'Dance']);
    audioFile.setTag(genreTag);
    print('MP4 genre encoding: "${genreTag.toEncodedString(';')}"');

    // MP4-specific atoms
    audioFile.setTag(TrackNumberTag(3));
    audioFile.setTag(DiscNumberTag(1));
    audioFile.setTag(YearTag(2024));

    // iTunes-style rating (0-100 scale)
    audioFile.setTag(RatingTag(90));

    // Custom freeform atoms (----:domain:name format)
    audioFile.setTag(const CustomTag('Custom MP4 metadata'));

    print('MP4 atoms updated');

    audioFile.dispose();
    print('');
  } catch (e) {
    print('Error in MP4 format example: $e\n');
  }
}

/// Demonstrates format detection and capability checking.
Future<void> formatDetectionExample() async {
  print('6. Format Detection and Capabilities');
  print('-----------------------------------');

  final testFiles = [
    ('test.mp3', _createMp3WithMultipleId3()),
    ('test.flac', _createFlacWithVorbisComments()),
    ('test.ogg', _createOggVorbis()),
    ('test.opus', _createOpusFile()),
    ('test.m4a', _createMp4WithAtoms()),
  ];

  for (final (filename, bytes) in testFiles) {
    try {
      final audioFile = await Phonic.fromBytesAsync(bytes, filename);

      // Format detection happens automatically
      print('File: $filename');

      // Check what tags are supported by examining existing tags
      final allTags = audioFile.getAllTags();
      final supportedKeys = allTags.map((tag) => tag.key).toSet();

      print('  Detected format capabilities:');
      print('  Supported tag types: ${supportedKeys.length}');

      // Test format-specific features
      if (filename.endsWith('.mp3')) {
        print('  MP3 features: Multiple ID3 versions, precedence rules');
      } else if (filename.endsWith('.flac') || filename.endsWith('.ogg') || filename.endsWith('.opus')) {
        print('  Vorbis features: Native multi-value support, UTF-8 encoding');
      } else if (filename.endsWith('.m4a')) {
        print('  MP4 features: iTunes atoms, freeform atoms');
      }

      audioFile.dispose();
    } catch (e) {
      print('  Error detecting format for $filename: $e');
    }
  }
  print('');
}

/// Demonstrates cross-format compatibility and conversion scenarios.
Future<void> crossFormatCompatibilityExample() async {
  print('7. Cross-Format Compatibility');
  print('-----------------------------');

  try {
    // Start with MP3 file
    final mp3Bytes = _createMp3WithMultipleId3();
    final mp3File = await Phonic.fromBytesAsync(mp3Bytes, 'source.mp3');

    // Read metadata from MP3
    final title = mp3File.getTag(TagKey.title);
    final artist = mp3File.getTag(TagKey.artist);
    final genres = mp3File.getTag(TagKey.genre) as GenreTag?;

    print('Source MP3 metadata:');
    print('  Title: ${title?.value}');
    print('  Artist: ${artist?.value}');
    print('  Genres: ${genres?.value.join(', ')}');

    // Create FLAC file and transfer metadata
    final flacBytes = _createFlacWithVorbisComments();
    final flacFile = await Phonic.fromBytesAsync(flacBytes, 'target.flac');

    // Transfer tags (format conversion handled automatically)
    if (title != null) flacFile.setTag(TitleTag(title.value));
    if (artist != null) flacFile.setTag(ArtistTag(artist.value));
    if (genres != null) flacFile.setTag(GenreTag(genres.value));

    // Add format-specific enhancements
    flacFile.setTag(const CommentTag('Converted from MP3 to FLAC'));
    flacFile.setTag(const EncoderTag('Phonic Library'));

    print('Metadata transferred to FLAC format');

    // Demonstrate constraint handling
    print('Format constraint examples:');

    // ID3v1 has 30-character limit for text fields
    final longTitle = 'This is a very long song title that exceeds ID3v1 limits';
    print('  Long title: "$longTitle" (${longTitle.length} chars)');
    print('  ID3v1 would truncate to: "${longTitle.substring(0, 30)}"');

    // Rating scale differences
    final rating = RatingTag(75); // 0-100 scale (unified)
    print('  Unified rating: ${rating.value}/100');
    print('  ID3v2 POPM would encode as: ${(rating.value * 255 / 100).round()}/255');
    print('  MP4 would encode as: ${rating.value}/100');

    // Genre encoding differences
    final multiGenre = GenreTag(const ['Rock', 'Alternative', 'Indie']);
    print('  Multi-genre encoding:');
    print('    ID3v2.4: "${multiGenre.toId3v24String()}"');
    print('    ID3v2.3: "${multiGenre.toId3v23String()}"');
    print('    MP4: "${multiGenre.toEncodedString(';')}"');
    print('    Vorbis: Multiple GENRE fields (one per genre)');

    mp3File.dispose();
    flacFile.dispose();
    print('');
  } catch (e) {
    print('Error in cross-format compatibility: $e\n');
  }
}

// Sample file creation methods for different formats

Uint8List _createMp3WithMultipleId3() {
  // ID3v2.4 header
  final id3v24Header = [
    0x49, 0x44, 0x33, // "ID3"
    0x04, 0x00, // Version 2.4.0
    0x00, // Flags
    0x00, 0x00, 0x00, 0x3F, // Size
  ];

  // ID3v2.4 TIT2 frame
  final id3v24Title = [
    0x54, 0x49, 0x54, 0x32, // "TIT2"
    0x00, 0x00, 0x00, 0x15, // Size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('ID3v2.4 Title'.codeUnits),
  ];

  // ID3v2.4 TCON frame with null-terminated genres
  final id3v24Genre = [
    0x54, 0x43, 0x4F, 0x4E, // "TCON"
    0x00, 0x00, 0x00, 0x18, // Size
    0x00, 0x00, // Flags
    0x03, // UTF-8 encoding
    ...('Rock\x00Alternative\x00Indie'.codeUnits),
  ];

  // MP3 audio data
  final audioData = [
    0xFF, 0xFB, 0x90, 0x00, // MP3 frame header
    ...List.filled(1000, 0x00), // Audio data
  ];

  // ID3v1 tag at the end
  final id3v1Tag = [
    ...('TAG'.codeUnits), // Signature
    ...('ID3v1 Title'.padRight(30, '\x00').codeUnits.take(30)), // Title
    ...('ID3v1 Artist'.padRight(30, '\x00').codeUnits.take(30)), // Artist
    ...('ID3v1 Album'.padRight(30, '\x00').codeUnits.take(30)), // Album
    ...('2024'.codeUnits), // Year
    ...('ID3v1 Comment'.padRight(28, '\x00').codeUnits.take(28)), // Comment
    0x00, // Zero byte
    0x05, // Track number
    0x11, // Genre (Rock)
  ];

  return Uint8List.fromList([
    ...id3v24Header,
    ...id3v24Title,
    ...id3v24Genre,
    ...audioData,
    ...id3v1Tag,
  ]);
}

Uint8List _createFlacWithVorbisComments() {
  // FLAC signature
  final flacSignature = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"

  // STREAMINFO block
  final streamInfo = [
    0x00, // Last metadata block flag + block type (STREAMINFO)
    0x00, 0x00, 0x22, // Block length (34 bytes)
    ...List.filled(34, 0x00), // STREAMINFO data
  ];

  // Vorbis Comment block
  final vorbisComments = [
    0x84, // Last metadata block flag + block type (VORBIS_COMMENT)
    0x00, 0x00, 0x40, // Block length
    0x08, 0x00, 0x00, 0x00, // Vendor length
    ...('libFLAC'.codeUnits), // Vendor string
    0x03, 0x00, 0x00, 0x00, // User comment list length
    0x0B, 0x00, 0x00, 0x00, // Comment 1 length
    ...('TITLE=FLAC'.codeUnits),
    0x0D, 0x00, 0x00, 0x00, // Comment 2 length
    ...('ARTIST=Artist'.codeUnits),
    0x0F, 0x00, 0x00, 0x00, // Comment 3 length
    ...('GENRE=Classical'.codeUnits),
  ];

  return Uint8List.fromList([...flacSignature, ...streamInfo, ...vorbisComments]);
}

Uint8List _createOggVorbis() {
  // OGG page header
  final oggHeader = [
    0x4F, 0x67, 0x67, 0x53, // "OggS"
    0x00, // Version
    0x02, // Header type (first page of logical bitstream)
    ...List.filled(22, 0x00), // Granule position, serial, page sequence, checksum, etc.
  ];

  return Uint8List.fromList(oggHeader);
}

Uint8List _createOpusFile() {
  // OGG page with Opus identification header
  final opusHeader = [
    0x4F, 0x67, 0x67, 0x53, // "OggS"
    0x00, // Version
    0x02, // Header type
    ...List.filled(22, 0x00), // OGG page fields
    0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
    ...List.filled(11, 0x00), // Opus header data
  ];

  return Uint8List.fromList(opusHeader);
}

Uint8List _createMp4WithAtoms() {
  // ftyp box
  final ftypBox = [
    0x00, 0x00, 0x00, 0x20, // Box size
    0x66, 0x74, 0x79, 0x70, // "ftyp"
    0x4D, 0x34, 0x41, 0x20, // "M4A "
    0x00, 0x00, 0x00, 0x00, // Minor version
    0x4D, 0x34, 0x41, 0x20, // Compatible brands
    0x6D, 0x70, 0x34, 0x32,
    0x69, 0x73, 0x6F, 0x6D,
  ];

  // moov box with minimal ilst
  final moovBox = [
    0x00, 0x00, 0x00, 0x40, // Box size
    0x6D, 0x6F, 0x6F, 0x76, // "moov"
    // udta box
    0x00, 0x00, 0x00, 0x38, // Box size
    0x75, 0x64, 0x74, 0x61, // "udta"
    // meta box
    0x00, 0x00, 0x00, 0x30, // Box size
    0x6D, 0x65, 0x74, 0x61, // "meta"
    0x00, 0x00, 0x00, 0x00, // Version/flags
    // ilst box
    0x00, 0x00, 0x00, 0x24, // Box size
    0x69, 0x6C, 0x73, 0x74, // "ilst"
    // ©nam atom (title)
    0x00, 0x00, 0x00, 0x1C, // Atom size
    0xA9, 0x6E, 0x61, 0x6D, // "©nam"
    0x00, 0x00, 0x00, 0x14, // Data size
    0x64, 0x61, 0x74, 0x61, // "data"
    0x00, 0x00, 0x00, 0x01, // Type/flags
    0x00, 0x00, 0x00, 0x00, // Reserved
    ...('MP4 Title'.codeUnits), // Title data
  ];

  return Uint8List.fromList([...ftypBox, ...moovBox]);
}
