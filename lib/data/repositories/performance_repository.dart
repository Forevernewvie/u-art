import 'package:intl/intl.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'performance_repository.g.dart';

@riverpod
UartApiService uartApiService(Ref ref) {
  // Production Cloudflare Tunnel endpoint
  return UartApiService(
    'https://loaded-boring-keeping-previously.trycloudflare.com',
  );
}

@riverpod
PerformanceRepository performanceRepository(Ref ref) {
  return PerformanceRepository(
    ref.watch(uartApiServiceProvider),
    kopisService: KopisService('534331c08630453bbd1df50692635746'),
  );
}

class PerformanceRepository {
  final UartApiService _service;
  final KopisService _kopisService;

  PerformanceRepository(this._service, {KopisService? kopisService})
      : _kopisService =
            kopisService ?? KopisService('534331c08630453bbd1df50692635746');

  Future<List<Performance>> getUpcomingPerformances() async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14));

    final dateFormat = DateFormat('yyyyMMdd');
    final stdateStr = dateFormat.format(now);
    final eddateStr = dateFormat.format(endDate);

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

      final combined = [...ulsanArtsCenter, ...jungguArtsCenter];
      combined.sort((a, b) => a.startDate.compareTo(b.startDate));
      return combined;
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

      final combined = [...ulsanArtsCenter, ...jungguArtsCenter];
      combined.sort((a, b) => a.startDate.compareTo(b.startDate));
      return combined;
    }
  }

  Future<PerformanceDetail> getPerformanceDetail(String id) async {
    try {
      return await _service.getPerformanceDetail(id).timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      return _kopisService.getPerformanceDetail(id);
    }
  }
}
