import base64
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage
import os


async def analyze_image(image_b64: str, question: str = "Describe this image") -> str:
    """Analyze an image using Gemini Flash Vision.
    Supports: handwritten answers, diagrams, whiteboard photos, ID cards."""
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-1.5-flash-latest",
            temperature=0.3,
            google_api_key=os.getenv("GOOGLE_API_KEY", "AIza-placeholder-google-key")
        )
        msg = HumanMessage(content=[
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
            {"type": "text", "text": question or "Describe and analyze this image in detail."}
        ])
        response = await llm.ainvoke([msg])
        return response.content
    except Exception as e:
        return f"Image analysis error: {str(e)}"