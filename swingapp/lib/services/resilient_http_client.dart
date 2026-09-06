import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

/// Un client HTTP robuste qui ajoute :
/// 1. Des Timeouts automatiques pour chaque requête.
/// 2. Un Retry automatique (avec exponential backoff) en cas d'erreur réseau transitoire.
/// 3. Une injection transparente des headers (peut être ajoutée en amont).
class ResilientHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final int maxRetries;
  final Duration timeout;

  ResilientHttpClient({
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 12),
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    int attempts = 0;

    while (true) {
      attempts++;
      try {
        final response = await _inner.send(_copyRequest(request)).timeout(timeout);
        return response;
      } on TimeoutException catch (e, stack) {
        if (attempts >= maxRetries) {
          LoggerService.error('HTTP Timeout apres $attempts essais: ${request.url}', e, stack);
          rethrow;
        }
        LoggerService.warning('HTTP Timeout, retry $attempts/$maxRetries: ${request.url}');
      } on SocketException catch (e, stack) {
        if (attempts >= maxRetries) {
          LoggerService.error('HTTP Reseau indisponible apres $attempts essais: ${request.url}', e, stack);
          rethrow;
        }
        LoggerService.warning('HTTP SocketException, retry $attempts/$maxRetries: ${request.url}');
      } catch (e) {
        // Autres erreurs non transitoires, on ne retry pas par défaut
        rethrow;
      }

      // Exponential backoff: 500ms, 1s, 2s...
      await Future.delayed(Duration(milliseconds: 500 * (1 << (attempts - 1))));
    }
  }

  /// Copie la requête car le framework http empêche de renvoyer la même instance BaseRequest deux fois.
  http.BaseRequest _copyRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects;
      return copy;
    }
    // Fallback pour MultipartRequest ou StreamedRequest (plus complexe à cloner, on renvoie l'original à nos risques)
    return request;
  }
}
