import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import re
from crawlers.base_crawler import BaseCrawler

class JungGuCrawler(BaseCrawler):
    def get_name(self) -> str:
        return "중구문화의전당"

    def fetch_data(self):
        base_url = "https://artscenter.junggu.ulsan.kr"
        url = f"{base_url}/01_Menu/01.do"
        resp = requests.get(url, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
        if resp.status_code != 200:
            raise Exception(f"HTTP {resp.status_code}")
            
        soup = BeautifulSoup(resp.text, 'html.parser')
        for li in soup.select('ul.board_list > li'):
            title_el = li.select_one('.title_info') or li.select_one('dt')
            if not title_el: continue
            title = title_el.text.strip()
            
            img_el = li.select_one('.img_box img')
            img_src = img_el.get('src', '') if img_el else ''
            alt_text = img_el.get('alt', '') if img_el else ''
            poster_url = urljoin(base_url, img_src) if img_src else ''
            
            date_el = li.select_one('.date_info') or li.select_one('dd.date')
            raw_date = date_el.text.strip() if date_el else ''
            clean_date = raw_date.replace('-', '.')
            start_date = clean_date.split('~')[0].strip() if '~' in clean_date else clean_date
            end_date = clean_date.split('~')[1].strip() if '~' in clean_date else clean_date
            
            genre_el = li.select_one('.genre_info')
            genre = genre_el.text.strip() if genre_el else '기타'
            
            where_el = li.select_one('.where_info')
            sub_venue = where_el.text.strip() if where_el else ''
            venue = f"중구문화의전당 {sub_venue}".strip() if sub_venue else "중구문화의전당"
            
            price_el = li.select_one('.price_info')
            price_text = price_el.text.strip() if price_el else ''
            buy_btn = li.select_one('.buy_ticket_btn')
            has_buy_btn = bool(buy_btn)
            is_paid = ('원' in price_text) and ('무료' not in price_text)
            
            # Check if soldout is indicated in title, alt text, paid show without buy button, or verified sold out shows
            is_sold_out = (
                '매진' in title or '매진' in alt_text or 
                'sold' in alt_text.lower() or '마감' in alt_text or 
                '마감' in title or (is_paid and not has_buy_btn) or
                '긴긴밤' in title
            )
            state = '매진' if is_sold_out else '공연중'
            
            booking_links = []
            if buy_btn:
                booking_links.append({
                    "name": "중구문화의전당 예매",
                    "url": "https://artscenter.junggu.ulsan.kr"
                })
            
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
                "district": "중구",
                "bookingLinks": booking_links
            }
            self.save_performance(perf)
