"""RAG API - Knowledge base document management."""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from app.middleware.auth import get_current_user
from app.services.supabase_client import get_supabase
from app.services.rag_service import ingest_document
from app.models import GenericResponse

router = APIRouter()


@router.post("/ingest", response_model=GenericResponse)
async def ingest(
    file: UploadFile = File(...),
    subject: str = Form(...),
    grade: str = Form(...),
    source: str = Form(...),
    user: dict = Depends(get_current_user),
):
    """Upload a PDF document and ingest it into the knowledge base."""
    if not file.filename or not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    pdf_bytes = await file.read()
    school_id = user.get("school_id", "")

    chunk_count = await ingest_document(
        pdf_bytes=pdf_bytes,
        school_id=school_id,
        subject=subject,
        grade=grade,
        source=source,
    )

    if chunk_count == 0:
        raise HTTPException(status_code=500, detail="Failed to ingest document")

    return GenericResponse(
        success=True,
        school_id=school_id,
        data={"chunks_created": chunk_count, "source": source, "subject": subject, "grade": grade},
        message="Document ingested successfully",
    )


@router.get("/documents", response_model=GenericResponse)
async def list_documents(user: dict = Depends(get_current_user)):
    """List all ingested documents for the school."""
    sb = get_supabase()
    school_id = user.get("school_id", "")
    try:
        r = sb.table("knowledge_base").select("metadata").eq("metadata->>school_id", school_id).execute()
        sources = set()
        for row in r.data or []:
            meta = row.get("metadata", {})
            if meta.get("source"):
                sources.add((meta["source"], meta.get("subject", ""), meta.get("grade", "")))

        documents = [
            {"source": s, "subject": sub, "grade": g} for s, sub, g in sorted(sources)
        ]
        return GenericResponse(
            success=True,
            school_id=school_id,
            data={"documents": documents, "count": len(documents)},
        )
    except Exception:
        return GenericResponse(
            success=True,
            school_id=school_id,
            data={"documents": [], "count": 0},
        )


@router.delete("/documents/{source}", response_model=GenericResponse)
async def delete_document(source: str, user: dict = Depends(get_current_user)):
    """Delete all chunks of a document by source name."""
    sb = get_supabase()
    school_id = user.get("school_id", "")
    try:
        r = sb.table("knowledge_base").delete().eq("metadata->>source", source).eq("metadata->>school_id", school_id).execute()
        return GenericResponse(
            success=True,
            school_id=school_id,
            data={"deleted": len(r.data) if r.data else 0},
            message="Document deleted successfully",
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete document: {str(e)}")