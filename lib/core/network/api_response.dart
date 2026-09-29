import 'dart:convert';

import 'package:http/http.dart' as http;

Map<String, dynamic> decodeJsonObject(http.Response response) {
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Era esperado um objeto JSON.');
  }
  return decoded;
}

String apiErrorMessage(http.Response response, String fallback) {
  try {
    final body = decodeJsonObject(response);
    final detail = body['detail'];
    final error =
        body['error'] ??
        (detail is Map<String, dynamic> ? detail['error'] : null);
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (detail is String && detail.trim().isNotEmpty) return detail;
  } catch (_) {
    // Uma resposta de erro inválida ainda deve virar uma mensagem segura.
  }
  return fallback;
}
