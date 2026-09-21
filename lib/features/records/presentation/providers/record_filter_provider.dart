import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/record_filter.dart';

part 'record_filter_provider.g.dart';

class RecordFilterState {
  final RecordFilter filter;
  final Set<String> selectedRecordIds;
  final bool isBulkSelectionMode;

  RecordFilterState({
    required this.filter,
    this.selectedRecordIds = const {},
    this.isBulkSelectionMode = false,
  });

  RecordFilterState copyWith({
    RecordFilter? filter,
    Set<String>? selectedRecordIds,
    bool? isBulkSelectionMode,
  }) {
    return RecordFilterState(
      filter: filter ?? this.filter,
      selectedRecordIds: selectedRecordIds ?? this.selectedRecordIds,
      isBulkSelectionMode: isBulkSelectionMode ?? this.isBulkSelectionMode,
    );
  }
}

@riverpod
class RecordFilterNotifier extends _$RecordFilterNotifier {
  @override
  RecordFilterState build() {
    return RecordFilterState(filter: RecordFilter());
  }

  void updateFilter(RecordFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void toggleSelection(String recordId) {
    final newSelection = Set<String>.from(state.selectedRecordIds);
    if (newSelection.contains(recordId)) {
      newSelection.remove(recordId);
    } else {
      newSelection.add(recordId);
    }
    state = state.copyWith(
      selectedRecordIds: newSelection,
      isBulkSelectionMode: newSelection.isNotEmpty,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedRecordIds: {},
      isBulkSelectionMode: false,
    );
  }
}
