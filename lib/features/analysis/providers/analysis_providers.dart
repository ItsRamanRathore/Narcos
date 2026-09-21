import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/kit_repository.dart';

final kitRepositoryProvider = Provider((ref) => KitRepository());

final availableKitsProvider = FutureProvider<List<KitManifest>>((ref) async {
  final repo = ref.watch(kitRepositoryProvider);
  return repo.loadAllKits();
});
