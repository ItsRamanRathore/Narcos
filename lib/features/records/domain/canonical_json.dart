import 'dart:convert';
import 'dart:collection';
import 'dart:typed_data';

class CanonicalJson {
  /// Encodes a map into deterministic, sorted canonical JSON bytes.
  static Uint8List encode(Map<String, dynamic> data) {
    final sorted = _sortRecursive(data);
    final jsonString = jsonEncode(sorted);
    return utf8.encode(jsonString);
  }

  static dynamic _sortRecursive(dynamic value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _sortRecursive(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_sortRecursive).toList();
    }
    // No floats allowed in canonical JSON. They must be integers or strings.
    if (value is double) {
      throw ArgumentError('Floats are not permitted in canonical JSON. Convert to int first.');
    }
    return value; // Primitives pass through
  }
}
