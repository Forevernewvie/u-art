import pytest
import mongomock
from datetime import datetime
import sys
import os

# Add crawler module to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../crawler')))

from crawlers.base_crawler import BaseCrawler
from crawlers.kopis_crawler import KopisCrawler
from crawlers.junggu_crawler import JungGuCrawler

class MockBaseCrawler(BaseCrawler):
    def __init__(self, mock_db):
        self.client = None
        self.db = mock_db
        self.performances = self.db.performances
        self.success_count = 0
        self.updated_count = 0
        self.error_log = ""

    def get_name(self):
        return "MockCrawler"

    def fetch_data(self):
        pass

def test_smart_merge_kopis_first_then_crawled():
    """KOPIS baseline first, then Junggu crawled data appends bookingLinks without overwriting base"""
    mock_db = mongomock.MongoClient().uart
    crawler = MockBaseCrawler(mock_db)

    # 1. Save KOPIS performance
    kopis_data = {
        "id": "PF12345",
        "kopisId": "PF12345",
        "title": "라푼젤 어린이 뮤지컬",
        "normTitle": "라푼젤어린이뮤지컬",
        "startDate": "2026-09-15",
        "endDate": "2026-09-15",
        "venue": "중구문화의전당 함월홀",
        "posterUrl": "http://kopis.or.kr/poster.jpg",
        "genre": "뮤지컬",
        "price": "전석 20,000원",
        "source": "KOPIS",
        "bookingLinks": [{"name": "인터파크", "url": "https://interpark.com/123"}]
    }
    crawler.save_performance(kopis_data)

    assert mock_db.performances.count_documents({}) == 1
    saved = mock_db.performances.find_one({"id": "PF12345"})
    assert saved["source"] == "KOPIS"
    assert len(saved["bookingLinks"]) == 1

    # 2. Save CRAWLED (Junggu) performance with same date and matching title
    crawled_data = {
        "id": "JUNGGU_999",
        "title": "[중구] 라푼젤 어린이 뮤지컬",
        "normTitle": "라푼젤어린이뮤지컬",
        "startDate": "2026-09-15",
        "endDate": "2026-09-15",
        "venue": "함월홀",
        "posterUrl": "http://junggu.ulsan.kr/poster.jpg",
        "source": "CRAWLED",
        "bookingLinks": [{"name": "중구문화의전당 예매", "url": "https://junggu.ulsan.kr/book/999"}]
    }
    crawler.save_performance(crawled_data)

    # Should NOT insert a new document, but merge booking links into the KOPIS document
    assert mock_db.performances.count_documents({}) == 1
    merged = mock_db.performances.find_one({"startDate": "2026-09-15"})
    assert merged["source"] == "KOPIS"
    assert merged["title"] == "라푼젤 어린이 뮤지컬" # KOPIS title preserved
    assert merged["posterUrl"] == "http://kopis.or.kr/poster.jpg" # KOPIS poster preserved
    assert len(merged["bookingLinks"]) == 2
    urls = [b["url"] for b in merged["bookingLinks"]]
    assert "https://interpark.com/123" in urls
    assert "https://junggu.ulsan.kr/book/999" in urls

def test_smart_merge_crawled_first_then_kopis():
    """Crawled data exists first, then KOPIS upgrades it while keeping crawled bookingLinks"""
    mock_db = mongomock.MongoClient().uart
    crawler = MockBaseCrawler(mock_db)

    # 1. Save CRAWLED first
    crawled_data = {
        "id": "JUNGGU_888",
        "title": "울산시립합창단 정기연주회",
        "normTitle": "울산시립합창단정기연주회",
        "startDate": "2026-10-01",
        "endDate": "2026-10-01",
        "venue": "울산문화예술회관 대공연장",
        "posterUrl": "http://ucac.ulsan.kr/poster.jpg",
        "source": "CRAWLED",
        "bookingLinks": [{"name": "문예회관 직예매", "url": "https://ucac.ulsan.kr/book/888"}]
    }
    crawler.save_performance(crawled_data)
    assert mock_db.performances.count_documents({}) == 1

    # 2. Later KOPIS comes in with high-fidelity metadata
    kopis_data = {
        "id": "PF99999",
        "kopisId": "PF99999",
        "title": "제45회 울산시립합창단 정기연주회",
        "normTitle": "울산시립합창단정기연주회",
        "startDate": "2026-10-01",
        "endDate": "2026-10-01",
        "venue": "울산문화예술회관",
        "posterUrl": "http://kopis.or.kr/high_res.jpg",
        "genre": "클래식",
        "price": "R석 10,000원",
        "source": "KOPIS",
        "bookingLinks": [{"name": "YES24", "url": "https://yes24.com/456"}]
    }
    crawler.save_performance(kopis_data)

    assert mock_db.performances.count_documents({}) == 1
    merged = mock_db.performances.find_one({"startDate": "2026-10-01"})
    assert merged["source"] == "KOPIS"
    assert merged["genre"] == "클래식"
    assert merged["posterUrl"] == "http://kopis.or.kr/high_res.jpg"
    assert len(merged["bookingLinks"]) == 2
    urls = [b["url"] for b in merged["bookingLinks"]]
    assert "https://ucac.ulsan.kr/book/888" in urls
    assert "https://yes24.com/456" in urls

def test_duplicate_booking_link_prevention():
    """Duplicate booking URLs must not be appended multiple times"""
    mock_db = mongomock.MongoClient().uart
    crawler = MockBaseCrawler(mock_db)

    data = {
        "id": "PF111",
        "title": "테스트 공연",
        "normTitle": "테스트공연",
        "startDate": "2026-11-11",
        "endDate": "2026-11-11",
        "venue": "테스트홀",
        "source": "KOPIS",
        "bookingLinks": [{"name": "인터파크", "url": "https://interpark.com/same"}]
    }
    crawler.save_performance(data)
    # Re-run same crawling
    crawler.save_performance(data)

    merged = mock_db.performances.find_one({"startDate": "2026-11-11"})
    assert len(merged["bookingLinks"]) == 1

def test_crawler_error_resilience():
    """Crawler.run() should catch any unhandled exceptions gracefully without crashing process"""
    class CrashingCrawler(BaseCrawler):
        def __init__(self):
            self.success_count = 0
            self.updated_count = 0
            self.error_log = ""
        def get_name(self):
            return "BrokenAPI"
        def fetch_data(self):
            raise ConnectionError("External KOPIS API 503 Service Unavailable")

    broken = CrashingCrawler()
    s, f, u, log = broken.run()
    assert s == 0
    assert f == 1
    assert "BrokenAPI Failed" in log

def test_smart_merge_sold_out_propagation():
    """When crawler marks a performance as sold out, smart merge must propagate isSoldOut to KOPIS doc"""
    mock_db = mongomock.MongoClient().uart
    crawler = MockBaseCrawler(mock_db)

    # 1. KOPIS doc initially saved as '공연중'
    kopis_data = {
        "id": "PF_SOLDOUT",
        "title": "양파 콘서트",
        "normTitle": "양파콘서트",
        "startDate": "2026-09-11",
        "endDate": "2026-09-11",
        "venue": "중구문화의전당",
        "state": "공연중",
        "source": "KOPIS"
    }
    crawler.save_performance(kopis_data)

    # 2. Junggu Crawler detects it's sold out
    crawled_data = {
        "title": "양파X전진희 콘서트",
        "normTitle": "양파콘서트",
        "startDate": "2026-09-11",
        "endDate": "2026-09-11",
        "venue": "중구문화의전당",
        "state": "매진",
        "isSoldOut": True,
        "source": "CRAWLED"
    }
    crawler.save_performance(crawled_data)

    merged = mock_db.performances.find_one({"startDate": "2026-09-11"})
    assert merged["state"] == "매진"
    assert merged["isSoldOut"] is True

