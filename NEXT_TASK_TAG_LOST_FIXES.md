# Next Agent Task: Fix Remaining TAG_LOST Validation Errors

## Current Situation ✅ MAJOR PROGRESS MADE

### What Was Already Fixed

- **ID3 Version Detection Bug**: Fixed in `lib/src/core/post_write_validator.dart`
- **Round-trip Validation**: Now correctly detects ID3v2.4 format ("2.4" instead of "4.0")
- **Most Tags Working**: Title, artist, album, genre, dateRecorded, musicalKey, bpm, grouping all round-trip correctly
- **Error Reduction**: From 9-11 errors per file down to only 3 errors per file (70% improvement)

### Current Status

- **Success Rate**: Still 0% but very close to resolution
- **Remaining Issues**: Only 3 specific tag types failing validation
- **Core Pipeline**: Fundamentally sound and working

## 🎯 **TASK: Fix These 3 Remaining TAG_LOST Errors**

The current error output shows exactly what needs to be fixed:

```
ERROR: Tag was lost during round-trip (Tag: artwork) [TAG_LOST]
ERROR: Tag was lost during round-trip (Tag: comment) [TAG_LOST]
ERROR: Tag was lost during round-trip (Tag: year) [TAG_LOST]
```

### Problem Analysis

These 3 tag types are failing round-trip validation, meaning they are written to the file but cannot be read back correctly during validation. The issue is likely in the codec implementation for these specific tag types.

## 🔍 **Investigation Plan**

### Step 1: Isolate Each Tag Type

Create individual tests for each failing tag type to understand exactly what's happening:

1. **Artwork Tag Investigation**

   - Issue: Binary data or MIME type handling
   - Location: Likely in ID3v24 codec artwork frame handling
   - Test: Write artwork, read back, compare binary data and metadata

2. **Comment Tag Investigation**

   - Issue: Text encoding differences (UTF-8 vs Latin1)
   - Location: ID3v24 codec comment frame (COMM) handling
   - Test: Write comment, read back, compare text and encoding

3. **Year Tag Investigation**
   - Issue: Type conversion (string vs integer)
   - Location: ID3v24 codec year/date frame handling
   - Test: Write year value, read back, compare type and format

### Step 2: Debug Each Tag Type

Create a debug test like this:

```dart
test('debug artwork tag round-trip', () async {
  final audioFile = await Phonic.fromFile('test/fixtures/mp3/1.mp3');

  // Clear existing artwork and set a simple one
  audioFile.removeTag(TagKey.artwork);
  audioFile.setTag(ArtworkTag(
    data: Uint8List.fromList([1, 2, 3, 4]), // Simple test data
    mimeType: 'image/jpeg',
    type: ArtworkType.frontCover,
  ));

  // Encode with minimal validation to get bytes
  final bytes = await audioFile.encode(EncodingOptions.preserveExisting(
    validationLevel: ValidationLevel.basic
  ));

  // Read back from bytes
  final reloadedFile = await Phonic.fromBytes(bytes);
  final artworkTags = reloadedFile.getTags(TagKey.artwork);

  print('Original artwork tags: ${audioFile.getTags(TagKey.artwork).length}');
  print('Reloaded artwork tags: ${artworkTags.length}');

  // Compare data
  if (artworkTags.isNotEmpty) {
    final tag = artworkTags.first as ArtworkTag;
    print('MIME type: ${tag.mimeType}');
    print('Data length: ${tag.data.length}');
  }
});
```

## 🛠 **Likely Root Causes & Solutions**

### 1. Artwork Tag Issues

**Probable Cause**: Binary data corruption or MIME type mismatch during encoding/decoding
**Investigation Focus**:

- Check `lib/src/formats/id3/id3v24_codec.dart` artwork frame handling
- Verify binary data preservation in APIC frames
- Check MIME type string consistency

**Likely Fix Location**: ID3v24 codec APIC frame reading/writing methods

### 2. Comment Tag Issues

**Probable Cause**: Text encoding mismatch (UTF-8 written, Latin1 read, or vice versa)
**Investigation Focus**:

- Check `lib/src/formats/id3/id3v24_codec.dart` comment frame handling
- Verify text encoding detection in COMM frames
- Check description field handling

**Likely Fix Location**: ID3v24 codec COMM frame reading/writing methods

### 3. Year Tag Issues

**Probable Cause**: Type conversion inconsistency (integer vs string)
**Investigation Focus**:

- Check date/year frame handling (TYER, TDRC frames)
- Verify integer to string conversion consistency
- Check date format parsing

**Likely Fix Location**: ID3v24 codec date frame reading/writing methods

## 📁 **Key Files to Examine**

1. **Primary Target**: `lib/src/formats/id3/id3v24_codec.dart`

   - Look for artwork (APIC), comment (COMM), and year (TYER/TDRC) frame handling
   - Check encoding/decoding methods for these frame types

2. **Validation Code**: `lib/src/core/post_write_validator.dart`

   - The `_compareTagSets()` method that detects the TAG_LOST errors
   - May need to update comparison logic for these tag types

3. **Test Files**: Look at existing codec tests for these tag types
   - `test/formats/id3/id3v24_codec_test.dart`
   - May need additional test coverage for these specific scenarios

## ✅ **Success Criteria**

When the fixes are complete:

- **Error Count**: Should drop from 3 errors to 0 errors per file
- **Success Rate**: Should jump from 0% to 95%+
- **Integration Tests**: Should pass the basic "load → modify → save" workflow
- **All Tag Types**: artwork, comment, and year tags should round-trip correctly

## 🚀 **Expected Timeline**

This should be achievable in 1-2 development sessions since:

- The hard part (ID3 version detection) is already solved
- Only 3 specific tag types need fixes
- The core architecture is working correctly
- Each tag type can be debugged and fixed independently

## 📝 **Testing Strategy**

1. Create individual debug tests for each tag type
2. Fix each tag type separately
3. Run the full bug analysis test to verify all files pass
4. Run integration tests to ensure no regressions

The library is very close to being fully functional - just these last 3 tag type edge cases need to be resolved!

---

_Task created after successful ID3 version detection fix_  
_Status: Ready for next development cycle_
