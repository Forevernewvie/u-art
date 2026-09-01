import requests
from bs4 import BeautifulSoup
from datetime import datetime
from crawlers.base_crawler import BaseCrawler

class UcacCrawler(BaseCrawler):
    def get_name(self) -> str:
        return "울산문화예술회관"

    def fetch_data(self):
        url = "https://www.ulsan.go.kr/ucac/art/page.do?mnu_code=mnu001002"
        # ucac is using self signed or legacy ssl, ignore warning
        resp = requests.get(url, verify=False)
        if resp.status_code != 200:
            raise Exception(f"HTTP {resp.status_code}")
            
        soup = BeautifulSoup(resp.text, 'html.parser')
        for li in soup.select('ul.list_in > li'):
            title_el = li.select_one('strong')
            if not title_el: continue
            
            perf = {
                "title": title_el.text.strip(),
                "startDate": datetime.now().strftime("%Y.%m.%d"),
                "endDate": datetime.now().strftime("%Y.%m.%d"),
                "venue": "울산문화예술회관",
                "posterUrl": "",
                "genre": "기타",
                "state": "공연중",
                "source": "UCAC",
                "district": "남구" # 문예회관은 남구에 위치
            }
            self.save_performance(perf)
