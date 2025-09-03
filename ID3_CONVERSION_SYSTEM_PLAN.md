# Generic Audio Metadata Conversion System - Implementation Plan

## Problem Statement

The current implementation only handles Year ↔ DateRecorded conversion for ID3, but audio files use multiple container formats (ID3, Vorbis Comments, MP4/iTunes, APE, etc.) with different tag naming conventions, data types, and capabilities. We need a **generic, bidirectional conversion system** that can handle conversions between **any container formats** and their versions dynamically.

## Core Issues to Solve

### 1. **Cross-Container Format Conversion**

Different container formats use completely different field names and structures:

```
Semantic Concept: "Artist"
├── ID3v1/v2: TPE1 frame
├── Vorbis Comments: ARTIST field
├── MP4/iTunes: ©ART atom
├── APE: Artist field
└── FLAC: ARTIST field (Vorbis-style)
```

### 2. **Multi-Frame to Single-Frame Consolidation (ID3v2.3 → ID3v2.4)**

ID3v2.3 uses multiple frames for date/time information that get consolidated into single frames in ID3v2.4:

```
ID3v2.3                    ID3v2.4
--------                   -------
TYER (Year)       ┐
TDAT (Date)       ├────→   TDRC (Recording Date)
TIME (Time)       ┘
TRDA (Recording)  ────→    TDRC (Recording Date)
TORY (Original)   ────→    TDOR (Original Release)
```

### 3. **Container-Specific Data Type Handling**

Different formats support different data types and structures:

```
Multi-valued fields:
├── ID3v2: Multiple frames (e.g., multiple TPE1 frames)
├── Vorbis: Multiple ARTIST=value entries
├── MP4: Single field with separator (Artist1/Artist2)
└── APE: Single field with null separators

Date formats:
├── ID3v2.4: ISO-8601 (YYYY-MM-DDTHH:MM:SS)
├── Vorbis: ISO-8601 or partial (YYYY, YYYY-MM, etc.)
├── MP4: iTunes date format
└── ID3v1: 4-digit year only
```

### 4. **Container Capability Limitations**

Each format has different capabilities that require graceful degradation:

```
Feature Support Matrix:
                   ID3v1  ID3v2  Vorbis  MP4   APE
                   -----  -----  ------  ---   ---
Multi-valued       ❌     ✅     ✅      ⚠️    ✅
Custom fields      ❌     ✅     ✅      ⚠️    ✅
Unicode            ❌     ✅     ✅      ✅    ✅
Binary data        ❌     ✅     ❌      ✅    ✅
Long text          ❌     ✅     ✅      ✅    ✅
```

### 5. **Semantic Equivalence Across Formats**

Same information represented differently:

```
Album Artist concept:
├── ID3v2.3: TPE2 (Band/Orchestra/Accompaniment)
├── ID3v2.4: TPE2 (Band/Orchestra/Accompaniment)
├── Vorbis: ALBUMARTIST
├── MP4: aART (Album Artist)
└── APE: AlbumArtist or Album Artist
```

### 6. **Cross-Format Conversion Requirements**

Support all format combinations:

- **ID3 (v1/v2.2/v2.3/v2.4)** ↔ **Vorbis Comments** ↔ **MP4/iTunes** ↔ **APE** ↔ **FLAC**
- Graceful degradation when target format doesn't support certain features
- Data validation and conflict resolution across different paradigms

### 7. **Validation Modes**

- **Permissive**: Allow data loss, choose best available representation
- **Strict**: Fail if data cannot be represented exactly in target format
- **Conservative**: Warn about potential data loss but continue

## Proposed Architecture

### Core Components

#### 1. **MetadataConverter** (Main Interface)

```dart
abstract class MetadataConverter {
  /// Convert tags from source format to target format
  ConversionResult convertTags(
    List<MetadataTag> sourceTags,
    ContainerFormat sourceFormat,
    ContainerFormat targetFormat,
    ConversionOptions options,
  );

  /// Check if conversion is possible without data loss
  ConversionAnalysis analyzeConversion(
    List<MetadataTag> sourceTags,
    ContainerFormat sourceFormat,
    ContainerFormat targetFormat,
  );
}
```

#### 2. **ConversionRule** (Individual Conversion Logic)

```dart
abstract class ConversionRule {
  /// Which format combinations this rule applies to
  bool appliesTo(ContainerFormat source, ContainerFormat target);

  /// Tags this rule can handle
  Set<TagKey> handledTags();

  /// Perform the conversion
  ConversionRuleResult convert(
    List<MetadataTag> inputTags,
    ConversionContext context,
  );

  /// Check if conversion is lossless
  ConversionLossAssessment assessLoss(
    List<MetadataTag> inputTags,
    ConversionContext context,
  );
}
```

#### 3. **Container Format Definitions**

```dart
enum ContainerFormat {
  id3v1,
  id3v22,
  id3v23,
  id3v24,
  vorbisComments,
  mp4iTunes,
  ape,
  flacVorbis,
}

class ContainerCapabilities {
  final bool supportsMultiValue;
  final bool supportsCustomFields;
  final bool supportsUnicode;
  final bool supportsBinaryData;
  final int? maxTextLength;
  final Set<TagKey> supportedTags;
}
```

#### 4. **Specific Conversion Rules**

##### **CrossFormatMappingRule** (ID3 ↔ Vorbis ↔ MP4 ↔ APE)

```dart
class CrossFormatMappingRule extends ConversionRule {
  // Handles: TPE1 ↔ ARTIST ↔ ©ART ↔ Artist
  // Handles: TIT2 ↔ TITLE ↔ ©nam ↔ Title
  // Handles: TALB ↔ ALBUM ↔ ©alb ↔ Album
}
```

##### **DateTimeConversionRule** (Cross-format date handling)

```dart
class DateTimeConversionRule extends ConversionRule {
  // ID3v2.3: TYER+TDAT+TIME → ID3v2.4: TDRC
  // ID3v2.4: TDRC → Vorbis: DATE
  // Vorbis: DATE → MP4: ©day
  // Handle different date format requirements
}
```

##### **MultiValueConversionRule** (Multi-value field handling)

```dart
class MultiValueConversionRule extends ConversionRule {
  // ID3v2: Multiple TPE1 frames → Vorbis: Multiple ARTIST fields
  // Vorbis: Multiple ARTIST → MP4: Single ©ART with separators
  // APE: Null-separated values ↔ Other formats
}
```

##### **CapabilityDegradationRule** (Handle format limitations)

```dart
class CapabilityDegradationRule extends ConversionRule {
  // Unicode → ASCII conversion for ID3v1
  // Long text truncation for limited formats
  // Custom field removal for unsupported formats
}
```

##### **ID3VersionTransitionRule** (ID3-specific version changes)

```dart
class ID3VersionTransitionRule extends ConversionRule {
  // ID3v2.2: TT2 → ID3v2.3/2.4: TIT2
  // ID3v2.3 multi-frame → ID3v2.4 consolidated
}
```

##### **VorbisSpecificRule** (Vorbis-specific conversions)

```dart
class VorbisSpecificRule extends ConversionRule {
  // Handle ALBUMARTIST vs ALBUM_ARTIST variations
  // TRACKNUMBER vs TRACKTOTAL handling
  // Case-insensitive field matching
}
```

##### **MP4SpecificRule** (MP4/iTunes-specific conversions)

```dart
class MP4SpecificRule extends ConversionRule {
  // iTunes-specific atoms (rtng, stik, etc.)
  // Artwork format conversions
  // Genre handling (text vs numeric)
}
```

#### 5. **ConversionRegistry**

```dart
class ConversionRegistry {
  void registerRule(ConversionRule rule);
  List<ConversionRule> getRulesFor(ContainerFormat source, ContainerFormat target);

  // Built-in rule sets for different scenarios
  void registerCrossFormatRules();
  void registerID3TransitionRules();
  void registerCapabilityRules();
}
```

### Data Structures

#### **ConversionContext**

```dart
class ConversionContext {
  final ContainerFormat sourceFormat;
  final ContainerFormat targetFormat;
  final ConversionMode mode;
  final ContainerCapabilities sourceCapabilities;
  final ContainerCapabilities targetCapabilities;
  final Map<String, dynamic> options;
}

enum ConversionMode {
  permissive,  // Allow data loss
  strict,      // Fail on any data loss
  conservative // Warn but continue
}
```

#### **ConversionResult**

```dart
class ConversionResult {
  final List<MetadataTag> convertedTags;
  final List<ConversionWarning> warnings;
  final List<ConversionError> errors;
  final bool isLossless;
  final ConversionSummary summary;
  final Map<TagKey, ConversionAction> appliedConversions;
}

enum ConversionAction {
  directMapping,     // 1:1 field mapping
  consolidation,     // Multiple → Single
  expansion,         // Single → Multiple
  dataTypeChange,    // String → Number, etc.
  truncation,        // Data loss due to limits
  customLogic,       // Complex rule applied
}
```

## Implementation Strategy

### Phase 1: Foundation

1. **Define Core Interfaces** (`MetadataConverter`, `ConversionRule`, etc.)
2. **Create Container Format Definitions** (Capabilities, format enums)
3. **Build ConversionRegistry** with rule registration/lookup system
4. **Implement Base ConversionRule** with common functionality

### Phase 2: Cross-Format Mapping Rules

1. **CrossFormatMappingRule** (Replace current hardcoded logic)
   - ID3: TPE1, TIT2, TALB → Vorbis: ARTIST, TITLE, ALBUM
   - Vorbis: ARTIST, TITLE, ALBUM → MP4: ©ART, ©nam, ©alb
   - APE: Artist, Title, Album ↔ other formats
2. **MultiValueConversionRule**
   - Handle different multi-value representations
3. **DateTimeConversionRule** (Enhanced for all formats)
   - ID3 date variations → standardized representations
   - Cross-format date format conversions

### Phase 3: Format-Specific Rules

1. **ID3VersionTransitionRule**
   - ID3v2.2 ↔ ID3v2.3/2.4 frame name changes
   - ID3v2.3 multi-frame ↔ ID3v2.4 consolidated frames
2. **CapabilityDegradationRule**
   - Unicode → ASCII for limited formats
   - Text truncation for length limits
   - Custom field handling
3. **VorbisSpecificRule** & **MP4SpecificRule**
   - Format-specific field variations
   - Special atom/field handling

### Phase 4: Advanced Features & Integration

1. **Complex Conversion Scenarios**
   - Genre mapping (numeric ↔ text ↔ custom)
   - Artwork format conversions
   - Rating system conversions (0-255 ↔ 1-5 ↔ percentage)
2. **Update EncodingPreparation** to use new conversion system
3. **Update PostWriteValidator** to understand cross-format conversions
4. **Comprehensive Testing** with all format combinations

## Example: Cross-Format Conversion Implementation

### ID3v2.4 → Vorbis Comments (Cross-Format)

```dart
class CrossFormatMappingRule extends ConversionRule {
  static const _fieldMappings = {
    // ID3v2 → Vorbis mappings
    (ContainerFormat.id3v24, ContainerFormat.vorbisComments): {
      TagKey.title: 'TITLE',
      TagKey.artist: 'ARTIST',
      TagKey.album: 'ALBUM',
      TagKey.albumArtist: 'ALBUMARTIST',
      TagKey.date: 'DATE',
      TagKey.genre: 'GENRE',
      TagKey.trackNumber: 'TRACKNUMBER',
    },
    // Vorbis → MP4 mappings
    (ContainerFormat.vorbisComments, ContainerFormat.mp4iTunes): {
      TagKey.title: '©nam',
      TagKey.artist: '©ART',
      TagKey.album: '©alb',
      TagKey.albumArtist: 'aART',
      TagKey.date: '©day',
      TagKey.genre: '©gen',
    },
  };

  @override
  ConversionRuleResult convert(List<MetadataTag> inputTags, ConversionContext context) {
    final mappings = _fieldMappings[(context.sourceFormat, context.targetFormat)];
    if (mappings == null) return ConversionRuleResult.noChange();

    final result = <MetadataTag>[];
    final applied = <TagKey, ConversionAction>{};

    for (final tag in inputTags) {
      if (mappings.containsKey(tag.key)) {
        // Handle multi-value conversion
        if (_requiresMultiValueConversion(tag, context)) {
          final converted = _convertMultiValue(tag, context);
          result.addAll(converted);
          applied[tag.key] = ConversionAction.dataTypeChange;
        } else {
          // Direct mapping
          result.add(_mapTag(tag, mappings[tag.key]!, context));
          applied[tag.key] = ConversionAction.directMapping;
        }
      } else {
        // Check if target format supports this tag
        if (context.targetCapabilities.supportedTags.contains(tag.key)) {
          result.add(tag);
        } else if (context.mode == ConversionMode.strict) {
          return ConversionRuleResult.error('Tag ${tag.key} not supported in target format');
        }
        // In permissive mode, unsupported tags are simply dropped
      }
    }

    return ConversionRuleResult.success(result, applied);
  }
}
```

### Multi-Value Conversion Example

```dart
class MultiValueConversionRule extends ConversionRule {
  ConversionRuleResult _convertMultiValue(MetadataTag tag, ConversionContext context) {
    switch ((context.sourceFormat, context.targetFormat)) {
      // ID3v2 multiple frames → Vorbis multiple fields (no change needed)
      case (ContainerFormat.id3v24, ContainerFormat.vorbisComments):
        return ConversionRuleResult.success([tag]);

      // Vorbis multiple fields → MP4 separator-delimited single field
      case (ContainerFormat.vorbisComments, ContainerFormat.mp4iTunes):
        if (tag is MultiValueTag) {
          final combined = tag.values.join(' / ');
          return ConversionRuleResult.success([
            _createMP4Tag(tag.key, combined)
          ], {tag.key: ConversionAction.consolidation});
        }

      // MP4 separator-delimited → APE null-separated
      case (ContainerFormat.mp4iTunes, ContainerFormat.ape):
        if (tag.value is String && (tag.value as String).contains(' / ')) {
          final values = (tag.value as String).split(' / ');
          final combined = values.join('\0'); // APE uses null separators
          return ConversionRuleResult.success([
            _createAPETag(tag.key, combined)
          ], {tag.key: ConversionAction.dataTypeChange});
        }
    }

    return ConversionRuleResult.noChange();
  }
}
```

## Integration Points

### 1. **EncodingPreparation Integration**

Replace current `SemanticTagConverter` usage:

```dart
// Instead of:
final convertedTags = _semanticConverter.convertForTargetVersion(tags, strategy.fanout);

// Use:
final conversionResults = <MetadataTag>[];
for (final (containerKind, version) in strategy.fanout) {
  final targetFormat = _mapToContainerFormat(containerKind, version);
  final conversionResult = _metadataConverter.convertTags(
    tags,
    detectedSourceFormat,
    targetFormat,
    ConversionOptions(mode: ConversionMode.permissive)
  );
  conversionResults.addAll(conversionResult.convertedTags);
}
```

### 2. **PostWriteValidator Integration**

Update validation to understand cross-format conversions:

```dart
bool _isAcceptableConversion(MetadataTag original, MetadataTag extracted,
                           ContainerFormat sourceFormat, ContainerFormat targetFormat) {
  final analysis = _metadataConverter.analyzeConversion(
    [original],
    sourceFormat,
    targetFormat
  );
  return analysis.wouldConvertTo(extracted) ||
         analysis.wouldBeDropped(original.key); // Handle capability limitations
}
```

### 3. **Multi-Container File Handling**

When files have multiple containers (e.g., MP3 with both ID3v1 and ID3v2.4):

```dart
// Convert tags appropriately for each target container
final id3v1Tags = converter.convertTags(sourceTags, sourceFormat, ContainerFormat.id3v1, options);
final id3v24Tags = converter.convertTags(sourceTags, sourceFormat, ContainerFormat.id3v24, options);

// Validate that essential information is preserved in all formats
_validateCrossContainerConsistency(id3v1Tags.convertedTags, id3v24Tags.convertedTags);
```

## Benefits of This Approach

### ✅ **Universal Format Support**

- Handles **all** major audio metadata formats (ID3, Vorbis, MP4, APE, FLAC)
- Bidirectional conversion between any format combinations
- Unified handling regardless of source/target format

### ✅ **Extensibility**

- Easy to add new container formats (e.g., future standards)
- Pluggable rule system for custom conversion logic
- Format-specific rules can be added independently

### ✅ **Capability Awareness**

- Understands each format's limitations and strengths
- Graceful degradation when converting to limited formats
- Intelligent multi-value handling based on format support

### ✅ **Maintainability**

- Each conversion rule is isolated and testable
- Clear separation between format-specific and cross-format logic
- Self-documenting rule system with clear responsibilities

### ✅ **Flexibility**

- Different validation modes (strict/permissive/conservative)
- Configurable conversion options per use case
- Detailed reporting of what conversions were applied

### ✅ **Correctness**

- Comprehensive validation before conversion
- Detailed error reporting with specific failure reasons
- Lossless conversion detection across all formats

## Migration Strategy

### Step 1: Create New System (Parallel)

- Implement new conversion system alongside existing code
- Comprehensive unit tests for each conversion rule
- Integration tests for all format combinations
- Capability testing for format-specific limitations

### Step 2: Gradual Integration

- Update EncodingPreparation to use new system
- Update PostWriteValidator with cross-format awareness
- Keep existing logic as fallback initially
- Add conversion result logging and monitoring

### Step 3: Complete Migration

- Remove old SemanticTagConverter logic
- Remove all hardcoded format-specific handling
- Full test suite validation across all supported formats
- Performance optimization for common conversion paths

### Step 4: Extended Format Support

- Add support for additional formats (WMA, OGG Theora, etc.)
- Implement format-specific optimization rules
- Add user-configurable conversion preferences

This approach transforms the hardcoded, limited system into a **comprehensive, universal audio metadata conversion framework** that can handle conversions between **any audio container formats** while maintaining strict validation, detailed error reporting, and optimal data preservation across all scenarios.
