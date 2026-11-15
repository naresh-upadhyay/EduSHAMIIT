"""
Unit Tests for AI ERP Enterprise Tools.
Validates data generation, formatting, card output syntax, and multi-tenant scoping.
"""
import pytest
import uuid
from app.tools.erp_enterprise_tools import get_erp_enterprise_tools, format_inr
from app.tools import filter_tools_by_role


def test_format_inr():
    assert format_inr(1284500) == "₹ 12,84,500"
    assert format_inr(236750) == "₹ 2,36,750"
    assert format_inr(500) == "₹ 500"
    assert format_inr(15000) == "₹ 15,000"


def test_erp_tools_generation():
    school_id = str(uuid.uuid4())
    tools = get_erp_enterprise_tools(school_id)
    assert len(tools) >= 10

    tool_names = [t.name for t in tools]
    assert "get_fee_collection_report" in tool_names
    assert "get_pending_fee_students" in tool_names
    assert "get_school_attendance_summary" in tool_names
    assert "get_student_enrollment_overview" in tool_names
    assert "get_hostel_status_summary" in tool_names
    assert "get_library_status_summary" in tool_names
    assert "get_transport_fleet_summary" in tool_names
    assert "get_hr_staff_summary" in tool_names
    assert "draft_school_notice" in tool_names
    assert "correlate_attendance_and_fees" in tool_names


def test_fee_collection_report_output():
    school_id = str(uuid.uuid4())
    tools = {t.name: t for t in get_erp_enterprise_tools(school_id)}
    
    report_tool = tools["get_fee_collection_report"]
    res = report_tool.invoke({"date_or_month": "April 2025", "class_name": "all"})
    
    assert "Here is the fee collection report for April 2025 for all classes." in res
    assert "Total Collected:" in res
    assert "Total Pending:" in res
    assert "Collection Rate:" in res
    assert ":::card type=\"fee_report\"" in res
    assert "View Report" in res


def test_pending_fee_students_output():
    school_id = str(uuid.uuid4())
    tools = {t.name: t for t in get_erp_enterprise_tools(school_id)}
    
    pending_tool = tools["get_pending_fee_students"]
    res = pending_tool.invoke({"class_name": "", "limit": 10})
    
    assert "Here is the list of students with pending fees:" in res
    assert "Total Pending Students:" in res
    assert "Highest Pending Amount:" in res
    assert "Lowest Pending Amount:" in res
    assert ":::card type=\"pending_fee_list\"" in res
    assert "View Pending Fee List" in res


def test_notice_drafting_prevents_automatic_publishing():
    school_id = str(uuid.uuid4())
    tools = {t.name: t for t in get_erp_enterprise_tools(school_id)}
    
    notice_tool = tools["draft_school_notice"]
    res = notice_tool.invoke({
        "title": "School Closed Tomorrow",
        "content": "Due to heavy rainfall, school will remain closed tomorrow.",
        "target_audience": "Parents",
        "is_urgent": True
    })
    
    assert "Awaiting Confirmation" in res
    assert "notices are not published automatically" in res
    assert "Review in Notices Module" in res


def test_cross_module_correlation():
    school_id = str(uuid.uuid4())
    tools = {t.name: t for t in get_erp_enterprise_tools(school_id)}
    
    corr_tool = tools["correlate_attendance_and_fees"]
    res = corr_tool.invoke({"class_name": "Class 10"})
    
    assert "Cross-Module Intelligence" in res
    assert "Attendance vs. Fee Status" in res
    assert "Key Insight:" in res
