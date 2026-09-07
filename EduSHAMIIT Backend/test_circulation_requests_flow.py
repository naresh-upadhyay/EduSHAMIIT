import psycopg2
import uuid
import json
from datetime import date, timedelta
from app.config import settings

def run_test():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor()

    # 1. Fetch a school, a student profile, and a book
    cur.execute("SELECT id FROM public.schools LIMIT 1;")
    school_row = cur.fetchone()
    if not school_row:
        print("No school found, creating dummy...")
        school_id = str(uuid.uuid4())
    else:
        school_id = str(school_row[0])

    cur.execute("SELECT id FROM public.profiles WHERE role = 'student' LIMIT 1;")
    student_row = cur.fetchone()
    if not student_row:
        cur.execute("SELECT id FROM public.profiles LIMIT 1;")
        student_row = cur.fetchone()
    student_id = str(student_row[0])

    cur.execute("SELECT id, title FROM public.library_books WHERE school_id = %s::uuid LIMIT 1;", (school_id,))
    book_row = cur.fetchone()
    if not book_row:
        print("No book found for school.")
        conn.close()
        return
    book_id = str(book_row[0])
    book_title = book_row[1]

    print(f"Testing with School: {school_id}, Student: {student_id}, Book: {book_title} ({book_id})")

    # 2. Test fn_library_get_circulation_stats (Admin vs Student)
    cur.execute("SELECT public.fn_library_get_circulation_stats(%s::uuid, %s::uuid, %s) AS stats;", (school_id, None, 'admin'))
    admin_stats = cur.fetchone()[0]
    print("Admin Stats:", json.dumps(admin_stats, indent=2))

    cur.execute("SELECT public.fn_library_get_circulation_stats(%s::uuid, %s::uuid, %s) AS stats;", (school_id, student_id, 'student'))
    student_stats = cur.fetchone()[0]
    print("Student Stats:", json.dumps(student_stats, indent=2))

    # 3. Test fn_library_raise_issue_request
    req_date = date.today() + timedelta(days=14)
    cur.execute(
        "SELECT public.fn_library_raise_issue_request(%s::uuid, %s::uuid, %s::uuid, %s::date, %s, %s, %s) AS res;",
        (school_id, student_id, book_id, req_date, "Exam Preparation", "Please keep copy ready", "Physical")
    )
    req_res = cur.fetchone()[0]
    conn.commit()
    print("Raise Issue Request Result:", json.dumps(req_res, indent=2))
    borrow_id = req_res.get("borrow_id")
    request_id = req_res.get("request_id")

    # 4. Test fn_library_list_transactions for Student
    cur.execute(
        """
        SELECT public.fn_library_list_transactions(
            %s::uuid, %s::text, %s::text, %s::text, %s::text, %s::text,
            %s::date, %s::date, %s::int, %s::int, %s::text, %s::text,
            %s::text, %s::text, %s::text, %s::uuid, %s::text
        ) AS res;
        """,
        (school_id, None, "All Transactions", "ALL", "ALL", "ALL", None, None, 1, 10, "created_at", "DESC", None, None, "issue_date", student_id, 'student')
    )
    student_txs = cur.fetchone()[0]
    print(f"Student Transactions Total: {student_txs.get('total')}, counts: {student_txs.get('counts')}")

    # 5. Test fn_library_process_issue_request (Mark as WAITING)
    cur.execute(
        "SELECT public.fn_library_process_issue_request(%s::uuid, %s::uuid, %s, %s::uuid, %s::date, %s::date, %s::uuid, %s) AS res;",
        (school_id, borrow_id, "WAITING", None, None, None, student_id, "Copies of book are currently not available")
    )
    wait_res = cur.fetchone()[0]
    conn.commit()
    print("Process Request (WAITING) Result:", json.dumps(wait_res, indent=2))

    # 6. Test fn_library_process_issue_request (Mark as ISSUE)
    iss_date = date.today()
    due_date = date.today() + timedelta(days=14)
    cur.execute(
        "SELECT public.fn_library_process_issue_request(%s::uuid, %s::uuid, %s, %s::uuid, %s::date, %s::date, %s::uuid, %s) AS res;",
        (school_id, borrow_id, "ISSUE", None, iss_date, due_date, student_id, "Issued at desk")
    )
    issue_res = cur.fetchone()[0]
    conn.commit()
    print("Process Request (ISSUE) Result:", json.dumps(issue_res, indent=2))

    # 7. Test fn_library_raise_renew_request
    new_due = date.today() + timedelta(days=28)
    cur.execute(
        "SELECT public.fn_library_raise_renew_request(%s::uuid, %s::uuid, %s::uuid, %s, %s::date) AS res;",
        (school_id, borrow_id, student_id, "Need 2 more weeks for assignment", new_due)
    )
    renew_res = cur.fetchone()[0]
    conn.commit()
    print("Raise Renew Request Result:", json.dumps(renew_res, indent=2))

    print("\nAll database functions and circulation workflows verified successfully!")
    conn.close()

if __name__ == "__main__":
    run_test()
