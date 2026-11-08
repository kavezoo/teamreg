/*
 * A teamreg.vzsfoto.hu JSON API hívásai.
 *
 * Minden kérés Bearer tokennel megy, a belépés kivételével.
 * 401-nél egyszer megújítja a tokent, utána a szerver üzenetét adja vissza.
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// A szerver hibája, a felhasználónak szánt [message] szöveggel.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// GET, POST, PATCH és DELETE a /api-v1 útvonalakra. A törzs JSON.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Rövid életű belépési token. A [refresh] hosszabbítja meg.
  String? accessToken;

  /// Lejárt tokennél az AppModel ezt hívja. Igaz, ha sikerült megújítani.
  Future<bool> Function()? refresh;

  Future<Map<String, dynamic>> get(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body, bool auth = true]) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', path);
  }

  /// Lapozott lista. A [key] a JSON-tömb neve, legfeljebb 30 lap.
  Future<List<Map<String, dynamic>>> pages(String path, String key) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (page < 30) {
      final separator = path.contains('?') ? '&' : '?';
      final json = await get('$path${separator}page=$page&limit=100');
      final list = json[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            rows.add(Map<String, dynamic>.from(item));
          }
        }
        if (list.isEmpty) {
          break;
        }
      } else {
        break;
      }
      final paging = json['paging'];
      final pageCount = paging is Map ? int.tryParse('${paging['pageCount']}') ?? 1 : 1;
      if (page >= pageCount) {
        break;
      }
      page++;
    }
    return rows;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final response = await _request(method, path, body: body, auth: auth);
    // Egy lejárt tokennél egyetlen újrapróbálás, hogy ne pörögjön a hurok.
    if (response.statusCode == 401 && auth && !retried && refresh != null) {
      final renewed = await refresh!();
      if (renewed) {
        return _send(method, path, body: body, auth: auth, retried: true);
      }
    }
    return _decode(response);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool auth,
  }) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final encoded = body == null ? null : jsonEncode(body);
    final Future<http.Response> call;
    switch (method) {
      case 'GET':
        call = _client.get(uri, headers: headers);
      case 'POST':
        call = _client.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        call = _client.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        call = _client.delete(uri, headers: headers);
      default:
        call = _client.get(uri, headers: headers);
    }
    return call.timeout(const Duration(seconds: 30));
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic json;
    try {
      json = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (error) {
      debugPrint('Nem JSON válasz (${response.statusCode}): $error');
      throw ApiException('A szerver nem adott olvasható választ.', statusCode: response.statusCode);
    }
    if (json is! Map) {
      throw ApiException('A szerver válasza nem olvasható.', statusCode: response.statusCode);
    }
    final map = Map<String, dynamic>.from(json);
    if (response.statusCode >= 400) {
      throw ApiException(_message(map), statusCode: response.statusCode);
    }
    return map;
  }

  String _message(Map<String, dynamic> json) {
    final message = json['message'];
    final base = message is String && message.trim().isNotEmpty
        ? message.trim()
        : 'A művelet nem sikerült.';
    final errors = json['errors'];
    if (errors is! Map || errors.isEmpty) {
      return base;
    }
    final details = <String>[];
    for (final value in errors.values) {
      final text = _flatten(value);
      if (text.isNotEmpty) {
        details.add(text);
      }
    }
    if (details.isEmpty) {
      return base;
    }
    return '$base ${details.join(' ')}';
  }

  String _flatten(dynamic value) {
    if (value is Map) {
      return value.values.map(_flatten).where((item) => item.isNotEmpty).join(' ');
    }
    if (value is List) {
      return value.map(_flatten).where((item) => item.isNotEmpty).join(' ');
    }
    return asText(value).trim();
  }

  String asText(dynamic value) => value == null ? '' : value.toString();
}
