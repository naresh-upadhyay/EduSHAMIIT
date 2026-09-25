import asyncio
import os
import sys
import uuid

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.api.library import (
    exec_sql,
    get_filter_options,
    create_book,
    update_book,
    list_library_books,
    archive_or_delete_book,
    BookCreateRequest,
    BookUpdateRequest
)

async def main():
    print("=" * 80)
    print("📚 TEST: LIBRARY DROPDOWNS, PAGES, FINANCIAL YEARS, CLASSES, SUBJECTS & CONDITIONS")
    print("=" * 80)

    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    assert len(schools) > 0, "No school found"
    school_id = str(schools[0]["id"])

    profiles = await exec_sql("SELECT id, role FROM public.profiles LIMIT 1")
    assert len(profiles) > 0, "No profile found"
    current_user = {"id": str(profiles[0]["id"]), "school_id": school_id, "role": profiles[0].get("role", "ADMIN")}

    # 1. Test Filter Options (Financial Years, Classes, Subjects, Conditions, Categories)
    print("\n1. Testing Filter Options (GET /api/library/books/filter-options)...")
    res_opts = await get_filter_options(school_id=school_id, current_user=current_user)
    assert res_opts.get("success") is True, f"Failed to fetch filter options: {res_opts}"
    opts_data = res_opts.get("data", {})
    
    years = opts_data.get("years", [])
    classes = opts_data.get("classes", [])
    subjects = opts_data.get("subjects", [])
    conditions = opts_data.get("conditions", [])
    categories = opts_data.get("categories", [])

    print(f"  - Financial Years ({len(years)}): {years[:5]}")
    print(f"  - Classes from Class Management ({len(classes)}): {classes[:5]}")
    print(f"  - Subjects from Class Management ({len(subjects)}): {subjects[:5]}")
    print(f"  - Conditions ({len(conditions)}): {conditions[:5]}")
    print(f"  - Categories ({len(categories)}): {categories[:5]}")

    assert "2026-27" in years, "Expected '2026-27' in financial years"
    assert len(classes) > 0, "Expected non-empty classes list from Class Management"
    assert len(subjects) > 0, "Expected non-empty subjects list from Class Management"
    assert len(conditions) > 0, "Expected non-empty conditions list"

    # 2. Test Creating a Book with pages, subject, grade_level, condition, financial_year
    print("\n2. Testing Book Creation (pages=385, condition='EXCELLENT', subject, grade_level)...")
    sel_subject = subjects[0] if subjects else "Mathematics"
    sel_class = classes[0] if classes else "Class 10"
    
    create_req = BookCreateRequest(
        title=f"Advanced Mathematics Guide {uuid.uuid4().hex[:6]}",
        author="Prof. S. Ramanujan",
        publisher="Cambridge University Press",
        category_name=categories[0] if categories else "Science",
        language_name="English",
        book_type_name="Physical Book",
        pages=385,
        publication_year=2026,
        financial_year="2026-27",
        subject=sel_subject,
        grade_level=sel_class,
        initial_condition="EXCELLENT",
        initial_copies_count=2,
        purchase_price=499.0
    )
    
    res_create = await create_book(payload=create_req, school_id=school_id, current_user=current_user)
    assert res_create.get("success") is True, f"Failed to create book: {res_create}"
    created_book = res_create.get("data", {})
    book_id = created_book["id"]
    print(f"  - Created Book ID: {book_id}")
    print(f"  - Pages: {created_book.get('pages')}")
    print(f"  - Subject: {created_book.get('subject')}")
    print(f"  - Grade Level: {created_book.get('grade_level')}")
    
    assert created_book.get("pages") == 385, f"Expected pages=385, got {created_book.get('pages')}"
    assert created_book.get("subject") == sel_subject
    assert created_book.get("grade_level") == sel_class

    # 3. Test Detail Retrieval (Check copies condition and pages in DB)
    print("\n3. Testing Book Detail Retrieval...")
    book_rows = await exec_sql("SELECT * FROM public.library_books WHERE id = %s", (book_id,))
    assert len(book_rows) > 0
    copies = await exec_sql("SELECT * FROM public.library_book_copies WHERE book_id = %s ORDER BY copy_number ASC", (book_id,))
    assert len(copies) == 2, f"Expected 2 copies, got {len(copies)}"
    assert copies[0].get("condition") == "EXCELLENT", f"Expected copy condition 'EXCELLENT', got {copies[0].get('condition')}"
    assert book_rows[0].get("pages") == 385
    print(f"  - Copies Count: {len(copies)}")
    print(f"  - Copy 1 Condition: {copies[0].get('condition')}")
    print(f"  - Copy 2 Condition: {copies[1].get('condition')}")

    # 4. Test Updating Book (pages=520, condition='UNDER_REPAIR', subject, grade_level)
    print("\n4. Testing Book Update (PATCH /api/library/books/{id})...")
    update_req = BookUpdateRequest(
        pages=520,
        subject="Theoretical Physics",
        grade_level="Class 12",
        condition="UNDER_REPAIR",
        financial_year="2025-26"
    )
    res_update = await update_book(book_id=book_id, payload=update_req, school_id=school_id, current_user=current_user)
    assert res_update.get("success") is True, f"Failed to update book: {res_update}"

    # 5. Re-fetch Detail to verify update persisted
    print("\n5. Verifying Updated Book Detail & Copy Condition in DB...")
    book_rows2 = await exec_sql("SELECT * FROM public.library_books WHERE id = %s", (book_id,))
    detail2 = book_rows2[0]
    assert detail2.get("pages") == 520, f"Expected pages=520, got {detail2.get('pages')}"
    assert detail2.get("subject") == "Theoretical Physics"
    assert detail2.get("grade_level") == "Class 12"
    copies2 = await exec_sql("SELECT * FROM public.library_book_copies WHERE book_id = %s ORDER BY copy_number ASC", (book_id,))
    assert copies2[0].get("condition") == "UNDER_REPAIR", f"Expected copy condition 'UNDER_REPAIR', got {copies2[0].get('condition')}"
    print(f"  - Updated Pages: {detail2.get('pages')}")
    print(f"  - Updated Subject: {detail2.get('subject')}")
    print(f"  - Updated Grade Level: {detail2.get('grade_level')}")
    print(f"  - Updated Copy 1 Condition: {copies2[0].get('condition')}")

    # 6. Test Book List API (fn_library_list_books returns pages and primary_condition)
    print("\n6. Verifying fn_library_list_books returns pages and primary_condition...")
    res_list = await list_library_books(
        search="Advanced Mathematics Guide",
        category=None,
        author=None,
        publisher=None,
        language=None,
        book_type=None,
        rack=None,
        status="ACTIVE",
        availability="ALL",
        publication_year_min=None,
        publication_year_max=None,
        sort_by="created_at",
        sort_order="DESC",
        page=1,
        page_size=10,
        school_id=school_id,
        current_user=current_user
    )
    assert res_list.get("success") is True
    list_items = res_list.get("data", [])
    matched = [b for b in list_items if b["id"] == book_id]
    assert len(matched) == 1, "Expected created book in list"
    assert matched[0].get("pages") == 520, f"Expected pages=520 in list, got {matched[0].get('pages')}"
    assert matched[0].get("primary_condition") == "UNDER_REPAIR", f"Expected primary_condition='UNDER_REPAIR', got {matched[0].get('primary_condition')}"
    print(f"  - List Item Pages: {matched[0].get('pages')}")
    print(f"  - List Item Primary Condition: {matched[0].get('primary_condition')}")

    # 7. Cleanup
    await archive_or_delete_book(book_id=book_id, force_delete=True, school_id=school_id, current_user=current_user)
    print("\n7. Test Book Deleted Cleanly.")
    print("\n🎉 ALL TESTS PASSED! 100% VERIFIED!")

if __name__ == '__main__':
    asyncio.run(main())
