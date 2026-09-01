import os
import time
import schedule
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

from crawlers.kopis_crawler import KopisCrawler
from crawlers.junggu_crawler import JungGuCrawler
from crawlers.ucac_crawler import UcacCrawler

def get_crawlers():
    return [
        KopisCrawler(),
        JungGuCrawler(),
        UcacCrawler()
    ]

SMTP_USER = os.getenv("SMTP_USER", "dlfjs351@gmail.com")
SMTP_PASS = os.getenv("SMTP_PASS", "#gksrnrwpwl3A")
REPORT_EMAIL = os.getenv("REPORT_EMAIL", "dlfjs351@gmail.com")

def send_email_report(success_count, fail_count, new_count, logs):
    try:
        msg = MIMEMultipart()
        msg['From'] = SMTP_USER
        msg['To'] = REPORT_EMAIL
        msg['Subject'] = f"[U-Art] 크롤러 정기 보고서 ({datetime.now().strftime('%Y-%m-%d %H:%M')})"
        
        body = f"""
        <h2>U-Art 공연 데이터 크롤링 결과</h2>
        <ul>
            <li><b>전체 수집 시도:</b> {success_count}건</li>
            <li><b>신규 업데이트:</b> {new_count}건</li>
            <li><b>수집 실패:</b> {fail_count}건</li>
        </ul>
        <hr>
        <h3>상세 로그</h3>
        <pre>{logs}</pre>
        """
        msg.attach(MIMEText(body, 'html'))
        
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(SMTP_USER, SMTP_PASS)
        server.send_message(msg)
        server.quit()
        print("Email report sent successfully.")
    except Exception as e:
        print(f"Failed to send email report: {e}")

def full_sync_job():
    print(f"Starting full sync job at {datetime.now()}")
    total_success = total_fail = total_new = 0
    logs = ""
    
    crawlers = [
        KopisCrawler(),
        JungGuCrawler(),
        UcacCrawler(),
        NamGuCrawler(),
        BukGuCrawler(),
        DongGuCrawler(),
        UljuCrawler()
    ]
    
    for crawler in crawlers:
        s, f, n, log = crawler.run()
        total_success += s
        total_fail += f
        total_new += n
        logs += log
            
    send_email_report(total_success, total_fail, total_new, logs)
    print("Full sync job completed.")

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings()
    print("Crawler started. Running initial sync...")
    full_sync_job()
    # 4 times a day = every 6 hours
    schedule.every(6).hours.do(full_sync_job)
    while True:
        schedule.run_pending()
        time.sleep(60)
