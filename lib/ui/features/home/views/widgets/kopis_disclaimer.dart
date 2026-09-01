import 'package:flutter/material.dart';

class KopisDisclaimer extends StatelessWidget {
  const KopisDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    // Get today's date in YYYY.MM.DD format
    final now = DateTime.now();
    final dateString = "\${now.year}.\${now.month.toString().padLeft(2, '0')}.\${now.day.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        children: [
          const Text(
            '※ KOPIS(공연예술통합전산망) 제공 데이터 안내',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white30,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '· 집계기간 : 최종집계 $dateString\n'
            '· 집계대상 : 모든 공연 데이터 전송기관\n'
            '· 아래 집계 데이터는 공연예술통합전산망 연계기관의 티켓판매시스템에서 발권된 분량을 기준으로 제공함으로 해당 공연의 전체 관객 수와 차이가 있을 수 있습니다.',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white30,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
