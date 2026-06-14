import psycopg2

def main():
    try:
        conn = psycopg2.connect(
            host="127.0.0.1",
            port=5432,
            dbname="postgres",
            user="postgres",
            password="eduSHAMIIT2026_pg"
        )
        cursor = conn.cursor()
        cursor.execute("SELECT id, title, status FROM exams;")
        exams = cursor.fetchall()
        print("Exams in DB:")
        for exam in exams:
            eid, title, status = exam
            cursor.execute("SELECT count(*) FROM exam_questions WHERE exam_id = %s;", (str(eid),))
            q_count = cursor.fetchone()[0]
            print(f"ID: {eid} | Title: {title} | Status: {status} | Questions in DB: {q_count}")
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
