import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/performance.dart';

class KopisService {
  final String _apiKey;
  final http.Client _client;

  KopisService(this._apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  Future<List<Performance>> getPerformances({
    required String stdate,
    required String eddate,
    String? shprfnmfct,
    String? signgucode,
    int cpage = 1,
    int rows = 100,
  }) async {
    final queryParams = <String, String>{
      'service': _apiKey,
      'stdate': stdate,
      'eddate': eddate,
      'cpage': cpage.toString(),
      'rows': rows.toString(),
    };
    if (shprfnmfct != null && shprfnmfct.isNotEmpty) {
      queryParams['shprfnmfct'] = shprfnmfct;
    }
    if (signgucode != null && signgucode.isNotEmpty) {
      queryParams['signgucode'] = signgucode;
    }

    final url = Uri.http(
      'kopis.or.kr',
      '/openApi/restful/pblprfr',
      queryParams,
    );
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
      final elements = document.findAllElements('db');
      return elements.map((node) => Performance.fromXml(node)).toList();
    } else {
      throw Exception('Failed to load performances');
    }
  }

  Future<List<Performance>> getAllPerformancesByRegion({
    required String stdate,
    required String eddate,
    String signgucode = '31',
  }) async {
    final List<Performance> all = [];
    int cpage = 1;
    while (true) {
      final list = await getPerformances(
        stdate: stdate,
        eddate: eddate,
        signgucode: signgucode,
        cpage: cpage,
        rows: 100,
      );
      if (list.isEmpty) break;
      all.addAll(list);
      if (list.length < 100) break;
      cpage++;
    }
    return all;
  }

  Future<PerformanceDetail> getPerformanceDetail(String id) async {
    final url = Uri.http('kopis.or.kr', '/openApi/restful/pblprfr/$id', {
      'service': _apiKey,
    });
    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
      final db = document.findAllElements('db').first;
      return PerformanceDetail.fromXml(db);
    } else {
      throw Exception('Failed to load performance detail');
    }
  }
}
