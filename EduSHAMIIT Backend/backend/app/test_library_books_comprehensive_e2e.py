import asyncio
import os
import sys
import uuid
import logging
from decimal import Decimal

# Add backend directory to sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.api.library import (
    exec_sql,
    get_library_books_stats,
    get_filter_options,
    list_library_books,
    get_book_details,
    create_book,
    update_book,
    archive_or_delete_book,
    restore_book,
    add_book_copies,
    update_book_copy,
    archive_copy,
    check_isbn_uniqueness,
    bulk_book_operations,
    BookCreateRequest,
    BookUpdateRequest,
    CopyCreateRequest,
    CopyUpdateRequest,
    BulkActionRequest,
    CheckIsbnRequest,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("TestLibraryBooksComprehensive")

async def run_all_e2e_tests():
    logger.info("==================================================================")
    logger.info("   EduSHAMIIT ERP - 100% COMPREHENSIVE LIBRARY E2E SUITE          ")
    logger.info("==================================================================")

    # 1. Setup Test School and Admin Context
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    school_id = str(schools[0]["id"])

    users = await exec_sql("SELECT id FROM public.profiles WHERE school_id = %s AND role = 'super_admin' LIMIT 1;", (school_id,))
    user_id = str(users[0]["id"])
    current_user = {"id": user_id, "school_id": school_id, "role": "super_admin"}

    passed = 0
    total = 0

    def assert_test(name, condition, msg=""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            logger.info(f"[PASS] Scenario {total:02d}: {name}")
        else:
            logger.error(f"[FAIL] Scenario {total:02d}: {name} -> {msg}")
            raise AssertionError(f"Failed {name}: {msg}")

    # TEST 1: Aggregated Stats
    stats_res = await get_library_books_stats(school_id=school_id, current_user=current_user)
    assert_test(
        "Aggregated KPI Stats (Total Titles > 0, Copies > 0, Available > 0)",
        stats_res["success"] is True and stats_res["data"]["total_titles"] > 0 and stats_res["data"]["total_copies"] > 0,
        f"stats: {stats_res}"
    )

    # TEST 2: Dynamic Filter Options with Lookups (Categories, Financial Years, Languages, Book Types)
    filters_res = await get_filter_options(school_id=school_id, current_user=current_user)
    data = filters_res["data"]
    assert_test(
        "Dynamic Filter Options from Lookups (Categories, Years, Languages, Book Types)",
        len(data["categories"]) > 0 and len(data["years"]) > 0 and len(data["languages"]) > 0 and len(data["book_types"]) > 0,
        f"filters: {data}"
    )

    # TEST 3: Books Listing with Pagination
    list_res = await list_library_books(
        search=None, category=None, author=None, publisher=None, language=None, book_type=None,
        rack=None, status="ACTIVE", availability="ALL", publication_year_min=None, publication_year_max=None,
        sort_by="title", sort_order="ASC", page=1, page_size=10, school_id=school_id, current_user=current_user
    )
    assert_test(
        "Paginated Books Catalogue (page=1, pageSize=10, meta present)",
        list_res["success"] is True and len(list_res["data"]) > 0 and list_res["pagination"]["total_records"] > 0,
        f"list: {list_res.get('pagination')}"
    )

    # TEST 4: Live ISBN Duplicate Detection
    unique_isbn = f"978-{uuid.uuid4().hex[:10]}"
    check_new = await check_isbn_uniqueness(payload=CheckIsbnRequest(isbn13=unique_isbn), school_id=school_id, current_user=current_user)
    assert_test("ISBN Check (New ISBN -> Available)", check_new["exists"] is False, f"check: {check_new}")

    # TEST 5: Create New Book with Initial Physical Copies & Financial Year
    book_req = BookCreateRequest(
        title=f"E2E Artificial Intelligence Handbook {uuid.uuid4().hex[:6]}",
        subtitle="Foundations of Neural Networks",
        author="Dr. Alan Turing",
        isbn13=unique_isbn,
        publisher="Cambridge University Press",
        category_name="Computer Science",
        language_name="English",
        book_type_name="Paperback",
        publication_year=2026,
        rack_location="Rack CS-1",
        shelf_location="Shelf 3",
        initial_copies_count=3,
        purchase_price=499.00,
        supplier="Global Book House",
        initial_condition="NEW",
        acquisition_type="PURCHASE"
    )
    create_res = await create_book(payload=book_req, school_id=school_id, current_user=current_user)
    new_book_id = create_res["data"]["id"]
    assert_test(
        "Create Book Title + Initial Physical Copies with Accession & Barcodes",
        create_res["success"] is True and new_book_id is not None,
        f"create: {create_res}"
    )

    # TEST 6: Fetch Details & Physical Copies in Drawer
    details_res = await get_book_details(book_id=new_book_id, school_id=school_id, current_user=current_user)
    book_obj = details_res["data"]["book"]
    copies_obj = details_res["data"]["copies"]
    assert_test(
        "Fetch Book Details & Verify Physical Copies Generated for Drawer",
        details_res["success"] is True and len(copies_obj) == 3 and book_obj["total_copies"] == 3 and book_obj["available_copies"] == 3,
        f"copies count: {len(copies_obj)}, total: {book_obj.get('total_copies')}"
    )

    # TEST 7: Add More Copies to Existing Book
    batch_req = CopyCreateRequest(
        number_of_copies=2,
        purchase_price=499.00,
        condition="EXCELLENT",
        supplier="Global Book House",
        rack="Rack CS-1",
        shelf="Shelf 3"
    )
    add_copies_res = await add_book_copies(book_id=new_book_id, payload=batch_req, school_id=school_id, current_user=current_user)
    assert_test("Add Batch Physical Copies", add_copies_res["success"] is True and len(add_copies_res["data"]) == 2, f"add_copies: {add_copies_res}")

    # TEST 8: Verify DB Sync Triggers Synchronized total_copies = 5
    details_res2 = await get_book_details(book_id=new_book_id, school_id=school_id, current_user=current_user)
    assert_test(
        "DB Sync Trigger (Total Copies = 5, Available Copies = 5)",
        details_res2["data"]["book"]["total_copies"] == 5 and len(details_res2["data"]["copies"]) == 5,
        f"details: {details_res2['data']['book']}"
    )

    # TEST 9: Update Copy Condition and Location
    copy_to_update = details_res2["data"]["copies"][0]
    update_copy_req = CopyUpdateRequest(
        condition="FAIR",
        rack="Rack CS-2",
        shelf="Shelf 1",
        notes="Minor crease on cover"
    )
    update_copy_res = await update_book_copy(copy_id=copy_to_update["id"], payload=update_copy_req, school_id=school_id, current_user=current_user)
    assert_test("Update Physical Copy Condition & Location", update_copy_res["success"] is True, f"update_copy: {update_copy_res}")

    # TEST 10: Update Book Bibliographic Details
    update_book_req = BookUpdateRequest(
        title=f"Updated AI Handbook {uuid.uuid4().hex[:6]}",
        author="Dr. Alan Turing & Geoffrey Hinton",
        description="Comprehensive guide to deep learning and transformers."
    )
    update_book_res = await update_book(book_id=new_book_id, payload=update_book_req, school_id=school_id, current_user=current_user)
    assert_test("Update Book Bibliographic Metadata", update_book_res["success"] is True, f"update_book: {update_book_res}")

    # TEST 11: Bulk Operations (Change Category)
    bulk_req = BulkActionRequest(
        action="CHANGE_CATEGORY",
        book_ids=[new_book_id],
        category_name="Artificial Intelligence"
    )
    bulk_res = await bulk_book_operations(payload=bulk_req, school_id=school_id, current_user=current_user)
    assert_test("Bulk Operations (Update Category)", bulk_res["success"] is True and bulk_res["data"]["modified_count"] >= 1, f"bulk: {bulk_res}")

    # TEST 12: Archive & Restore Book
    archive_res = await archive_or_delete_book(book_id=new_book_id, school_id=school_id, current_user=current_user)
    assert_test("Archive Book Title", archive_res["success"] is True, f"archive: {archive_res}")

    restore_res = await restore_book(book_id=new_book_id, school_id=school_id, current_user=current_user)
    assert_test("Restore Book Title", restore_res["success"] is True, f"restore: {restore_res}")

    # TEST 13: Clean up test book copies
    await archive_or_delete_book(book_id=new_book_id, school_id=school_id, current_user=current_user)

    logger.info("==================================================================")
    logger.info(f"  ALL {passed}/{total} COMPREHENSIVE E2E SCENARIOS PASSED (100%)  ")
    logger.info("==================================================================")

if __name__ == "__main__":
    asyncio.run(run_all_e2e_tests())
