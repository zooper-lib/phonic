import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';
import 'package:phonic/src/utils/unknown_data_preservation.dart';

// Test implementation of TagCodec for testing purposes
class TestTagCodec implements TagCodec {
  final ContainerKind _containerKind;
  final String _containerVersion;

  TestTagCodec(this._containerKind, this._containerVersion);

  @override
  ContainerKind get containerKind => _containerKind;

  @override
  String get containerVersion => _containerVersion;

  @override
  TagCapability get capability => TagCapability(
    containerKind: _containerKind,
    containerVersion: _containerVersion,
    semanticsByKey: const {
      TagKey.title: TagSemantics(maxTextLength: 100),
      TagKey.artist: TagSemantics(maxTextLength: 100),
    },
  );

  @override
  List<MetadataTag> readFromContainer(
    Uint8List containerBytes, {
    UnknownDataPreservationManager? preservationManager,
  }) {
    return [
      TitleTag(
        'Test Title',
        provenance: TagProvenance(containerKind, containerVersion, TagConfidence.certain),
      ),
    ];
  }

  @override
  Uint8List writeToContainer({
    required List<MetadataTag> tagsToWrite,
    Uint8List? existingContainerBytes,
    UnknownDataPreservationManager? preservationManager,
  }) {
    return Uint8List.fromList([0x01, 0x02, 0x03]);
  }
}

// Test implementation of ContainerLocator for testing purposes
class TestContainerLocator extends ContainerLocator {
  final ContainerKind _containerKind;

  TestContainerLocator(this._containerKind);

  @override
  ContainerKind get containerKind => _containerKind;

  @override
  bool fileMatches(Uint8List fileBytes) {
    return fileBytes.isNotEmpty && fileBytes[0] == 0xFF;
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    if (!fileMatches(fileBytes)) return null;
    return fileBytes.sublist(0, 10);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    if (containerBytes == null) return fileBytes;
    return Uint8List.fromList([...containerBytes, ...fileBytes]);
  }
}

void main() {
  group('CodecRegistry', () {
    late List<TagCodec> testCodecs;
    late List<ContainerLocator> testLocators;
    late CodecRegistry registry;

    setUp(() {
      testCodecs = [
        TestTagCodec(ContainerKind.id3v2, '2.4'),
        TestTagCodec(ContainerKind.id3v2, '2.3'),
        TestTagCodec(ContainerKind.id3v1, 'v1'),
        TestTagCodec(ContainerKind.vorbis, ''),
        TestTagCodec(ContainerKind.mp4, ''),
      ];

      testLocators = [
        TestContainerLocator(ContainerKind.id3v2),
        TestContainerLocator(ContainerKind.id3v1),
        TestContainerLocator(ContainerKind.vorbis),
        TestContainerLocator(ContainerKind.mp4),
      ];

      registry = CodecRegistry(
        codecList: testCodecs,
        containerLocatorList: testLocators,
      );
    });

    group('constructor', () {
      test('should create registry with provided codecs and locators', () {
        expect(registry.codecList, equals(testCodecs));
        expect(registry.containerLocatorList, equals(testLocators));
      });

      test('should accept empty lists', () {
        final emptyRegistry = CodecRegistry(
          codecList: const [],
          containerLocatorList: const [],
        );

        expect(emptyRegistry.codecList, isEmpty);
        expect(emptyRegistry.containerLocatorList, isEmpty);
      });

      test('should create immutable collections', () {
        // Verify that the registry stores its own copies
        expect(registry.codecList, isNot(same(testCodecs)));
        expect(registry.containerLocatorList, isNot(same(testLocators)));

        // Verify that modifying original lists doesn't affect registry
        testCodecs.clear();
        testLocators.clear();

        expect(registry.codecList, hasLength(5));
        expect(registry.containerLocatorList, hasLength(4));
      });

      test('should handle duplicate codecs for same format', () {
        final duplicateCodecs = [
          TestTagCodec(ContainerKind.id3v2, '2.4'),
          TestTagCodec(ContainerKind.id3v2, '2.4'), // Duplicate
        ];

        final registryWithDuplicates = CodecRegistry(
          codecList: duplicateCodecs,
          containerLocatorList: const [],
        );

        expect(registryWithDuplicates.codecList, hasLength(2));
      });
    });

    group('properties', () {
      test('should provide access to codec list', () {
        final codecs = registry.codecList;

        expect(codecs, hasLength(5));
        expect(codecs, everyElement(isA<TagCodec>()));

        // Verify specific codecs are present
        expect(codecs.any((c) => c.containerKind == ContainerKind.id3v2 && c.containerVersion == '2.4'), isTrue);
        expect(codecs.any((c) => c.containerKind == ContainerKind.id3v2 && c.containerVersion == '2.3'), isTrue);
        expect(codecs.any((c) => c.containerKind == ContainerKind.id3v1), isTrue);
        expect(codecs.any((c) => c.containerKind == ContainerKind.vorbis), isTrue);
        expect(codecs.any((c) => c.containerKind == ContainerKind.mp4), isTrue);
      });

      test('should provide access to locator list', () {
        final locators = registry.containerLocatorList;

        expect(locators, hasLength(4));
        expect(locators, everyElement(isA<ContainerLocator>()));

        // Verify specific locators are present
        expect(locators.any((l) => l.containerKind == ContainerKind.id3v2), isTrue);
        expect(locators.any((l) => l.containerKind == ContainerKind.id3v1), isTrue);
        expect(locators.any((l) => l.containerKind == ContainerKind.vorbis), isTrue);
        expect(locators.any((l) => l.containerKind == ContainerKind.mp4), isTrue);
      });

      test('should return immutable collections', () {
        final codecs = registry.codecList;
        final locators = registry.containerLocatorList;

        // Verify collections are unmodifiable
        expect(() => codecs.add(TestTagCodec(ContainerKind.id3v2, '2.2')), throwsUnsupportedError);
        expect(() => locators.add(TestContainerLocator(ContainerKind.id3v2)), throwsUnsupportedError);
      });
    });

    group('codec management', () {
      test('should store all provided codecs', () {
        expect(registry.codecList, hasLength(5));

        // Verify each codec is accessible
        for (final codec in testCodecs) {
          expect(registry.codecList.contains(codec), isTrue);
        }
      });

      test('should maintain codec order from constructor', () {
        final orderedCodecs = [
          TestTagCodec(ContainerKind.id3v1, 'v1'),
          TestTagCodec(ContainerKind.id3v2, '2.3'),
          TestTagCodec(ContainerKind.vorbis, ''),
        ];

        final orderedRegistry = CodecRegistry(
          codecList: orderedCodecs,
          containerLocatorList: const [],
        );

        final retrievedCodecs = orderedRegistry.codecList;
        expect(retrievedCodecs[0].containerKind, equals(ContainerKind.id3v1));
        expect(retrievedCodecs[1].containerKind, equals(ContainerKind.id3v2));
        expect(retrievedCodecs[2].containerKind, equals(ContainerKind.vorbis));
      });

      test('should handle codecs with same container kind but different versions', () {
        final id3Codecs = registry.codecList.where((c) => c.containerKind == ContainerKind.id3v2).toList();

        expect(id3Codecs, hasLength(2));
        expect(id3Codecs.any((c) => c.containerVersion == '2.4'), isTrue);
        expect(id3Codecs.any((c) => c.containerVersion == '2.3'), isTrue);
      });
    });

    group('locator management', () {
      test('should store all provided locators', () {
        expect(registry.containerLocatorList, hasLength(4));

        // Verify each locator is accessible
        for (final locator in testLocators) {
          expect(registry.containerLocatorList.contains(locator), isTrue);
        }
      });

      test('should maintain locator order from constructor', () {
        final orderedLocators = [
          TestContainerLocator(ContainerKind.mp4),
          TestContainerLocator(ContainerKind.id3v1),
          TestContainerLocator(ContainerKind.vorbis),
        ];

        final orderedRegistry = CodecRegistry(
          codecList: const [],
          containerLocatorList: orderedLocators,
        );

        final retrievedLocators = orderedRegistry.containerLocatorList;
        expect(retrievedLocators[0].containerKind, equals(ContainerKind.mp4));
        expect(retrievedLocators[1].containerKind, equals(ContainerKind.id3v1));
        expect(retrievedLocators[2].containerKind, equals(ContainerKind.vorbis));
      });

      test('should handle unique locators per container kind', () {
        // Verify each container kind has exactly one locator
        final containerKinds = registry.containerLocatorList.map((l) => l.containerKind).toSet();

        expect(containerKinds, hasLength(4));
        expect(containerKinds.contains(ContainerKind.id3v2), isTrue);
        expect(containerKinds.contains(ContainerKind.id3v1), isTrue);
        expect(containerKinds.contains(ContainerKind.vorbis), isTrue);
        expect(containerKinds.contains(ContainerKind.mp4), isTrue);
      });
    });

    group('registry instantiation', () {
      test('should create registry with minimal configuration', () {
        final minimalRegistry = CodecRegistry(
          codecList: [TestTagCodec(ContainerKind.id3v1, 'v1')],
          containerLocatorList: [TestContainerLocator(ContainerKind.id3v1)],
        );

        expect(minimalRegistry.codecList, hasLength(1));
        expect(minimalRegistry.containerLocatorList, hasLength(1));
      });

      test('should create registry with comprehensive configuration', () {
        // Test with a realistic full configuration
        final comprehensiveCodecs = [
          TestTagCodec(ContainerKind.id3v2, '2.4'),
          TestTagCodec(ContainerKind.id3v2, '2.3'),
          TestTagCodec(ContainerKind.id3v2, '2.2'),
          TestTagCodec(ContainerKind.id3v1, 'v1'),
          TestTagCodec(ContainerKind.vorbis, ''),
          TestTagCodec(ContainerKind.mp4, ''),
        ];

        final comprehensiveLocators = [
          TestContainerLocator(ContainerKind.id3v2),
          TestContainerLocator(ContainerKind.id3v1),
          TestContainerLocator(ContainerKind.vorbis),
          TestContainerLocator(ContainerKind.mp4),
        ];

        final comprehensiveRegistry = CodecRegistry(
          codecList: comprehensiveCodecs,
          containerLocatorList: comprehensiveLocators,
        );

        expect(comprehensiveRegistry.codecList, hasLength(6));
        expect(comprehensiveRegistry.containerLocatorList, hasLength(4));

        // Verify all major container types are supported
        final codecKinds = comprehensiveRegistry.codecList.map((c) => c.containerKind).toSet();
        expect(codecKinds.contains(ContainerKind.id3v2), isTrue);
        expect(codecKinds.contains(ContainerKind.id3v1), isTrue);
        expect(codecKinds.contains(ContainerKind.vorbis), isTrue);
        expect(codecKinds.contains(ContainerKind.mp4), isTrue);
      });
    });

    group('thread safety', () {
      test('should be safe for concurrent access', () {
        // Verify that multiple threads can safely access the same registry
        // This test verifies immutability rather than actual threading
        final registry1 = CodecRegistry(
          codecList: testCodecs,
          containerLocatorList: testLocators,
        );

        final registry2 = CodecRegistry(
          codecList: testCodecs,
          containerLocatorList: testLocators,
        );

        // Both registries should have independent collections
        expect(registry1.codecList, isNot(same(registry2.codecList)));
        expect(registry1.containerLocatorList, isNot(same(registry2.containerLocatorList)));

        // But should have equivalent content
        expect(registry1.codecList.length, equals(registry2.codecList.length));
        expect(registry1.containerLocatorList.length, equals(registry2.containerLocatorList.length));
      });

      test('should maintain state consistency', () {
        // Verify that registry state cannot be modified after construction
        final originalCodecCount = registry.codecList.length;
        final originalLocatorCount = registry.containerLocatorList.length;

        // Attempt to access collections multiple times
        for (int i = 0; i < 10; i++) {
          expect(registry.codecList.length, equals(originalCodecCount));
          expect(registry.containerLocatorList.length, equals(originalLocatorCount));
        }
      });
    });

    group('findCodec', () {
      test('should find codec by container kind and version', () {
        final codec = registry.findCodec(ContainerKind.id3v2, '2.4');

        expect(codec, isNotNull);
        expect(codec!.containerKind, equals(ContainerKind.id3v2));
        expect(codec.containerVersion, equals('2.4'));
      });

      test('should find codec for different versions of same container', () {
        final codec23 = registry.findCodec(ContainerKind.id3v2, '2.3');
        final codec24 = registry.findCodec(ContainerKind.id3v2, '2.4');

        expect(codec23, isNotNull);
        expect(codec24, isNotNull);
        expect(codec23!.containerVersion, equals('2.3'));
        expect(codec24!.containerVersion, equals('2.4'));
        expect(codec23, isNot(same(codec24)));
      });

      test('should find codec for different container kinds', () {
        final id3v1Codec = registry.findCodec(ContainerKind.id3v1, 'v1');
        final vorbisCodec = registry.findCodec(ContainerKind.vorbis, '');
        final mp4Codec = registry.findCodec(ContainerKind.mp4, '');

        expect(id3v1Codec, isNotNull);
        expect(vorbisCodec, isNotNull);
        expect(mp4Codec, isNotNull);

        expect(id3v1Codec!.containerKind, equals(ContainerKind.id3v1));
        expect(vorbisCodec!.containerKind, equals(ContainerKind.vorbis));
        expect(mp4Codec!.containerKind, equals(ContainerKind.mp4));
      });

      test('should return null for non-existent codec', () {
        final codec = registry.findCodec(ContainerKind.id3v2, '1.0');

        expect(codec, isNull);
      });

      test('should return null for non-existent container kind', () {
        final codec = registry.findCodec(ContainerKind.none, '');

        expect(codec, isNull);
      });

      test('should return first matching codec when duplicates exist', () {
        final duplicateCodecs = [
          TestTagCodec(ContainerKind.id3v2, '2.4'),
          TestTagCodec(ContainerKind.id3v2, '2.4'), // Duplicate
          TestTagCodec(ContainerKind.vorbis, ''),
        ];

        final registryWithDuplicates = CodecRegistry(
          codecList: duplicateCodecs,
          containerLocatorList: const [],
        );

        final codec = registryWithDuplicates.findCodec(ContainerKind.id3v2, '2.4');

        expect(codec, isNotNull);
        expect(codec, same(duplicateCodecs[0])); // Should return first match
      });

      test('should handle empty codec list', () {
        final emptyRegistry = CodecRegistry(
          codecList: const [],
          containerLocatorList: const [],
        );

        final codec = emptyRegistry.findCodec(ContainerKind.id3v2, '2.4');

        expect(codec, isNull);
      });

      test('should be case sensitive for version matching', () {
        final testCodec = TestTagCodec(ContainerKind.id3v1, 'V1'); // Uppercase
        final registryWithCase = CodecRegistry(
          codecList: [testCodec],
          containerLocatorList: const [],
        );

        final codecLower = registryWithCase.findCodec(ContainerKind.id3v1, 'v1');
        final codecUpper = registryWithCase.findCodec(ContainerKind.id3v1, 'V1');

        expect(codecLower, isNull);
        expect(codecUpper, isNotNull);
        expect(codecUpper, same(testCodec));
      });

      test('should handle exact version matching', () {
        final codec = registry.findCodec(ContainerKind.id3v2, '2.4.0'); // Non-existent version

        expect(codec, isNull);
      });
    });

    group('findLocator', () {
      test('should find locator by container kind', () {
        final locator = registry.findLocator(ContainerKind.id3v2);

        expect(locator, isNotNull);
        expect(locator!.containerKind, equals(ContainerKind.id3v2));
      });

      test('should find locators for different container kinds', () {
        final id3v2Locator = registry.findLocator(ContainerKind.id3v2);
        final id3v1Locator = registry.findLocator(ContainerKind.id3v1);
        final vorbisLocator = registry.findLocator(ContainerKind.vorbis);
        final mp4Locator = registry.findLocator(ContainerKind.mp4);

        expect(id3v2Locator, isNotNull);
        expect(id3v1Locator, isNotNull);
        expect(vorbisLocator, isNotNull);
        expect(mp4Locator, isNotNull);

        expect(id3v2Locator!.containerKind, equals(ContainerKind.id3v2));
        expect(id3v1Locator!.containerKind, equals(ContainerKind.id3v1));
        expect(vorbisLocator!.containerKind, equals(ContainerKind.vorbis));
        expect(mp4Locator!.containerKind, equals(ContainerKind.mp4));
      });

      test('should return null for non-existent locator', () {
        final locator = registry.findLocator(ContainerKind.none);

        expect(locator, isNull);
      });

      test('should return first matching locator when duplicates exist', () {
        final duplicateLocators = [
          TestContainerLocator(ContainerKind.id3v2),
          TestContainerLocator(ContainerKind.id3v2), // Duplicate
          TestContainerLocator(ContainerKind.vorbis),
        ];

        final registryWithDuplicates = CodecRegistry(
          codecList: const [],
          containerLocatorList: duplicateLocators,
        );

        final locator = registryWithDuplicates.findLocator(ContainerKind.id3v2);

        expect(locator, isNotNull);
        expect(locator, same(duplicateLocators[0])); // Should return first match
      });

      test('should handle empty locator list', () {
        final emptyRegistry = CodecRegistry(
          codecList: const [],
          containerLocatorList: const [],
        );

        final locator = emptyRegistry.findLocator(ContainerKind.id3v2);

        expect(locator, isNull);
      });

      test('should find all available locator types', () {
        // Verify that all container kinds in the test setup can be found
        final containerKinds = [
          ContainerKind.id3v2,
          ContainerKind.id3v1,
          ContainerKind.vorbis,
          ContainerKind.mp4,
        ];

        for (final kind in containerKinds) {
          final locator = registry.findLocator(kind);
          expect(locator, isNotNull, reason: 'Should find locator for $kind');
          expect(locator!.containerKind, equals(kind));
        }
      });
    });

    group('lookup method integration', () {
      test('should find matching codec and locator for same container kind', () {
        final codec = registry.findCodec(ContainerKind.id3v2, '2.4');
        final locator = registry.findLocator(ContainerKind.id3v2);

        expect(codec, isNotNull);
        expect(locator, isNotNull);
        expect(codec!.containerKind, equals(locator!.containerKind));
      });

      test('should handle cases where codec exists but locator does not', () {
        final codecOnlyRegistry = CodecRegistry(
          codecList: [TestTagCodec(ContainerKind.id3v2, '2.4')],
          containerLocatorList: const [], // No locators
        );

        final codec = codecOnlyRegistry.findCodec(ContainerKind.id3v2, '2.4');
        final locator = codecOnlyRegistry.findLocator(ContainerKind.id3v2);

        expect(codec, isNotNull);
        expect(locator, isNull);
      });

      test('should handle cases where locator exists but codec does not', () {
        final locatorOnlyRegistry = CodecRegistry(
          codecList: const [], // No codecs
          containerLocatorList: [TestContainerLocator(ContainerKind.id3v2)],
        );

        final codec = locatorOnlyRegistry.findCodec(ContainerKind.id3v2, '2.4');
        final locator = locatorOnlyRegistry.findLocator(ContainerKind.id3v2);

        expect(codec, isNull);
        expect(locator, isNotNull);
      });

      test('should maintain consistent results across multiple calls', () {
        // Verify that lookup methods return consistent results
        final codec1 = registry.findCodec(ContainerKind.vorbis, '');
        final codec2 = registry.findCodec(ContainerKind.vorbis, '');
        final locator1 = registry.findLocator(ContainerKind.vorbis);
        final locator2 = registry.findLocator(ContainerKind.vorbis);

        expect(codec1, same(codec2));
        expect(locator1, same(locator2));
      });
    });
  });
}

