import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:u_art/data/services/junggu_crawler_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'performance_repository.g.dart';

@riverpod
UartApiService uartApiService(Ref ref) {
  // Linux Server backend endpoint
  return UartApiService(
    'http://172.30.1.43:3000',
  );
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

  PerformanceRepository(
    this._service, {
    KopisService? kopisService,
    JungguCrawlerService? jungguService,
  })  : _kopisService =
            kopisService ?? KopisService('534331c08630453bbd1df50692635746'),
        _jungguService = jungguService ?? JungguCrawlerService();

  Future<List<Performance>> getUpcomingPerformances() async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14));

    final dateFormat = DateFormat('yyyyMMdd');
    final stdateStr = dateFormat.format(now);
    final eddateStr = dateFormat.format(endDate);

    List<Performance> combined = [];

    try {
      final ulsanArtsCenter = await _service.getPerformances(
        stdate: DateFormat('yyyy.MM.dd').format(now),
        eddate: DateFormat('yyyy.MM.dd').format(endDate),
        venue: '울산문화예술회관',
      ).timeout(const Duration(milliseconds: 1500));

      final jungguArtsCenter = await _service.getPerformances(
        stdate: DateFormat('yyyy.MM.dd').format(now),
        eddate: DateFormat('yyyy.MM.dd').format(endDate),
        venue: '중구문화의전당',
      ).timeout(const Duration(milliseconds: 1500));

      combined = [...ulsanArtsCenter, ...jungguArtsCenter];
    } catch (_) {
      final ulsanArtsCenter = await _kopisService.getPerformances(
        stdate: stdateStr,
        eddate: eddateStr,
        shprfnmfct: '울산문화예술회관',
      );

      final jungguArtsCenter = await _kopisService.getPerformances(
        stdate: stdateStr,
        eddate: eddateStr,
        shprfnmfct: '중구문화의전당',
      );

      combined = [...ulsanArtsCenter, ...jungguArtsCenter];
    }

    // Deduplicate by ID
    final seenIds = <String>{};
    final deduped = <Performance>[];
    for (final p in combined) {
      if (seenIds.add(p.id)) {
        deduped.add(p);
      }
    }

    final enriched = await _enrichPerformancesWithJungguStatuses(deduped);
    enriched.sort((a, b) => a.startDate.compareTo(b.startDate));
    return enriched;
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

    if (detail.venue.contains('중구') ||
        detail.venue.contains('함월홀') ||
        detail.venue.contains('달빛마루')) {
      try {
        final statuses = await _jungguService.fetchSoldOutStatuses();
        if (JungguCrawlerService.isTitleSoldOut(detail.title, statuses)) {
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
            price: detail.price,
            posterUrl: detail.posterUrl,
            genre: detail.genre,
            state: '매진',
            district: detail.district,
            bookingLinks: detail.bookingLinks,
            detailImages: detail.detailImages,
          );
        }
      } catch (_) {}
    }

    return detail;
  }
}
