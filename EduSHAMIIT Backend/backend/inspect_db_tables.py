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
    
    # List all tables
    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
    tables = [t[0] for t in cur.fetchall()]
    print("ALL TABLES IN PUBLIC SCHEMA:")
    print(tables)
    
    # Inspect tables starting with live_class
    live_class_tables = [t for t in tables if 'live_class' in t]
    print("\nLIVE CLASS TABLES:")
    print(live_class_tables)
    
    for table in live_class_tables:
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
