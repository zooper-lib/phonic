class Id3Exception implements Exception {
  Id3Exception([this.message]);

  final String? message;

  @override
  String toString() => '$Id3Exception: $message';
}
