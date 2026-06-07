import psycopg2

try:
    conn = psycopg2.connect(
        host="db",
        port=5432,
        user="postgres",
        password="eduSHAMIIT2026_pg",
        database="postgres"
    )
    cur = conn.cursor()
    
    for table in ['live_class_comments', 'call_sessions']:
        cur.execute(f"""
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = '{table}'
            ORDER BY ordinal_position;
        """)
        columns = cur.fetchall()
        print(f"\nColumns in {table}:")
        for col in columns:
            print(f"  - {col[0]}: {col[1]} (Nullable: {col[2]})")
            
    cur.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
