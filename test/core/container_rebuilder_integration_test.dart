import 'dart:typed_data';

import 'package:phonic/src/core/container_rebuilder.dart';
import 'package:phonic/src/core/metadata_tag.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:test/test.dart';

void main() {
  group('ContainerRebuilder Integration Tests', () {
    test('should demonstrate container rebuilding workflow', () {
      // Step 1: Create initial container with some tags
      final codec = const Id3v24Codec();
      final initialTags = [
        const TitleTag('Original Title'),
        const ArtistTag('Original Artist'),
        const AlbumTag('Original Album'),
      ];

      final originalContainer = codec.writeToContainer(tagsToWrite: initialTags);
      expect(originalContainer, isNotEmpty);

      // Step 2: Verify original tags can be read back
      final parsedOriginalTags = codec.readFromContainer(originalContainer);
      expect(parsedOriginalTags.length, equals(3));

      final originalTitle = parsedOriginalTags.whereType<TitleTag>().first;
      expect(originalTitle.value, equals('Original Title'));

      // Step 3: Use container rebuilder to update some tags while preserving others
      const rebuilder = ContainerRebuilder();
      final updatedTags = [
        const TitleTag('Updated Title'), // Update title
        const ArtistTag('Updated Artist'), // Update artist
        // Note: Album tag is not included, so it should be preserved in a full implementation
      ];

      final rebuiltContainer = rebuilder.rebuildContainer(
        codec: codec,
        tagsToWrite: updatedTags,
        existingContainerBytes: originalContainer,
      );

      expect(rebuiltContainer, isNotEmpty);

      // Step 4: Verify updated tags are present
      final parsedUpdatedTags = codec.readFromContainer(rebuiltContainer);
      expect(parsedUpdatedTags.length, greaterThanOrEqualTo(2));

      final updatedTitle = parsedUpdatedTags.whereType<TitleTag>().firstOrNull;
      final updatedArtist = parsedUpdatedTags.whereType<ArtistTag>().firstOrNull;

      expect(updatedTitle?.value, equals('Updated Title'));
      expect(updatedArtist?.value, equals('Updated Artist'));

      // Note: In a full implementation with unknown frame preservation,
      // we would also verify that the album tag is still present
    });

    test('should handle empty existing container gracefully', () {
      const rebuilder = ContainerRebuilder();
      final codec = const Id3v24Codec();

      final tags = [const TitleTag('New Title')];

      final result = rebuilder.rebuildContainer(
        codec: codec,
        tagsToWrite: tags,
        existingContainerBytes: Uint8List(0), // Empty container
      );

      expect(result, isNotEmpty);

      final parsedTags = codec.readFromContainer(result);
      final titleTag = parsedTags.whereType<TitleTag>().firstOrNull;
      expect(titleTag?.value, equals('New Title'));
    });

    test('should handle null existing container', () {
      const rebuilder = ContainerRebuilder();
      final codec = const Id3v24Codec();

      final tags = [
        const TitleTag('New Title'),
        const ArtistTag('New Artist'),
      ];

      final result = rebuilder.rebuildContainer(
        codec: codec,
        tagsToWrite: tags,
        existingContainerBytes: null, // No existing container
      );

      expect(result, isNotEmpty);

      final parsedTags = codec.readFromContainer(result);
      expect(parsedTags.length, equals(2));

      final titleTag = parsedTags.whereType<TitleTag>().firstOrNull;
      final artistTag = parsedTags.whereType<ArtistTag>().firstOrNull;

      expect(titleTag?.value, equals('New Title'));
      expect(artistTag?.value, equals('New Artist'));
    });

    test('should demonstrate extensibility for future unknown frame preservation', () {
      // This test demonstrates how the container rebuilder provides a foundation
      // for future implementation of unknown frame preservation

      const rebuilder = ContainerRebuilder();
      final codec = const Id3v24Codec();

      // Create a container that would have unknown frames in a real scenario
      final originalTags = [const TitleTag('Original')];
      final originalContainer = codec.writeToContainer(tagsToWrite: originalTags);

      // Update with new tags
      final newTags = [const TitleTag('Updated')];
      final rebuiltContainer = rebuilder.rebuildContainer(
        codec: codec,
        tagsToWrite: newTags,
        existingContainerBytes: originalContainer,
      );

      // Verify the rebuilding process works
      expect(rebuiltContainer, isNotEmpty);

      final parsedTags = codec.readFromContainer(rebuiltContainer);
      final titleTag = parsedTags.whereType<TitleTag>().firstOrNull;
      expect(titleTag?.value, equals('Updated'));

      // In a full implementation, this is where we would verify that
      // unknown frames from the original container are preserved
    });
  });
}
