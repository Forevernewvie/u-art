import abc
from datetime import datetime
from pymongo import MongoClient
import os

MONGO_URI = os.getenv("MONGO_URI", "mongodb://root:examplepassword@db:27017/uart?authSource=admin")

class BaseCrawler(abc.ABC):
    def __init__(self):
        self.client = MongoClient(MONGO_URI)
        self.db = self.client.uart
        self.performances = self.db.performances
        self.success_count = 0
        self.updated_count = 0
        self.error_log = ""

    def save_performance(self, perf: dict):
        target_doc = None
        
        # 1. Search by exact startDate
        candidates = list(self.performances.find({"startDate": perf.get("startDate")}))
        
        perf_norm = perf.get("normTitle", "")
        for doc in candidates:
            doc_norm = doc.get("normTitle", "")
            # Identity Key check: Title inclusion matching
            if perf_norm and doc_norm:
                if perf_norm in doc_norm or doc_norm in perf_norm:
                    target_doc = doc
                    break
        
        perf["updatedAt"] = datetime.now()
        
        if target_doc:
            existing_source = target_doc.get("source", "CRAWLED")
            new_source = perf.get("source", "CRAWLED")
            
            # Combine booking links
            existing_links = target_doc.get("bookingLinks", [])
            new_links = perf.get("bookingLinks", [])
            
            merged_links = existing_links.copy()
            existing_urls = {link["url"] for link in existing_links if "url" in link}
            for nl in new_links:
                if "url" in nl and nl["url"] not in existing_urls:
                    merged_links.append(nl)
                    existing_urls.add(nl["url"])
            
            if new_source == "KOPIS" and existing_source == "CRAWLED":
                # KOPIS overwrites CRAWLED, but keep combined bookingLinks
                perf["bookingLinks"] = merged_links
                self.performances.replace_one({"_id": target_doc["_id"]}, perf)
                self.updated_count += 1
                
            elif new_source == "CRAWLED" and existing_source == "KOPIS":
                # CRAWLED adds booking links to KOPIS, does NOT overwrite KOPIS baseline
                self.performances.update_one(
                    {"_id": target_doc["_id"]},
                    {"$set": {"bookingLinks": merged_links, "updatedAt": datetime.now()}}
                )
                self.updated_count += 1
            else:
                # Same source overwriting
                perf["bookingLinks"] = merged_links
                self.performances.replace_one({"_id": target_doc["_id"]}, perf)
                self.updated_count += 1
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
