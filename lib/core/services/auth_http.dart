import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as base;
import 'package:shared_preferences/shared_preferences.dart';

// Re-export tipe yang dipakai oleh screen agar `http.Response`, `http.MultipartFile`, dll tetap bisa dipakai.
export 'package:http/http.dart'
    show Response, StreamedResponse, MultipartFile, ClientException;

/// Wrapper tipis di atas package `http`.
///
/// Backend Laravel memakai Sanctum (`auth:sanctum`), sehingga hampir semua endpoint
/// wajib header `Authorization: Bearer <token>`. Token disimpan di SharedPreferences
/// dengan key `token` saat login. Wrapper ini otomatis menambahkan header tersebut
/// ke setiap request, kecuali jika pemanggil sudah menyetel Authorization sendiri.
///
/// Pemakaian: cukup ganti
///   import 'package:http/http.dart' as http;
/// menjadi
///   import 'package:laundrypoint/core/services/auth_http.dart' as http;
Future<Map<String, String>> _withAuth(Map<String, String>? headers) async {
  final result = <String, String>{...?headers};
  if (!result.keys.any((k) => k.toLowerCase() == 'accept')) {
    result['Accept'] = 'application/json';
  }
  final hasAuth = result.keys.any((k) => k.toLowerCase() == 'authorization');
  if (!hasAuth) {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      result['Authorization'] = 'Bearer $token';
    }
  }
  return result;
}

Future<base.Response> get(Uri url, {Map<String, String>? headers}) async =>
    base.get(url, headers: await _withAuth(headers));

Future<base.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async =>
    base.post(
      url,
      headers: await _withAuth(headers),
      body: body,
      encoding: encoding,
    );

Future<base.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async =>
    base.put(
      url,
      headers: await _withAuth(headers),
      body: body,
      encoding: encoding,
    );

Future<base.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async =>
    base.patch(
      url,
      headers: await _withAuth(headers),
      body: body,
      encoding: encoding,
    );

Future<base.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async =>
    base.delete(
      url,
      headers: await _withAuth(headers),
      body: body,
      encoding: encoding,
    );

/// Multipart request yang otomatis menyertakan token saat `send()`.
class MultipartRequest extends base.MultipartRequest {
  MultipartRequest(super.method, super.url);

  @override
  Future<base.StreamedResponse> send() async {
    headers.addAll(await _withAuth(headers));
    return super.send();
  }
}
