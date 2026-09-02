import 'package:flutter_test/flutter_test.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/junggu_crawler_service.dart';

void main() {
  test('verify enrichment logic matches Yangpa and BeautyAndBeast', () {
    final statuses = {
      '양파x전진희콘서트노래가된우리': true,
      '가족뮤지컬미녀와야수': true,
      '입과손스튜디오긴긴밤': false,
    };

    final p1 = Performance(
      id: 'PF296116',
      title: '양파X전진희 콘서트: 노래가 된 우리 [울산]',
      startDate: '2026.09.11',
      endDate: '2026.09.11',
      venue: '울산중구문화의전당',
      posterUrl: '',
      genre: '대중음악',
      state: '공연예정',
      district: '전체',
    );

    final isP1SoldOut = JungguCrawlerService.isTitleSoldOut(p1.title, statuses);
    expect(isP1SoldOut, isTrue);

    final p2 = Performance(
      id: 'PF296377',
      title: '미녀와 야수 [울산]',
      startDate: '2026.09.12',
      endDate: '2026.09.12',
      venue: '울산중구문화의전당',
      posterUrl: '',
      genre: '뮤지컬',
      state: '공연예정',
      district: '전체',
    );

    final isP2SoldOut = JungguCrawlerService.isTitleSoldOut(p2.title, statuses);
    expect(isP2SoldOut, isTrue);
  });
}
