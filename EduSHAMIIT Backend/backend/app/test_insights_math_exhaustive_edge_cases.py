import asyncio
import os
import sys
import uuid
import json
import logging
from datetime import date, datetime, timedelta

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestInsightsMath")

sys.path.insert(0, "/app")
from app.api.attendance import (
    exec_sql,
    get_attendance_insights,
    get_student_attendance_insights_profile
)

async def run_insights_math_tests():
    logger.info("=" * 85)
    logger.info("  STARTING EXHAUSTIVE ATTENDANCE INSIGHTS MATHEMATICAL TEST SUITE")
    logger.info("=" * 85)

    passed_count = 0
    total_count = 0

    def check(name: str, condition: bool, detail: str = ""):
        nonlocal passed_count, total_count
        total_count += 1
        if condition:
            passed_count += 1
            logger.info(f"  [PASS] {name} {detail}")
        else:
            logger.error(f"  [FAIL] {name} {detail}")
            raise AssertionError(f"Test failed: {name} -> {detail}")

    # Bootstrap Context
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    school_id = str(schools[0]["id"])
    users = await exec_sql("SELECT id, email FROM public.profiles WHERE role = 'super_admin' LIMIT 1;")
    user_id = str(users[0]["id"])
    user_dict = {"id": user_id, "school_id": school_id, "role": "super_admin", "email": "superadmin@edushamiit.com"}

    # 1. Test Overall Insights
    res_overall = await get_attendance_insights(
        start_date="2026-08-01",
        end_date="2026-08-25",
        view_by="OVERALL",
        role=None,
        class_id=None,
        section_id=None,
        department=None,
        subject_id=None,
        granularity="daily",
        current_user=user_dict,
        school_id=school_id
    )
    assert res_overall["success"] is True
    data = res_overall["data"]

    # 1.1 Verify KPI Sparklines (7 buckets)
    kpis = data["kpis"]
    check("KPI overall sparkline has 7 buckets", len(kpis["overall"]["sparkline"]) == 7, f"Count: {len(kpis['overall']['sparkline'])}")
    check("KPI present sparkline has 7 buckets", len(kpis["present"]["sparkline"]) == 7, f"Count: {len(kpis['present']['sparkline'])}")

    # 1.2 Mathematical check on Overall Attendance Rate %
    pres = kpis["present"]["value"]
    ab = kpis["absent"]["value"]
    lt = kpis["late"]["value"]
    hd = kpis["half_day"]["value"]
    tot_dist = data["distribution"]["total"]
    if tot_dist > 0:
        expected_pct = round(((pres + lt + (hd * 0.5)) / tot_dist) * 100.0, 2)
        check("Overall Attendance Rate % matches formula", abs(kpis["overall"]["value"] - expected_pct) < 0.05, f"Expected {expected_pct}%, Got {kpis['overall']['value']}%")

    # 1.3 Verify Top Classes math (No Cartesian join duplication)
    top_classes = data["top_classes"]
    for tc in top_classes:
        c_id = tc["class_id"]
        # Direct DB count for this class
        db_records = await exec_sql("""
            SELECT COUNT(*) as tot,
                   COUNT(CASE WHEN UPPER(status) = 'PRESENT' THEN 1 END) as p,
                   COUNT(CASE WHEN UPPER(status) = 'ABSENT' THEN 1 END) as a,
                   COUNT(CASE WHEN UPPER(status) = 'LATE' THEN 1 END) as l,
                   COUNT(CASE WHEN UPPER(status) = 'HALF_DAY' THEN 1 END) as h
            FROM public.attendance_daily_records
            WHERE school_id = %s AND class_id = %s AND attendance_date BETWEEN '2026-08-01' AND '2026-08-25';
        """, (school_id, c_id))
        db_tot = db_records[0]["tot"]
        check(f"Top Class '{tc['class_name']}' record count is accurate", tc["total_records"] == db_tot, f"API: {tc['total_records']}, DB: {db_tot}")
        check(f"Top Class '{tc['class_name']}' present count is accurate", tc["present"] == db_records[0]["p"], f"API: {tc['present']}, DB: {db_records[0]['p']}")

    # 1.4 Verify Top Absentees (Consecutive trailing streak math)
    top_absentees = data["top_absentees"]
    for ab_st in top_absentees[:3]:
        p_id = ab_st["person_id"]
        # Verify consecutive absences
        recs = await exec_sql("""
            SELECT attendance_date, UPPER(status) as st
            FROM public.attendance_daily_records
            WHERE school_id = %s AND student_id = %s AND attendance_date BETWEEN '2026-08-01' AND '2026-08-25'
            ORDER BY attendance_date DESC;
        """, (school_id, p_id))
        expected_consec = 0
        for r in recs:
            if r["st"] == "ABSENT":
                expected_consec += 1
            else:
                break
        check(f"Top Absentee '{ab_st['name']}' consecutive absences streak", ab_st["consecutive_absences"] == expected_consec, f"API: {ab_st['consecutive_absences']}, Calculated: {expected_consec}")

    # 1.5 Verify Day of Week (Sun-Sat) series (7 elements)
    dow = data["day_of_week"]
    check("Day of week distribution has 7 days", len(dow) == 7, f"Length: {len(dow)}")
    day_names = [d["day_abbr"] for d in dow]
    check("Day of week ordering is Mon to Sun", day_names == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], f"Order: {day_names}")

    # 1.6 Verify Alerts generation
    alerts = data["insights_alerts"]
    check("Insights alerts array contains structured insights", len(alerts) >= 3, f"Alert count: {len(alerts)}")

    # 2. Test Student Drilldown Profile
    if len(top_absentees) > 0:
        sample_st_id = top_absentees[0]["person_id"]
        prof_res = await get_student_attendance_insights_profile(
            student_id=uuid.UUID(sample_st_id),
            start_date="2026-08-01",
            end_date="2026-08-25",
            current_user=user_dict,
            school_id=school_id
        )
        assert prof_res["success"] is True
        prof_data = prof_res["data"]
        check("Profile contains student identity", prof_data["profile"]["id"] == sample_st_id)
        check("Profile contains 30-day heatmap records", len(prof_data["heatmap"]) == 30, f"Heatmap length: {len(prof_data['heatmap'])}")
        check("Profile contains detailed history logs", isinstance(prof_data["history"], list))

    logger.info("\n" + "=" * 85)
    logger.info(f"  🎉 ALL ATTENDANCE INSIGHTS MATHEMATICAL TESTS PASSED: {passed_count}/{total_count} (100%)!")
    logger.info("=" * 85)

if __name__ == "__main__":
    asyncio.run(run_insights_math_tests())
