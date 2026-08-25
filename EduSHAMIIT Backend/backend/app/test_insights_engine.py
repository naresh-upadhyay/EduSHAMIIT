import asyncio
from datetime import date, datetime, timedelta
import json
from app.api.attendance import exec_sql

async def test_insights_engine():
    school_id = '11111111-1111-1111-1111-111111111111'
    start_date = '2026-08-01'
    end_date = '2026-08-16'
    
    # 1. Summary KPIs
    daily_stats = await exec_sql("""
        SELECT 
            COUNT(*) as total_records,
            COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) as present_count,
            COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) as absent_count,
            COUNT(CASE WHEN UPPER(status) = 'LATE' THEN 1 END) as late_count,
            COUNT(CASE WHEN UPPER(status) IN ('ON_LEAVE', 'HALF_DAY') THEN 1 END) as half_day_count
        FROM public.attendance_daily_records
        WHERE school_id = %s::UUID AND attendance_date BETWEEN %s::DATE AND %s::DATE;
    """, (school_id, start_date, end_date))
    print("Daily stats:", daily_stats)

    staff_stats = await exec_sql("""
        SELECT 
            COUNT(*) as total_records,
            COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) as present_count,
            COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) as absent_count,
            COUNT(CASE WHEN UPPER(status) = 'LATE' THEN 1 END) as late_count,
            COUNT(CASE WHEN UPPER(status) IN ('ON_LEAVE', 'HALF_DAY') THEN 1 END) as half_day_count
        FROM public.attendance_staff_records
        WHERE school_id = %s::UUID AND attendance_date BETWEEN %s::DATE AND %s::DATE;
    """, (school_id, start_date, end_date))
    print("Staff stats:", staff_stats)

    # 2. Top Classes
    classes = await exec_sql("""
        SELECT 
            c.id as class_id,
            c.name as class_name,
            COUNT(DISTINCT sca.student_id) as total_students,
            COUNT(a.id) as total_records,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) as present_count,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) as absent_count,
            COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) as late_count,
            CASE 
                WHEN COUNT(a.id) > 0 THEN ROUND((COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END as attendance_pct
        FROM public.academic_classes c
        LEFT JOIN public.student_class_assignments sca ON sca.class_id = c.id AND sca.status = 'ACTIVE'
        LEFT JOIN public.attendance_daily_records a ON a.class_id = c.id AND a.school_id = %s::UUID AND a.attendance_date BETWEEN %s::DATE AND %s::DATE
        WHERE c.school_id = %s::UUID AND (c.deleted_at IS NULL OR c.status != 'ARCHIVED')
        GROUP BY c.id, c.name, c.display_order
        ORDER BY attendance_pct DESC, c.display_order ASC
        LIMIT 10;
    """, (school_id, start_date, end_date, school_id))
    print("Top classes count:", len(classes))
    for cl in classes[:3]:
        print(cl)

    # 3. Attendance by Day of Week
    dow_stats = await exec_sql("""
        SELECT 
            EXTRACT(DOW FROM attendance_date)::INT as dow,
            COUNT(*) as total_records,
            COUNT(CASE WHEN UPPER(status) IN ('PRESENT', 'LATE') THEN 1 END) as attended_records,
            ROUND((COUNT(CASE WHEN UPPER(status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100.0, 2) as attendance_pct
        FROM public.attendance_daily_records
        WHERE school_id = %s::UUID AND attendance_date BETWEEN %s::DATE AND %s::DATE
        GROUP BY EXTRACT(DOW FROM attendance_date)
        ORDER BY dow ASC;
    """, (school_id, start_date, end_date))
    print("DOW stats:", dow_stats)

    # 4. Attendance by Department (Staff)
    dept_stats = await exec_sql("""
        SELECT 
            COALESCE(NULLIF(TRIM(p.department), ''), 'Others') as department,
            COUNT(*) as total_records,
            COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END) as attended_records,
            ROUND((COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / NULLIF(COUNT(*), 0)::NUMERIC) * 100.0, 2) as attendance_pct
        FROM public.attendance_staff_records a
        JOIN public.profiles p ON p.id = a.employee_id
        WHERE a.school_id = %s::UUID AND a.attendance_date BETWEEN %s::DATE AND %s::DATE
        GROUP BY COALESCE(NULLIF(TRIM(p.department), ''), 'Others')
        ORDER BY attendance_pct DESC;
    """, (school_id, start_date, end_date))
    print("Department stats:", dept_stats)

if __name__ == '__main__':
    asyncio.run(test_insights_engine())
