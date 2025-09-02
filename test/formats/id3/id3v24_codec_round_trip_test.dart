import 'package:phonic/src/core/core.dart';
import 'package:phonic/src/formats/id3/id3v24_codec.dart';
import 'package:test/test.dart';

void main() {
  group('ID3v24Codec Tag Round-trip Tests', () {
    late Id3v24Codec codec;

    setUp(() {
      codec = const Id3v24Codec();
    });

    test('comment tag round-trip', () {
      // Create a comment tag
      final originalTag = const CommentTag('Test comment value');
      final tags = [originalTag];

      // Encode tags to container
      final containerBytes = codec.writeToContainer(tagsToWrite: tags);

      // Decode tags back from container
      final decodedTags = codec.readFromContainer(containerBytes);

      // Verify we got the same tag back
      expect(decodedTags.length, equals(1));
      expect(decodedTags.first, isA<CommentTag>());

      final decodedComment = decodedTags.first as CommentTag;
      expect(decodedComment.value, equals(originalTag.value));
    });

    test('dateRecorded tag round-trip', () {
      // Create a dateRecorded tag
      final originalTag = DateRecordedTag('2023-12-25');
      final tags = [originalTag];

      // Encode tags to container
      final containerBytes = codec.writeToContainer(tagsToWrite: tags);

      // Decode tags back from container
      final decodedTags = codec.readFromContainer(containerBytes);

      // Verify we got the same tag back
      expect(decodedTags.length, equals(1));
      expect(decodedTags.first, isA<DateRecordedTag>());

      final decodedDate = decodedTags.first as DateRecordedTag;
      expect(decodedDate.value, equals(originalTag.value));
    });
  });
}
