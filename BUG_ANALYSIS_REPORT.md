# Phonic Library Bug Analysis & Fix Roadmap

## Current Status: CRITICAL BUGS PREVENTING CORE FUNCTIONALITY

The integration tests reveal **100% failure rate** for the basic load → modify → save audio workflow. This indicates fundamental issues that must be resolved before the library can be used reliably.

## Bug Summary

- **Total test files**: 5 MP3 files
- **Success rate**: 0.0% (ALL files fail to encode)
- **Primary failure**: `CorruptedContainerException: Post-write validation failed`

## Identified Bug Categories

### 1. ROUND_TRIP_FAILED (5/5 files affected) - CRITICAL

**Issue**: ID3 version mismatch during validation

- Original files contain ID3v2.4 tags
- Round-trip validation expects ID3v2.3
- Error: "Expected ID3v2.3, got ID3v2.4"

**Root Cause**: The library is not preserving the original ID3 version during encoding operations.

**Fix Locations**:

- `ID3v2 codec validation` - Update to handle version mismatches
- `Container rebuilder` - Preserve original ID3 version
- `Encoding options` - Add ID3 version preservation setting

### 2. TAG_VALUE_INCONSISTENT (4/5 files affected) - CRITICAL

**Issue**: Tags are not synchronized between ID3v1 and ID3v2 containers

- ID3v1 has 30-character limits that cause truncation
- Modified tags are not properly synced across container types
- Error: "Tag values are inconsistent across containers"

**Root Cause**: Tag merger/synchronization logic is broken.

**Fix Locations**:

- `Tag merger` - Implement proper cross-container synchronization
- `ID3v1 handler` - Handle character limits and truncation properly
- `Container rebuilder` - Ensure consistent tag values across containers

### 3. Validation Severity Issues

**Issue**: Some validation failures should be warnings, not hard errors

- Current system treats all validation issues as fatal errors
- This prevents encoding even when issues are minor/recoverable

**Fix Locations**:

- `Validation system` - Implement warning vs error classification
- `ValidationLevel enum` - Add granular control over error vs warning treatment
- `Post-write validator` - Allow configurable error handling

## Reproduction Steps

```bash
# Run the integration test to see failures
flutter test test/integration/full_workflow_integration_test.dart --name "Basic metadata modification workflow"

# Run detailed bug analysis
flutter test test/integration/bug_analysis_test.dart --name "BUG REPORT"

# Analyze specific bug types
flutter test test/integration/bug_analysis_test.dart --name "ROUND_TRIP_FAILED"
flutter test test/integration/bug_analysis_test.dart --name "TAG_VALUE_INCONSISTENT"
```

## Expected Behavior After Fixes

1. **Load** any valid MP3 file ✓ (currently working)
2. **Modify** metadata tags ✓ (currently working)
3. **Encode** modified file with proper validation ✗ (currently broken)
4. **Round-trip** validation should pass ✗ (currently broken)
5. **Cross-container** tag synchronization ✗ (currently broken)

## Priority Fix Order

1. **HIGH**: Fix ID3 version preservation in ROUND_TRIP_FAILED
2. **HIGH**: Fix tag synchronization in TAG_VALUE_INCONSISTENT
3. **MEDIUM**: Implement warning vs error classification in validation
4. **LOW**: Performance optimizations

## Success Criteria

- Integration test `Basic metadata modification workflow` passes
- Integration test `Batch processing performance` passes
- All matrix tests in `Load → Modify → Save Matrix` pass
- Bug analysis tests show 0% failure rate

## Files to Focus On

Based on the error patterns, these source files likely contain the bugs:

```
lib/src/core/
├── phonic_audio_file_impl.dart (line 1049 - encoding logic)
├── container_rebuilder.dart (tag synchronization)
├── post_write_validator.dart (validation logic)
└── encoding_options.dart (encoding configuration)

lib/src/formats/
├── id3/ (ID3 version handling)
└── mp3/ (container management)

lib/src/tags/
└── tag_merger.dart (cross-container synchronization)
```

## Test-Driven Development Approach

The integration tests are now properly written to **FAIL** when bugs exist. This is correct behavior - they should continue failing until the underlying bugs are fixed. Once fixed:

1. All integration tests should pass
2. The library will be ready for production use
3. Future regressions will be caught immediately

**DO NOT modify the integration tests to "work around" these bugs. Fix the bugs in the core library instead.**
