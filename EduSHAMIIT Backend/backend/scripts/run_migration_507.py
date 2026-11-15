import os
import sys
import psycopg2

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.config import settings

def run():
    migration_file = os.path.abspath(os.path.join(
        os.path.dirname(__file__),
        "../../../EduSHAMIIT Database/edushamiit-db/migrations/507_document_management_full_features_and_enhancements.sql"
    ))
    with open(migration_file, "r", encoding="utf-8") as f:
        sql = f.read()

    conn = psycopg2.connect(settings.DATABASE_URL)
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        print("Migration 507 successfully applied to database!")
    finally:
        conn.close()

if __name__ == "__main__":
    run()
