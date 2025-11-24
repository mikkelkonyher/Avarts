// Package imports
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:avarts/services/auth_service.dart';

/// Service class for handling image uploads
/// Supports both Supabase Storage and direct S3 uploads
class ImageUploadService {
  /// Gets the Supabase client instance
  SupabaseClient get client => Supabase.instance.client;

  /// Gets the current user ID
  String? get currentUserId => AuthService().currentUser?.id;

  /// Uploads an image to Supabase Storage
  ///
  /// [file] - The image file to upload
  /// [bucketName] - The storage bucket name (default: 'activity-images')
  ///
  /// Returns the public URL of the uploaded image
  /// Throws [Exception] if upload fails
  Future<String> uploadToSupabaseStorage({
    required File file,
    String bucketName = 'activity-images',
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to upload images');
    }

    try {
      // Generate a unique file name
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      final filePath = '$userId/$fileName';

      // Upload to Supabase Storage
      await client.storage.from(bucketName).upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = client.storage.from(bucketName).getPublicUrl(filePath);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Failed to upload image: ${e.message}');
    } on Exception catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Uploads an image from URL (for existing URLs, just returns the URL)
  ///
  /// [imageUrl] - The image URL (if it's already a URL, returns it as-is)
  ///
  /// Returns the image URL
  Future<String> handleImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }

    // If it's already a URL (starts with http), return it
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // Otherwise, treat it as a file path and upload
    final file = File(imageUrl);
    if (await file.exists()) {
      return await uploadToSupabaseStorage(file: file);
    }

    throw Exception('Invalid image URL or file path');
  }

  /// Uploads image bytes to Supabase Storage
  ///
  /// [bytes] - The image bytes to upload
  /// [bucketName] - The storage bucket name (default: 'activity-images')
  ///
  /// Returns the public URL of the uploaded image
  /// Throws [Exception] if upload fails
  Future<String> uploadBytesToSupabaseStorage({
    required Uint8List bytes,
    String bucketName = 'activity-images',
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to upload images');
    }

    try {
      // Create a temporary file from bytes
      final tempDir = Directory.systemTemp;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      // Upload using the file method
      return await uploadToSupabaseStorage(
        file: tempFile,
        bucketName: bucketName,
      );
    } on Exception catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Uploads an image directly to S3
  ///
  /// Note: This requires AWS credentials (access key ID and secret access key)
  /// You'll need to add these to your .env file:
  /// - AWS_ACCESS_KEY_ID
  /// - AWS_SECRET_ACCESS_KEY
  /// - AWS_REGION
  /// - AWS_S3_BUCKET_NAME
  ///
  /// [file] - The image file to upload
  /// [bucketName] - S3 bucket name
  /// [region] - AWS region (e.g., 'us-east-1')
  /// [accessKeyId] - AWS access key ID
  /// [secretAccessKey] - AWS secret access key
  ///
  /// Returns the public URL of the uploaded image
  /// Throws [Exception] if upload fails
  Future<String> uploadToS3({
    required File file,
    required String bucketName,
    required String region,
    required String accessKeyId,
    required String secretAccessKey,
  }) async {
    // Note: For direct S3 uploads, you would need to use AWS SDK
    // This is a placeholder - you'll need to add 'aws_s3_upload' or similar package
    // For now, we recommend using Supabase Storage instead
    throw UnimplementedError(
      'Direct S3 upload requires AWS SDK. Please use Supabase Storage or add aws_s3_upload package.',
    );
  }
}

