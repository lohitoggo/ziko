import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class UploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Compresses the image to stay below [targetKb] and returns the compressed file.
  Future<File?> _compressImage(File file, {int targetKb = 200}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');
      
      int quality = 85;
      File? compressedFile;
      
      // Attempt compression with decreasing quality until size is below threshold
      while (quality > 10) {
        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        
        if (result == null) break;
        
        compressedFile = File(result.path);
        final sizeInKb = compressedFile.lengthSync() / 1024;
        
        if (sizeInKb <= targetKb) {
          break;
        }
        
        quality -= 15;
      }
      
      return compressedFile;
    } catch (e) {
      print('Compression error: $e');
      return file; // Fallback to original
    }
  }

  /// Uploads an image to Supabase Storage with automatic compression.
  Future<String?> uploadImage(File file, String bucket) async {
    try {
      // Compress before upload (Target 200KB)
      final compressedFile = await _compressImage(file);
      final fileToUpload = compressedFile ?? file;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(fileToUpload.path)}';
      
      final response = await _supabase.storage.from(bucket).upload(
        fileName,
        fileToUpload,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      if (response.isEmpty) {
        print('Upload failed: Empty response from Supabase');
        return null;
      }

      final String publicUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
      print('Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Uploads multiple images and returns a list of public URLs.
  Future<List<String>> uploadMultipleImages(List<File> files, String bucket) async {
    List<String> urls = [];
    for (var file in files) {
      final url = await uploadImage(file, bucket);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }
}
