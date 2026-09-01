import pytest
import mongomock
from datetime import datetime
import sys
import os

# Set module path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../crawler')))

from crawlers.base_crawler import BaseCrawler

class MockPipelineCrawler(BaseCrawler):
    def __init__(self, mock_db):
        self.client = None
        self.db = mock_db
        self.performances = self.db.performances
        self.success_count = 0
        self.updated_count = 0
        self.error_log = ""

    def get_name(self):
        return "PipelineCrawler"

    def fetch_data(self):
        pass

def test_full_e2e_pipeline_data_flow():
    """
    Simulate full data pipeline:
    1. KOPIS Crawler ingests base data
    2. Local Crawler (Junggu) ingests crawled ticket link
    3. Smart Merge produces consolidated record
    4. API Query Filters simulate search & retrieval
    5. Flutter Performance Model schema validation
    """
    mock_db = mongomock.MongoClient().uart
    crawler = MockPipelineCrawler(mock_db)

    # Stage 1: KOPIS Ingestion
    kopis_item = {
        "id": "PF2026_001",
        "kopisId": "PF2026_001",
        "title": "2026 울산 태화강 재즈 페스티벌",
        "normTitle": "2026울산태화강재즈페스티벌",
        "startDate": "2026-09-20",
        "endDate": "2026-09-22",
        "venue": "태화강국가정원 야외공연장",
        "district": "중구",
        "posterUrl": "https://kopis.or.kr/jazz_poster.jpg",
        "genre": "대중음악",
        "price": "전석 무료",
        "state": "공연예정",
        "source": "KOPIS",
        "bookingLinks": [{"name": "KOPIS", "url": "https://kopis.or.kr/book/1"}]
    }
    crawler.save_performance(kopis_item)
    assert mock_db.performances.count_documents({}) == 1

    # Stage 2: Junggu local crawler ingests direct reservation
    junggu_item = {
        "id": "JG_TICKET_777",
        "title": "[울산중구] 2026 울산 태화강 재즈 페스티벌",
        "normTitle": "2026울산태화강재즈페스티벌",
        "startDate": "2026-09-20",
        "endDate": "2026-09-22",
        "venue": "태화강 야외무대",
        "source": "CRAWLED",
        "bookingLinks": [{"name": "중구문화의전당 직예매", "url": "https://junggu.ulsan.kr/reserve/777"}]
    }
    crawler.save_performance(junggu_item)
    assert mock_db.performances.count_documents({}) == 1

    # Stage 3: Smart Merge Inspection
    merged = mock_db.performances.find_one({"startDate": "2026-09-20"})
    assert merged is not None
    assert merged["source"] == "KOPIS"
    assert merged["title"] == "2026 울산 태화강 재즈 페스티벌"
    assert len(merged["bookingLinks"]) == 2

    # Stage 4: API Query Filtering Simulation
    # 4-1. Search by Keyword '재즈'
    found_by_q = list(mock_db.performances.find({"title": {"$regex": "재즈"}}))
    assert len(found_by_q) == 1
    assert found_by_q[0]["id"] == "PF2026_001"

    # 4-2. Filter by Date Range
    found_by_date = list(mock_db.performances.find({
        "endDate": {"$gte": "2026-09-01"},
        "startDate": {"$lte": "2026-09-30"}
    }))
    assert len(found_by_date) == 1

    # Stage 5: Flutter App Model Compatibility & Null Safety Assertions
    record = merged
    # Flutter Performance model requires: id, title, venue, startDate, endDate, posterUrl, bookingLinks
    required_fields = ["id", "title", "venue", "startDate", "endDate", "posterUrl"]
    for field in required_fields:
        assert field in record, f"Missing required Flutter field: {field}"
        assert record[field] is not None, f"Field {field} must not be None"
        assert isinstance(record[field], str), f"Field {field} must be String"

    assert "bookingLinks" in record
    assert isinstance(record["bookingLinks"], list)
    for link in record["bookingLinks"]:
        assert "name" in link and "url" in link
        assert link["url"].startswith("http")

def test_flutter_null_safety_defensive_edge_case():
    """Verify that even when external sources have missing optional fields, Flutter contract holds"""
    mock_db = mongomock.MongoClient().uart
    crawler = MockPipelineCrawler(mock_db)

    sparse_item = {
        "id": "SPARSE_001",
        "title": "소규모 버스킹",
        "normTitle": "소규모버스킹",
        "startDate": "2026-10-05",
        "endDate": "2026-10-05",
        "venue": "울산대공원",
        "posterUrl": "", # empty poster fallback
        "genre": None,   # None genre fallback
        "price": None,   # None price fallback
        "bookingLinks": []
    }
    crawler.save_performance(sparse_item)

    retrieved = mock_db.performances.find_one({"id": "SPARSE_001"})
    assert retrieved is not None
    # Ensure ID and basic string keys are preserved for Flutter Dart json serialization
    assert retrieved["id"] == "SPARSE_001"
    assert retrieved["title"] == "소규모 버스킹"
    assert isinstance(retrieved["bookingLinks"], list)
