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
        resp = requests.get(url, verify=False, headers={'User-Agent': 'Mozilla/5.0'})
        if resp.status_code != 200:
            raise Exception(f"HTTP {resp.status_code}")
            
        soup = BeautifulSoup(resp.text, 'html.parser')
        for li in soup.select('ul.list_in > li'):
            title_el = li.select_one('.pf_title') or li.select_one('strong')
            if not title_el: continue
            
            title = title_el.text.strip()
            
            img_el = li.select_one('.img_zone img')
            poster_url = 'https://www.ulsan.go.kr' + img_el['src'] if img_el and img_el.get('src') else ''
            
            btn_zone = li.select_one('.btn_zone')
            btn_class = btn_zone.get('class', []) if btn_zone else []
            is_sold_out = ('soldout' in btn_class) or ('매진' in title)
            state = '매진' if is_sold_out else '공연중'
            
            date_el = li.select_one('.date')
            raw_date = date_el.text.strip().replace('\n', '').replace('\t', '') if date_el else ''
            # Handle date range format e.g. "2026.09.04 ~ 09.05"
            parts = [p.strip() for p in raw_date.split('~')]
            start_date = parts[0].strip() if parts else datetime.now().strftime("%Y.%m.%d")
            end_date = start_date
            if len(parts) > 1 and parts[1]:
                end_p = parts[1].strip()
                if len(end_p) == 5: # e.g. "09.05" -> prefix year
                    year = start_date.split('.')[0] if '.' in start_date else str(datetime.now().year)
                    end_date = f"{year}.{end_p}"
                else:
                    end_date = end_p
            
            loc_el = li.select_one('.loc')
            subvenue = loc_el.text.strip() if loc_el else ''
            venue = f"울산문화예술회관 ({subvenue})".strip() if subvenue else "울산문화예술회관"
            
            genre_el = li.select_one('.cate_field span')
            genre = genre_el.text.strip() if genre_el else '기타'
            
            booking_links = [{
                "name": "울산문화예술회관 공식 예매",
                "url": url
            }]
            
            import re
            norm_title = re.sub(r'[\s\W_]+', '', title)
            
            perf = {
                "title": title,
                "normTitle": norm_title,
                "startDate": start_date,
                "endDate": end_date,
                "venue": venue,
                "posterUrl": poster_url,
                "genre": genre,
                "state": state,
                "isSoldOut": is_sold_out,
                "source": "CRAWLED",
                "district": "남구",
                "bookingLinks": booking_links
            }
            self.save_performance(perf)
