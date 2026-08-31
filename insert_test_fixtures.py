import psycopg2

DATABASE_URL = "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:6543/postgres"

def main():
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    school_id = "11111111-1111-1111-1111-111111111111"

    # Ensure school exists
    cur.execute("""
        INSERT INTO public.schools (id, name, subscription_status)
        VALUES (%s, 'Shami Innovation Academy', 'active')
        ON CONFLICT (id) DO UPDATE SET subscription_status = 'active';
    """, (school_id,))

    profiles = [
        ("38a93170-997b-4b4c-bc8e-256b93169c23", school_id, "mathematicsking888@gmail.com", "King Doe", "super_admin"),
        ("33d93277-35a4-4b33-bdf1-9bf0f3c8b45a", school_id, "driver.rajesh@school.com", "Rajesh Kumar", "driver"),
        ("22222222-2222-2222-2222-222222222222", school_id, "teacher.priya@school.com", "Priya Sharma", "teacher"),
        ("44444444-4444-4444-4444-444444444444", school_id, "student.aarav@school.com", "Aarav Patel", "student"),
        ("55555555-5555-5555-5555-555555555555", school_id, "student.diya@school.com", "Diya Sharma", "student"),
        ("66666666-6666-6666-6666-666666666666", school_id, "student.kabir@school.com", "Kabir Khan", "student"),
        ("77777777-7777-7777-7777-777777777777", school_id, "student.ananya@school.com", "Ananya Verma", "student"),
    ]

    for uid, sid, email, name, role in profiles:
        cur.execute("""
            INSERT INTO public.profiles (id, user_id, school_id, email, full_name, role)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE SET 
                school_id = EXCLUDED.school_id,
                email = EXCLUDED.email,
                full_name = EXCLUDED.full_name,
                role = EXCLUDED.role;
        """, (uid, uid, sid, email, name, role))
        print(f"✅ Synced profile: {name} ({uid}) [{role}]")

    conn.commit()
    cur.close()
    conn.close()
    print("\n🎉 Test fixture profiles successfully synced in PostgreSQL!")

if __name__ == "__main__":
    main()
