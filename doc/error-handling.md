# Error Handling

This guide covers comprehensive error handling strategies when working with Phonic, including exception types, recovery strategies, and best practices.

## Exception Hierarchy

Phonic uses a structured exception hierarchy for different error conditions:

```
PhonicException (base class)
├── UnsupportedFormatException
├── CorruptedContainerException
├── TagValidationException
└── (Other specialized exceptions)
```

## Core Exception Types

### PhonicException

Base class for all Phonic-specific exceptions:

```dart
try {
  final audioFile = await Phonic.fromFileAsync('song.mp3');
  // ... use audioFile
} on PhonicException catch (e) {
  print('Phonic error: ${e.message}');
  if (e.context != null) {
    print('Context: ${e.context}');
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

### UnsupportedFormatException

Thrown when file format is not supported:

```dart
try {
  final audioFile = await Phonic.fromFileAsync('video.mp4');
} on UnsupportedFormatException catch (e) {
  print('Format not supported: ${e.message}');
  print('File: ${e.filePath}');
  print('Detected format: ${e.detectedFormat}');

  // Suggest alternatives
  if (e.suggestedFormats.isNotEmpty) {
    print('Supported formats: ${e.suggestedFormats.join(', ')}');
  }
}
```

### CorruptedContainerException

Thrown when file structure is corrupted or invalid:

```dart
try {
  final audioFile = await Phonic.fromFileAsync('corrupted.mp3');
} on CorruptedContainerException catch (e) {
  print('File is corrupted: ${e.message}');
  print('Container type: ${e.containerKind}');
  print('Error location: byte ${e.offsetInFile}');

  // Attempt recovery if possible
  if (e.isRecoverable) {
    print('Attempting recovery...');
    try {
      final recovered = await _attemptRecovery(e);
      // Use recovered data
    } catch (recoveryError) {
      print('Recovery failed: $recoveryError');
    }
  }
}
```

### TagValidationException

Thrown when tag values fail validation:

```dart
try {
  audioFile.setTag(RatingTag(-5)); // Invalid rating
} on TagValidationException catch (e) {
  print('Invalid tag value: ${e.message}');
  print('Field: ${e.fieldName}');
  print('Invalid value: ${e.invalidValue}');
  print('Valid range: ${e.validRange}');

  // Provide corrected value
  if (e.suggestedValue != null) {
    print('Suggested value: ${e.suggestedValue}');
    audioFile.setTag(RatingTag(e.suggestedValue as int));
  }
}
```

## File System Error Handling

### File Access Errors

```dart
Future<PhonicAudioFile?> safeFileLoad(String filePath) async {
  try {
    return await Phonic.fromFileAsync(filePath);

  } on FileSystemException catch (e) {
    switch (e.osError?.errorCode) {
      case 2: // File not found (Unix/Windows)
        print('File not found: $filePath');
        return null;

      case 13: // Permission denied (Unix)
      case 5:  // Access denied (Windows)
        print('Permission denied: $filePath');
        // Maybe try to change permissions or run as administrator
        return null;

      case 28: // No space left on device
        print('Disk space full');
        return null;

      default:
        print('File system error ${e.osError?.errorCode}: ${e.message}');
        return null;
    }

  } on PathNotFoundException catch (e) {
    print('Path not found: ${e.path}');
    return null;

  } on PathAccessException catch (e) {
    print('Path access error: ${e.path} - ${e.message}');
    return null;
  }
}
```

### Directory Operations

```dart
Future<List<String>> safeDirectoryScan(String directoryPath) async {
  final audioFiles = <String>[];

  try {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      print('Directory does not exist: $directoryPath');
      return audioFiles;
    }

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();
        if (['.mp3', '.flac', '.ogg', '.opus', '.m4a', '.mp4'].contains(extension)) {
          audioFiles.add(entity.path);
        }
      }
    }

  } on FileSystemException catch (e) {
    print('Error scanning directory: ${e.message}');
  } on PathNotFoundException catch (e) {
    print('Directory path not found: ${e.path}');
  }

  return audioFiles;
}
```

## Memory and Performance Error Handling

### Memory Pressure Handling

```dart
Future<void> memoryAwareProcessing(List<String> files) async {
  final memoryMonitor = MemoryUsageMonitor();

  try {
    for (final filePath in files) {
      // Check memory before processing each file
      final memoryInfo = memoryMonitor.getCurrentUsage();

      if (memoryInfo.usagePercent > 80.0) {
        print('High memory usage detected: ${memoryInfo.usagePercent.toStringAsFixed(1)}%');

        // Force garbage collection
        print('Forcing garbage collection...');
        memoryMonitor.forceGarbageCollection();

        // Wait a bit for GC to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Check again
        final afterGC = memoryMonitor.getCurrentUsage();
        if (afterGC.usagePercent > 85.0) {
          print('Memory pressure still high, pausing processing');
          throw OutOfMemoryError('Memory pressure too high: ${afterGC.usagePercent.toStringAsFixed(1)}%');
        }
      }

      // Process file with memory monitoring
      await _processFileWithMemoryChecks(filePath, memoryMonitor);
    }

  } finally {
    memoryMonitor.dispose();
  }
}

Future<void> _processFileWithMemoryChecks(String filePath, MemoryUsageMonitor monitor) async {
  PhonicAudioFile? audioFile;

  try {
    audioFile = await Phonic.fromFileAsync(filePath);

    // Check memory after loading
    if (monitor.getCurrentUsage().usagePercent > 90.0) {
      throw OutOfMemoryError('Memory limit exceeded after loading $filePath');
    }

    // Process the file...
    // Your processing logic here

  } finally {
    // Always dispose to free memory
    audioFile?.dispose();
  }
}
```

### Timeout Handling

```dart
Future<PhonicAudioFile?> loadWithTimeout(String filePath, {Duration timeout = const Duration(seconds: 30)}) async {
  try {
    return await Phonic.fromFileAsync(filePath).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException('File loading timed out', timeout);
      },
    );

  } on TimeoutException catch (e) {
    print('Timeout loading file: $filePath (${e.duration})');
    return null;
  }
}
```

## Batch Processing Error Handling

### Resilient Batch Processing

```dart
class ProcessingResults {
  final List<String> successful = [];
  final List<ProcessingError> errors = [];
  final List<String> skipped = [];

  int get totalProcessed => successful.length + errors.length + skipped.length;
  double get successRate => successful.length / totalProcessed;
}

class ProcessingError {
  final String filePath;
  final String error;
  final Exception? exception;

  ProcessingError(this.filePath, this.error, [this.exception]);
}

Future<ProcessingResults> processBatchResilient(List<String> filePaths) async {
  final results = ProcessingResults();

  for (final filePath in filePaths) {
    try {
      final success = await _processSingleFileResilient(filePath);
      if (success) {
        results.successful.add(filePath);
      } else {
        results.skipped.add(filePath);
      }

    } on UnsupportedFormatException catch (e) {
      results.errors.add(ProcessingError(filePath, 'Unsupported format: ${e.message}', e));

    } on CorruptedContainerException catch (e) {
      results.errors.add(ProcessingError(filePath, 'Corrupted file: ${e.message}', e));

    } on FileSystemException catch (e) {
      results.errors.add(ProcessingError(filePath, 'File system error: ${e.message}', e));

    } on OutOfMemoryError catch (e) {
      print('Out of memory, stopping batch processing');
      results.errors.add(ProcessingError(filePath, 'Out of memory: ${e.message}', e));
      break; // Stop processing on memory errors

    } catch (e) {
      results.errors.add(ProcessingError(filePath, 'Unexpected error: $e',
          e is Exception ? e : Exception(e.toString())));
    }

    // Brief pause to allow system recovery
    if (results.totalProcessed % 100 == 0) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  return results;
}

Future<bool> _processSingleFileResilient(String filePath) async {
  PhonicAudioFile? audioFile;

  try {
    audioFile = await loadWithTimeout(filePath);
    if (audioFile == null) {
      return false; // Skip file that couldn't be loaded
    }

    // Validate file has minimum required metadata
    final title = audioFile.getTag(TagKey.title);
    final artist = audioFile.getTag(TagKey.artist);

    if (title == null && artist == null) {
      print('Skipping file with no metadata: $filePath');
      return false;
    }

    // Process the file
    // ... your processing logic here ...

    return true;

  } finally {
    audioFile?.dispose();
  }
}
```

## Error Recovery Strategies

### Automatic Recovery

```dart
Future<PhonicAudioFile?> loadWithRecovery(String filePath, {int maxRetries = 3}) async {
  Exception? lastException;

  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      if (attempt > 0) {
        print('Retry attempt $attempt for $filePath');
        // Brief delay before retry
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }

      return await Phonic.fromFileAsync(filePath);

    } on CorruptedContainerException catch (e) {
      lastException = e;

      if (e.isRecoverable) {
        print('Attempting to recover corrupted file: $filePath');

        try {
          // Try recovery-specific logic
          final recovered = await _attemptFileRecovery(filePath, e);
          if (recovered != null) {
            return recovered;
          }
        } catch (recoveryError) {
          print('Recovery attempt failed: $recoveryError');
        }
      }

    } on FileSystemException catch (e) {
      lastException = e;

      // For temporary file system issues, retry might work
      if (_isTemporaryFileSystemError(e)) {
        print('Temporary file system error, will retry: ${e.message}');
        continue;
      } else {
        // Permanent error, don't retry
        break;
      }

    } on Exception catch (e) {
      lastException = e;
      print('Error loading file (attempt ${attempt + 1}): $e');
    }
  }

  print('Failed to load file after $maxRetries attempts: $filePath');
  if (lastException != null) {
    print('Last error: $lastException');
  }

  return null;
}

bool _isTemporaryFileSystemError(FileSystemException e) {
  // Check for specific error codes that might be temporary
  return e.osError?.errorCode == 11 || // Resource temporarily unavailable
         e.osError?.errorCode == 26 || // Text file busy
         e.message.contains('temporarily');
}

Future<PhonicAudioFile?> _attemptFileRecovery(String filePath, CorruptedContainerException error) async {
  // Implementation would depend on the specific corruption type
  // This is a placeholder for recovery logic
  print('Attempting recovery for corruption at byte ${error.offsetInFile}');

  try {
    // Read file and try to fix corruption
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Apply corruption-specific fixes
    final fixed = _applyCorruptionFixes(bytes, error);
    if (fixed != null) {
      return Phonic.fromBytes(fixed, filePath);
    }
  } catch (e) {
    print('Recovery attempt failed: $e');
  }

  return null;
}

Uint8List? _applyCorruptionFixes(Uint8List bytes, CorruptedContainerException error) {
  // This would contain format-specific corruption repair logic
  // For now, return null to indicate recovery not possible
  return null;
}
```

### User Interaction for Errors

```dart
Future<void> interactiveErrorHandling(List<String> files) async {
  for (final filePath in files) {
    try {
      final audioFile = await Phonic.fromFileAsync(filePath);
      // Process file...
      audioFile.dispose();

    } on UnsupportedFormatException catch (e) {
      print('\\nUnsupported format: $filePath');
      print('Error: ${e.message}');
      print('Options:');
      print('  1. Skip this file');
      print('  2. Skip all unsupported files');
      print('  3. Stop processing');

      final choice = _getUserChoice(['1', '2', '3']);

      switch (choice) {
        case '1':
          continue; // Skip this file
        case '2':
          // Set flag to skip all unsupported files
          return; // or implement skip logic
        case '3':
          return; // Stop processing
      }

    } on CorruptedContainerException catch (e) {
      print('\\nCorrupted file: $filePath');
      print('Error: ${e.message}');

      if (e.isRecoverable) {
        print('Attempt recovery? (y/n)');
        if (_getUserChoice(['y', 'n']) == 'y') {
          try {
            final recovered = await _attemptFileRecovery(filePath, e);
            if (recovered != null) {
              print('Recovery successful!');
              // Continue with recovered file
              recovered.dispose();
              continue;
            } else {
              print('Recovery failed.');
            }
          } catch (recoveryError) {
            print('Recovery error: $recoveryError');
          }
        }
      }

      print('Skip this file? (y/n)');
      if (_getUserChoice(['y', 'n']) == 'y') {
        continue;
      } else {
        return; // Stop processing
      }
    }
  }
}

String _getUserChoice(List<String> validChoices) {
  while (true) {
    final input = stdin.readLineSync()?.toLowerCase();
    if (input != null && validChoices.contains(input)) {
      return input;
    }
    print('Invalid choice. Please enter one of: ${validChoices.join(', ')}');
  }
}
```

## Validation and Defensive Programming

### Input Validation

```dart
class AudioFileValidator {
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int minFileSizeBytes = 1024; // 1KB

  static ValidationResult validateFile(String filePath) {
    final file = File(filePath);

    // Check file exists
    if (!file.existsSync()) {
      return ValidationResult.error('File does not exist: $filePath');
    }

    // Check file size
    final stat = file.statSync();
    if (stat.size < minFileSizeBytes) {
      return ValidationResult.error('File too small: ${stat.size} bytes');
    }

    if (stat.size > maxFileSizeBytes) {
      return ValidationResult.warning('File very large: ${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB');
    }

    // Check file extension
    final extension = path.extension(filePath).toLowerCase();
    const supportedExtensions = ['.mp3', '.flac', '.ogg', '.opus', '.m4a', '.mp4'];

    if (!supportedExtensions.contains(extension)) {
      return ValidationResult.warning('Unusual file extension: $extension');
    }

    return ValidationResult.success();
  }

  static ValidationResult validateTagValue(TagKey key, dynamic value) {
    switch (key) {
      case TagKey.rating:
        if (value is! int || value < 0 || value > 100) {
          return ValidationResult.error('Rating must be 0-100, got: $value');
        }
        break;

      case TagKey.trackNumber:
      case TagKey.discNumber:
        if (value is! int || value < 1) {
          return ValidationResult.error('${key.name} must be positive integer, got: $value');
        }
        break;

      case TagKey.year:
        if (value is! int || value < 1900 || value > DateTime.now().year + 1) {
          return ValidationResult.error('Year must be reasonable value, got: $value');
        }
        break;

      case TagKey.bpm:
        if (value is! int || value < 1 || value > 300) {
          return ValidationResult.error('BPM must be 1-300, got: $value');
        }
        break;
    }

    return ValidationResult.success();
  }
}

class ValidationResult {
  final bool isValid;
  final String? message;
  final ValidationLevel level;

  ValidationResult._(this.isValid, this.message, this.level);

  factory ValidationResult.success() => ValidationResult._(true, null, ValidationLevel.success);
  factory ValidationResult.warning(String message) => ValidationResult._(true, message, ValidationLevel.warning);
  factory ValidationResult.error(String message) => ValidationResult._(false, message, ValidationLevel.error);
}

enum ValidationLevel { success, warning, error }
```

### Safe Tag Operations

```dart
extension SafeTagOperations on PhonicAudioFile {
  bool setTagSafely(MetadataTag tag) {
    try {
      // Validate tag value
      final validation = AudioFileValidator.validateTagValue(tag.key, tag.value);
      if (!validation.isValid) {
        print('Tag validation failed: ${validation.message}');
        return false;
      }

      if (validation.level == ValidationLevel.warning) {
        print('Tag validation warning: ${validation.message}');
      }

      setTag(tag);
      return true;

    } on TagValidationException catch (e) {
      print('Tag validation error: ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error setting tag: $e');
      return false;
    }
  }

  T? getTagSafely<T extends MetadataTag>(TagKey key) {
    try {
      return getTag(key) as T?;
    } catch (e) {
      print('Error getting tag $key: $e');
      return null;
    }
  }
}

// Usage
if (audioFile.setTagSafely(RatingTag(85))) {
  print('Rating set successfully');
} else {
  print('Failed to set rating');
}

final title = audioFile.getTagSafely<TitleTag>(TagKey.title);
```

## Logging and Monitoring

### Error Logging

```dart
class ErrorLogger {
  final List<LogEntry> _entries = [];
  final int maxEntries;

  ErrorLogger({this.maxEntries = 1000});

  void logError(String operation, Exception error, {Map<String, dynamic>? context}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      operation: operation,
      message: error.toString(),
      context: context,
    );

    _addEntry(entry);
    print('ERROR [$operation]: ${error.toString()}');

    if (context != null) {
      print('Context: $context');
    }
  }

  void logWarning(String operation, String message, {Map<String, dynamic>? context}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      operation: operation,
      message: message,
      context: context,
    );

    _addEntry(entry);
    print('WARNING [$operation]: $message');
  }

  void _addEntry(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  List<LogEntry> getRecentErrors({Duration? since}) {
    if (since == null) return List.from(_entries);

    final cutoff = DateTime.now().subtract(since);
    return _entries.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }

  void exportToFile(String filePath) async {
    final file = File(filePath);
    final buffer = StringBuffer();

    for (final entry in _entries) {
      buffer.writeln('${entry.timestamp.toIso8601String()} [${entry.level.name.toUpperCase()}] ${entry.operation}: ${entry.message}');
      if (entry.context != null) {
        buffer.writeln('  Context: ${entry.context}');
      }
    }

    await file.writeAsString(buffer.toString());
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String operation;
  final String message;
  final Map<String, dynamic>? context;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.operation,
    required this.message,
    this.context,
  });
}

enum LogLevel { info, warning, error }

// Usage
final logger = ErrorLogger();

try {
  final audioFile = await Phonic.fromFileAsync(filePath);
  // ...
} on UnsupportedFormatException catch (e) {
  logger.logError('loadFile', e, context: {'filePath': filePath});
} on CorruptedContainerException catch (e) {
  logger.logError('loadFile', e, context: {
    'filePath': filePath,
    'offset': e.offsetInFile,
    'containerKind': e.containerKind.toString(),
  });
}

// Export error log
await logger.exportToFile('error_log.txt');
```

## Next Steps

- **[Best Practices](best-practices.md)** - Overall best practices for using Phonic
- **[Performance Optimization](performance-optimization.md)** - Memory and performance considerations
- **[Examples](examples.md)** - Complete error handling examples
