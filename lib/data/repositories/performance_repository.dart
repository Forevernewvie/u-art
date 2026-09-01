import 'package:intl/intl.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'performance_repository.g.dart';

@riverpod
UartApiService uartApiService(Ref ref) {
  // Production Cloudflare Tunnel endpoint
  return UartApiService('https://loaded-boring-keeping-previously.trycloudflare.com'); 
}

@riverpod
PerformanceRepository performanceRepository(Ref ref) {
  return PerformanceRepository(ref.watch(uartApiServiceProvider));
}

class PerformanceRepository {
  final UartApiService _service;

  PerformanceRepository(this._service);

  Future<List<Performance>> getUpcomingPerformances() async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 14));
    
    final dateFormat = DateFormat('yyyy.MM.dd');
    final stdateStr = dateFormat.format(now);
    final eddateStr = dateFormat.format(endDate);

    final ulsanArtsCenter = await _service.getPerformances(
      stdate: stdateStr, 
      eddate: eddateStr, 
      venue: '울산문화예술회관'
    );
    
    final jungguArtsCenter = await _service.getPerformances(
      stdate: stdateStr, 
      eddate: eddateStr, 
      venue: '중구문화의전당'
    );

    final combined = [...ulsanArtsCenter, ...jungguArtsCenter];
    combined.sort((a, b) => a.startDate.compareTo(b.startDate));
    
    return combined;
  }

  Future<PerformanceDetail> getPerformanceDetail(String id) {
    return _service.getPerformanceDetail(id);
  }
}
