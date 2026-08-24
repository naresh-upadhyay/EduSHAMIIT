import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor
from app.config import settings

def main():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # 1. Fetch all leave applications
    cur.execute("SELECT id, school_id, applicant_id, start_date, end_date, half_day_type, status, applied_at FROM public.leave_applications ORDER BY applied_at ASC;")
    apps = cur.fetchall()
    print(f"Processing {len(apps)} leave applications...")
    
    for app in apps:
        app_id = app['id']
        school_id = app['school_id']
        applicant_id = app['applicant_id']
        start_d = app['start_date']
        end_d = app['end_date']
        half_day = app['half_day_type']
        applied_at = app['applied_at']
        
        # Calculate holidays in range
        cur.execute("""
            SELECT DISTINCT d::DATE as dt
            FROM generate_series(%s::DATE, %s::DATE, '1 day'::interval) d
            WHERE EXISTS (
                SELECT 1 FROM public.schedules s
                LEFT JOIN public.calendars c ON s.calendar_id = c.id
                LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
                WHERE (s.school_id = %s OR s.school_id IS NULL)
                  AND s.deleted_at IS NULL
                  AND (
                      c.name ILIKE '%holiday%' OR c.name ILIKE '%holy%' OR c.name ILIKE '%vacation%' OR c.name ILIKE '%closure%'
                      OR c.type ILIKE '%holiday%' OR c.type ILIKE '%school_events%'
                      OR s.schedule_type ILIKE '%holiday%' OR s.schedule_type ILIKE '%holy%' OR s.schedule_type ILIKE '%vacation%' OR s.schedule_type ILIKE '%off%'
                      OR s.category ILIKE '%holiday%' OR s.category ILIKE '%holy%' OR s.category ILIKE '%vacation%'
                      OR s.title ILIKE '%holiday%' OR s.title ILIKE '%holy%' OR s.title ILIKE '%vacation%' OR s.title ILIKE '%closed%' OR s.title ILIKE '%off%'
                      OR s.description ILIKE '%holiday%' OR s.description ILIKE '%holy%'
                  )
                  AND (
                      (d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE AND d::DATE <= (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE)
                      OR (
                          sr.id IS NOT NULL
                          AND d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                          AND (sr.end_date IS NULL OR d::DATE <= sr.end_date::DATE)
                          AND (
                              (sr.frequency = 'weekly' AND (
                                  (sr.days_of_week IS NOT NULL AND (sr.days_of_week ? UPPER(TRIM(TO_CHAR(d::DATE, 'DY'))) OR sr.days_of_week ? SUBSTRING(UPPER(TRIM(TO_CHAR(d::DATE, 'DY'))) FROM 1 FOR 2)))
                                  OR EXTRACT(DOW FROM d::DATE) = EXTRACT(DOW FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE)
                              ))
                              OR (sr.frequency = 'daily' AND ((d::DATE - (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE) %% GREATEST(sr.interval, 1) = 0))
                              OR (sr.frequency = 'monthly' AND EXTRACT(DAY FROM d::DATE) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE))
                          )
                      )
                  )
            );
        """, (start_d, end_d, school_id))
        holidays = cur.fetchall()
        holiday_dts = {h['dt'] for h in holidays}
        holiday_count = len(holiday_dts)
        
        # Calculate overlap with prior applications for THIS applicant only
        cur.execute("""
            SELECT DISTINCT d::DATE as dt
            FROM generate_series(%s::DATE, %s::DATE, '1 day'::interval) d
            WHERE EXISTS (
                SELECT 1 FROM public.leave_applications la
                WHERE la.applicant_id = %s
                  AND la.id != %s
                  AND la.applied_at < %s
                  AND la.status IN ('pending', 'approved')
                  AND d::DATE >= la.start_date::DATE
                  AND d::DATE <= la.end_date::DATE
            );
        """, (start_d, end_d, applicant_id, app_id, applied_at))
        overlaps = cur.fetchall()
        overlap_dts = {o['dt'] for o in overlaps if o['dt'] not in holiday_dts}
        overlap_count = len(overlap_dts)
        
        total_days = (end_d - start_d).days + 1
        if half_day in ('FIRST_HALF', 'SECOND_HALF'):
            billable = 0.5 if (holiday_count == 0 and overlap_count == 0) else 0.0
        else:
            billable = max(float(total_days - holiday_count - overlap_count), 0.0)
            
        cur.execute("""
            UPDATE public.leave_applications
            SET billable_days = %s, holidays_count = %s, overlap_days_count = %s
            WHERE id = %s;
        """, (billable, holiday_count, overlap_count, app_id))
        
    # Resync balances
    cur.execute("SELECT public.fn_sync_all_leave_balances();")
    conn.commit()
    print("Recalculation and sync completed successfully!")
    
    # Verify King Doe's balance
    cur.execute("""
        SELECT lt.name, lb.allocated_days, lb.used_days, lb.pending_days, 
               (lb.allocated_days + lb.carried_forward_days - lb.used_days - lb.pending_days) as remaining
        FROM public.leave_balances lb
        JOIN public.leave_types lt ON lt.id = lb.leave_type_id
        WHERE lb.user_id = '38a93170-997b-4b4c-bc8e-256b93169c23';
    """)
    for row in cur.fetchall():
        print("King Doe Balance:", dict(row))
        
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
