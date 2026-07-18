import asyncio
from app.api.transport import get_route_reports

async def test():
    class MockUser:
        pass
    mock_user = MockUser()
    res = await get_route_reports(
        school_id="11111111-1111-1111-1111-111111111111",
        start_date=None,
        end_date=None,
        route_id=None,
        vehicle_id=None,
        driver_id=None,
        status=None,
        user=mock_user
    )
    print("REPORTS API STATUS:", res.get("success"))
    print("KPI SUMMARY:", res.get("data", {}).get("summary"))
    print("STATUS DONUT:", res.get("data", {}).get("status_donut"))
    print("TRENDS COUNT:", len(res.get("data", {}).get("trends", [])))
    print("ROUTES PERFORMANCE COUNT:", len(res.get("data", {}).get("routes_performance", [])))
    print("SAMPLE PERFORMANCE HIGHLIGHTS:", res.get("data", {}).get("performance_summary"))

asyncio.run(test())
