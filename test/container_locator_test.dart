import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonic/src/core/core.dart';

/// Test implementation of ContainerLocator for testing purposes
class TestContainerLocator extends ContainerLocator {
  @override
  ContainerKind get containerKind => ContainerKind.none;

  @override
  bool fileMatches(Uint8List fileBytes) {
    return fileBytes.isNotEmpty && fileBytes[0] == 0x54; // 'T'
  }

  @override
  Uint8List? extract(Uint8List fileBytes) {
    if (!fileMatches(fileBytes)) return null;
    return fileBytes.sublist(0, 10);
  }

  @override
  Uint8List inject(Uint8List fileBytes, Uint8List? containerBytes) {
    if (containerBytes == null) {
      return fileBytes.sublist(10); // Remove first 10 bytes
    }
    return Uint8List.fromList([...containerBytes, ...fileBytes.sublist(10)]);
  }
}

void main() {
  group('ContainerLocator', () {
    late TestContainerLocator locator;

    setUp(() {
      locator = TestContainerLocator();
    });

    test('should have containerKind property', () {
      expect(locator.containerKind, equals(ContainerKind.none));
    });

    test('should implement fileMatches method', () {
      final matchingBytes = Uint8List.fromList([0x54, 0x45, 0x53, 0x54]); // "TEST"
      final nonMatchingBytes = Uint8List.fromList([0x41, 0x42, 0x43]); // "ABC"
      final emptyBytes = Uint8List(0);

      expect(locator.fileMatches(matchingBytes), isTrue);
      expect(locator.fileMatches(nonMatchingBytes), isFalse);
      expect(locator.fileMatches(emptyBytes), isFalse);
    });

    test('should implement extract method', () {
      final testBytes = Uint8List.fromList([0x54, 0x45, 0x53, 0x54, 0x44, 0x41, 0x54, 0x41, 0x00, 0x00, 0x01, 0x02]);
      final nonMatchingBytes = Uint8List.fromList([0x41, 0x42, 0x43]);

      final extracted = locator.extract(testBytes);
      expect(extracted, isNotNull);
      expect(extracted!.length, equals(10));
      expect(extracted, equals(testBytes.sublist(0, 10)));

      final notExtracted = locator.extract(nonMatchingBytes);
      expect(notExtracted, isNull);
    });

    test('should implement inject method', () {
      final originalBytes = Uint8List.fromList([0x54, 0x45, 0x53, 0x54, 0x44, 0x41, 0x54, 0x41, 0x00, 0x00, 0x01, 0x02]);
      final newContainer = Uint8List.fromList([0x4E, 0x45, 0x57, 0x44, 0x41, 0x54, 0x41, 0x00, 0x00, 0x00]); // "NEWDATA..."

      // Test injection with new container
      final injected = locator.inject(originalBytes, newContainer);
      expect(injected.length, equals(newContainer.length + 2)); // 10 new + 2 remaining
      expect(injected.sublist(0, 10), equals(newContainer));
      expect(injected.sublist(10), equals([0x01, 0x02]));

      // Test removal (null container)
      final removed = locator.inject(originalBytes, null);
      expect(removed.length, equals(2));
      expect(removed, equals([0x01, 0x02]));
    });

    test('should be abstract class that can be extended', () {
      expect(locator, isA<ContainerLocator>());
      expect(locator.containerKind, isA<ContainerKind>());
    });
  });
}
