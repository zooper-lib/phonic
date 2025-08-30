/// ID3 format support for MP3 files.
///
/// This module provides support for reading and writing ID3v1, ID3v2.2, ID3v2.3, and ID3v2.4 tags
/// commonly found in MP3 files.
library phonic.formats.id3;

export 'id3v22_codec.dart';
export 'id3v23_codec.dart';
export 'id3v24_codec.dart';
export 'id3v2_apic_frame_parser.dart';
export 'id3v2_comm_frame_parser.dart';
export 'id3v2_frame_map.dart';
export 'id3v2_frame_parser.dart';
export 'id3v2_popm_frame_parser.dart';
export 'mp3_format_strategy.dart';
