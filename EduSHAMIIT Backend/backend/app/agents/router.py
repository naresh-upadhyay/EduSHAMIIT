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

    # Force tool call for document/image creation requests
    if any(k in msg for k in ["pdf", "excel", "xlsx", "csv", "document", "spreadsheet", "report", "image", "picture", "illustration", "draw"]):
        return TaskType.TOOL_CALL

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
        ant_key = os.getenv("ANTHROPIC_API_KEY", "")
        if ant_key and not ant_key.startswith("sk-ant-placeholder"):
            try:
                from langchain_anthropic import ChatAnthropic
                return ChatAnthropic(
                    model="claude-haiku-4-5-20251001",
                    temperature=0.0,
                    max_tokens=2048,
                    streaming=True,
                    anthropic_api_key=ant_key
                )
            except Exception:
                pass

    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(
        model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
        temperature=0.3,
        max_tokens=8192,
        streaming=True,
        google_api_key=os.getenv("GOOGLE_API_KEY", "AIza-placeholder-google-key")
    )


def get_fallback_llms():
    """Return a list of fallback ChatOpenAI LLMs in order of preference (higher limits first)."""
    import os
    from langchain_openai import ChatOpenAI

    fallbacks = []

    # 1. OpenRouter models (highest weekly tokens limits first)
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    if openrouter_key and openrouter_key != "sk-or-v1-placeholder":
        # Order of OpenRouter models (highest limit first)
        or_models = [
            "nvidia/nemotron-3-super-120b-a12b:free",
            "nvidia/nemotron-3-super-120b-a12b",
            "poolside/laguna-m1:free",
            "poolside/laguna-m1",
            "openai/gpt-oss-120b:free",
            "openai/gpt-oss-120b",
            "z-ai/glm-4.5-air:free",
            "z-ai/glm-4.5-air",
            "arcee/trinity-large-thinking:free",
            "arcee/trinity-large-thinking",
            "deepseek/deepseek-v4-flash:free",
            "deepseek/deepseek-v4-flash",
        ]
        for model in or_models:
            fallbacks.append(
                ChatOpenAI(
                    model=model,
                    openai_api_key=openrouter_key,
                    openai_api_base="https://openrouter.ai/api/v1",
                    temperature=0.3,
                    max_tokens=8192,
                    streaming=True,
                    default_headers={
                        "HTTP-Referer": "https://edushamiit.com",
                        "X-Title": "EduSHAMIIT AI"
                    }
                )
            )

    # 2. GitHub Models API (as final fallback)
    github_token = os.getenv("GITHUB_TOKEN")
    if github_token:
        # Common models available on GitHub models
        gh_models = [
            "gpt-4o-mini",
            "meta-llama-3.1-70b-instruct",
            "gpt-4o",
        ]
        for model in gh_models:
            fallbacks.append(
                ChatOpenAI(
                    model=model,
                    api_key=github_token,
                    base_url="https://models.github.ai/inference",
                    temperature=0.3,
                    max_tokens=8192,
                    streaming=True
                )
            )

    return fallbacks