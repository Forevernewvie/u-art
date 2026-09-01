import requests
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
import os
from crawlers.base_crawler import BaseCrawler

class KopisCrawler(BaseCrawler):
    def __init__(self):
        super().__init__()
        self.api_key = os.getenv("KOPIS_API_KEY", "534331c08630453bbd1df50692635746")

    def get_name(self) -> str:
        return "KOPIS"
        
    def _map_venue_to_district(self, venue: str) -> str:
        # 간단한 매핑 규칙
        if "중구" in venue: return "중구"
        if "남구" in venue: return "남구"
        if "북구" in venue: return "북구"
        if "동구" in venue: return "동구"
        if "울주" in venue: return "울주군"
        if "울산문화예술회관" in venue: return "남구" # 울산문예회관은 남구에 위치
        return "전체"

    def fetch_data(self):
        stdate = datetime.now().strftime("%Y%m%d")
        eddate = (datetime.now() + timedelta(days=90)).strftime("%Y%m%d")
        url = f"http://kopis.or.kr/openApi/restful/pblprfr?service={self.api_key}&stdate={stdate}&eddate={eddate}&cpage=1&rows=100&signgucode=31"
        
        resp = requests.get(url)
        if resp.status_code != 200:
            raise Exception(f"HTTP {resp.status_code}")
            
        root = ET.fromstring(resp.text)
        for node in root.findall('db'):
            venue = node.findtext('fcltynm') or ""
            perf = {
                "id": node.findtext('mt20id'),
                "title": node.findtext('prfnm'),
                "startDate": node.findtext('prfpdfrom'),
                "endDate": node.findtext('prfpdto'),
                "venue": venue,
                "posterUrl": node.findtext('poster'),
                "genre": node.findtext('genrenm'),
                "state": node.findtext('prfstate'),
                "source": "KOPIS",
                "district": self._map_venue_to_district(venue)
            }
            self.save_performance(perf)
