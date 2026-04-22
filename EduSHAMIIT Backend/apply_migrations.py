"""Apply DB migrations and verify schema."""
import psycopg2

conn = psycopg2.connect(
    host='127.0.0.1', port=54322,
    dbname='postgres', user='postgres', password='postgres'
)
conn.autocommit = True
cur = conn.cursor()

migrations = [
    r'e:\EduSHAMIIT\EduSHAMIIT Database\edushamiit-db\migrations\087_payment_schema_enhancement.sql',
    r'e:\EduSHAMIIT\EduSHAMIIT Database\edushamiit-db\migrations\088_sample_payments.sql',
]

for path in migrations:
    name = path.split('\\')[-1]
    with open(path, 'r') as f:
        sql = f.read()
    try:
        cur.execute(sql)
        print(f'[OK]    {name}')
    except Exception as e:
        print(f'[ERROR] {name}: {e}')

cur.close()
conn.close()

# Verify
conn2 = psycopg2.connect(
    host='127.0.0.1', port=54322,
    dbname='postgres', user='postgres', password='postgres'
)
cur2 = conn2.cursor()

for tbl in ['payments', 'fees', 'salary']:
    cur2.execute(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_name = %s ORDER BY ordinal_position", (tbl,)
    )
    cols = [r[0] for r in cur2.fetchall()]
    print(f'\n{tbl} columns: {cols}')

cur2.execute("SELECT COUNT(*) FROM payments")
print(f'\npayments rows: {cur2.fetchone()[0]}')

cur2.close()
conn2.close()
print('\nDone.')
