# Copilot instructions (Phonic)

## Big picture
- `lib/phonic.dart` is the public surface; prefer adding/adjusting exports here only for user-facing APIs.
- Core entrypoint is `lib/src/core/phonic.dart` (`Phonic.fromFile`/`fromBytes`). It selects a `FormatStrategy` and builds a `CodecRegistry` (codecs + container locators).
- Reading/writing behavior is governed by:
  - `FormatStrategy` (`lib/src/core/format_strategy.dart`): format detection + container precedence + write fan-out.
  - `MergePolicy` (`lib/src/core/merge_policy.dart`): precedence + per-target normalization using `TagCapability`/`TagSemantics`.