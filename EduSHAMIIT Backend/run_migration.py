"""
Script to run the password_resets migration.
"""
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv(".env")

# Database configuration
DB_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", 5432)),
    "database": os.getenv("POSTGRES_DB", "edushamiit"),
    "user": os.getenv("POSTGRES_USER", "postgres"),
    "password": os.getenv("POSTGRES_PASSWORD", "postgres_password_2026"),
}

def run_migration():
    """Run the password_resets table migration."""
    try:
        # Connect to the database
        print(f"Connecting to database: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()
        
        # Read the migration SQL file
        migration_path = "../EduSHAMIIT Database/edushamiit-db/migrations/004_password_resets.sql"
        with open(migration_path, 'r') as f:
            migration_sql = f.read()
        
        print("Running migration...")
        print(migration_sql)
        
        # Execute the migration
        cur.execute(migration_sql)
        
        print("Migration completed successfully!")
        
        # Verify the table was created
        cur.execute("""
            SELECT table_name, column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'password_resets' 
            ORDER BY ordinal_position;
        """)
        
        columns = cur.fetchall()
        print("\nTable 'password_resets' created with columns:")
        for col in columns:
            print(f"  - {col[1]}: {col[2]}")
        
        cur.close()
        conn.close()
        
    except psycopg2.OperationalError as e:
        print(f"Database connection error: {e}")
        print("Make sure the database is running and accessible.")
    except FileNotFoundError as e:
        print(f"Migration file not found: {e}")
    except Exception as e:
        print(f"Error running migration: {e}")

if __name__ == "__main__":
    run_migration()