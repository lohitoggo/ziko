import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'upload_service.dart';

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService();
});
