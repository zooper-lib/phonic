import 'dart:typed_data';

import '../exceptions/phonic_exception.dart';
import 'metadata_tag.dart';
import 'tag_key.dart';

/// Manages rollback capabilities for failed write operations.
///
/// This class provides a mechanism to save the state of an audio file before
/// modifications and restore it if validation fails or other errors occur
/// during the write process. It maintains both the file bytes and tag state
/// to enable complete restoration.
///
/// ## Usage Pattern
///
/// ```dart
/// final rollbackManager = RollbackManager();
///
/// // Save current state before modifications
/// rollbackManager.saveState(
///   fileBytes: originalFileBytes,
///   tags: currentTags,
///   description: 'Before updating album information',
/// );
///
/// try {
///   // Perform modifications
///   audioFile.setTag(AlbumTag('New Album'));
///   final encodedBytes = await audioFile.encode();
///
///   // Validate the result
///   final validationResult = await validator.validateEncodedFile(...);
///   if (!validationResult.isValid) {
///     // Rollback on validation failure
///     final restoredState = rollbackManager.rollback();
///     // Apply restored state to audio file
///   }
/// } catch (e) {
///   // Rollback on exception
///   final restoredState = rollbackManager.rollback();
/// }
/// ```
class RollbackManager {
  /// Stack of saved states for nested rollback support.
  final List<RollbackState> _stateStack = [];

  /// Maximum number of states to keep in the rollback stack.
  final int maxStackSize;

  /// Creates a new RollbackManager.
  ///
  /// Parameters:
  /// - [maxStackSize]: Maximum number of rollback states to maintain
  RollbackManager({this.maxStackSize = 10});

  /// Saves the current state of the audio file for potential rollback.
  ///
  /// This method captures both the file bytes and tag state, allowing
  /// complete restoration if needed. Multiple states can be saved to
  /// support nested operations and partial rollbacks.
  ///
  /// Parameters:
  /// - [fileBytes]: The current file bytes
  /// - [tags]: The current tag state
  /// - [description]: Optional description of the state being saved
  /// - [metadata]: Optional additional metadata about the state
  ///
  /// Returns:
  /// - [RollbackToken] that can be used for targeted rollback operations
  RollbackToken saveState({
    required Uint8List fileBytes,
    required Map<TagKey, List<MetadataTag>> tags,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    // Create a deep copy of the tag state
    final tagsCopy = <TagKey, List<MetadataTag>>{};
    for (final entry in tags.entries) {
      tagsCopy[entry.key] = List<MetadataTag>.from(entry.value);
    }

    final state = RollbackState(
      fileBytes: Uint8List.fromList(fileBytes),
      tags: tagsCopy,
      timestamp: DateTime.now(),
      description: description,
      metadata: metadata != null ? Map<String, dynamic>.from(metadata) : null,
    );

    // Add to stack and manage size
    _stateStack.add(state);
    if (_stateStack.length > maxStackSize) {
      _stateStack.removeAt(0); // Remove oldest state
    }

    return RollbackToken._(state);
  }

  /// Rolls back to the most recent saved state.
  ///
  /// This method removes and returns the most recent state from the stack.
  /// If no states are available, returns null.
  ///
  /// Returns:
  /// - [RollbackState] containing the restored file bytes and tags
  /// - `null` if no rollback state is available
  RollbackState? rollback() {
    if (_stateStack.isEmpty) {
      return null;
    }

    return _stateStack.removeLast();
  }

  /// Rolls back to a specific state identified by a rollback token.
  ///
  /// This method allows rolling back to a specific saved state rather than
  /// just the most recent one. All states newer than the target state are
  /// discarded from the stack.
  ///
  /// Parameters:
  /// - [token]: The rollback token identifying the target state
  ///
  /// Returns:
  /// - [RollbackState] containing the restored file bytes and tags
  /// - `null` if the token is not found in the stack
  RollbackState? rollbackTo(RollbackToken token) {
    final targetState = token._state;
    final index = _stateStack.indexOf(targetState);

    if (index == -1) {
      return null; // State not found
    }

    // Remove all states after the target state
    _stateStack.removeRange(index + 1, _stateStack.length);

    // Return and remove the target state
    return _stateStack.removeLast();
  }

  /// Discards the most recent saved state without rolling back.
  ///
  /// This method is useful when an operation completes successfully and
  /// the rollback state is no longer needed.
  ///
  /// Returns:
  /// - `true` if a state was discarded
  /// - `false` if no states were available
  bool discardLastState() {
    if (_stateStack.isEmpty) {
      return false;
    }

    _stateStack.removeLast();
    return true;
  }

  /// Discards all saved states up to and including the specified token.
  ///
  /// This method is useful for cleaning up rollback states after a
  /// successful operation that involved multiple intermediate states.
  ///
  /// Parameters:
  /// - [token]: The rollback token identifying the state to discard up to
  ///
  /// Returns:
  /// - Number of states that were discarded
  int discardStatesUpTo(RollbackToken token) {
    final targetState = token._state;
    final index = _stateStack.indexOf(targetState);

    if (index == -1) {
      return 0; // State not found
    }

    final discardedCount = index + 1;
    _stateStack.removeRange(0, discardedCount);
    return discardedCount;
  }

  /// Clears all saved rollback states.
  ///
  /// This method removes all states from the rollback stack, freeing
  /// memory used by saved file bytes and tag data.
  void clearAll() {
    _stateStack.clear();
  }

  /// Gets information about the current rollback stack.
  ///
  /// Returns:
  /// - [RollbackStackInfo] containing details about saved states
  RollbackStackInfo getStackInfo() {
    final totalSize = _stateStack.fold<int>(
      0,
      (sum, state) => sum + state.fileBytes.length,
    );

    return RollbackStackInfo(
      stateCount: _stateStack.length,
      totalMemoryUsage: totalSize,
      oldestStateTimestamp: _stateStack.isNotEmpty ? _stateStack.first.timestamp : null,
      newestStateTimestamp: _stateStack.isNotEmpty ? _stateStack.last.timestamp : null,
      descriptions: _stateStack.map((state) => state.description).toList(),
    );
  }

  /// Checks if rollback is available.
  ///
  /// Returns:
  /// - `true` if at least one rollback state is available
  /// - `false` if no rollback states are saved
  bool get canRollback => _stateStack.isNotEmpty;

  /// Gets the number of available rollback states.
  int get stateCount => _stateStack.length;

  /// Gets the memory usage of all saved states in bytes.
  int get memoryUsage {
    return _stateStack.fold<int>(
      0,
      (sum, state) => sum + state.fileBytes.length,
    );
  }
}

/// Represents a saved state that can be restored via rollback.
class RollbackState {
  /// The file bytes at the time the state was saved.
  final Uint8List fileBytes;

  /// The tag state at the time the state was saved.
  final Map<TagKey, List<MetadataTag>> tags;

  /// When this state was saved.
  final DateTime timestamp;

  /// Optional description of this state.
  final String? description;

  /// Optional additional metadata about this state.
  final Map<String, dynamic>? metadata;

  /// Creates a new RollbackState.
  const RollbackState({
    required this.fileBytes,
    required this.tags,
    required this.timestamp,
    this.description,
    this.metadata,
  });

  /// Gets the size of this rollback state in bytes.
  int get sizeInBytes => fileBytes.length;

  /// Gets a summary of this rollback state.
  String get summary {
    final tagCount = tags.values.fold<int>(0, (sum, tagList) => sum + tagList.length);
    final sizeKB = (sizeInBytes / 1024).round();
    final timeStr = timestamp.toIso8601String();

    return 'RollbackState(${description ?? 'Unnamed'}, $tagCount tags, ${sizeKB}KB, $timeStr)';
  }
}

/// Token that identifies a specific rollback state.
///
/// This class provides a safe way to reference rollback states without
/// exposing the internal state data. Tokens can be used for targeted
/// rollback operations and state management.
class RollbackToken {
  /// The internal rollback state this token references.
  final RollbackState _state;

  /// Creates a new RollbackToken (internal use only).
  const RollbackToken._(this._state);

  /// Gets the timestamp when this state was saved.
  DateTime get timestamp => _state.timestamp;

  /// Gets the description of this state.
  String? get description => _state.description;

  /// Gets the size of this state in bytes.
  int get sizeInBytes => _state.sizeInBytes;

  @override
  bool operator ==(Object other) {
    return other is RollbackToken && other._state == _state;
  }

  @override
  int get hashCode => _state.hashCode;

  @override
  String toString() => 'RollbackToken(${description ?? 'Unnamed'}, ${timestamp.toIso8601String()})';
}

/// Information about the current rollback stack.
class RollbackStackInfo {
  /// Number of states currently saved.
  final int stateCount;

  /// Total memory usage of all saved states in bytes.
  final int totalMemoryUsage;

  /// Timestamp of the oldest saved state.
  final DateTime? oldestStateTimestamp;

  /// Timestamp of the newest saved state.
  final DateTime? newestStateTimestamp;

  /// Descriptions of all saved states.
  final List<String?> descriptions;

  /// Creates a new RollbackStackInfo.
  const RollbackStackInfo({
    required this.stateCount,
    required this.totalMemoryUsage,
    this.oldestStateTimestamp,
    this.newestStateTimestamp,
    required this.descriptions,
  });

  /// Gets the memory usage in a human-readable format.
  String get memoryUsageFormatted {
    if (totalMemoryUsage < 1024) {
      return '${totalMemoryUsage}B';
    } else if (totalMemoryUsage < 1024 * 1024) {
      return '${(totalMemoryUsage / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalMemoryUsage / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  /// Gets the age of the oldest state.
  Duration? get oldestStateAge {
    if (oldestStateTimestamp == null) return null;
    return DateTime.now().difference(oldestStateTimestamp!);
  }

  /// Gets a summary of the rollback stack.
  String get summary {
    if (stateCount == 0) {
      return 'No rollback states available';
    }

    return 'RollbackStack($stateCount states, $memoryUsageFormatted)';
  }
}

/// Exception thrown when rollback operations fail.
class RollbackException extends PhonicException {
  /// Creates a new RollbackException.
  const RollbackException(super.message, {super.context});
}
