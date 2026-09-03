import 'package:xml/xml.dart';

class Performance {
  final String id;
  final String title;
  final String startDate;
  final String endDate;
  final String venue;
  final String posterUrl;
  final String genre;
  final String state;
  final String district;

  bool get isSoldOut =>
      state.contains('매진') ||
      state.toLowerCase().contains('sold out');

  Performance({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.venue,
    required this.posterUrl,
    required this.genre,
    required this.state,
    required this.district,
  });

  factory Performance.fromJson(Map<String, dynamic> json) {
    final stateStr = json['state']?.toString() ?? '';
    final isSold =
        json['isSoldOut'] == true ||
        stateStr.contains('매진') ||
        stateStr.toLowerCase().contains('sold out');

    return Performance(
      id: json['id'] ?? json['kopisId'] ?? '',
      title: json['title'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      venue: json['venue'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      genre: json['genre'] ?? '',
      state: isSold
          ? (stateStr.isNotEmpty ? stateStr : '매진')
          : (stateStr.isNotEmpty ? stateStr : '공연예정'),
      district: json['district'] ?? '전체',
    );
  }

  factory Performance.fromXml(XmlElement node) {
    return Performance(
      id: node.findElements('mt20id').firstOrNull?.innerText ?? '',
      title: node.findElements('prfnm').firstOrNull?.innerText ?? '',
      startDate: node.findElements('prfpdfrom').firstOrNull?.innerText ?? '',
      endDate: node.findElements('prfpdto').firstOrNull?.innerText ?? '',
      venue: node.findElements('fcltynm').firstOrNull?.innerText ?? '',
      posterUrl: node.findElements('poster').firstOrNull?.innerText ?? '',
      genre: node.findElements('genrenm').firstOrNull?.innerText ?? '',
      state: node.findElements('prfstate').firstOrNull?.innerText ?? '',
      district: '전체',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startDate': startDate,
      'endDate': endDate,
      'venue': venue,
      'posterUrl': posterUrl,
      'genre': genre,
      'state': state,
      'district': district,
      'isSoldOut': isSoldOut,
    };
  }
}

class BookingLink {
  final String name;
  final String url;

  BookingLink({required this.name, required this.url});
}

class PerformanceDetail {
  final String id;
  final String title;
  final String startDate;
  final String endDate;
  final String venue;
  final String cast;
  final String runtime;
  final String timeGuidance;
  final String ageLimit;
  final String price;
  final String posterUrl;
  final String genre;
  final String state;
  final String district;
  final List<BookingLink> bookingLinks;
  final List<String> detailImages;

  bool get isSoldOut =>
      state.contains('매진') ||
      state.toLowerCase().contains('sold out');

  PerformanceDetail({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.venue,
    required this.cast,
    required this.runtime,
    required this.timeGuidance,
    required this.ageLimit,
    required this.price,
    required this.posterUrl,
    required this.genre,
    required this.state,
    required this.district,
    required this.bookingLinks,
    required this.detailImages,
  });

  factory PerformanceDetail.fromJson(Map<String, dynamic> json) {
    List<BookingLink> parsedLinks = [];
    if (json['bookingLinks'] != null) {
      for (var link in json['bookingLinks']) {
        parsedLinks.add(
          BookingLink(name: link['name'] ?? '', url: link['url'] ?? ''),
        );
      }
    }

    final stateStr = json['state']?.toString() ?? '';

    // Convert string fields safely
    return PerformanceDetail(
      id: json['id'] ?? json['kopisId'] ?? '',
      title: json['title'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      venue: json['venue'] ?? '',
      cast: json['cast'] ?? '출연진 정보 없음',
      runtime: json['runtime'] ?? '',
      timeGuidance: json['timeGuidance'] ?? '',
      ageLimit: json['ageLimit'] ?? '전체관람가',
      price: () {
        final p = json['price']?.toString().trim();
        if (p != null && p.isNotEmpty && p != 'None' && p != 'null') {
          return p;
        }
        return '공연장/기획사 문의';
      }(),
      posterUrl: json['posterUrl'] ?? '',
      genre: json['genre'] ?? '',
      state: stateStr.isNotEmpty ? stateStr : '공연예정',
      district: json['district'] ?? '전체',
      bookingLinks: parsedLinks,
      detailImages:
          (json['detailImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory PerformanceDetail.fromXml(XmlElement node) {
    final title = node.findElements('prfnm').firstOrNull?.innerText ?? '';
    final venue = node.findElements('fcltynm').firstOrNull?.innerText ?? '';

    // Parse relates / booking links
    final List<BookingLink> parsedLinks = [];
    final relatesElements = node
        .findElements('relates')
        .expand((r) => r.findElements('relate'));
    for (final r in relatesElements) {
      final name =
          r.findElements('relatenm').firstOrNull?.innerText.trim() ?? '';
      final url =
          r.findElements('relateurl').firstOrNull?.innerText.trim() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) {
        parsedLinks.add(
          BookingLink(name: name.isNotEmpty ? name : '예매처 바로가기', url: url),
        );
      }
    }

    // Fallback booking link if none provided but in booking state
    if (parsedLinks.isEmpty) {
      if (venue.contains('울산문화예술회관')) {
        parsedLinks.add(
          BookingLink(name: '울산문화예술회관 공식 예매', url: 'https://ucac.ulsan.go.kr'),
        );
      } else if (venue.contains('중구문화의전당') ||
          venue.contains('함월홀') ||
          venue.contains('달빛마루')) {
        parsedLinks.add(
          BookingLink(
            name: '중구문화의전당 공식 예매',
            url: 'https://artscenter.junggu.ulsan.kr/01_Menu/01.do',
          ),
        );
      } else {
        parsedLinks.add(
          BookingLink(
            name: '인터파크 티켓 검색',
            url:
                'https://tickets.interpark.com/search?keyword=${Uri.encodeComponent(title)}',
          ),
        );
      }
    }

    return PerformanceDetail(
      id: node.findElements('mt20id').firstOrNull?.innerText ?? '',
      title: title,
      startDate: node.findElements('prfpdfrom').firstOrNull?.innerText ?? '',
      endDate: node.findElements('prfpdto').firstOrNull?.innerText ?? '',
      venue: venue,
      cast: node.findElements('prfcast').firstOrNull?.innerText ?? '',
      runtime: node.findElements('prfruntime').firstOrNull?.innerText ?? '',
      timeGuidance:
          node.findElements('dtguidance').firstOrNull?.innerText ?? '',
      ageLimit: node.findElements('prfage').firstOrNull?.innerText ?? '',
      price: () {
        final p = node
            .findElements('pcseguidance')
            .firstOrNull
            ?.innerText
            .trim();
        if (p != null && p.isNotEmpty && p != 'None' && p != 'null') {
          return p;
        }
        return '공연장/기획사 문의';
      }(),
      posterUrl: node.findElements('poster').firstOrNull?.innerText ?? '',
      genre: node.findElements('genrenm').firstOrNull?.innerText ?? '',
      state: node.findElements('prfstate').firstOrNull?.innerText ?? '',
      district: '전체',
      bookingLinks: parsedLinks,
      detailImages: node
          .findElements('styurls')
          .expand((s) => s.findElements('styurl'))
          .map((e) => e.innerText.trim())
          .where((url) => url.isNotEmpty)
          .toList(),
    );
  }
}
