// imagekit_upload.dart
//
// Uses Cloudflare Worker auth endpoint:
// https://twilight-snowflake-e0c1.24630483.workers.dev/imagekit/auth
//
// Upload endpoint:
// https://upload.imagekit.io/api/v1/files/upload
//
// pubspec.yaml:
//   dependencies:
//     http: ^1.2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ImageKitUploader {
  ImageKitUploader({
    required this.urlEndpoint, // e.g. https://ik.imagekit.io/<your_id>
    Uri? authEndpoint,
    http.Client? client,
  })  : authEndpoint = authEndpoint ??
            Uri.parse(
              'https://twilight-snowflake-e0c1.24630483.workers.dev/imagekit/auth',
            ),
        _http = client ?? http.Client();

  final String urlEndpoint;
  final Uri authEndpoint;
  final http.Client _http;

  void close() => _http.close();

  Future<ImageKitUploadResult> uploadFile({
    required File file,
    required String fileName,
    String? folder, // e.g. "/events/<eventId>"
    bool useUniqueFileName = true,
    bool isPrivateFile = false,
    List<String>? tags,
    Map<String, dynamic>? customMetadata,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      folder: folder,
      useUniqueFileName: useUniqueFileName,
      isPrivateFile: isPrivateFile,
      tags: tags,
      customMetadata: customMetadata,
    );
  }

  Future<ImageKitUploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String? folder,
    bool useUniqueFileName = true,
    bool isPrivateFile = false,
    List<String>? tags,
    Map<String, dynamic>? customMetadata,
  }) async {
    final auth = await _fetchAuth();

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
    );

    // ImageKit signed upload fields
    req.fields['publicKey'] = auth.publicKey;
    req.fields['token'] = auth.token;
    req.fields['expire'] = auth.expire.toString();
    req.fields['signature'] = auth.signature;

    // Upload params
    req.fields['fileName'] = fileName;
    req.fields['useUniqueFileName'] = useUniqueFileName ? 'true' : 'false';
    req.fields['isPrivateFile'] = isPrivateFile ? 'true' : 'false';

    if (folder != null && folder.trim().isNotEmpty) {
      // ImageKit expects folder like "/events/123"
      req.fields['folder'] = folder.startsWith('/') ? folder : '/$folder';
    }

    if (tags != null && tags.isNotEmpty) {
      req.fields['tags'] = tags.join(',');
    }

    if (customMetadata != null && customMetadata.isNotEmpty) {
      req.fields['customMetadata'] = jsonEncode(customMetadata);
    }

    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ImageKitException(
        operation: 'uploadBytes',
        statusCode: streamed.statusCode,
        message: _extractImageKitError(body) ?? 'Upload failed',
        rawBody: body,
      );
    }

    final jsonMap = jsonDecode(body) as Map<String, dynamic>;
    return ImageKitUploadResult.fromJson(jsonMap);
  }

  /// Build a transformed ImageKit URL from a filePath.
  /// If you store result.url, you can just use it directly.
  String buildUrlFromPath(
    String filePath, {
    List<IKTransform> transforms = const [],
  }) {
    final base = _joinUrl(urlEndpoint, filePath);
    if (transforms.isEmpty) return base;
    final tr = transforms.map((t) => t.toParam()).join(',');
    final sep = base.contains('?') ? '&' : '?';
    return '$base${sep}tr=$tr';
  }

  Future<ImageKitAuth> _fetchAuth() async {
    try {
      final resp = await _http.get(
        authEndpoint,
        headers: {'accept': 'application/json'},
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ImageKitException(
          operation: 'fetchAuth',
          statusCode: resp.statusCode,
          message: 'Auth endpoint failed',
          rawBody: resp.body,
        );
      }

      final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
      return ImageKitAuth.fromJson(jsonMap);
    } on ImageKitException {
      rethrow;
    } catch (e) {
      throw ImageKitException(
        operation: 'fetchAuth',
        statusCode: null,
        message: 'Auth fetch failed',
        rawBody: e.toString(),
      );
    }
  }

  static String _joinUrl(String base, String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  static String? _extractImageKitError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = decoded['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return null;
  }
}

class ImageKitAuth {
  ImageKitAuth({
    required this.token,
    required this.expire,
    required this.signature,
    required this.publicKey,
  });

  final String token;
  final int expire;
  final String signature;
  final String publicKey;

  factory ImageKitAuth.fromJson(Map<String, dynamic> json) {
    // Your worker returns { token, expire, signature, publicKey }
    return ImageKitAuth(
      token: json['token'] as String,
      expire: (json['expire'] as num).toInt(),
      signature: json['signature'] as String,
      publicKey: json['publicKey'] as String,
    );
  }
}

class ImageKitUploadResult {
  ImageKitUploadResult({
    required this.fileId,
    required this.name,
    required this.url,
    required this.thumbnailUrl,
    required this.filePath,
    required this.size,
    required this.fileType,
  });

  final String fileId;
  final String name;
  final String url;
  final String thumbnailUrl;
  final String filePath;
  final int size;
  final String fileType;

  factory ImageKitUploadResult.fromJson(Map<String, dynamic> json) {
    return ImageKitUploadResult(
      fileId: json['fileId'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      thumbnailUrl: (json['thumbnailUrl'] as String?) ?? '',
      filePath: (json['filePath'] as String?) ?? '',
      size: (json['size'] as num).toInt(),
      fileType: (json['fileType'] as String?) ?? '',
    );
  }
}

class ImageKitException implements Exception {
  ImageKitException({
    required this.operation,
    required this.statusCode,
    required this.message,
    required this.rawBody,
  });

  final String operation;
  final int? statusCode;
  final String message;
  final String rawBody;

  @override
  String toString() =>
      'ImageKitException(op: $operation, status: $statusCode, message: $message, body: $rawBody)';
}

class IKTransform {
  IKTransform._(this._param);
  final String _param;

  String toParam() => _param;

  static IKTransform w(int width) => IKTransform._('w-$width');
  static IKTransform h(int height) => IKTransform._('h-$height');
  static IKTransform q(int quality) => IKTransform._('q-$quality');
  static IKTransform f(String format) => IKTransform._('f-$format');
  static IKTransform c(String cropMode) => IKTransform._('c-$cropMode');
}
