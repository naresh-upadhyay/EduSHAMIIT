"""Image API - Upload image, base64 encode, analyze via GeminiVision."""
import base64
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from app.middleware.auth import get_current_user
from app.services.vision_service import analyze_image
from app.models import GenericResponse

router = APIRouter()


@router.post("/image", response_model=GenericResponse)
async def image_analysis(
    image: UploadFile = File(...),
    question: str = Form("Describe this image"),
    user: dict = Depends(get_current_user),
):
    """Upload an image for AI-powered analysis via Gemini Flash Vision."""
    if not image.content_type:
        raise HTTPException(status_code=400, detail="Could not determine image content type")
    if not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail=f"File must be an image. Received: {image.content_type}")
    image_bytes = await image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image file")
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image file too large. Maximum size is 10MB.")
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    try:
        result = await analyze_image(image_b64, question)
        if result.startswith("Image analysis error:"):
            raise HTTPException(status_code=500, detail=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image analysis failed: {str(e)}")

    return GenericResponse(
        success=True,
        school_id=user.get("school_id"),
        data={
            "analysis": result,
            "question": question,
            "image_size": len(image_bytes),
            "content_type": image.content_type,
        },
    )
