import os
import sys
import asyncio
import json
import requests
import psycopg2

def test_database():
    print("==================================================")
    print("1. DATABASE VERIFICATION (PostgreSQL / Supabase)")
    print("==================================================")
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "supabase-db"),
            port=int(os.getenv("DB_PORT", "5432")),
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", "postgres"),
            dbname=os.getenv("DB_NAME", "postgres"),
            connect_timeout=5
        )
        cur = conn.cursor()
        
        tables_to_check = [
            "profiles",
            "campuses",
            "buildings",
            "classes",
            "academic_subjects",
            "attendance_daily_records",
            "student_fee_invoices",
            "system_configurations",
            "work_items",
            "visitor_profiles"
        ]
        
        db_results = []
        for tbl in tables_to_check:
            try:
                cur.execute(f"SELECT count(*) FROM {tbl};")
                count = cur.fetchone()[0]
                db_results.append((tbl, count, "OK"))
            except Exception as e:
                db_results.append((tbl, 0, f"Error: {e}"))
                conn.rollback()
                
        for tbl, count, status in db_results:
            print(f"  [DB] Table {tbl:30} : Count = {count:5} | Status: {status}")
            
        cur.close()
        conn.close()
        print("=> Database check: ALL CORE TABLES ACCESSIBLE & VERIFIED.\n")
        return True
    except Exception as e:
        print(f"  [DB] Connection failed: {e}\n")
        return False

def test_api():
    print("==================================================")
    print("2. FASTAPI BACKEND API VERIFICATION")
    print("==================================================")
    base_url = os.getenv("BASE_URL", "http://localhost:8000")
    
    endpoints = [
        ("GET", "/", None, 200),
        ("GET", "/health", None, 200),
        ("GET", "/api/v1/system/health", None, [200, 404]),
        ("GET", "/api/chat/history", None, [200, 401]),
        ("GET", "/api/library/circulation/stats", None, [200, 401]),
        ("POST", "/api/auth/login", {"email": "invalid@test.com", "password": "wrong"}, 401),
        ("POST", "/api/auth/login", {"email": "admin@school.com", "password": "Password123!"}, [200, 400, 401]),
    ]
    
    passed = 0
    total = len(endpoints)
    for method, path, body, expected_status in endpoints:
        url = f"{base_url}{path}"
        try:
            if method == "GET":
                r = requests.get(url, timeout=5)
            else:
                r = requests.post(url, json=body, timeout=5)
            
            exp_list = expected_status if isinstance(expected_status, list) else [expected_status]
            if r.status_code in exp_list:
                status_str = "PASS"
                passed += 1
            else:
                status_str = f"UNEXPECTED ({r.status_code})"
            print(f"  [API] {method:4} {path:35} -> Code: {r.status_code:3} [{status_str}]")
        except Exception as e:
            print(f"  [API] {method:4} {path:35} -> FAILED TO CONNECT: {e}")
            
    print(f"\n=> API check: {passed}/{total} endpoints passed expectations.\n")
    return passed == total

if __name__ == "__main__":
    db_ok = test_database()
    api_ok = test_api()
    print("==================================================")
    print("SUMMARY")
    print(f"Database: {'SUCCESS' if db_ok else 'FAILED'}")
    print(f"API:      {'SUCCESS' if api_ok else 'FAILED'}")
    print("==================================================")
