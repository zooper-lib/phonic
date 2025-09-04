import 'package:phonic/src/core/tag_key.dart';
import 'package:phonic/src/formats/mp4/mp4_atom_map.dart';
import 'package:test/test.dart';

void main() {
  group('Mp4AtomMap', () {
    group('Standard Atoms', () {
      test('should map all standard tag keys to correct atom identifiers', () {
        expect(Mp4AtomMap.atoms[TagKey.title], equals('©nam'));
        expect(Mp4AtomMap.atoms[TagKey.artist], equals('©ART'));
        expect(Mp4AtomMap.atoms[TagKey.album], equals('©alb'));
        expect(Mp4AtomMap.atoms[TagKey.albumArtist], equals('aART'));
        expect(Mp4AtomMap.atoms[TagKey.trackNumber], equals('trkn'));
        expect(Mp4AtomMap.atoms[TagKey.discNumber], equals('disk'));
        expect(Mp4AtomMap.atoms[TagKey.dateRecorded], equals('©day'));
        expect(Mp4AtomMap.atoms[TagKey.genre], equals('©gen'));
        expect(Mp4AtomMap.atoms[TagKey.comment], equals('©cmt'));
        expect(Mp4AtomMap.atoms[TagKey.bpm], equals('tmpo'));
        expect(Mp4AtomMap.atoms[TagKey.lyrics], equals('©lyr'));
        expect(Mp4AtomMap.atoms[TagKey.artwork], equals('covr'));
        expect(Mp4AtomMap.atoms[TagKey.grouping], equals('©grp'));
        expect(Mp4AtomMap.atoms[TagKey.composer], equals('©wrt'));
        expect(Mp4AtomMap.atoms[TagKey.encoder], equals('©too'));
      });

      test('should not include freeform-only fields in standard atoms', () {
        expect(Mp4AtomMap.atoms.containsKey(TagKey.musicalKey), isFalse);
        expect(Mp4AtomMap.atoms.containsKey(TagKey.rating), isFalse);
        expect(Mp4AtomMap.atoms.containsKey(TagKey.isrc), isFalse);
        expect(Mp4AtomMap.atoms.containsKey(TagKey.custom), isFalse);
      });

      test('should not include year as separate atom (derived from dateRecorded)', () {
        expect(Mp4AtomMap.atoms.containsKey(TagKey.year), isFalse);
      });
    });

    group('Freeform Atoms', () {
      test('should map freeform tag keys to correct atom names', () {
        expect(Mp4AtomMap.freeformAtoms[TagKey.musicalKey], equals('MUSICAL_KEY'));
        expect(Mp4AtomMap.freeformAtoms[TagKey.rating], equals('RATING'));
        expect(Mp4AtomMap.freeformAtoms[TagKey.isrc], equals('ISRC'));
        expect(Mp4AtomMap.freeformAtoms[TagKey.custom], equals('CUSTOM'));
      });

      test('should not include standard atom fields in freeform atoms', () {
        expect(Mp4AtomMap.freeformAtoms.containsKey(TagKey.title), isFalse);
        expect(Mp4AtomMap.freeformAtoms.containsKey(TagKey.artist), isFalse);
        expect(Mp4AtomMap.freeformAtoms.containsKey(TagKey.album), isFalse);
      });

      test('should have consistent freeform domain', () {
        expect(Mp4AtomMap.freeformDomain, equals('com.phonic.tags'));
        expect(Mp4AtomMap.freeformDomain, isNotEmpty);
      });
    });

    group('Alternative Atoms', () {
      test('should recognize standard atoms in alternative map', () {
        expect(Mp4AtomMap.alternativeAtoms['©nam'], equals(TagKey.title));
        expect(Mp4AtomMap.alternativeAtoms['©ART'], equals(TagKey.artist));
        expect(Mp4AtomMap.alternativeAtoms['©alb'], equals(TagKey.album));
        expect(Mp4AtomMap.alternativeAtoms['aART'], equals(TagKey.albumArtist));
      });

      test('should recognize uppercase legacy atoms', () {
        expect(Mp4AtomMap.alternativeAtoms['TRKN'], equals(TagKey.trackNumber));
        expect(Mp4AtomMap.alternativeAtoms['DISK'], equals(TagKey.discNumber));
        expect(Mp4AtomMap.alternativeAtoms['TMPO'], equals(TagKey.bpm));
        expect(Mp4AtomMap.alternativeAtoms['COVR'], equals(TagKey.artwork));
      });

      test('should handle QuickTime legacy atoms', () {
        expect(Mp4AtomMap.alternativeAtoms['©nam'], equals(TagKey.title));
        expect(Mp4AtomMap.alternativeAtoms['©day'], equals(TagKey.dateRecorded));
        expect(Mp4AtomMap.alternativeAtoms['©gen'], equals(TagKey.genre));
      });
    });

    group('getSupportedTags', () {
      test('should return all standard atom tag keys', () {
        final supportedTags = Mp4AtomMap.getSupportedTags();

        expect(supportedTags.contains(TagKey.title), isTrue);
        expect(supportedTags.contains(TagKey.artist), isTrue);
        expect(supportedTags.contains(TagKey.album), isTrue);
        expect(supportedTags.contains(TagKey.albumArtist), isTrue);
        expect(supportedTags.contains(TagKey.trackNumber), isTrue);
        expect(supportedTags.contains(TagKey.discNumber), isTrue);
        expect(supportedTags.contains(TagKey.dateRecorded), isTrue);
        expect(supportedTags.contains(TagKey.genre), isTrue);
        expect(supportedTags.contains(TagKey.comment), isTrue);
        expect(supportedTags.contains(TagKey.bpm), isTrue);
        expect(supportedTags.contains(TagKey.lyrics), isTrue);
        expect(supportedTags.contains(TagKey.artwork), isTrue);
        expect(supportedTags.contains(TagKey.grouping), isTrue);
        expect(supportedTags.contains(TagKey.composer), isTrue);
        expect(supportedTags.contains(TagKey.encoder), isTrue);
      });

      test('should not include freeform-only tags', () {
        final supportedTags = Mp4AtomMap.getSupportedTags();

        expect(supportedTags.contains(TagKey.musicalKey), isFalse);
        expect(supportedTags.contains(TagKey.rating), isFalse);
        expect(supportedTags.contains(TagKey.isrc), isFalse);
        expect(supportedTags.contains(TagKey.custom), isFalse);
      });

      test('should not include derived tags', () {
        final supportedTags = Mp4AtomMap.getSupportedTags();
        expect(supportedTags.contains(TagKey.year), isFalse);
      });
    });

    group('getAllSupportedTags', () {
      test('should return both standard and freeform tag keys', () {
        final allTags = Mp4AtomMap.getAllSupportedTags();

        // Standard tags
        expect(allTags.contains(TagKey.title), isTrue);
        expect(allTags.contains(TagKey.artist), isTrue);
        expect(allTags.contains(TagKey.artwork), isTrue);

        // Freeform tags
        expect(allTags.contains(TagKey.musicalKey), isTrue);
        expect(allTags.contains(TagKey.rating), isTrue);
        expect(allTags.contains(TagKey.isrc), isTrue);
        expect(allTags.contains(TagKey.custom), isTrue);
      });

      test('should be superset of getSupportedTags', () {
        final standardTags = Mp4AtomMap.getSupportedTags();
        final allTags = Mp4AtomMap.getAllSupportedTags();

        expect(allTags.containsAll(standardTags), isTrue);
        expect(allTags.length, greaterThan(standardTags.length));
      });
    });

    group('getAtomId', () {
      test('should return correct atom IDs for standard tags', () {
        expect(Mp4AtomMap.getAtomId(TagKey.title), equals('©nam'));
        expect(Mp4AtomMap.getAtomId(TagKey.artist), equals('©ART'));
        expect(Mp4AtomMap.getAtomId(TagKey.trackNumber), equals('trkn'));
        expect(Mp4AtomMap.getAtomId(TagKey.artwork), equals('covr'));
      });

      test('should return null for freeform-only tags', () {
        expect(Mp4AtomMap.getAtomId(TagKey.musicalKey), isNull);
        expect(Mp4AtomMap.getAtomId(TagKey.rating), isNull);
        expect(Mp4AtomMap.getAtomId(TagKey.isrc), isNull);
        expect(Mp4AtomMap.getAtomId(TagKey.custom), isNull);
      });

      test('should return null for derived tags', () {
        expect(Mp4AtomMap.getAtomId(TagKey.year), isNull);
      });
    });

    group('getFreeformAtomName', () {
      test('should return correct names for freeform tags', () {
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.musicalKey), equals('MUSICAL_KEY'));
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.rating), equals('RATING'));
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.isrc), equals('ISRC'));
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.custom), equals('CUSTOM'));
      });

      test('should return null for standard atom tags', () {
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.title), isNull);
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.artist), isNull);
        expect(Mp4AtomMap.getFreeformAtomName(TagKey.artwork), isNull);
      });
    });

    group('getTagKey', () {
      test('should return correct tag keys for standard atoms', () {
        expect(Mp4AtomMap.getTagKey('©nam'), equals(TagKey.title));
        expect(Mp4AtomMap.getTagKey('©ART'), equals(TagKey.artist));
        expect(Mp4AtomMap.getTagKey('©alb'), equals(TagKey.album));
        expect(Mp4AtomMap.getTagKey('trkn'), equals(TagKey.trackNumber));
        expect(Mp4AtomMap.getTagKey('covr'), equals(TagKey.artwork));
      });

      test('should return correct tag keys for alternative atoms', () {
        expect(Mp4AtomMap.getTagKey('TRKN'), equals(TagKey.trackNumber));
        expect(Mp4AtomMap.getTagKey('DISK'), equals(TagKey.discNumber));
        expect(Mp4AtomMap.getTagKey('TMPO'), equals(TagKey.bpm));
        expect(Mp4AtomMap.getTagKey('COVR'), equals(TagKey.artwork));
      });

      test('should return null for unknown atoms', () {
        expect(Mp4AtomMap.getTagKey('XXXX'), isNull);
        expect(Mp4AtomMap.getTagKey('unknown'), isNull);
        expect(Mp4AtomMap.getTagKey(''), isNull);
      });

      test('should handle case sensitivity correctly', () {
        expect(Mp4AtomMap.getTagKey('©nam'), equals(TagKey.title));
        expect(Mp4AtomMap.getTagKey('©NAM'), equals(TagKey.title)); // Now supported as alternative
      });
    });

    group('getTagKeyFromFreeform', () {
      test('should return correct tag keys for freeform names', () {
        expect(Mp4AtomMap.getTagKeyFromFreeform('MUSICAL_KEY'), equals(TagKey.musicalKey));
        expect(Mp4AtomMap.getTagKeyFromFreeform('RATING'), equals(TagKey.rating));
        expect(Mp4AtomMap.getTagKeyFromFreeform('ISRC'), equals(TagKey.isrc));
        expect(Mp4AtomMap.getTagKeyFromFreeform('CUSTOM'), equals(TagKey.custom));
      });

      test('should return null for unknown freeform names', () {
        expect(Mp4AtomMap.getTagKeyFromFreeform('UNKNOWN_FIELD'), isNull);
        expect(Mp4AtomMap.getTagKeyFromFreeform(''), isNull);
      });

      test('should return null for standard atom names', () {
        expect(Mp4AtomMap.getTagKeyFromFreeform('©nam'), isNull);
        expect(Mp4AtomMap.getTagKeyFromFreeform('trkn'), isNull);
      });
    });

    group('isStandardAtom', () {
      test('should return true for standard atoms', () {
        expect(Mp4AtomMap.isStandardAtom('©nam'), isTrue);
        expect(Mp4AtomMap.isStandardAtom('©ART'), isTrue);
        expect(Mp4AtomMap.isStandardAtom('trkn'), isTrue);
        expect(Mp4AtomMap.isStandardAtom('covr'), isTrue);
      });

      test('should return true for alternative atoms', () {
        expect(Mp4AtomMap.isStandardAtom('TRKN'), isTrue);
        expect(Mp4AtomMap.isStandardAtom('DISK'), isTrue);
        expect(Mp4AtomMap.isStandardAtom('COVR'), isTrue);
      });

      test('should return false for freeform atoms', () {
        expect(Mp4AtomMap.isStandardAtom('----:com.example:FIELD'), isFalse);
        expect(Mp4AtomMap.isStandardAtom('----'), isFalse);
      });

      test('should return false for unknown atoms', () {
        expect(Mp4AtomMap.isStandardAtom('XXXX'), isFalse);
        expect(Mp4AtomMap.isStandardAtom('unknown'), isFalse);
      });
    });

    group('isFreeformAtom', () {
      test('should return true for freeform atom format', () {
        expect(Mp4AtomMap.isFreeformAtom('----:com.example:FIELD'), isTrue);
        expect(Mp4AtomMap.isFreeformAtom('----:com.phonic.tags:RATING'), isTrue);
        expect(Mp4AtomMap.isFreeformAtom('----:domain:name'), isTrue);
      });

      test('should return false for standard atoms', () {
        expect(Mp4AtomMap.isFreeformAtom('©nam'), isFalse);
        expect(Mp4AtomMap.isFreeformAtom('trkn'), isFalse);
        expect(Mp4AtomMap.isFreeformAtom('covr'), isFalse);
      });

      test('should return false for malformed freeform atoms', () {
        expect(Mp4AtomMap.isFreeformAtom('----'), isFalse); // Missing colon
        expect(Mp4AtomMap.isFreeformAtom('----:domain'), isTrue); // Has colon, so it's freeform format
        expect(Mp4AtomMap.isFreeformAtom('domain:name'), isFalse);
      });
    });

    group('parseFreeformAtom', () {
      test('should parse valid freeform atoms correctly', () {
        final result1 = Mp4AtomMap.parseFreeformAtom('----:com.example:FIELD');
        expect(result1?.domain, equals('com.example'));
        expect(result1?.name, equals('FIELD'));

        final result2 = Mp4AtomMap.parseFreeformAtom('----:com.phonic.tags:RATING');
        expect(result2?.domain, equals('com.phonic.tags'));
        expect(result2?.name, equals('RATING'));
      });

      test('should handle complex domain and name values', () {
        final result = Mp4AtomMap.parseFreeformAtom('----:org.musicbrainz.tags:MUSICBRAINZ_TRACKID');
        expect(result?.domain, equals('org.musicbrainz.tags'));
        expect(result?.name, equals('MUSICBRAINZ_TRACKID'));
      });

      test('should return null for invalid freeform atoms', () {
        expect(Mp4AtomMap.parseFreeformAtom('©nam'), isNull);
        expect(Mp4AtomMap.parseFreeformAtom('----'), isNull);
        expect(Mp4AtomMap.parseFreeformAtom('----:domain'), isNull);
        expect(Mp4AtomMap.parseFreeformAtom('domain:name'), isNull);
        expect(Mp4AtomMap.parseFreeformAtom(''), isNull);
      });

      test('should return null for malformed freeform format', () {
        expect(Mp4AtomMap.parseFreeformAtom('----:domain:name:extra'), isNull);
        expect(Mp4AtomMap.parseFreeformAtom('XXXX:domain:name'), isNull);
      });
    });

    group('buildFreeformAtom', () {
      test('should construct valid freeform atom identifiers', () {
        final atom1 = Mp4AtomMap.buildFreeformAtom('com.example', 'FIELD');
        expect(atom1, equals('----:com.example:FIELD'));

        final atom2 = Mp4AtomMap.buildFreeformAtom('com.phonic.tags', 'RATING');
        expect(atom2, equals('----:com.phonic.tags:RATING'));
      });

      test('should handle complex domain and name values', () {
        final atom = Mp4AtomMap.buildFreeformAtom('org.musicbrainz.tags', 'MUSICBRAINZ_TRACKID');
        expect(atom, equals('----:org.musicbrainz.tags:MUSICBRAINZ_TRACKID'));
      });

      test('should create parseable atoms', () {
        final domain = 'com.test.app';
        final name = 'CUSTOM_FIELD';
        final atom = Mp4AtomMap.buildFreeformAtom(domain, name);

        expect(Mp4AtomMap.isFreeformAtom(atom), isTrue);

        final parsed = Mp4AtomMap.parseFreeformAtom(atom);
        expect(parsed?.domain, equals(domain));
        expect(parsed?.name, equals(name));
      });

      test('should handle empty domain and name', () {
        final atom = Mp4AtomMap.buildFreeformAtom('', '');
        expect(atom, equals('----::'));
        expect(Mp4AtomMap.isFreeformAtom(atom), isTrue);
      });
    });

    group('Mapping Completeness', () {
      test('should have no overlap between standard and freeform atoms', () {
        final standardKeys = Mp4AtomMap.atoms.keys.toSet();
        final freeformKeys = Mp4AtomMap.freeformAtoms.keys.toSet();

        expect(standardKeys.intersection(freeformKeys), isEmpty);
      });

      test('should cover all relevant TagKey values', () {
        final allMappedKeys = {
          ...Mp4AtomMap.atoms.keys,
          ...Mp4AtomMap.freeformAtoms.keys,
        };

        // Check that major tag keys are covered
        expect(allMappedKeys.contains(TagKey.title), isTrue);
        expect(allMappedKeys.contains(TagKey.artist), isTrue);
        expect(allMappedKeys.contains(TagKey.album), isTrue);
        expect(allMappedKeys.contains(TagKey.genre), isTrue);
        expect(allMappedKeys.contains(TagKey.artwork), isTrue);
        expect(allMappedKeys.contains(TagKey.rating), isTrue);
        expect(allMappedKeys.contains(TagKey.custom), isTrue);

        // Year is derived from dateRecorded, so it's not directly mapped
        expect(allMappedKeys.contains(TagKey.year), isFalse);
      });

      test('should have unique atom identifiers in standard atoms', () {
        final atomIds = Mp4AtomMap.atoms.values.toList();
        final uniqueIds = atomIds.toSet();

        expect(atomIds.length, equals(uniqueIds.length));
      });

      test('should have unique atom names in freeform atoms', () {
        final atomNames = Mp4AtomMap.freeformAtoms.values.toList();
        final uniqueNames = atomNames.toSet();

        expect(atomNames.length, equals(uniqueNames.length));
      });

      test('should have consistent alternative atom mappings', () {
        // All alternative atoms should map to valid tag keys
        for (final tagKey in Mp4AtomMap.alternativeAtoms.values) {
          expect(TagKey.values.contains(tagKey), isTrue);
        }

        // Alternative atoms should not conflict with standard atoms
        for (final atomId in Mp4AtomMap.alternativeAtoms.keys) {
          if (Mp4AtomMap.atoms.containsValue(atomId)) {
            // If it's also a standard atom, it should map to the same tag key
            final standardTagKey = Mp4AtomMap.atoms.entries.firstWhere((entry) => entry.value == atomId).key;
            expect(Mp4AtomMap.alternativeAtoms[atomId], equals(standardTagKey));
          }
        }
      });
    });

    group('Integration with TagKey enum', () {
      test('should handle all TagKey values gracefully', () {
        for (final tagKey in TagKey.values) {
          // Should not throw exceptions
          expect(() => Mp4AtomMap.getAtomId(tagKey), returnsNormally);
          expect(() => Mp4AtomMap.getFreeformAtomName(tagKey), returnsNormally);
        }
      });

      test('should provide coverage for most common metadata fields', () {
        // Essential metadata fields should be supported
        final essentialFields = [
          TagKey.title,
          TagKey.artist,
          TagKey.album,
          TagKey.trackNumber,
          TagKey.genre,
          TagKey.dateRecorded,
        ];

        for (final field in essentialFields) {
          final hasStandard = Mp4AtomMap.getAtomId(field) != null;
          final hasFreeform = Mp4AtomMap.getFreeformAtomName(field) != null;

          expect(hasStandard || hasFreeform, isTrue, reason: 'Essential field $field should be supported');
        }
      });
    });
  });
}
