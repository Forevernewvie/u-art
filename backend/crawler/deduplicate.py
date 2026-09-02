import os
import sys
import argparse
from datetime import datetime
from pymongo import MongoClient

# Add crawlers package to path
sys.path.insert(0, os.path.dirname(__file__))

from crawlers.base_crawler import (
    canonical_date,
    canonical_venue,
    canonical_title,
    is_same_performance,
    merge_booking_links
)

MONGO_URI = os.getenv("MONGO_URI", "mongodb://root:examplepassword@db:27017/uart?authSource=admin")

def run_deduplication(dry_run=False, uri=None):
    mongo_uri = uri or MONGO_URI
    print(f"Connecting to MongoDB at {mongo_uri}...")
    client = MongoClient(mongo_uri)
    db = client.uart
    performances = db.performances

    all_docs = list(performances.find({}))
    total_before = len(all_docs)
    print(f"[*] Total documents found in 'performances': {total_before}")

    if total_before == 0:
        print("[!] No documents to deduplicate. Exiting.")
        return

    # 1. Create a safe backup collection
    backup_col_name = f"performances_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    if not dry_run:
        print(f"[*] Creating backup collection: '{backup_col_name}'...")
        db[backup_col_name].insert_many(all_docs)
        print(f"[+] Backup created with {len(all_docs)} documents.")
    else:
        print(f"[DRY-RUN] Would create backup collection '{backup_col_name}'.")

    # 2. Cluster duplicates
    clusters = [] # list of lists of docs
    processed_ids = set()

    for i, doc in enumerate(all_docs):
        doc_id = doc["_id"]
        if doc_id in processed_ids:
            continue

        cluster = [doc]
        processed_ids.add(doc_id)

        for other_doc in all_docs[i + 1:]:
            other_id = other_doc["_id"]
            if other_id in processed_ids:
                continue

            if is_same_performance(doc, other_doc):
                cluster.append(other_doc)
                processed_ids.add(other_id)

        clusters.append(cluster)

    # 3. Process clusters
    duplicate_groups = [c for c in clusters if len(c) > 1]
    print(f"[*] Found {len(duplicate_groups)} duplicate clusters across {total_before} documents.")

    merged_count = 0
    removed_ids = []

    for group in duplicate_groups:
        # Determine master document: Prefer KOPIS source as baseline
        kopis_docs = [d for d in group if d.get("source") == "KOPIS"]
        if kopis_docs:
            master = kopis_docs[0]
            others = [d for d in group if d["_id"] != master["_id"]]
        else:
            # If all CRAWLED, pick the one with the longest title or description
            master = group[0]
            others = group[1:]

        # Merge booking links (CRAWLED / official links placed first)
        master_links = master.get("bookingLinks", [])
        for other in others:
            other_links = other.get("bookingLinks", [])
            master_links = merge_booking_links(other_links, master_links)

        # Check sold out status across all members
        is_sold = any(
            d.get("isSoldOut", False) or d.get("state") == "매진"
            for d in group
        )

        update_fields = {
            "bookingLinks": master_links,
            "startDate": canonical_date(master.get("startDate", "")),
            "normTitle": canonical_title(master.get("title", "")),
            "updatedAt": datetime.now()
        }
        if master.get("endDate"):
            update_fields["endDate"] = canonical_date(master.get("endDate", ""))

        if is_sold:
            update_fields["state"] = "매진"
            update_fields["isSoldOut"] = True

        print(f"  -> Merging {len(group)} docs into: '{master.get('title')}' (date: {master.get('startDate')})")
        for o in others:
            print(f"     - Removing duplicate: '{o.get('title')}' (id: {o.get('id')}, source: {o.get('source')})")
            removed_ids.append(o["_id"])

        if not dry_run:
            performances.update_one({"_id": master["_id"]}, {"$set": update_fields})
            merged_count += len(others)

    if not dry_run and removed_ids:
        delete_result = performances.delete_many({"_id": {"$in": removed_ids}})
        print(f"[+] Successfully deleted {delete_result.deleted_count} duplicate documents.")

    total_after = total_before - len(removed_ids) if not dry_run else total_before
    print("\n" + "=" * 50)
    print("DEDUPLICATION SUMMARY REPORT")
    print("=" * 50)
    print(f"Total documents before: {total_before}")
    print(f"Duplicate clusters resolved: {len(duplicate_groups)}")
    print(f"Redundant documents removed: {len(removed_ids)}")
    print(f"Total clean documents after: {total_after}")
    if not dry_run:
        print(f"Backup preserved in: '{backup_col_name}'")
    else:
        print("[DRY-RUN completed. No changes made to DB]")
    print("=" * 50 + "\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="U-Art Database Deduplication Tool")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without modifying database")
    parser.add_argument("--uri", type=str, default=None, help="Custom MongoDB URI")
    args = parser.parse_args()

    run_deduplication(dry_run=args.dry_run, uri=args.uri)
