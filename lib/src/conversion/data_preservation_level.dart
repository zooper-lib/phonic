/// Level of data preservation achieved by a conversion.
enum DataPreservationLevel {
  /// All data preserved exactly with no modifications.
  perfect,

  /// Minor modifications (formatting, encoding) but no semantic data loss.
  excellent,

  /// Some data modifications but core information preserved.
  good,

  /// Significant data loss but basic information preserved.
  limited,

  /// Major data loss, conversion not recommended.
  poor,

  /// Rule doesn't apply to this conversion scenario.
  notApplicable,
}
