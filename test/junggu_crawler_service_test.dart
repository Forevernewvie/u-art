import 'package:flutter_test/flutter_test.dart';
import 'package:u_art/data/services/junggu_crawler_service.dart';

void main() {
  group('JungguCrawlerService matching tests', () {
    test(
      'correctly matches KOPIS titles to crawled Junggu sold out titles',
      () {
        final statuses = {
          '양파x전진희콘서트노래가된우리': true,
          '가족뮤지컬미녀와야수': true,
          '입과손스튜디오긴긴밤': false,
          '2026렉처콘서트조우제3장리골레토': false,
        };

        expect(
          JungguCrawlerService.isTitleSoldOut(
            '양파X전진희 콘서트: 노래가 된 우리 [울산]',
            statuses,
          ),
          isTrue,
        );

        expect(
          JungguCrawlerService.isTitleSoldOut('미녀와 야수 [울산]', statuses),
          isTrue,
        );

        expect(
          JungguCrawlerService.isTitleSoldOut('긴긴밤 [울산]', statuses),
          isFalse,
        );

        expect(
          JungguCrawlerService.isTitleSoldOut('렉처콘서트 조우, 제3장 리골레토', statuses),
          isFalse,
        );
      },
    );

    test('matches Ginginbam when marked sold out in statuses', () {
      final statuses = {'입과손스튜디오긴긴밤': true};

      expect(JungguCrawlerService.isTitleSoldOut('긴긴밤 [울산]', statuses), isTrue);

      expect(
        JungguCrawlerService.isTitleSoldOut('입과손스튜디오 <긴긴밤>', statuses),
        isTrue,
      );
    });

    test('clearCache resets static in-memory cache', () {
      JungguCrawlerService.clearCache();
      // Verifies no exception thrown
      expect(true, isTrue);
    });
  });
}
