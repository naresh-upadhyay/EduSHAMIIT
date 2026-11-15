"""
Task Router - Dynamic multi-provider orchestration with Supabase Vault integration.
Enforces intelligent routing:
  1. Groq (Primary)
  2. Google Gemini
  3. Cloudflare Workers AI
  4. OpenRouter
Prioritizes Individual user credentials over Global credentials from Vault.
"""
import os
from typing import List, Dict, Any, Optional

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


def get_smart_secret(secret_name: str, user_id: Optional[str] = None) -> str:
    """
    Retrieve a secret value from Supabase Vault with smart priority:
    1. If user_id is provided, check if user has an Individual secret.
    2. Fallback to Global secret in Supabase Vault.
    3. Fallback to os.environ / settings / defaults.
    """
    try:
        from app.services.supabase_client import get_supabase
        sb = get_supabase()
        params = {"p_secret_name": secret_name}
        if user_id:
            params["p_user_id"] = str(user_id)
        res = sb.rpc("get_smart_secret_value", params).execute()
        if res.data:
            val = res.data[0] if isinstance(res.data, list) else res.data
            if val is not None and str(val).strip():
                return str(val).strip().strip("'\"")
    except Exception:
        pass

    # Check os.environ
    env_val = os.getenv(secret_name, "").strip().strip("'\"")
    if env_val:
        return env_val

    # Check settings
    try:
        from app.config import settings
        cfg_val = getattr(settings, secret_name, None)
        if cfg_val and str(cfg_val).strip():
            return str(cfg_val).strip().strip("'\"")
    except Exception:
        pass

    return ""


# =========================================================================
# Provider Keys & Models
# =========================================================================

def get_groq_key(user_id: Optional[str] = None) -> str:
    """Retrieve Groq API key (Individual -> Global -> default)."""
    key = get_smart_secret("GROQ_API_KEY", user_id)
    if key and not key.startswith("gsk-placeholder"):
        return key
    return os.getenv("GROQ_API_KEY", "")


def get_groq_models(user_id: Optional[str] = None) -> List[str]:
    """Retrieve Groq models list."""
    models_str = get_smart_secret("GROQ_MODELS", user_id)
    if models_str:
        models = [m.strip() for m in models_str.split(",") if m.strip()]
        if models:
            return models
    return ["qwen/qwen3.8-27b", "openai/gpt-oss-120b", "allam-2-7b"]


def get_gemini_key(user_id: Optional[str] = None) -> str:
    """Retrieve Gemini key from Vault (Individual -> Global -> default)."""
    key = get_smart_secret("GEMINI_API_KEY", user_id) or get_smart_secret("GOOGLE_API_KEY", user_id)
    if key and not key.startswith("AIza-placeholder"):
        return key
    return os.getenv("GEMINI_API_KEY", "") or os.getenv("GOOGLE_API_KEY", "")


def is_gemini_key_valid(key: str) -> bool:
    """Check if Gemini key is present and valid."""
    if not key or key.startswith("AIza-placeholder"):
        return False
    return True


def get_cloudflare_key(user_id: Optional[str] = None) -> str:
    """Retrieve Cloudflare Workers AI token."""
    key = get_smart_secret("CLOUDFLARE_API_KEY", user_id)
    if key and not key.startswith("cfut-placeholder"):
        return key
    return os.getenv("CLOUDFLARE_API_KEY", "")


def get_cloudflare_account_id(user_id: Optional[str] = None) -> str:
    """Retrieve Cloudflare Account ID."""
    acc_id = get_smart_secret("CLOUDFLARE_ACCOUNT_ID", user_id)
    if acc_id:
        return acc_id
    return os.getenv("CLOUDFLARE_ACCOUNT_ID", "")


def get_cloudflare_model(user_id: Optional[str] = None) -> str:
    """Retrieve Cloudflare Workers AI model."""
    model = get_smart_secret("CLOUDFLARE_MODEL", user_id)
    if model:
        return model
    return "@cf/zai-org/glm-4.7-flash"


def get_openrouter_key(user_id: Optional[str] = None) -> str:
    """Retrieve OpenRouter key from Vault, environ, or configured fallback."""
    key = get_smart_secret("OPENROUTER_API_KEY", user_id)
    if key and not key.startswith("sk-or-v1-placeholder"):
        return key
    return os.getenv("OPENROUTER_API_KEY", "")


def get_openrouter_models(user_id: Optional[str] = None) -> List[str]:
    """Retrieve OpenRouter free fallback models."""
    models_str = get_smart_secret("OPENROUTER_FALLBACK_MODELS", user_id)
    if models_str:
        models = [m.strip() for m in models_str.split(",") if m.strip()]
        if models:
            return models
    return [
        "nvidia/nemotron-3.5-lightning:free",
        "nvidia/nemotron-3-ultra-550b-a55b:free",
        "cohere/north-mini-code:free"
    ]


def get_provider_priority(user_id: Optional[str] = None) -> List[str]:
    """Retrieve provider priority order (default: groq, gemini, cloudflare, openrouter)."""
    p_str = get_smart_secret("AI_PROVIDER_PRIORITY", user_id)
    if p_str:
        order = [p.strip().lower() for p in p_str.split(",") if p.strip()]
        if order:
            return order
    return ["groq", "gemini", "cloudflare", "openrouter"]


# =========================================================================
# LLM Constructors
# =========================================================================

def get_groq_llm(model: Optional[str] = None, user_id: Optional[str] = None):
    """Return a Groq ChatOpenAI instance using Vault API key."""
    from langchain_openai import ChatOpenAI
    key = get_groq_key(user_id)
    models = get_groq_models(user_id)
    selected_model = model or (models[0] if models else "qwen/qwen3.8-27b")
    return ChatOpenAI(
        model=selected_model,
        api_key=key,
        base_url="https://api.groq.com/openai/v1",
        temperature=0.3,
        max_tokens=8192,
        streaming=True,
        default_headers={
            "User-Agent": "curl/7.68.0",
            "HTTP-Referer": "https://edushamiit.com",
            "X-Title": "EduSHAMIIT AI"
        }
    )


def get_gemini_llm(model: Optional[str] = None, user_id: Optional[str] = None):
    """Return a Gemini ChatGoogleGenerativeAI instance."""
    from langchain_google_genai import ChatGoogleGenerativeAI
    key = get_gemini_key(user_id)
    selected_model = model or get_smart_secret("GEMINI_MODEL", user_id) or "gemini-1.5-flash"
    if "3.5" in selected_model or "lite" in selected_model:
        selected_model = "gemini-1.5-flash"
    return ChatGoogleGenerativeAI(
        model=selected_model,
        temperature=0.3,
        max_tokens=8192,
        max_retries=1,
        streaming=True,
        google_api_key=key
    )


def get_cloudflare_llm(model: Optional[str] = None, user_id: Optional[str] = None):
    """Return a Cloudflare Workers AI ChatOpenAI instance."""
    from langchain_openai import ChatOpenAI
    key = get_cloudflare_key(user_id)
    acc_id = get_cloudflare_account_id(user_id)
    selected_model = model or get_cloudflare_model(user_id)
    return ChatOpenAI(
        model=selected_model,
        api_key=key,
        base_url=f"https://api.cloudflare.com/client/v4/accounts/{acc_id}/ai/v1",
        temperature=0.3,
        max_tokens=8192,
        streaming=True,
        default_headers={
            "User-Agent": "curl/7.68.0"
        }
    )


def get_openrouter_llm(model: Optional[str] = None, user_id: Optional[str] = None):
    """Return an OpenRouter ChatOpenAI instance using Vault API key."""
    from langchain_openai import ChatOpenAI
    openrouter_key = get_openrouter_key(user_id)
    models = get_openrouter_models(user_id)
    selected_model = model or (models[0] if models else "nvidia/nemotron-3.5-lightning:free")
    return ChatOpenAI(
        model=selected_model,
        api_key=openrouter_key,
        base_url="https://openrouter.ai/api/v1",
        temperature=0.3,
        max_tokens=8192,
        streaming=True,
        default_headers={
            "HTTP-Referer": "https://edushamiit.com",
            "X-Title": "EduSHAMIIT AI"
        }
    )


# =========================================================================
# Candidate Chain & Orchestrator
# =========================================================================

def get_candidate_chain(user_id: Optional[str] = None, preferred_model: Optional[str] = None, force_openrouter: bool = False) -> List[Dict[str, Any]]:
    """
    Construct the sequential multi-provider candidate chain in priority order:
    1. Groq (qwen/qwen3.8-27b, openai/gpt-oss-120b, allam-2-7b)
    2. Gemini (gemini-1.5-flash, gemini-2.0-flash)
    3. Cloudflare Workers AI (@cf/zai-org/glm-4.7-flash)
    4. OpenRouter (nemotron-3.5-lightning, nemotron-3-ultra, cohere)
    """
    candidates = []
    
    # Check if a specific model was preferred
    if preferred_model:
        pref_lower = preferred_model.lower()
        if any(g in pref_lower for g in ["qwen", "groq", "gpt-oss", "allam"]):
            try:
                candidates.append({
                    "provider": "Groq",
                    "model": preferred_model,
                    "llm": get_groq_llm(preferred_model, user_id)
                })
            except Exception:
                pass
        elif "gemini" in pref_lower:
            key = get_gemini_key(user_id)
            if is_gemini_key_valid(key):
                try:
                    candidates.append({
                        "provider": "Gemini",
                        "model": preferred_model,
                        "llm": get_gemini_llm(preferred_model, user_id)
                    })
                except Exception:
                    pass
        elif any(c in pref_lower for c in ["cloudflare", "glm", "@cf"]):
            try:
                candidates.append({
                    "provider": "Cloudflare",
                    "model": preferred_model,
                    "llm": get_cloudflare_llm(preferred_model, user_id)
                })
            except Exception:
                pass
        elif any(o in pref_lower for o in ["nemotron", "cohere", "openrouter", "deepseek"]):
            try:
                candidates.append({
                    "provider": "OpenRouter",
                    "model": preferred_model,
                    "llm": get_openrouter_llm(preferred_model, user_id)
                })
            except Exception:
                pass

    if force_openrouter:
        # Prioritize OpenRouter when forced
        for m in get_openrouter_models(user_id):
            try:
                candidates.append({
                    "provider": "OpenRouter",
                    "model": m,
                    "llm": get_openrouter_llm(m, user_id)
                })
            except Exception:
                pass
        return candidates

    # Build sequence based on priority order: Groq -> Gemini -> Cloudflare -> OpenRouter
    priority_order = get_provider_priority(user_id)

    for prov in priority_order:
        if prov == "groq":
            for m in get_groq_models(user_id):
                if not any(c["model"] == m for c in candidates):
                    try:
                        candidates.append({
                            "provider": "Groq",
                            "model": m,
                            "llm": get_groq_llm(m, user_id)
                        })
                    except Exception as e:
                        print(f"[Router] Error preparing Groq model {m}: {e}")

        elif prov == "gemini":
            gem_key = get_gemini_key(user_id)
            if is_gemini_key_valid(gem_key):
                for m in ["gemini-1.5-flash", "gemini-2.0-flash"]:
                    if not any(c["model"] == m for c in candidates):
                        try:
                            candidates.append({
                                "provider": "Gemini",
                                "model": m,
                                "llm": get_gemini_llm(m, user_id)
                            })
                        except Exception as e:
                            print(f"[Router] Error preparing Gemini model {m}: {e}")

        elif prov in ("cloudflare", "cloudflare_ai", "cf"):
            cf_m = get_cloudflare_model(user_id)
            if not any(c["model"] == cf_m for c in candidates):
                try:
                    candidates.append({
                        "provider": "Cloudflare",
                        "model": cf_m,
                        "llm": get_cloudflare_llm(cf_m, user_id)
                    })
                except Exception as e:
                    print(f"[Router] Error preparing Cloudflare model {cf_m}: {e}")

        elif prov == "openrouter":
            for m in get_openrouter_models(user_id):
                if not any(c["model"] == m for c in candidates):
                    try:
                        candidates.append({
                            "provider": "OpenRouter",
                            "model": m,
                            "llm": get_openrouter_llm(m, user_id)
                        })
                    except Exception as e:
                        print(f"[Router] Error preparing OpenRouter model {m}: {e}")

    # Ensure at least one OpenRouter model is included as final backstop
    if not any(c["provider"] == "OpenRouter" for c in candidates):
        try:
            m = "nvidia/nemotron-3.5-lightning:free"
            candidates.append({
                "provider": "OpenRouter",
                "model": m,
                "llm": get_openrouter_llm(m, user_id)
            })
        except Exception:
            pass

    return candidates


def get_llm(task: str = "qa", force_openrouter: bool = False, preferred_model: Optional[str] = None, user_id: Optional[str] = None):
    """
    Return the primary LLM for this task with dynamic multi-provider resolution.
    Strictly adheres to priority: Groq -> Gemini -> Cloudflare -> OpenRouter.
    """
    candidates = get_candidate_chain(user_id=user_id, preferred_model=preferred_model, force_openrouter=force_openrouter)
    if candidates:
        return candidates[0]["llm"]
    # Fallback to OpenRouter default
    return get_openrouter_llm("nvidia/nemotron-3.5-lightning:free", user_id)


def get_fallback_llms(user_id: Optional[str] = None) -> List[Any]:
    """
    Return list of fallback LLMs excluding the primary candidate.
    """
    candidates = get_candidate_chain(user_id=user_id)
    if len(candidates) > 1:
        return [c["llm"] for c in candidates[1:]]
    return [get_openrouter_llm("nvidia/nemotron-3-ultra-550b-a55b:free", user_id)]
