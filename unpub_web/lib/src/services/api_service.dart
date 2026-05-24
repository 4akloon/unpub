import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unpub_api/models.dart';

import 'base_url.dart';

class PackageNotExistsException implements Exception {
  PackageNotExistsException(this.message);

  final String message;
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl;

  String? _baseUrl;

  String get baseUrl => _baseUrl ?? defaultBaseUrl;

  void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
  }

  Future<dynamic> _fetch(
    String path, [
    Map<String, dynamic> queryParameters = const {},
  ]) async {
    final params = Map<String, dynamic>.from(queryParameters)
      ..removeWhere((_, value) => value == null);

    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: params.map((key, value) => MapEntry(key, value.toString())),
    );
    final response = await http.get(uri);
    final data = json.decode(response.body) as Map<String, dynamic>;

    if (data['error'] != null) {
      final error = data['error'] as String;
      if (error.contains('package not exists')) {
        throw PackageNotExistsException(error);
      }
      throw ApiException(error);
    }

    return data['data'];
  }

  Future<ListApi> fetchPackages({
    int? size,
    int? page,
    String? sort,
    String? q,
  }) async {
    final result = await _fetch('/webapi/packages', {
      'size': size,
      'page': page,
      'sort': sort,
      'q': q,
    });
    return ListApi.fromJson(result as Map<String, dynamic>);
  }

  Future<WebapiDetailView> fetchPackage(String name, String? version) async {
    final resolvedVersion = version ?? 'latest';
    final result = await _fetch('/webapi/package/$name/$resolvedVersion');
    return WebapiDetailView.fromJson(result as Map<String, dynamic>);
  }
}

final apiService = ApiService();
