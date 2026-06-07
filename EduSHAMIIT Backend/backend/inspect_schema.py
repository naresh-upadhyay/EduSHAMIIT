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
    
    # Query table columns for live_classes
    cur.execute("""
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'live_classes'
        ORDER BY ordinal_position;
    """)
    columns = cur.fetchall()
    print("Columns in live_classes:")
    for col in columns:
        print(f"  - {col[0]}: {col[1]} (Nullable: {col[2]})")
        
    # Query constraints
    cur.execute("""
        SELECT conname, pg_get_constraintdef(oid) 
        FROM pg_constraint 
        WHERE conrelid = 'live_classes'::regclass;
    """)
    constraints = cur.fetchall()
    print("\nConstraints on live_classes:")
    for con in constraints:
        print(f"  Name: {con[0]}, Def: {con[1]}")
        
    cur.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
