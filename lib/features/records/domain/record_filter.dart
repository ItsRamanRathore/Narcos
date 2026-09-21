class RecordFilter {
  final String? searchQuery;
  final String? resultType;
  final String? kitUsed;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? operatorId;
  final double? minConfidence; // 0.0 to 1.0 (will map to 0-10000 in SQL)
  final String? sortBy; // 'newest', 'oldest', 'confidence', 'proximity'

  RecordFilter({
    this.searchQuery,
    this.resultType,
    this.kitUsed,
    this.dateFrom,
    this.dateTo,
    this.operatorId,
    this.minConfidence,
    this.sortBy = 'newest',
  });

  RecordFilter copyWith({
    String? searchQuery,
    String? resultType,
    String? kitUsed,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? operatorId,
    double? minConfidence,
    String? sortBy,
  }) {
    return RecordFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      resultType: resultType ?? this.resultType,
      kitUsed: kitUsed ?? this.kitUsed,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      operatorId: operatorId ?? this.operatorId,
      minConfidence: minConfidence ?? this.minConfidence,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class FtsQueryBuilder {
  static String sanitize(String raw) {
    // Escape double quotes, wrap in quotes for exact phrase matching
    final escaped = raw.replaceAll('"', '""');
    return '"$escaped"';
  }
  
  // For prefix matching (user types partial word):
  static String prefix(String raw) {
    if (raw.trim().isEmpty) return '';
    final escaped = raw.trim().replaceAll('"', '""');
    return '"$escaped"*';  // trailing * enables prefix match
  }
}
