import 'dart:convert';
import 'dart:io';

import 'run_replay_uploader.dart';
import 'run_session_api.dart';

RunReplayUploader createRunReplayUploader() => HttpRunReplayUploader();

class HttpRunReplayUploader implements RunReplayUploader {
  HttpRunReplayUploader({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<void> uploadReplay({
    required RunUploadGrant uploadGrant,
    required String replayArtifactId,
    required int contentLengthBytes,
    required String contentType,
  }) async {
    if (uploadGrant.uploadMethod.toUpperCase() != 'POST') {
      throw const RunReplayUploadException(
        code: 'unsupported-upload-method',
        message: 'Replay upload grant method is not supported.',
      );
    }
    if (contentLengthBytes <= 0) {
      throw const RunReplayUploadException(
        code: 'invalid-content-length',
        message: 'Replay content length must be greater than zero.',
      );
    }
    if (contentLengthBytes > uploadGrant.maxBytes) {
      throw RunReplayUploadException(
        code: 'content-length-exceeds-grant',
        message:
            'Replay content length $contentLengthBytes exceeds upload grant max '
            '${uploadGrant.maxBytes}.',
      );
    }
    if (contentType != uploadGrant.contentType) {
      throw const RunReplayUploadException(
        code: 'content-type-mismatch',
        message: 'Replay content type did not match the upload grant.',
      );
    }
    _validateMultipartFields(uploadGrant);

    final replayFile = File(replayArtifactId);
    if (!await replayFile.exists()) {
      throw RunReplayUploadException(
        code: 'replay-file-missing',
        message: 'Replay file does not exist at "$replayArtifactId".',
      );
    }
    final fileLength = await replayFile.length();
    if (fileLength != contentLengthBytes) {
      throw RunReplayUploadException(
        code: 'content-length-mismatch',
        message:
            'Replay file length $fileLength did not match expected '
            '$contentLengthBytes.',
      );
    }

    final boundary =
        '----RpgRunnerReplay${DateTime.now().microsecondsSinceEpoch}';
    final fields = uploadGrant.uploadFields.entries.toList(growable: false);
    final fieldParts = <List<int>>[
      for (final field in fields)
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="${field.key}"\r\n'
          '\r\n'
          '${field.value}\r\n',
        ),
    ];
    final fileHeader = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; '
      'filename="replay.bin.gz"\r\n'
      'Content-Type: ${uploadGrant.contentType}\r\n'
      '\r\n',
    );
    final closingBoundary = utf8.encode('\r\n--$boundary--\r\n');
    final requestContentLength =
        fieldParts.fold<int>(0, (total, part) => total + part.length) +
        fileHeader.length +
        contentLengthBytes +
        closingBoundary.length;

    final uploadUri = Uri.parse(uploadGrant.uploadUrl);
    final request = await _httpClient.postUrl(uploadUri);
    request.headers.contentType = ContentType(
      'multipart',
      'form-data',
      parameters: <String, String>{'boundary': boundary},
    );
    request.contentLength = requestContentLength;
    for (final fieldPart in fieldParts) {
      request.add(fieldPart);
    }
    request.add(fileHeader);
    await request.addStream(replayFile.openRead());
    request.add(closingBoundary);
    final response = await request.close();
    final accepted = response.statusCode >= 200 && response.statusCode < 300;
    if (accepted) {
      await response.drain<void>();
      return;
    }
    final responseBody = await utf8.decodeStream(response);
    final code =
        response.statusCode == HttpStatus.forbidden &&
            _bodyContainsAccessDenied(responseBody)
        ? 'upload-access-denied'
        : 'upload-rejected';
    throw RunReplayUploadException(
      code: code,
      message: _buildUploadRejectedMessage(
        statusCode: response.statusCode,
        responseBody: responseBody,
      ),
      statusCode: response.statusCode,
    );
  }

  void _validateMultipartFields(RunUploadGrant uploadGrant) {
    if (uploadGrant.uploadFields.isEmpty ||
        uploadGrant.uploadFields['Content-Type'] != uploadGrant.contentType) {
      throw const RunReplayUploadException(
        code: 'invalid-upload-fields',
        message: 'Replay upload grant did not contain a valid signed form.',
      );
    }
    for (final field in uploadGrant.uploadFields.entries) {
      if (field.key.isEmpty ||
          field.value.isEmpty ||
          _containsFormLineBreak(field.key) ||
          _containsFormLineBreak(field.value)) {
        throw const RunReplayUploadException(
          code: 'invalid-upload-fields',
          message: 'Replay upload grant did not contain a valid signed form.',
        );
      }
    }
  }
}

bool _containsFormLineBreak(String value) =>
    value.contains('\r') || value.contains('\n');

bool _bodyContainsAccessDenied(String body) {
  final normalized = body.toLowerCase();
  return normalized.contains('accessdenied') ||
      normalized.contains('access denied');
}

String _buildUploadRejectedMessage({
  required int statusCode,
  required String responseBody,
}) {
  final normalizedBody = _singleLineText(responseBody);
  if (statusCode == HttpStatus.forbidden) {
    final lower = normalizedBody.toLowerCase();
    if (lower.contains('storage.objects.create')) {
      return 'Replay upload denied (HTTP 403): replay upload service account '
          'is missing storage.objects.create permission.';
    }
    if (lower.contains('accessdenied') || lower.contains('access denied')) {
      return 'Replay upload denied (HTTP 403): storage access denied.';
    }
  }
  if (normalizedBody.isEmpty) {
    return 'Replay upload rejected with HTTP $statusCode.';
  }
  return 'Replay upload rejected with HTTP $statusCode: '
      '${_trimForUi(normalizedBody, maxChars: 280)}';
}

String _singleLineText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _trimForUi(String value, {required int maxChars}) {
  if (value.length <= maxChars) {
    return value;
  }
  return '${value.substring(0, maxChars - 3)}...';
}
