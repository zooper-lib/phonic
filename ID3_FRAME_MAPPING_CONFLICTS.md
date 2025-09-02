# ID3 Frame Mapping Conflicts: Analysis & Fix Requirements

## Problem Summary

The phonic library suffers from **frame mapping conflicts** when encoding audio files with different ID3 versions, particularly affecting the **optimized encoding strategy** and **round-trip validation**. The root cause is that multiple semantic tags map to the same physical frame in certain ID3 versions, causing data loss and validation failures.

## Root Cause Analysis

### The Core Issue: Frame Mapping Conflicts

Different ID3 versions have incompatible frame structures that create semantic conflicts:

| Tag Type          | ID3v1      | ID3v2.2 | ID3v2.3 | ID3v2.4 |
| ----------------- | ---------- | ------- | ------- | ------- |
| `YearTag`         | year field | `TYE`   | `TYER`  | `TDRC`  |
| `DateRecordedTag` | ❌         | ❌      | ❌      | `TDRC`  |

**Critical Conflict**: In ID3v2.4, both `YearTag` and `DateRecordedTag` map to the same `TDRC` frame, but the system treats them as separate tags during loading and validation.

### Failure Scenario

1. **Original File**: Contains ID3v1 (with year) + ID3v2.4 (with dateRecorded)
2. **Tag Loading**: System loads both as separate tags: `YearTag(2020)` and `DateRecordedTag(2020)`
3. **Optimized Encoding**: Targets only ID3v2.4, attempts to write both tags
4. **Frame Conflict**: Both tags write to `TDRC` frame → last write wins, first is lost
5. **Round-trip Validation**: Expects 2 tags, finds only 1 → **"Tag was lost during round-trip (Tag: year)"**

### Affected Components

- **Optimized Encoding Strategy**: Loses tags during cross-version encoding
- **Round-trip Validation**: Fails due to frame mapping mismatches
- **Multi-container Files**: Data loss when consolidating containers
- **Version Conversion**: Any ID3 version changes cause conflicts

## Current Impact

### Test Results

- **ValidationLevel.basic**: ✅ Works (no round-trip validation)
- **ValidationLevel.standard**: ✅ Works (no round-trip validation)
- **ValidationLevel.strict**: ❌ Fails with `TAG_LOST` errors

### Failing Test Cases

```
ERROR: Tag was lost during round-trip (Tag: year) [TAG_LOST]
ERROR: Tag value changed during round-trip (Tag: album, original: "", extracted: "") [TAG_VALUE_CHANGED]
```

## Requirements for Fix

### Functional Requirements

#### FR-1: Semantic Tag Conversion System

- **Requirement**: Implement intelligent conversion between semantically equivalent tags across ID3 versions
- **Priority**: High
- **Acceptance Criteria**:
  - `YearTag` ↔ `DateRecordedTag` conversion preserves year information
  - Conversion rules handle all ID3 version combinations (v1, v2.2, v2.3, v2.4)
  - No data loss during version transitions

#### FR-2: Frame Conflict Resolution

- **Requirement**: Resolve conflicts when multiple tags map to the same frame
- **Priority**: High
- **Acceptance Criteria**:
  - When `YearTag` and `DateRecordedTag` both target `TDRC`, merge intelligently
  - Precedence rules determine which tag takes priority
  - User can override default precedence

#### FR-3: Enhanced Round-trip Validation

- **Requirement**: Update validation to understand semantic equivalence
- **Priority**: High
- **Acceptance Criteria**:
  - Validator recognizes that `YearTag(2020)` + `DateRecordedTag(2020)` can become single `DateRecordedTag(2020)` in ID3v2.4
  - No false-positive `TAG_LOST` errors for semantically preserved data
  - Validation accounts for version-specific limitations

#### FR-4: Capability-Aware Encoding

- **Requirement**: Prevent encoding tags not supported by target version
- **Priority**: Medium
- **Acceptance Criteria**:
  - Clear warnings when tags cannot be preserved in target version
  - Graceful degradation (drop unsupported tags vs. fail entirely)
  - User control over data loss handling

### Non-Functional Requirements

#### NFR-1: Backward Compatibility

- **Requirement**: Existing API behavior must not change
- **Priority**: High
- **Details**: Current working scenarios (basic/standard validation) continue to work

#### NFR-2: Performance

- **Requirement**: Conversion logic adds minimal overhead
- **Priority**: Medium
- **Details**: Tag conversion should be O(n) where n is number of tags

#### NFR-3: Extensibility

- **Requirement**: System can accommodate future ID3 versions or formats
- **Priority**: Low
- **Details**: Conversion rules should be configurable/pluggable

## Proposed Design

### Architecture Overview

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────┐
│   Tag Loading   │───▶│  Semantic Converter  │───▶│   Tag Writing   │
│  (Multi-format) │    │                      │    │ (Target format) │
└─────────────────┘    └──────────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │ Conversion Rules│
                       │ - Frame Maps    │
                       │ - Precedence    │
                       │ - Equivalence   │
                       └─────────────────┘
```

### Component Design

#### 1. Semantic Tag Converter

**Location**: `lib/src/core/semantic_tag_converter.dart`

**Responsibilities**:

- Convert tags between semantically equivalent representations
- Apply version-specific transformation rules
- Handle frame mapping conflicts

**Key Methods**:

```dart
class SemanticTagConverter {
  List<MetadataTag> convertForTargetVersion(
    List<MetadataTag> sourceTags,
    List<(ContainerKind, String)> targetContainers
  );

  List<MetadataTag> resolveFrameConflicts(
    List<MetadataTag> tags,
    ContainerKind targetContainer
  );

  bool areTagsSemanticallyEquivalent(
    MetadataTag tag1,
    MetadataTag tag2
  );
}
```

#### 2. Conversion Rules Engine

**Location**: `lib/src/core/conversion_rules.dart`

**Responsibilities**:

- Define conversion logic between tag types
- Maintain precedence rules for conflicts
- Provide version capability matrices

**Key Classes**:

```dart
class ConversionRule {
  bool canConvert(TagKey from, TagKey to);
  MetadataTag? convert(MetadataTag source, TagKey target);
}

class FrameConflictResolver {
  MetadataTag resolveConflict(List<MetadataTag> conflictingTags);
}
```

#### 3. Enhanced Round-trip Validator

**Modifications to**: `lib/src/core/post_write_validator.dart`

**Changes**:

- Add semantic equivalence checking in `_compareTagSets`
- Account for version-specific limitations
- Provide detailed context for validation errors

### Implementation Strategy

#### Phase 1: Core Conversion Logic (Week 1)

1. Implement `SemanticTagConverter` with basic year ↔ dateRecorded conversion
2. Add frame conflict resolution for ID3v2.4 `TDRC` conflicts
3. Update encoding preparation to use converter

#### Phase 2: Enhanced Validation (Week 2)

1. Modify `PostWriteValidator` to use semantic equivalence
2. Update `_compareTagSets` method with conversion awareness
3. Add comprehensive test coverage for all ID3 version combinations

#### Phase 3: Advanced Features (Week 3)

1. Implement capability-aware encoding with warnings
2. Add user-configurable precedence rules
3. Extend to handle all ID3 version pairs (not just v2.4)

### Test Requirements

#### Unit Tests

- [ ] Year ↔ DateRecorded conversion in all ID3 versions
- [ ] Frame conflict resolution with multiple conflict scenarios
- [ ] Semantic equivalence detection
- [ ] Version capability boundary testing

#### Integration Tests

- [ ] Optimized strategy with strict validation passes
- [ ] Cross-version conversion preserves semantic information
- [ ] Multi-container files handle conflicts correctly
- [ ] Error cases provide actionable feedback

#### Regression Tests

- [ ] All existing functionality continues to work
- [ ] Performance benchmarks meet requirements
- [ ] API compatibility maintained

## Success Criteria

### Definition of Done

1. **ValidationLevel.strict passes** for optimized encoding strategy
2. **Zero data loss** during semantic conversions
3. **Clear error messages** for unsupported conversions
4. **100% backward compatibility** with existing API
5. **Comprehensive test coverage** (>95%) for conversion logic

### Validation Metrics

- Round-trip validation success rate: 100% for semantically preservable tags
- Performance overhead: <10% increase in encoding time
- Memory usage: <5% increase during conversion
- Test coverage: >95% for conversion components

## Risks & Mitigation

### High Risk: Breaking Existing Functionality

- **Mitigation**: Extensive regression testing, feature flags for new behavior
- **Detection**: Automated test suite must pass 100%

### Medium Risk: Complex Conversion Logic

- **Mitigation**: Start with simple cases (year/dateRecorded), iterate
- **Detection**: Code review with domain experts

### Low Risk: Performance Impact

- **Mitigation**: Profile and optimize conversion algorithms
- **Detection**: Benchmark tests in CI pipeline

## Future Considerations

### Extensibility Points

- Support for other metadata formats (Vorbis Comments, MP4 atoms)
- User-defined conversion rules
- Pluggable validation strategies

### Standards Compliance

- Ensure conversions follow ID3v2 specification
- Handle edge cases in frame format variations
- Support for extended/experimental frames

---

**Document Version**: 1.0  
**Date**: September 2, 2025  
**Author**: Development Team  
**Status**: Draft - Pending Review
