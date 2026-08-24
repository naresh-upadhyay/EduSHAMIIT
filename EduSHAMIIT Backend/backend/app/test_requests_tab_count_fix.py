import asyncio
import logging
from app.api.attendance import exec_sql, get_leave_dashboard

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("TestRequestsTabCount")

async def test():
    school_id = "11111111-1111-1111-1111-111111111111"
    admin_res = await exec_sql("SELECT id FROM public.profiles WHERE full_name ILIKE '%King Doe%' LIMIT 1;")
    admin_id = str(admin_res[0]["id"])
    
    # Check total rows in database for school
    count_db = await exec_sql("SELECT COUNT(*) as cnt FROM public.leave_applications WHERE (school_id = %s::UUID OR school_id IS NULL) AND public.fn_resolve_academic_year(start_date, school_id) = '2026-2027';", (school_id,))
    real_db_count = count_db[0]["cnt"]
    
    # Query dashboard with page_size = 5
    res = await get_leave_dashboard(
        page=1,
        page_size=5,
        current_user={"id": admin_id, "role": "super_admin", "school_id": school_id, "permissions": ["*"]},
        school_id=school_id
    )
    d = res["data"]
    total_count = d.get("total_count")
    kpi_total = d.get("kpi", {}).get("total_requests")
    page_reqs = len(d.get("requests", []))
    
    logger.info(f"Real Total in DB: {real_db_count}")
    logger.info(f"Dashboard data.total_count: {total_count}")
    logger.info(f"Dashboard KPI total_requests: {kpi_total}")
    logger.info(f"Requests on page (pageSize=5): {page_reqs}")
    
    assert total_count == real_db_count, f"total_count ({total_count}) != real_db_count ({real_db_count})"
    assert kpi_total == real_db_count, f"kpi_total ({kpi_total}) != real_db_count ({real_db_count})"
    assert page_reqs <= 5, f"page_reqs ({page_reqs}) > 5"
    logger.info("✅ SUCCESS: Requests tab count correctly displays the real total count regardless of page size!")

if __name__ == "__main__":
    asyncio.run(test())
