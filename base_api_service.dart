import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class BaseApiService {
  final String? token;
  final http.Client _client;

  BaseApiService({this.token, http.Client? client})
      : _client = client ?? http.Client();

  // ===== METHOD DASAR =====
  Future<http.Response> get(String url) async {
    return await _client.get(
      Uri.parse(url),
      headers: ApiConstants.headers(token: token),
    );
  }

  Future<http.Response> post(String url, {Map<String, dynamic>? body}) async {
    return await _client.post(
      Uri.parse(url),
      headers: ApiConstants.headers(token: token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String url, {Map<String, dynamic>? body}) async {
    return await _client.put(
      Uri.parse(url),
      headers: ApiConstants.headers(token: token),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String url) async {
    return await _client.delete(
      Uri.parse(url),
      headers: ApiConstants.headers(token: token),
    );
  }

  // Untuk upload file (khusus)
  Future<http.StreamedResponse> uploadImage({
    required String url,
    required String filePath,
    required String productId,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(ApiConstants.multipartHeaders(token: token));
    request.files.add(await http.MultipartFile.fromPath('image', filePath));
    request.fields['product_id'] = productId;
    return await request.send();
  }

  void dispose() {
    _client.close();
  }
}