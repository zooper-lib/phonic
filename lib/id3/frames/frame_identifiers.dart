import 'package:phonic/id3/enums/frame_name.dart';
import 'package:phonic/id3/frames/frame_identifier.dart';
import 'package:phonic/id3/frames/frame_type.dart';

final List<FrameIdentifier> frameIdentifiers = [
  // A
  FrameIdentifier(FrameName.encryption, 0, 0, 'CRA', 'AENC', 'AENC', FrameType.other),
  FrameIdentifier(FrameName.picture, 0, 0, 'PIC', 'APIC', 'APIC', FrameType.custom),
  FrameIdentifier(FrameName.audioSeekPointIndex, 0, 0, null, null, 'ASPI', FrameType.other),

  // C
  FrameIdentifier(FrameName.comment, 30, 30, 'COM', 'COMM', 'COMM', FrameType.custom),
  FrameIdentifier(FrameName.commercial, 0, 0, null, 'COMR', 'COMR', FrameType.other),
  FrameIdentifier(FrameName.encryptedMetaFrame, 0, 0, 'CRM', null, null, FrameType.other),

  // E
  FrameIdentifier(FrameName.encryptionMethodRegistration, 0, 0, null, 'ENCR', 'ENCR', FrameType.other),
  FrameIdentifier(FrameName.equalization, 0, 0, 'EQU', 'EQUA', null, FrameType.other),
  FrameIdentifier(FrameName.equalization2, 0, 0, null, null, 'EQUA2', FrameType.other),
  FrameIdentifier(FrameName.eventTimingCodes, 0, 0, 'ETC', 'ETCO', 'ETCO', FrameType.other),

  // G
  FrameIdentifier(FrameName.GEOB, 0, 0, 'GEO', 'GEOB', 'GEOB', FrameType.other),
  FrameIdentifier(FrameName.GRID, 0, 0, null, 'GRID', 'GRID', FrameType.other),

  // I
  FrameIdentifier(FrameName.people, 0, 0, 'IPL', 'IPLS', null, FrameType.other),

  // L
  FrameIdentifier(FrameName.information, 0, 0, 'LNK', 'LINK', 'LINK', FrameType.other),

  // M
  FrameIdentifier(FrameName.MCDI, 0, 0, 'MCI', 'MCDI', 'MCDI', FrameType.other),
  FrameIdentifier(FrameName.MLLT, 0, 0, 'MLL', 'MLLT', 'MLLT', FrameType.other),

  // O
  FrameIdentifier(FrameName.owne, 0, 0, null, 'OWNE', 'OWNE', FrameType.other),

  // P
  FrameIdentifier(FrameName.private, 0, 0, null, 'PRIV', 'PRIV', FrameType.other),
  FrameIdentifier(FrameName.playCounter, 0, 0, 'CNT', 'PCNT', 'PCNT', FrameType.other),
  FrameIdentifier(FrameName.popularimeter, 0, 0, 'POP', 'POPM', 'POPM', FrameType.other),
  FrameIdentifier(FrameName.positionSynchronization, 0, 0, null, 'POSS', 'POSS', FrameType.other),

  // R
  FrameIdentifier(FrameName.recommendedBufferSize, 0, 0, 'BUF', 'RBUF', 'RBUF', FrameType.other),
  FrameIdentifier(FrameName.relativeVolumeAdjustment, 0, 0, 'RVA', 'RVAD', null, FrameType.other),
  FrameIdentifier(FrameName.relativeVolumeAdjustment2, 0, 0, null, null, 'RVA2', FrameType.other),
  FrameIdentifier(FrameName.reverb, 0, 0, 'REV', 'RVRB', 'RVRB', FrameType.other),
  //

  // S
  FrameIdentifier(FrameName.seek, 0, 0, null, null, 'SEEK', FrameType.other),
  FrameIdentifier(FrameName.signature, 0, 0, null, null, 'SIGN', FrameType.other),
  FrameIdentifier(FrameName.synchronizedLyrics, 0, 0, 'SLT', 'SYLT', 'SYLT', FrameType.other),
  FrameIdentifier(FrameName.synchronizedTempoCodes, 0, 0, 'STC', 'SYTC', 'SYTC', FrameType.other),

  // T
  FrameIdentifier(FrameName.album, 30, 30, 'TAL', 'TALB', 'TALB', FrameType.text),
  FrameIdentifier(FrameName.bpm, 0, 0, 'TBP', 'TBPM', 'TBPM', FrameType.text),
  FrameIdentifier(FrameName.composer, 0, 0, 'TCM', 'TCOM', 'TCOM', FrameType.text),
  FrameIdentifier(FrameName.contentType, 1, 1, 'TCO', 'TCON', 'TCON', FrameType.text),
  FrameIdentifier(FrameName.copyright, 0, 0, 'TCR', 'TCOP', 'TCOP', FrameType.text),
  FrameIdentifier(FrameName.encodingTime, 0, 0, null, null, 'TDEN', FrameType.text),
  FrameIdentifier(FrameName.playlistDelay, 0, 0, 'TDY', 'TDLY', 'TDLY', FrameType.text),
  FrameIdentifier(FrameName.originalReleaseTime, 0, 0, null, null, 'TDOR', FrameType.text),
  FrameIdentifier(FrameName.recordingTime, 0, 0, null, null, 'TDRC', FrameType.text),
  FrameIdentifier(FrameName.releaseTime, 0, 0, null, null, 'TDRL', FrameType.text),
  FrameIdentifier(FrameName.taggingTime, 0, 0, null, null, 'TDTG', FrameType.text),
  FrameIdentifier(FrameName.encodedBy, 0, 0, 'TEN', 'TENC', 'TENC', FrameType.text),
  FrameIdentifier(FrameName.lyricist, 0, 0, 'TXT', 'TEXT', 'TEXT', FrameType.text),
  FrameIdentifier(FrameName.fileType, 0, 0, 'TFT', 'TFLT', 'TFLT', FrameType.text),
  FrameIdentifier(FrameName.involvedPeople, 0, 0, null, null, 'TIPL', FrameType.text),
  FrameIdentifier(FrameName.contentGroupDescription, 0, 0, 'TT1', 'TIT1', 'TIT1', FrameType.text),
  FrameIdentifier(FrameName.title, 30, 30, 'TT2', 'TIT2', 'TIT2', FrameType.text),
  FrameIdentifier(FrameName.subTitle, 0, 0, 'TT3', 'TIT3', 'TIT3', FrameType.text),
  FrameIdentifier(FrameName.initialKey, 0, 0, 'TKE', 'TKEY', 'TKEY', FrameType.text),
  FrameIdentifier(FrameName.language, 0, 0, 'TLA', 'TLAN', 'TLAN', FrameType.text),
  FrameIdentifier(FrameName.length, 0, 0, 'TLE', 'TLEN', 'TLEN', FrameType.text),
  FrameIdentifier(FrameName.musicianCredits, 0, 0, null, null, 'TMCL', FrameType.text),
  FrameIdentifier(FrameName.mediaType, 0, 0, 'TMT', 'TMED', 'TMED', FrameType.text),
  FrameIdentifier(FrameName.mood, 0, 0, null, null, 'TMOO', FrameType.text),
  FrameIdentifier(FrameName.originalAlbum, 0, 0, 'TOT', 'TOAL', 'TOAL', FrameType.text),
  FrameIdentifier(FrameName.originalFilename, 0, 0, 'TOF', 'TOFN', 'TOFN', FrameType.text),
  FrameIdentifier(FrameName.originalLyricist, 0, 0, 'TOL', 'TOLY', 'TOLY', FrameType.text),
  FrameIdentifier(FrameName.originalPerformer, 0, 0, 'TOA', 'TOPE', 'TOPE', FrameType.text),
  FrameIdentifier(FrameName.owner, 0, 0, null, 'TOWN', 'TOWN', FrameType.text),
  FrameIdentifier(FrameName.artist, 30, 30, 'TP1', 'TPE1', 'TPE1', FrameType.text),
  FrameIdentifier(FrameName.accompaniment, 0, 0, 'TP2', 'TPE2', 'TPE2', FrameType.text),
  FrameIdentifier(FrameName.conductor, 0, 0, 'TP3', 'TPE3', 'TPE3', FrameType.text),
  FrameIdentifier(FrameName.modifiedBy, 0, 0, 'TP4', 'TPE4', 'TPE4', FrameType.text),
  FrameIdentifier(FrameName.partOfSet, 0, 0, 'TPA', 'TPOS', 'TPOS', FrameType.text),
  FrameIdentifier(FrameName.producedNotice, 0, 0, null, null, 'TPRO', FrameType.text),
  FrameIdentifier(FrameName.publisher, 0, 0, 'TPB', 'TPUB', 'TPUB', FrameType.text),
  FrameIdentifier(FrameName.track, 0, 0, 'TRK', 'TRCK', 'TRCK', FrameType.text),
  FrameIdentifier(FrameName.radioStation, 0, 0, null, 'TRSN', 'TRSN', FrameType.text),
  FrameIdentifier(FrameName.radioStationOwner, 0, 0, null, 'TRSO', 'TRSO', FrameType.text),
  FrameIdentifier(FrameName.albumSortOrder, 0, 0, null, null, 'TSOA', FrameType.text),
  FrameIdentifier(FrameName.performerSortOrder, 0, 0, null, null, 'TSOP', FrameType.text),
  FrameIdentifier(FrameName.titleSortOrder, 0, 0, null, null, 'TSOT', FrameType.text),
  FrameIdentifier(FrameName.isrc, 0, 0, 'TRC', 'TSRC', 'TSRC', FrameType.text),
  FrameIdentifier(FrameName.encodingSettings, 0, 0, 'TSS', 'TSSE', 'TSSE', FrameType.text),
  FrameIdentifier(FrameName.setSubtitle, 0, 0, null, null, 'TSST', FrameType.text),
  FrameIdentifier(FrameName.additionalInfo, 0, 0, 'TXX', 'TXXX', 'TXXX', FrameType.custom),
  FrameIdentifier(FrameName.date, 0, 0, 'TDA', 'TDAT', null, FrameType.text),
  FrameIdentifier(FrameName.time, 0, 0, 'TIM', 'TIME', null, FrameType.text),
  FrameIdentifier(FrameName.originalReleaseYear, 0, 0, null, 'TORY', null, FrameType.text),
  FrameIdentifier(FrameName.recordingDates, 0, 0, 'TRD', 'TRDA', null, FrameType.text),
  FrameIdentifier(FrameName.size, 0, 0, 'TSI', 'TSIZ', null, FrameType.text),
  FrameIdentifier(FrameName.year, 4, 4, 'TYE', 'TYER', null, FrameType.text),

  // U
  FrameIdentifier(FrameName.id, 0, 0, 'UFI', 'UFID', 'UFID', FrameType.other),
  FrameIdentifier(FrameName.termsofUse, 0, 0, null, 'USER', 'USER', FrameType.other),
  FrameIdentifier(FrameName.unsyncTranscript, 0, 0, 'ULT', 'USLT', 'USLT', FrameType.other),

  // W
  FrameIdentifier(FrameName.commercialInfo, 0, 0, 'WCM', 'WCOM', 'WCOM', FrameType.url),
  FrameIdentifier(FrameName.copyrightInfo, 0, 0, 'WCP', 'WCOP', 'WCOP', FrameType.url),
  FrameIdentifier(FrameName.oFileWebpage, 0, 0, 'WAF', 'WOAF', 'WOAF', FrameType.url),
  FrameIdentifier(FrameName.oArtistWebpage, 0, 0, 'WAR', 'WOAR', 'WOAR', FrameType.url),
  FrameIdentifier(FrameName.oAudioWebpage, 0, 0, 'WAS', 'WOAS', 'WOAS', FrameType.url),
  FrameIdentifier(FrameName.oRadioWebpage, 0, 0, null, 'WORS', 'WORS', FrameType.url),
  FrameIdentifier(FrameName.payment, 0, 0, null, 'WPAY', 'WPAY', FrameType.url),
  FrameIdentifier(FrameName.oPublisherWebpage, 0, 0, 'WPB', 'WPUB', 'WPUB', FrameType.url),
  FrameIdentifier(FrameName.cLink, 0, 0, 'WXX', 'WXXX', 'WXXX', FrameType.custom),
];
