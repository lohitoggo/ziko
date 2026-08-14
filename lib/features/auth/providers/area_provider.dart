import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/area_repository.dart';
import '../data/area_model.dart';

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepository();
});

final activeAreasProvider = StreamProvider<List<AreaModel>>((ref) {
  return ref.watch(areaRepositoryProvider).watchActiveAreas();
});