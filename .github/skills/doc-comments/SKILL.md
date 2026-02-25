---
name: doc-comments
description: Guidelines for writing documentation comments and inline comments in Dart/Flutter code. Use when documenting classes, methods, providers, errors, or writing inline comments. Enforces principles like avoiding usage examples, avoiding 'typically used by' sections, avoiding step numbers in comments, and focusing on contracts over usage.
---

# Documentation and Comment Guidelines

## When to Use This Skill

Use this skill when:
- Writing doc comments for classes, interfaces, methods, or functions
- Documenting error types and their cases
- Creating provider documentation
- Writing inline comments in implementation code
- Reviewing or improving existing documentation

## Core Principles

1. **Be Descriptive, Not Prescriptive**: Explain what something does and why it exists, not how to use it
2. **Document Contracts**: Focus on inputs, outputs, errors, and behavior
3. **Avoid Redundancy**: Don't duplicate information available through IDE features (type hints, autocomplete, Find Usages)
4. **Prevent Staleness**: Avoid documentation that becomes obsolete with code changes
5. **Add Value**: Only document what provides genuine insight beyond the code itself

## What NOT to Include in Documentation

### ❌ Usage Examples

Never include code examples showing how to use the documented element.

**Why:** Usage examples become outdated quickly and are redundant with IDE autocomplete and type information.

**Bad:**
```dart
/// Provider for the audio file validation use case.
///
/// Usage example:
/// ```dart
/// final useCase = ref.read(validateAudioFileUseCaseProvider);
/// final result = await useCase(file: File('/path/to/audio.mp3'));
/// ```
final validateAudioFileUseCaseProvider = Provider<ValidateAudioFileUseCase>(...);
```

**Good:**
```dart
/// Provider for the audio file validation use case.
///
/// Provides an instance of [ValidateAudioFileUseCase] that validates
/// whether a file exists, is accessible, and can be read. The use case is
/// stateless and can be safely shared across the application.
final validateAudioFileUseCaseProvider = Provider<ValidateAudioFileUseCase>(...);
```

### ❌ "Typically Used By" Sections

Never list which parts of the codebase use the documented element.

**Why:** Dependencies change frequently, and the IDE's "Find Usages" feature provides this information dynamically.

**Bad:**
```dart
/// Provider for the file accessibility validation use case.
///
/// This provider is typically used by:
/// - Import workflows to pre-validate files before processing
/// - Controllers that need to verify file accessibility before operations
/// - Background services that check file integrity
final validateFileAccessibilityUseCaseProvider = Provider<ValidateFileAccessibilityUseCase>(...);
```

**Good:**
```dart
/// Provider for the file accessibility validation use case.
///
/// Provides an instance of [ValidateFileAccessibilityUseCase] that validates
/// whether a file exists, is accessible, and can be read.
final validateFileAccessibilityUseCaseProvider = Provider<ValidateFileAccessibilityUseCase>(...);
```

### ❌ Step Numbers in Inline Comments

Never number sequential steps in implementation code.

**Why:** Step numbers become obsolete when steps are added, removed, or reordered.

**Bad:**
```dart
Future<Either<Error, Result>> process() async {
  // Step 1: Validate input
  final validationResult = await _validate();
  
  // Step 2: Process data
  final processResult = await _process();
  
  // Step 3: Save result
  await _save(processResult);
}
```

**Good:**
```dart
Future<Either<Error, Result>> process() async {
  // Validate input parameters and file accessibility
  final validationResult = await _validate();
  
  // Process data and transform to domain model
  final processResult = await _process();
  
  // Persist result to repository
  await _save(processResult);
}
```

## What to Include in Documentation

### Class/Interface Documentation

Document:
- The purpose and responsibility
- Key behaviors and workflows
- What it does NOT do (if relevant for clarity)
- State management characteristics (stateless, immutable, etc.)

**Example:**
```dart
/// Use case for validating that a file is accessible and suitable for import.
///
/// This use case performs filesystem I/O checks to guard against common issues
/// that would prevent successful file processing:
/// - File does not exist at the specified path
/// - Path points to a directory or other non-file entity
/// - File exists but is empty (0 bytes)
/// - Insufficient permissions to read the file
/// - File is locked by another process
///
/// The validation includes:
/// 1. Existence check
/// 2. Entity type verification (must be a file, not a directory)
/// 3. Size verification (must be non-empty)
/// 4. Read accessibility test (attempts to open and immediately close)
abstract interface class ValidateFileAccessibilityUseCase { ... }
```

### Method Documentation

Document:
- Brief description of what the method does
- Parameters with their purpose and constraints
- Return values and their meaning
- Error conditions (when Left/exceptions are returned)
- Side effects and I/O operations
- Important notes about behavior

**Example:**
```dart
/// Validates that the specified [file] is accessible and suitable for processing.
///
/// Performs a series of checks to ensure the file:
/// - Exists on the filesystem
/// - Is a regular file (not a directory or link)
/// - Has non-zero size
/// - Can be opened for reading
///
/// Parameters:
/// - [file]: The file to validate
///
/// Returns:
/// - [Right] with `void` if the file passes all validation checks
/// - [Left] with [ValidateFileAccessibilityError] describing the specific issue
///
/// Note: This method performs I/O operations and should be called from
/// an async context. The read accessibility test opens the file briefly
/// but does not read its contents.
Future<Either<ValidateFileAccessibilityError, void>> call({
  required File file,
});
```

### Error Type Documentation

Document each error case with:
- What the error represents
- When/why it occurs (specific conditions)
- User action or recovery path (if applicable)

**Example:**
```dart
@freezed
/// Error returned when file accessibility validation fails.
///
/// These error types represent specific, actionable failure modes that can
/// occur when validating file accessibility. Each error type maps to a
/// distinct user-facing message and potential recovery action.
sealed class ValidateFileAccessibilityError with _$ValidateFileAccessibilityError {
  /// The specified file does not exist at the given path.
  ///
  /// This error occurs when:
  /// - The file path is invalid or incorrect
  /// - The file was deleted after being selected
  ///
  /// User action: Verify the file path or select the file again.
  const factory ValidateFileAccessibilityError.fileNotFound() = _FileNotFound;

  /// Access to the file was denied due to insufficient permissions.
  ///
  /// This error occurs when:
  /// - The application lacks read permissions for the file
  /// - The file is in a protected system directory
  ///
  /// User action: Grant the application necessary file access permissions.
  const factory ValidateFileAccessibilityError.permissionDenied() = _PermissionDenied;
}
```

### Provider Documentation

Document:
- What the provider provides (be specific about the implementation)
- Key characteristics (stateless, singleton, etc.)

**Example:**
```dart
/// Provider for the audio file discovery use case.
///
/// Provides an instance of [DiscoverAudioFilesInDirectoryUseCase] that scans
/// directories for audio files. The use case is stateless and can be safely
/// shared across the application.
final discoverAudioFilesInDirectoryUseCaseProvider = 
  Provider<DiscoverAudioFilesInDirectoryUseCase>(
    (ref) => const DiscoverAudioFilesInDirectoryUseCaseImpl(),
  );
```

### Implementation Class Documentation

Document:
- High-level description of the implementation approach
- Key algorithms or patterns used
- State management and thread-safety characteristics

**Example:**
```dart
/// Default implementation of [CreateAudioFileWorkflow].
///
/// This implementation orchestrates the audio file creation process by:
/// 1. Validating file accessibility and format using dedicated use cases
/// 2. Allocating a sequential file number from the repository
/// 3. Creating the domain aggregate via domain events
/// 4. Persisting the aggregate through the repository
/// 5. Publishing domain events to the event bus
///
/// The workflow maintains transactional consistency by validating all inputs
/// before making changes, committing modifications atomically, and publishing
/// events only after successful persistence.
final class CreateAudioFileWorkflowImpl implements CreateAudioFileWorkflow {
  // ...
}
```

Note: Numbered lists are acceptable in class-level documentation when describing architecture or design, not sequential code steps.

### Inline Comments

Use descriptive comments that:
- Explain **what** the code block does
- Add context that isn't obvious from the code itself
- Clarify **why** something is done a certain way (if non-obvious)
- Note important behavioral details or constraints

**Good Examples:**
```dart
// Check if the file exists on the filesystem
if (!await file.exists()) {
  return const Left(ValidateFileAccessibilityError.fileNotFound());
}

// Verify that the path points to a file, not a directory or other entity
final fileStatistics = await file.stat();

// Attempt to open the file for reading to verify accessibility.
// This will fail if the file is locked or permissions are insufficient.
final randomAccessFile = await file.open(mode: FileMode.read);
await randomAccessFile.close();
```

### Private Method Documentation

Private methods should have doc comments if they:
- Have non-trivial logic
- Are reused across the class
- Have parameters that need explanation

**Example:**
```dart
/// Maps a [FileSystemException] to a use-case-specific error type.
///
/// Examines the OS error code from the exception and translates it into
/// one of the domain-specific error types based on common POSIX and Windows codes:
/// - `2` (ENOENT): File not found
/// - `13` (EACCES) or `5` (Windows): Permission denied
/// - `11` (EAGAIN) or `35` (macOS): File locked
///
/// Parameters:
/// - [e]: The filesystem exception to map
///
/// Returns the appropriate [ValidateFileAccessibilityError] subtype.
ValidateFileAccessibilityError _mapFileSystemException(FileSystemException e) {
  // ...
}
```

## Quick Review Checklist

When writing documentation, verify:
- [ ] Explains the purpose and responsibility
- [ ] Documents all parameters and return values
- [ ] Explains error conditions
- [ ] NO usage examples included
- [ ] NO "typically used by" lists
- [ ] NO step numbers in inline comments
- [ ] Is maintainable as code evolves
- [ ] Adds value beyond code and types

## Summary

Focus on documenting **contracts** (what, parameters, returns, errors) rather than **usage** (how to call, who uses it). Keep documentation maintainable by avoiding elements that become stale with code changes like usage examples, consumer lists, and step numbers.

