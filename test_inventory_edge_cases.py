import requests
import json
import base64
import hmac
import hashlib
import time

BASE_URL = "http://localhost:8082/api/v1/inventory"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
USER_ID = "10000000-0000-0000-0000-000000000002"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

def generate_jwt() -> str:
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode('utf-8'))
    payload = b64url(json.dumps({
        "sub": USER_ID,
        "school_id": SCHOOL_ID,
        "email": "admin@edushamiit.com",
        "role": "admin",
        "exp": int(time.time()) + 86400
    }).encode('utf-8'))
    msg = f"{header}.{payload}".encode('utf-8')
    sig = b64url(hmac.new(JWT_SECRET.encode('utf-8'), msg, hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"

TOKEN = generate_jwt()
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def log_test(name, success, details=""):
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"[{status}] {name}")
    if details:
        print(f"       -> {details}")

def run_tests():
    print("=================================================================")
    print("STARTING END-TO-END INVENTORY EDGE-CASE TEST SUITE")
    print(f"Target: {BASE_URL}")
    print(f"Tenant School ID: {SCHOOL_ID}")
    print("=================================================================\n")
    
    total = 0
    passed = 0

    # Test 1: Overview with dynamic intervals
    for interval in ["30d", "6m", "1y"]:
        total += 1
        try:
            r = requests.get(f"{BASE_URL}/overview?interval={interval}", headers=HEADERS)
            data = r.json()
            is_valid = r.status_code == 200 and data.get("success") is True and "kpis" in data
            log_test(f"Overview API with interval='{interval}'", is_valid, f"Status: {r.status_code}, Monthly trend points: {len(data.get('monthly_trend', []))}")
            if is_valid: passed += 1
        except Exception as e:
            log_test(f"Overview API with interval='{interval}'", False, str(e))

    # Test 2: Purchase orders global spend stability under status filter
    total += 1
    try:
        r_all = requests.get(f"{BASE_URL}/purchase-orders?page=1&page_size=10", headers=HEADERS)
        data_all = r_all.json()
        total_spend_all = data_all.get("kpis", {}).get("total_spend", 0.0)

        r_delivered = requests.get(f"{BASE_URL}/purchase-orders?status=Delivered&page=1&page_size=10", headers=HEADERS)
        data_deliv = r_delivered.json()
        total_spend_deliv = data_deliv.get("kpis", {}).get("total_spend", 0.0)

        spend_unchanged = (total_spend_all == total_spend_deliv and total_spend_all > 0)
        log_test("Purchase Orders KPI Total Spend Unchanged Under Status Filter", spend_unchanged, f"All spend: ₹{total_spend_all}, Filtered spend: ₹{total_spend_deliv}")
        if spend_unchanged: passed += 1
    except Exception as e:
        log_test("Purchase Orders KPI Total Spend Unchanged Under Status Filter", False, str(e))

    # Test 3: Sales orders global revenue stability under status filter
    total += 1
    try:
        r_all = requests.get(f"{BASE_URL}/sales-orders?page=1&page_size=10", headers=HEADERS)
        data_all = r_all.json()
        total_sales_all = data_all.get("kpis", {}).get("total_sales_value", 0.0)

        r_delivered = requests.get(f"{BASE_URL}/sales-orders?status=Delivered&page=1&page_size=10", headers=HEADERS)
        data_deliv = r_delivered.json()
        total_sales_deliv = data_deliv.get("kpis", {}).get("total_sales_value", 0.0)

        rev_unchanged = (total_sales_all == total_sales_deliv and total_sales_all > 0)
        log_test("Sales Orders KPI Total Revenue Unchanged Under Status Filter", rev_unchanged, f"All rev: ₹{total_sales_all}, Filtered rev: ₹{total_sales_deliv}")
        if rev_unchanged: passed += 1
    except Exception as e:
        log_test("Sales Orders KPI Total Revenue Unchanged Under Status Filter", False, str(e))

    # Test 4: Purchase order date range filtering
    total += 1
    try:
        r_date = requests.get(f"{BASE_URL}/purchase-orders?start_date=2024-01-01&end_date=2028-12-31", headers=HEADERS)
        data_date = r_date.json()
        is_ok = r_date.status_code == 200 and "purchase_orders" in data_date
        log_test("Purchase Orders with Start Date and End Date Query Params", is_ok, f"Total matched: {data_date.get('total')}")
        if is_ok: passed += 1
    except Exception as e:
        log_test("Purchase Orders with Start Date and End Date Query Params", False, str(e))

    # Test 5: Sales order date range filtering
    total += 1
    try:
        r_date = requests.get(f"{BASE_URL}/sales-orders?start_date=2024-01-01&end_date=2028-12-31", headers=HEADERS)
        data_date = r_date.json()
        is_ok = r_date.status_code == 200 and "sales_orders" in data_date
        log_test("Sales Orders with Start Date and End Date Query Params", is_ok, f"Total matched: {data_date.get('total')}")
        if is_ok: passed += 1
    except Exception as e:
        log_test("Sales Orders with Start Date and End Date Query Params", False, str(e))

    # Test 6: Create PO, then cancel it
    total += 1
    try:
        meta_res = requests.get(f"{BASE_URL}/metadata", headers=HEADERS).json()
        suppliers = meta_res.get("suppliers", [])
        stores = meta_res.get("stores", [])
        sup_id = suppliers[0]["id"] if suppliers else "00000000-0000-0000-0000-000000000001"
        store_id = stores[0]["id"] if stores else "00000000-0000-0000-0000-000000000001"

        po_payload = {
            "order": {
                "supplier_id": sup_id,
                "store_id": store_id,
                "status": "Pending",
                "notes": "Automated Edge Case Test PO"
            },
            "items": [
                {
                    "item_name": "Edge Case Test Item",
                    "sku": f"EDGE-PO-{int(time.time())}",
                    "unit": "Pcs",
                    "quantity": 10,
                    "unit_price": 50.0
                }
            ]
        }
        create_res = requests.post(f"{BASE_URL}/purchase-orders", json=po_payload, headers=HEADERS).json()
        po_id = create_res.get("po_id")
        
        if po_id:
            cancel_res = requests.post(f"{BASE_URL}/purchase-orders/{po_id}/cancel", json={"reason": "Testing cancellation edge case"}, headers=HEADERS).json()
            cancelled_ok = cancel_res.get("success") is True
            
            # Edge Case: Try to cancel it again (Should fail with 400 bad request)
            cancel_again = requests.post(f"{BASE_URL}/purchase-orders/{po_id}/cancel", json={"reason": "Double cancel test"}, headers=HEADERS)
            double_cancel_guarded = cancel_again.status_code == 400
            
            success = cancelled_ok and double_cancel_guarded
            log_test("Purchase Order Creation -> Cancellation -> Double-Cancel Guard", success, f"Cancelled: {cancelled_ok}, Re-cancel rejected: {double_cancel_guarded} ({cancel_again.status_code})")
            if success: passed += 1
        else:
            log_test("Purchase Order Creation -> Cancellation", False, f"Create response: {create_res}")
    except Exception as e:
        log_test("Purchase Order Creation -> Cancellation", False, str(e))

    # Test 7: Create SO, then cancel it (release reserved stock)
    total += 1
    try:
        so_payload = {
            "order": {
                "customer": "Edge Case Customer",
                "status": "Pending",
                "delivery_location": "Main Campus",
                "notes": "Automated Edge Case Test SO"
            },
            "items": [
                {
                    "item_name": "Edge Case Test SO Item",
                    "sku": f"EDGE-SO-{int(time.time())}",
                    "unit": "Pcs",
                    "quantity": 2,
                    "unit_price": 100.0
                }
            ]
        }
        create_res = requests.post(f"{BASE_URL}/sales-orders", json=so_payload, headers=HEADERS).json()
        so_id = create_res.get("so_id")
        
        if so_id:
            cancel_res = requests.post(f"{BASE_URL}/sales-orders/{so_id}/cancel", json={"reason": "Testing SO cancellation"}, headers=HEADERS).json()
            cancelled_ok = cancel_res.get("success") is True
            
            # Edge Case: Try to cancel it again
            cancel_again = requests.post(f"{BASE_URL}/sales-orders/{so_id}/cancel", json={"reason": "Double SO cancel test"}, headers=HEADERS)
            double_cancel_guarded = cancel_again.status_code == 400
            
            success = cancelled_ok and double_cancel_guarded
            log_test("Sales Order Creation -> Cancellation -> Double-Cancel Guard", success, f"Cancelled: {cancelled_ok}, Re-cancel rejected: {double_cancel_guarded} ({cancel_again.status_code})")
            if success: passed += 1
        else:
            log_test("Sales Order Creation -> Cancellation", False, f"Create response: {create_res}")
    except Exception as e:
        log_test("Sales Order Creation -> Cancellation", False, str(e))

    # Test 8: Selective CSV Export
    total += 1
    try:
        items_res = requests.get(f"{BASE_URL}/items?page=1&page_size=2", headers=HEADERS).json()
        items = items_res.get("items", [])
        if items:
            target_id = items[0].get("id") or items[0].get("item_id")
            export_res = requests.get(f"{BASE_URL}/export/items?ids={target_id}", headers=HEADERS)
            csv_text = export_res.text
            lines = [l for l in csv_text.strip().split("\n") if l.strip()]
            is_selective = (len(lines) == 2)
            log_test("Selective Items CSV Export with IDs filter", is_selective, f"Requested 1 item, returned {len(lines)-1} rows in CSV")
            if is_selective: passed += 1
        else:
            log_test("Selective Items CSV Export with IDs filter", True, "No items in catalog to filter")
            passed += 1
    except Exception as e:
        log_test("Selective Items CSV Export with IDs filter", False, str(e))

    # Test 9: Complete CSV Exports for Transactions and Purchase Orders
    for entity in ["transactions", "purchase-orders", "sales-orders"]:
        total += 1
        try:
            r = requests.get(f"{BASE_URL}/export/{entity}", headers=HEADERS)
            csv_len = len(r.text)
            has_header = "ID" in r.text or "PO Number" in r.text or "SO Number" in r.text or "Movement" in r.text or "Store" in r.text or "Customer" in r.text or "Supplier" in r.text
            is_valid = r.status_code == 200 and has_header
            log_test(f"Export CSV for '{entity}'", is_valid, f"Length: {csv_len} chars, Header detected: {has_header}")
            if is_valid: passed += 1
        except Exception as e:
            log_test(f"Export CSV for '{entity}'", False, str(e))

    print("\n=================================================================")
    print(f"RESULTS: {passed} / {total} TESTS PASSED ({(passed/total)*100:.1f}%)")
    print("=================================================================")
    if passed == total:
        print("🎉 ALL INVENTORY EDGE CASES VERIFIED AND PASSING SUCCESSFULLY!")
    else:
        print("⚠️ Some tests did not pass.")

if __name__ == "__main__":
    run_tests()
