# Generic Audio Metadata Conversion System

## Overview

The Generic Audio Metadata Conversion System provides comprehensive, bidirectional conversion between different audio metadata container formats (ID3, Vorbis Comments, MP4/iTunes, APE, etc.) while preserving semantic information and handling format-specific constraints.

## Architecture

### Core Components

#### 1. **MetadataConverter Interface**
```dart
abstract interface class MetadataConverter {
  ConversionResult convertTags(sourceTags, sourceFormat, targetFormat, options);
  ConversionAnalysis analyzeConversion(sourceTags, sourceFormat, targetFormat);
}
```

#### 2. **GenericMetadataConverter Implementation**
The main conversion engine that coordinates conversion rules and manages format capabilities.

#### 3. **ConversionRule System**
Modular rules that handle specific conversion scenarios:
- `CrossFormatMappingRule`: Direct field mappings (TPE1 ↔ ARTIST ↔ ©ART)
- `DateTimeConversionRule`: Date format conversions across formats
- `MultiValueConversionRule`: Multi-value field handling
- `CapabilityDegradationRule`: Format limitation handling
- `ID3VersionTransitionRule`: ID3 version-specific conversions

#### 4. **EnhancedSemanticTagConverter**
Integration layer that bridges the new system with existing `SemanticTagConverter` for backward compatibility.

## Key Features

### ✅ **Universal Format Support**
- **Cross-format conversions**: ID3v1/v2 ↔ Vorbis ↔ MP4/iTunes ↔ APE ↔ FLAC
- **Version-specific handling**: ID3v2.2/2.3/2.4 with appropriate frame mappings
- **Capability awareness**: Understands each format's limitations and strengths

### ✅ **Intelligent Conversion Modes**
- **Permissive**: Allow data loss for successful conversion
- **Strict**: Fail if any data would be lost  
- **Conservative**: Warn about data loss but continue

### ✅ **Comprehensive Analysis**
- **Pre-conversion analysis**: Determine feasibility without performing conversion
- **Data loss assessment**: Identify which tags would be modified or dropped
- **Conversion viability rating**: Perfect/Good/Limited/Poor assessment

### ✅ **Advanced Field Handling**

#### Multi-Value Fields
```
ID3v2: Multiple TPE1 frames → Vorbis: Multiple ARTIST fields
Vorbis: Multiple ARTIST → MP4: Single ©ART with separators
APE: Null-separated values ↔ Other formats
```

#### Date/Time Conversions  
```
ID3v2.3: TYER+TDAT+TIME → ID3v2.4: TDRC (consolidated)
ID3v2.4: TDRC → Vorbis: DATE field
Cross-format date format normalization
```

#### Capability Degradation
```
Unicode → ASCII for ID3v1
Text truncation for length limits
Custom field removal for unsupported formats
```

## Usage Examples

### Basic Cross-Format Conversion

```dart
// Create converter with built-in rules
final converter = GenericMetadataConverter();

// Convert ID3v2 tags to Vorbis Comments
final result = converter.convertTags(
  id3Tags,
  (ContainerKind.id3v2, '2.4'), // Source format
  (ContainerKind.vorbis, ''),   // Target format  
  ConversionOptions(mode: ConversionMode.permissive),
);

if (result.errors.isEmpty) {
  print('Conversion successful: ${result.convertedTags.length} tags');
  print('Data preservation: ${result.isLossless ? 'Lossless' : 'Some modifications'}');
} else {
  print('Conversion errors: ${result.errors.length}');
}
```

### Pre-Conversion Analysis

```dart
// Analyze conversion feasibility before performing it
final analysis = converter.analyzeConversion(
  sourceTags,
  (ContainerKind.id3v2, '2.4'),
  (ContainerKind.id3v1, 'v1'),
);

switch (analysis.viability) {
  case ConversionViability.perfect:
    print('Perfect conversion - no data loss');
  case ConversionViability.good: 
    print('Good conversion - minor modifications');
  case ConversionViability.limited:
    print('Limited conversion - some data loss');
    print('Dropped tags: ${analysis.droppedTags}');
  case ConversionViability.poor:
    print('Poor conversion - significant data loss');
}
```

### Enhanced Integration

```dart
// Use enhanced converter for seamless integration
final enhancedConverter = EnhancedSemanticTagConverter();

// Automatically routes to appropriate conversion method
final convertedTags = enhancedConverter.convertForTargetContainers(
  sourceTags,
  [(ContainerKind.vorbis, ''), (ContainerKind.mp4, '')],
  options: ConversionOptions(
    mode: ConversionMode.conservative,
    includeCustomFields: true,
    maxTextLength: 255,
  ),
);
```

### Multiple Target Analysis

```dart
final analyses = enhancedConverter.analyzeConversionsForTargets(
  sourceTags,
  [
    (ContainerKind.id3v1, 'v1'),
    (ContainerKind.id3v2, '2.4'), 
    (ContainerKind.vorbis, ''),
    (ContainerKind.mp4, ''),
  ],
);

for (final entry in analyses.entries) {
  final format = entry.key;
  final analysis = entry.value;
  print('${format.$1.name} conversion: ${analysis.viability}');
}
```

## Integration with Existing System

### EncodingPreparation Integration

The system integrates seamlessly with the existing `EncodingPreparation` class:

```dart
// Create enhanced preparation with conversion system
final preparation = EncodingPreparation(
  enhancedConverter: EnhancedSemanticTagConverter(),
);

// Prepare tags with cross-format conversion support
final prepared = preparation.prepareTagsForEncoding(
  tags: sourceTags,
  strategy: strategy,
  capabilities: capabilities,
  conversionOptions: ConversionOptions(mode: ConversionMode.conservative),
);
```

### Backward Compatibility

The enhanced system maintains full backward compatibility:
- Simple ID3 semantic conflicts are routed to the existing `SemanticTagConverter`
- Complex cross-format scenarios use the new generic system
- All existing APIs continue to work unchanged

## Field Mapping Reference

### Cross-Format Field Mappings

| Semantic Field | ID3v2 | Vorbis | MP4 | ID3v1 |
|----------------|-------|---------|-----|-------|
| Title | TIT2 | TITLE | ©nam | title |
| Artist | TPE1 | ARTIST | ©ART | artist |
| Album | TALB | ALBUM | ©alb | album |
| Album Artist | TPE2 | ALBUMARTIST | aART | ❌ |
| Year | TYER/TDRC | DATE | ©day | year |
| Genre | TCON | GENRE | ©gen | genre |
| Track Number | TRCK | TRACKNUMBER | trkn | track |
| Disc Number | TPOS | DISCNUMBER | disk | ❌ |
| Comment | COMM | COMMENT | ©cmt | comment |
| Composer | TCOM | COMPOSER | ©wrt | ❌ |
| BPM | TBPM | BPM | tmpo | ❌ |
| Rating | POPM | RATING | rtng | ❌ |
| Artwork | APIC | ❌* | covr | ❌ |

*Vorbis uses separate PICTURE blocks in FLAC format

### Format Capabilities

| Feature | ID3v1 | ID3v2 | Vorbis | MP4 |
|---------|-------|--------|--------|-----|
| Multi-valued fields | ❌ | ✅ | ✅ | ⚠️* |
| Custom fields | ❌ | ✅ | ✅ | ✅ |
| Unicode | ❌ | ✅ | ✅ | ✅ |
| Binary data | ❌ | ✅ | ❌** | ✅ |
| Text length limits | 30 chars | None | None | None |

*Uses separators within single fields  
**Artwork handled separately in FLAC/OGG

## Extension Points

### Adding New Formats

To add support for a new format:

1. **Define Container Kind**: Add to `ContainerKind` enum if needed
2. **Create Capability**: Define `TagCapability` with format constraints  
3. **Add Field Mappings**: Update `CrossFormatMappingRule` mappings
4. **Create Specific Rules**: Implement format-specific conversion rules
5. **Register Rules**: Add to built-in rule registration

### Custom Conversion Rules

```dart
class CustomConversionRule extends BaseConversionRule {
  @override
  bool appliesTo((ContainerKind, String) source, (ContainerKind, String) target) {
    // Define when this rule applies
  }
  
  @override  
  Set<TagKey> handledTags() {
    // Return tag keys this rule processes
  }
  
  @override
  ConversionRuleResult convert(List<MetadataTag> inputTags, ConversionContext context) {
    // Implement conversion logic
  }
}

// Register custom rule
final registry = ConversionRegistry();
registry.registerRule(CustomConversionRule());
final converter = GenericMetadataConverter(registry: registry);
```

## Performance Considerations

- **Rule Selection**: Only applicable rules are executed for each conversion
- **Lazy Processing**: Tags are only processed by rules that claim to handle them
- **Capability Caching**: Format capabilities are cached and reused
- **Memory Efficiency**: In-place transformations where possible
- **Parallel Processing**: Rules can be designed for parallel execution

## Future Enhancements

The system is designed for extensibility:

- **Additional Formats**: WMA, OGG Theora, AIFF, BWF
- **Advanced Rules**: Genre mapping, rating scale conversions, artwork format handling
- **Machine Learning**: Intelligent genre/mood inference and mapping
- **Validation**: Enhanced data integrity checking across conversions
- **Performance**: Parallelization and optimization for large tag sets

This comprehensive conversion system transforms the limited, hardcoded approach into a flexible, universal audio metadata conversion framework that handles any format combination while maintaining strict validation and optimal data preservation.
