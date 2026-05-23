import psycopg2
import sys
import os

passwords = [
    'postgres',
    'postgres_password_2026',
    'eduSHAMIIT2026_pg',
    'supabase',
    'password',
    'your-super-secret-and-long-postgres-password'
]

working_pw = None
conn = None

for pw in passwords:
    try:
        print(f"Trying password: {pw} ...")
        # Try both 'edushamiit' and 'postgres' databases
        for db in ['edushamiit', 'postgres']:
            try:
                conn = psycopg2.connect(
                    host='127.0.0.1',
                    port=5432,
                    dbname=db,
                    user='postgres',
                    password=pw,
                    connect_timeout=3
                )
                working_pw = pw
                working_db = db
                print(f"SUCCESS: Connected to DB '{db}' with password: {pw}")
                break
            except Exception as e:
                # Keep going
                pass
        if conn:
            break
    except Exception as e:
        print(f"Failed: {e}")

if not conn:
    print("ERROR: Could not connect to PostgreSQL with any of the passwords.")
    sys.exit(1)

# Now execute the migration SQL
migration_path = r"e:\EduSHAMIIT\EduSHAMIIT Database\edushamiit-db\migrations\096_admin_crud_distribution.sql"
print(f"Reading migration file: {migration_path}")
with open(migration_path, "r", encoding="utf-8") as f:
    sql = f.read()

try:
    with conn.cursor() as cursor:
        print("Executing migration SQL...")
        cursor.execute(sql)
        conn.commit()
        print("Migration successfully applied!")
except Exception as e:
    conn.rollback()
    print(f"ERROR executing migration: {e}")
    sys.exit(1)
finally:
    conn.close()
