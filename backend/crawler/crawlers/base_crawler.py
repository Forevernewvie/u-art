import abc
from datetime import datetime
from pymongo import MongoClient
import os
import re
import hashlib

MONGO_URI = os.getenv("MONGO_URI", "mongodb://root:examplepassword@db:27017/uart?authSource=admin")

def canonical_date(d_str: str) -> str:
    """Normalizes YYYY-MM-DD or YYYY.MM.DD to YYYY.MM.DD."""
    if not d_str:
        return ""
    cleaned = d_str.strip().replace("-", ".")
    parts = cleaned.split(".")
    if len(parts) == 3:
        return f"{parts[0]}.{parts[1].zfill(2)}.{parts[2].zfill(2)}"
    return cleaned

def canonical_venue(v_str: str) -> str:
    """Normalizes venue names into core facility clusters without cross-district collision."""
    if not v_str:
        return ""
    if "북구" in v_str and ("문화예술회관" in v_str or "문예회관" in v_str):
        return "북구문화예술회관"
    if "울주" in v_str and ("문화예술회관" in v_str or "문예회관" in v_str):
        return "울주문화예술회관"
    if "중구문화의전당" in v_str or "함월홀" in v_str or "달빛마루" in v_str:
        return "중구문화의전당"
    if "문화예술회관" in v_str or "문예회관" in v_str:
        return "울산문화예술회관"
    if "태화강" in v_str:
        return "태화강"
    if "꽃바위" in v_str:
        return "꽃바위문화관"
    if "서울주" in v_str:
        return "서울주문화센터"
    if "현대예술관" in v_str:
        return "현대예술관"
    return re.sub(r'[\s\W_]+', '', v_str)

def canonical_title(t_str: str) -> str:
    """Strips regional brackets, subtitles, and symbols for fuzzy matching."""
    if not t_str:
        return ""
    s = re.sub(r'\[.*?\]', '', t_str)
    s = re.sub(r'\(.*?\)', '', s)
    s = re.sub(r'[\s\W_]+', '', s)
    return s.lower()

def is_same_performance(perf_a: dict, perf_b: dict) -> bool:
    """Identity key check: canonical date + venue cluster + title fuzzy inclusion."""
    date_a = canonical_date(perf_a.get("startDate", ""))
    date_b = canonical_date(perf_b.get("startDate", ""))
    if date_a and date_b and date_a != date_b:
        return False

    venue_a = canonical_venue(perf_a.get("venue", ""))
    venue_b = canonical_venue(perf_b.get("venue", ""))
    if venue_a and venue_b and venue_a != venue_b:
        return False

    title_a = canonical_title(perf_a.get("title", ""))
    title_b = canonical_title(perf_b.get("title", ""))
    if not title_a or not title_b:
        return False

    # 1. Direct inclusion
    if title_a in title_b or title_b in title_a:
        return True

    # 2. Significant keyword inclusion (handles '양파 콘서트' vs '양파X전진희 콘서트')
    kws_a = set(re.findall(r'[가-힣a-zA-Z0-9]{2,}', perf_a.get("title", "")))
    kws_b = set(re.findall(r'[가-힣a-zA-Z0-9]{2,}', perf_b.get("title", "")))
    stopwords = {'울산', '공연', '콘서트', '연주회', '정기연주회', '대공연장', '소공연장', '함월홀', '기획', '초청'}
    sig_a = kws_a - stopwords
    sig_b = kws_b - stopwords
    if sig_a and sig_b and any(w1 in w2 or w2 in w1 for w1 in sig_a for w2 in sig_b):
        return True

    # 3. 4-character substring matching
    min_len = min(len(title_a), len(title_b))
    if min_len >= 4:
        for i in range(len(title_a) - 3):
            sub = title_a[i:i+4]
            if sub in title_b:
                return True

    return False

def merge_booking_links(links_a: list, links_b: list) -> list:
    """
    Merges booking link lists:
    - Removes duplicate URLs
    - Puts official venue direct booking links first
    """
    seen_urls = set()
    venue_links = []
    other_links = []

    for link in (links_a + links_b):
        url = link.get("url", "").strip()
        if not url or url in seen_urls:
            continue
        seen_urls.add(url)
        name = link.get("name", "")
        # Official venue booking indicator
        if any(kw in name for kw in ["중구", "문예회관", "공식", "직예매", "전당"]):
            venue_links.append(link)
        else:
            other_links.append(link)

    return venue_links + other_links

class BaseCrawler(abc.ABC):
    def __init__(self):
        self.client = MongoClient(MONGO_URI)
        self.db = self.client.uart
        self.performances = self.db.performances
        self.success_count = 0
        self.updated_count = 0
        self.error_log = ""

    def save_performance(self, perf: dict):
        # Normalize dates on ingestion
        start_d = canonical_date(perf.get("startDate", ""))
        perf["startDate"] = start_d
        if perf.get("endDate"):
            perf["endDate"] = canonical_date(perf.get("endDate", ""))

        perf["normTitle"] = canonical_title(perf.get("title", ""))

        # Ensure unique, stable deterministic ID
        if not perf.get("id"):
            h = hashlib.md5(f"{perf.get('venue')}_{perf.get('normTitle')}_{start_d}".encode()).hexdigest()[:12]
            perf["id"] = f"{perf.get('source', 'CRAWLED').lower()}_{h}"

        # 1. Search by date variations (dot and hyphen)
        dash_date = start_d.replace(".", "-")
        candidates = list(self.performances.find({
            "$or": [
                {"startDate": start_d},
                {"startDate": dash_date}
            ]
        }))

        matching_docs = [doc for doc in candidates if is_same_performance(perf, doc)]
        target_doc = None
        extra_docs = []

        if matching_docs:
            # Prefer KOPIS document as primary baseline if available
            kopis_targets = [d for d in matching_docs if d.get("source") == "KOPIS"]
            target_doc = kopis_targets[0] if kopis_targets else matching_docs[0]
            extra_docs = [d for d in matching_docs if d["_id"] != target_doc["_id"]]

        perf["updatedAt"] = datetime.now()

        if target_doc:
            existing_source = target_doc.get("source", "CRAWLED")
            new_source = perf.get("source", "CRAWLED")

            # Collect booking links from target and all extra duplicate docs
            all_existing_links = target_doc.get("bookingLinks", []).copy()
            for ex in extra_docs:
                all_existing_links.extend(ex.get("bookingLinks", []))

            new_links = perf.get("bookingLinks", [])
            merged_links = merge_booking_links(new_links, all_existing_links)

            # Sold out propagation: fresh CRAWLED live inspection is authoritative
            if new_source == "CRAWLED" and "isSoldOut" in perf:
                is_sold_out = perf["isSoldOut"] or perf.get("state") == "매진"
            else:
                is_sold_out = (
                    perf.get("isSoldOut", False) or
                    perf.get("state") == "매진" or
                    target_doc.get("isSoldOut", False) or
                    target_doc.get("state") == "매진" or
                    any(ex.get("isSoldOut", False) or ex.get("state") == "매진" for ex in extra_docs)
                )

            if new_source == "KOPIS" and existing_source == "CRAWLED":
                # KOPIS overwrites CRAWLED metadata, but prioritize CRAWLED direct booking links, price, detailed venue & sold out status
                perf["bookingLinks"] = merged_links
                if not perf.get("price") and target_doc.get("price"):
                    perf["price"] = target_doc.get("price")
                if "(" in target_doc.get("venue", ""):
                    perf["venue"] = target_doc.get("venue")
                if is_sold_out:
                    perf["state"] = "매진"
                    perf["isSoldOut"] = True
                else:
                    perf["isSoldOut"] = False
                self.performances.replace_one({"_id": target_doc["_id"]}, perf)
                self.updated_count += 1

            elif new_source == "CRAWLED" and existing_source == "KOPIS":
                # KOPIS baseline is preserved; update official direct links (1st), price, detailed venue & sold out flag
                update_fields = {
                    "bookingLinks": merged_links,
                    "updatedAt": datetime.now()
                }
                if perf.get("price") and not target_doc.get("price"):
                    update_fields["price"] = perf.get("price")
                if "(" in perf.get("venue", "") and "(" not in target_doc.get("venue", ""):
                    update_fields["venue"] = perf.get("venue")
                if is_sold_out:
                    update_fields["state"] = "매진"
                    update_fields["isSoldOut"] = True
                else:
                    update_fields["isSoldOut"] = False
                    if target_doc.get("state") == "매진":
                        update_fields["state"] = "공연예정"
                self.performances.update_one(
                    {"_id": target_doc["_id"]},
                    {"$set": update_fields}
                )
                self.updated_count += 1
            else:
                # Same source overwriting
                perf["bookingLinks"] = merged_links
                if is_sold_out:
                    perf["state"] = "매진"
                    perf["isSoldOut"] = True
                else:
                    perf["isSoldOut"] = False
                self.performances.replace_one({"_id": target_doc["_id"]}, perf)
                self.updated_count += 1

            # Self-healing: Delete any extra duplicate sister documents found
            if extra_docs:
                self.performances.delete_many({"_id": {"$in": [d["_id"] for d in extra_docs]}})
        else:
            # New document
            self.performances.insert_one(perf)
            self.updated_count += 1

        self.success_count += 1

    def run(self):
        """
        Returns a tuple: (success_count, fail_count, new_updated_count, log_str)
        """
        self.success_count = 0
        self.updated_count = 0
        self.error_log = ""

        try:
            print(f"Fetching {self.get_name()} data...")
            self.fetch_data()
            msg = f"{self.get_name()}: {self.success_count}건 수집 완료\n"
            return self.success_count, 0, self.updated_count, msg
        except Exception as e:
            msg = f"{self.get_name()} Failed: {str(e)}\n"
            return 0, 1, 0, msg

    @abc.abstractmethod
    def get_name(self) -> str:
        pass

    @abc.abstractmethod
    def fetch_data(self):
        pass
