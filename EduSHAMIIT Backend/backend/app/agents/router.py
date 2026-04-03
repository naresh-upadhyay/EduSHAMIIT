"""
Task Router - Routes tasks to appropriate LLM providers based on task type.
"""
import os

IOT_KEYWORDS = [
    "fan", "light", "lights", "camera", "turn on", "turn off",
    "switch", "projector", "ac", "bulb", "switch off", "band karo",
    "on karo", "off karo", "chalao", "bund karo"
]

TOOL_KEYWORDS = [
    "fee", "fees", "attendance", "marks", "result", "schedule",
    "timetable", "leave", "salary", "payment", "dues", "absent",
    "homework", "exam", "library", "bus", "transport", "notice"
]


class TaskType:
    QA = "qa"
    GENERATION = "generation"
    TOOL_CALL = "tool_call"
    IOT_CONTROL = "iot_control"
    VISION = "vision"
    RAG = "rag"


def detect_task(message: str, has_image: bool = False) -> str:
    """Detect the type of task from user message."""
    if has_image:
        return TaskType.VISION

    msg = message.lower()

    if any(k in msg for k in IOT_KEYWORDS):
        return TaskType.IOT_CONTROL

    if any(k in msg for k in TOOL_KEYWORDS):
        return TaskType.TOOL_CALL

    if any(k in msg for k in ["explain", "solve", "what is", "how does", "help me", "define"]):
        return TaskType.RAG

    return TaskType.QA


def get_llm(task: str):
    """Return the appropriate LLM for this task type."""
    if task in (TaskType.TOOL_CALL, TaskType.IOT_CONTROL):
        try:
            from langchain_anthropic import ChatAnthropic
            return ChatAnthropic(
                model="claude-haiku-4-5-20251001",
                temperature=0.0,
                max_tokens=1024,
                anthropic_api_key=os.getenv("ANTHROPIC_API_KEY", "sk-ant-placeholder")
            )
        except Exception:
            pass

    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(
        model="gemini-1.5-flash-latest",
        temperature=0.3,
        max_tokens=2048,
        google_api_key=os.getenv("GOOGLE_API_KEY", "AIza-placeholder-google-key")
    )