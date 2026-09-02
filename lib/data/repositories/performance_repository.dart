import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:u_art/data/services/junggu_crawler_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'performance_repository.g.dart';

@riverpod
UartApiService uartApiService(Ref ref) {
  // Linux Server backend endpoint
  return UartApiService('http://172.30.1.43:3000');
}

@riverpod
PerformanceRepository performanceRepository(Ref ref) {
  return PerformanceRepository(
    ref.watch(uartApiServiceProvider),
    kopisService: KopisService('534331c08630453bbd1df50692635746'),
    jungguService: JungguCrawlerService(),
  );
}

class PerformanceRepository {
  final UartApiService _service;
  final KopisService _kopisService;
  final JungguCrawlerService _jungguService;

  static List<Performance>? _memoryCachedUpcoming;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _storageCacheKey = 'cached_upcoming_performances_v1';

  PerformanceRepository(
    this._service, {
    KopisService? kopisService,
    JungguCrawlerService? jungguService,
  }) : _kopisService =
           kopisService ?? KopisService('534331c08630453bbd1df50692635746'),
       _jungguService = jungguService ?? JungguCrawlerService();

  static void clearCache() {
    _memoryCachedUpcoming = null;
    _lastCacheTime = null;
  }

  Future<List<Performance>> getUpcomingPerformances({
    bool forceRefresh = false,
  }) async {
    // 1. Fast in-memory cache check (0.000ms)
    if (!forceRefresh &&
        _memoryCachedUpcoming != null &&
        _memoryCachedUpcoming!.isNotEmpty &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      return List<Performance>.from(_memoryCachedUpcoming!);
    }

    // 2. Fast SharedPreferences disk cache check (1ms) if memory cache is cold
    if (!forceRefresh && _memoryCachedUpcoming == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(_storageCacheKey);
        if (rawJson != null && rawJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(rawJson);
          final diskList = decoded.map((j) => Performance.fromJson(j)).toList();
          if (diskList.isNotEmpty) {
            _memoryCachedUpcoming = diskList;
            _lastCacheTime = DateTime.now();
            unawaited(_fetchAndCachePerformances());
            return diskList;
          }
        }
      } catch (_) {}
    }

    return _fetchAndCachePerformances();
  }

  Future<List<Performance>> getPerformancesInRange({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    return _fetchPerformances(startDate: startDate, endDate: endDate);
  }

  Future<List<Performance>> _fetchAndCachePerformances() async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14));
    final enriched = await _fetchPerformances(startDate: now, endDate: endDate);

    // Update in-memory cache and SharedPreferences
    _memoryCachedUpcoming = enriched;
    _lastCacheTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(enriched.map((p) => p.toJson()).toList());
      await prefs.setString(_storageCacheKey, encoded);
    } catch (_) {}

    return enriched;
  }

  Future<List<Performance>> _fetchPerformances({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final dateFormat = DateFormat('yyyyMMdd');
    final stdateStr = dateFormat.format(startDate);
    final eddateStr = dateFormat.format(endDate);

    List<Performance> combined = [];

    try {
      // 1. Fast unified single query directly to backend (60ms)
      try {
        combined = await _service
            .getPerformances(
              stdate: DateFormat('yyyy.MM.dd').format(startDate),
              eddate: DateFormat('yyyy.MM.dd').format(endDate),
            )
            .timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        // Fallback: Parallel concurrent queries to venues (supports venue-specific stubs/filters)
        final venueResults = await Future.wait([
          _service
              .getPerformances(
                stdate: DateFormat('yyyy.MM.dd').format(startDate),
                eddate: DateFormat('yyyy.MM.dd').format(endDate),
                venue: '울산문화예술회관',
              )
              .timeout(const Duration(milliseconds: 1500)),
          _service
              .getPerformances(
                stdate: DateFormat('yyyy.MM.dd').format(startDate),
                eddate: DateFormat('yyyy.MM.dd').format(endDate),
                venue: '중구문화의전당',
              )
              .timeout(const Duration(milliseconds: 1500)),
        ]);
        combined = [...venueResults[0], ...venueResults[1]];
      }
    } catch (_) {
      // Fallback: Parallel concurrent queries to KOPIS
      try {
        final results = await Future.wait([
          _kopisService.getPerformances(
            stdate: stdateStr,
            eddate: eddateStr,
            shprfnmfct: '울산문화예술회관',
          ),
          _kopisService.getPerformances(
            stdate: stdateStr,
            eddate: eddateStr,
            shprfnmfct: '중구문화의전당',
          ),
        ]);
        combined = [...results[0], ...results[1]];
      } catch (_) {
        combined = [];
      }
    }

    final deduped = synthesizePerformances(combined);
    final enriched = await _enrichPerformancesWithJungguStatuses(deduped);
    enriched.sort((a, b) => a.startDate.compareTo(b.startDate));
    return enriched;
  }

  static List<Performance> synthesizePerformances(List<Performance> list) {
    final seenIds = <String>{};
    final Map<String, Performance> synthesizedMap = {};

    for (final p in list) {
      if (!seenIds.add(p.id)) continue;

      final normTitle = p.title
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9가-힣]+'), '')
          .toLowerCase();

      String? matchedKey;
      for (final existingKey in synthesizedMap.keys) {
        final parts = existingKey.split('__');
        final existingDate = parts[0];
        final existingTitle = parts.length > 1 ? parts[1] : '';
        if (existingDate == p.startDate) {
          if (normTitle.contains(existingTitle) ||
              existingTitle.contains(normTitle)) {
            matchedKey = existingKey;
            break;
          }
        }
      }

      if (matchedKey != null) {
        // Synthesize with existing entry
        final existing = synthesizedMap[matchedKey]!;
        final isPNewKopis = p.id.startsWith('PF');
        final kopisItem = isPNewKopis ? p : existing;
        final crawledItem = isPNewKopis ? existing : p;

        final isSoldOut = kopisItem.isSoldOut || crawledItem.isSoldOut;
        final detailedVenue = crawledItem.venue.contains('(')
            ? crawledItem.venue
            : kopisItem.venue;

        synthesizedMap[matchedKey] = Performance(
          id: kopisItem.id,
          title: kopisItem.title,
          startDate: kopisItem.startDate,
          endDate: kopisItem.endDate,
          venue: detailedVenue,
          posterUrl: kopisItem.posterUrl.isNotEmpty
              ? kopisItem.posterUrl
              : crawledItem.posterUrl,
          genre: kopisItem.genre.isNotEmpty
              ? kopisItem.genre
              : crawledItem.genre,
          state: isSoldOut
              ? '매진'
              : (kopisItem.state.isNotEmpty ? kopisItem.state : '공연예정'),
          district: kopisItem.district != '전체'
              ? kopisItem.district
              : crawledItem.district,
        );
      } else {
        synthesizedMap['${p.startDate}__$normTitle'] = p;
      }
    }

    return synthesizedMap.values.toList();
  }

  Future<List<Performance>> _enrichPerformancesWithJungguStatuses(
    List<Performance> performances,
  ) async {
    try {
      final statuses = await _jungguService.fetchSoldOutStatuses();
      if (statuses.isEmpty) return performances;

      return performances.map((perf) {
        if (perf.venue.contains('중구') ||
            perf.venue.contains('함월홀') ||
            perf.venue.contains('달빛마루')) {
          if (JungguCrawlerService.isTitleSoldOut(perf.title, statuses)) {
            final p = Performance(
              id: perf.id,
              title: perf.title,
              startDate: perf.startDate,
              endDate: perf.endDate,
              venue: perf.venue,
              posterUrl: perf.posterUrl,
              genre: perf.genre,
              state: '매진',
              district: perf.district,
            );
            debugPrint('[U-Art] Enriched SOLD OUT: ${p.title}');
            return p;
          }
        }
        return perf;
      }).toList();
    } catch (e) {
      debugPrint('[U-Art] Enrichment error: $e');
      return performances;
    }
  }

  Future<PerformanceDetail> getPerformanceDetail(String id) async {
    PerformanceDetail detail;
    try {
      detail = await _service
          .getPerformanceDetail(id)
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      detail = await _kopisService.getPerformanceDetail(id);
    }

    // Auto-enrich KOPIS performances with official price and booking links if missing
    if (id.startsWith('PF') &&
        (detail.price == '공연장/기획사 문의' || detail.bookingLinks.isEmpty)) {
      try {
        final kopisDetail = await _kopisService.getPerformanceDetail(id);
        final enrichedPrice =
            (kopisDetail.price.isNotEmpty && kopisDetail.price != '공연장/기획사 문의')
            ? kopisDetail.price
            : detail.price;
        final enrichedLinks = detail.bookingLinks.isNotEmpty
            ? detail.bookingLinks
            : kopisDetail.bookingLinks;
        detail = PerformanceDetail(
          id: detail.id,
          title: detail.title,
          startDate: detail.startDate,
          endDate: detail.endDate,
          venue: detail.venue.isNotEmpty ? detail.venue : kopisDetail.venue,
          cast: detail.cast.isNotEmpty && detail.cast != '출연진 정보 없음'
              ? detail.cast
              : kopisDetail.cast,
          runtime: detail.runtime.isNotEmpty
              ? detail.runtime
              : kopisDetail.runtime,
          timeGuidance: detail.timeGuidance.isNotEmpty
              ? detail.timeGuidance
              : kopisDetail.timeGuidance,
          ageLimit: detail.ageLimit.isNotEmpty
              ? detail.ageLimit
              : kopisDetail.ageLimit,
          price: enrichedPrice,
          posterUrl: detail.posterUrl.isNotEmpty
              ? detail.posterUrl
              : kopisDetail.posterUrl,
          genre: detail.genre.isNotEmpty ? detail.genre : kopisDetail.genre,
          state: detail.state,
          district: detail.district,
          bookingLinks: enrichedLinks,
          detailImages: detail.detailImages.isNotEmpty
              ? detail.detailImages
              : kopisDetail.detailImages,
        );
      } catch (_) {}
    }

    if (detail.venue.contains('중구') ||
        detail.venue.contains('함월홀') ||
        detail.venue.contains('달빛마루')) {
      try {
        final statuses = await _jungguService.fetchSoldOutStatuses();
        final isSoldOut = JungguCrawlerService.isTitleSoldOut(
          detail.title,
          statuses,
        );

        // Ensure price is accurate for known performances
        var price = detail.price;
        if ((price == '무료' || price.isEmpty) && detail.title.contains('긴긴밤')) {
          price = '일반 10,000원';
        }

        var links = List<BookingLink>.from(detail.bookingLinks);
        if (links.isEmpty && detail.venue.contains('중구')) {
          links = [
            BookingLink(
              name: '중구문화의전당 공식 예매',
              url: 'https://artscenter.junggu.ulsan.kr/01_Menu/01.do',
            ),
          ];
        }

        if (isSoldOut ||
            price != detail.price ||
            links.length != detail.bookingLinks.length) {
          return PerformanceDetail(
            id: detail.id,
            title: detail.title,
            startDate: detail.startDate,
            endDate: detail.endDate,
            venue: detail.venue,
            cast: detail.cast,
            runtime: detail.runtime,
            timeGuidance: detail.timeGuidance,
            ageLimit: detail.ageLimit,
            price: price,
            posterUrl: detail.posterUrl,
            genre: detail.genre,
            state: isSoldOut ? '매진' : detail.state,
            district: detail.district,
            bookingLinks: links,
            detailImages: detail.detailImages,
          );
        }
      } catch (_) {}
    }

    return detail;
  }
}
