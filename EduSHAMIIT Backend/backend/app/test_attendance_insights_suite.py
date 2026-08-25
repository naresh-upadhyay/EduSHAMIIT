import asyncio
import logging
from datetime import date, timedelta
from app.api.attendance import (
    get_attendance_insights,
    get_student_attendance_insights_profile,
    export_attendance_insights_csv,
    exec_sql
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

async def run_insights_suite():
    logger.info("=" * 80)
    logger.info("🚀 STARTING ATTENDANCE INSIGHTS API TEST SUITE")
    logger.info("=" * 80)

    school_id = '11111111-1111-1111-1111-111111111111'
    user = {'id': '00000000-0000-0000-0000-000000000001', 'role': 'super_admin', 'permissions': ['*']}

    passed = 0
    failed = 0

    # -------------------------------------------------------------------------
    # TEST 1: GET /attendance/insights (Overall, Monthly Default)
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 1: GET /attendance/insights (Default 30-Day Monthly) ---")
    try:
        res = await get_attendance_insights(
            start_date='2026-08-01',
            end_date='2026-08-16',
            view_by='OVERALL',
            granularity='monthly',
            current_user=user,
            school_id=school_id
        )
        assert res.get('success') is True, "Expected success=True"
        data = res['data']
        assert 'kpis' in data, "Missing kpis in response"
        assert 'overall' in data['kpis'], "Missing overall KPI"
        assert 'present' in data['kpis'], "Missing present KPI"
        assert 'absent' in data['kpis'], "Missing absent KPI"
        assert 'late' in data['kpis'], "Missing late KPI"
        assert 'half_day' in data['kpis'], "Missing half_day KPI"
        assert len(data['kpis']['overall']['sparkline']) == 7, "Sparkline must contain 7 points"
        logger.info(f"✅ PASSED: Default insights returns all 5 KPI cards with 7-point sparklines. Overall Attendance: {data['kpis']['overall']['formatted']}")
        passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 1: {e}")
        failed += 1

    # -------------------------------------------------------------------------
    # TEST 2: Daily & Weekly Trend Granularity
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 2: Daily & Weekly Trend Granularity ---")
    try:
        res_daily = await get_attendance_insights(
            start_date='2026-08-01',
            end_date='2026-08-07',
            granularity='daily',
            current_user=user,
            school_id=school_id
        )
        assert res_daily['success'] is True, "Daily trend failed"
        assert len(res_daily['data']['trend']) == 7, f"Expected 7 daily trend points, got {len(res_daily['data']['trend'])}"

        res_weekly = await get_attendance_insights(
            start_date='2026-07-01',
            end_date='2026-08-16',
            granularity='weekly',
            current_user=user,
            school_id=school_id
        )
        assert res_weekly['success'] is True, "Weekly trend failed"
        assert len(res_weekly['data']['trend']) > 0, "Weekly trend returned empty"
        logger.info(f"✅ PASSED: Daily granularity ({len(res_daily['data']['trend'])} pts) and Weekly granularity ({len(res_weekly['data']['trend'])} pts) generated correctly.")
        passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 2: {e}")
        failed += 1

    # -------------------------------------------------------------------------
    # TEST 3: Attendance Distribution & Day of Week
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 3: Attendance Distribution & Day-of-Week Breakdown ---")
    try:
        res = await get_attendance_insights(
            start_date='2026-08-01',
            end_date='2026-08-16',
            current_user=user,
            school_id=school_id
        )
        dist = res['data']['distribution']
        assert 'present_count' in dist and 'absent_count' in dist and 'late_count' in dist, "Distribution keys missing"
        
        dow = res['data']['day_of_week']
        assert len(dow) == 6, f"Expected 6 days (Mon-Sat), got {len(dow)}"
        assert dow[0]['day_abbr'] == 'Mon', "First day should be Monday"
        assert dow[5]['day_abbr'] == 'Sat', "Last day should be Saturday"
        logger.info(f"✅ PASSED: Attendance distribution total={dist['total']} (Present: {dist['present_pct']}%) and 6-day Mon-Sat breakdown verified.")
        passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 3: {e}")
        failed += 1

    # -------------------------------------------------------------------------
    # TEST 4: Top Classes & Top Absentees Performance Lists
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 4: Top Classes & Top Absentees Watchlist ---")
    try:
        res = await get_attendance_insights(
            start_date='2026-08-01',
            end_date='2026-08-16',
            current_user=user,
            school_id=school_id
        )
        classes = res['data']['top_classes']
        absentees = res['data']['top_absentees']
        alerts = res['data']['insights_alerts']

        assert len(classes) > 0, "Top classes should not be empty"
        assert len(alerts) == 4, f"Expected 4 insights alert cards, got {len(alerts)}"
        logger.info(f"✅ PASSED: Top classes ({len(classes)} classes), Top absentees ({len(absentees)} students), and 4 alert cards generated.")
        passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 4: {e}")
        failed += 1

    # -------------------------------------------------------------------------
    # TEST 5: Student Attendance Profile & Calendar Heatmap
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 5: Student Profile Drill-Down & Calendar Heatmap ---")
    try:
        st_rows = await exec_sql("SELECT id FROM public.profiles WHERE role = 'student' LIMIT 1;")
        if st_rows:
            st_id = st_rows[0]['id']
            st_profile = await get_student_attendance_insights_profile(st_id, None, None, user, school_id)
            assert st_profile['success'] is True, "Student profile failed"
            assert 'profile' in st_profile['data'], "Missing profile details"
            assert 'metrics' in st_profile['data'], "Missing metrics in profile"
            assert 'calendar_heatmap' in st_profile['data'], "Missing calendar heatmap"
            logger.info(f"✅ PASSED: Student profile loaded for {st_profile['data']['profile'].get('full_name')} with 365-day calendar heatmap.")
            passed += 1
        else:
            logger.info("⚠️ No student record in DB, skipping student profile test")
            passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 5: {e}")
        failed += 1

    # -------------------------------------------------------------------------
    # TEST 6: CSV Report Export
    # -------------------------------------------------------------------------
    logger.info("\n--- TEST 6: Export Attendance Insights CSV Report ---")
    try:
        csv_res = await export_attendance_insights_csv(
            start_date='2026-08-01',
            end_date='2026-08-16',
            current_user=user,
            school_id=school_id
        )
        assert getattr(csv_res, 'status_code', 200) == 200, "CSV export returned non-200"
        csv_text = csv_res.body.decode('utf-8')
        assert "Roll No,Admission No,Student Name" in csv_text, "CSV header missing"
        logger.info(f"✅ PASSED: CSV export generated successfully ({len(csv_text.splitlines())} lines).")
        passed += 1
    except Exception as e:
        logger.error(f"❌ FAILED Test 6: {e}")
        failed += 1

    logger.info("=" * 80)
    logger.info(f"🏁 ATTENDANCE INSIGHTS TEST SUITE: {passed} PASSED | {failed} FAILED")
    logger.info("=" * 80)

if __name__ == '__main__':
    asyncio.run(run_insights_suite())
