import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedSlotProvider = StateProvider<String?>((ref) => null);
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
