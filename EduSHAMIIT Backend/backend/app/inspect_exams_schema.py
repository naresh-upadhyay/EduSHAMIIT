import psycopg2
import sys

def main():
    try:
        conn = psycopg2.connect(
            host="db",
            port=5432,
            dbname="postgres",
            user="postgres",
            password="eduSHAMIIT2026_pg",
            connect_timeout=3
        )
        cursor = conn.cursor()
        cursor.execute("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_name = 'exams'
            ORDER BY ordinal_position;
        """)
        rows = cursor.fetchall()
        print("Columns in 'exams' table:")
        for row in rows:
            print(f"  {row[0]} ({row[1]}) - Nullable: {row[2]}")
        conn.close()
    except Exception as e:
        print(f"Error executing query: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
