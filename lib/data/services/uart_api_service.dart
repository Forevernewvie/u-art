import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/performance.dart';

class UartApiService {
  final String baseUrl;
  final http.Client _client;

  UartApiService(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  Future<List<Performance>> getPerformances({
    required String stdate,
    required String eddate,
    String? venue,
    String? genre,
  }) async {
    final queryParams = <String, String>{'stdate': stdate, 'eddate': eddate};
    if (venue != null && venue.isNotEmpty) {
      queryParams['venue'] = venue;
    }
    if (genre != null && genre.isNotEmpty) {
      queryParams['genre'] = genre;
    }

    final uri = Uri.parse(
      '$baseUrl/api/performances',
    ).replace(queryParameters: queryParams);

    // localtunnel bypass header for programmatic access
    final response = await _client.get(
      uri,
      headers: {'Bypass-Tunnel-Reminder': 'true'},
    );

    if (response.statusCode == 200) {
      // Must decode properly to handle Korean UTF-8
      final List<dynamic> jsonList = json.decode(
        utf8.decode(response.bodyBytes),
      );
      return jsonList.map((json) => Performance.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load performances from U-Art API');
    }
  }

  Future<PerformanceDetail> getPerformanceDetail(String id) async {
    final uri = Uri.parse('$baseUrl/api/performances/$id');
    final response = await _client.get(
      uri,
      headers: {'Bypass-Tunnel-Reminder': 'true'},
    );

    if (response.statusCode == 200) {
      final jsonMap = json.decode(utf8.decode(response.bodyBytes));
      return PerformanceDetail.fromJson(jsonMap);
    } else {
      throw Exception('Failed to load performance detail from U-Art API');
    }
  }
}
