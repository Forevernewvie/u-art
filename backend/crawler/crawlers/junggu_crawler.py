import requests
from bs4 import BeautifulSoup
from crawlers.base_crawler import BaseCrawler

class JungGuCrawler(BaseCrawler):
    def get_name(self) -> str:
        return "중구"

    def fetch_data(self):
        url = "https://artscenter.junggu.ulsan.kr/01_Menu/01.do"
        resp = requests.get(url)
        if resp.status_code != 200:
            raise Exception(f"HTTP {resp.status_code}")
            
        soup = BeautifulSoup(resp.text, 'html.parser')
        for li in soup.select('ul.board_list > li'):
            title_el = li.select_one('dt')
            if not title_el: continue
            title = title_el.text.strip()
            date_text = li.select_one('dd.date').text.strip() if li.select_one('dd.date') else ""
            
            perf = {
                "title": title,
                "startDate": date_text.split('~')[0].strip() if '~' in date_text else date_text,
                "endDate": date_text.split('~')[1].strip() if '~' in date_text else date_text,
                "venue": "중구문화의전당",
                "posterUrl": "",
                "genre": "기타",
                "state": "공연중",
                "source": "JUNGGU",
                "district": "중구"
            }
            self.save_performance(perf)
