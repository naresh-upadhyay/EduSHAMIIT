import os
import requests
import json
from typing import Optional
from app.agents.router import (
    get_gemini_key,
    is_gemini_key_valid,
    get_openrouter_key,
    get_cloudflare_key,
    get_cloudflare_account_id
)


async def analyze_image(image_b64: str, question: str = "Describe this image", user_id: Optional[str] = None) -> str:
    """
    Analyze an image using multi-provider vision with automatic fallbacks:
    1. Google Gemini Flash (if valid non-leaked key is configured)
    2. OpenRouter Free Vision (nvidia/nemotron-3.5-super-vl:free)
    3. OpenRouter Omni (nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free)
    4. Cloudflare Workers AI Vision (@cf/meta/llama-3.2-11b-vision-instruct)
    """
    clean_question = question.strip() if question and question.strip() else "Describe and analyze this image in detail."

    # Ensure clean base64 data URI
    if not image_b64.startswith("data:"):
        image_url = f"data:image/jpeg;base64,{image_b64}"
    else:
        image_url = image_b64

    # -------------------------------------------------------------------------
    # Provider 1: Google Gemini (if valid)
    # -------------------------------------------------------------------------
    gemini_key = get_gemini_key(user_id)
    if is_gemini_key_valid(gemini_key):
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
            from langchain_core.messages import HumanMessage
            
            model_name = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
            llm = ChatGoogleGenerativeAI(
                model=model_name,
                temperature=0.3,
                google_api_key=gemini_key
            )
            msg = HumanMessage(content=[
                {"type": "image_url", "image_url": {"url": image_url}},
                {"type": "text", "text": clean_question}
            ])
            response = await llm.ainvoke([msg])
            if response and response.content:
                return response.content
        except Exception as e:
            print(f"[Vision Fallback] Gemini failed: {e}. Falling back to OpenRouter Vision...")

    # -------------------------------------------------------------------------
    # Provider 2: OpenRouter Free Vision (nvidia/nemotron-3.5-super-vl:free)
    # -------------------------------------------------------------------------
    openrouter_key = get_openrouter_key(user_id)
    if openrouter_key:
        vision_models = [
            "nvidia/nemotron-3.5-super-vl:free",
            "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"
        ]
        for v_model in vision_models:
            try:
                headers = {
                    "Authorization": f"Bearer {openrouter_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://edushamiit.com",
                    "X-Title": "EduSHAMIIT Vision"
                }
                payload = {
                    "model": v_model,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {"type": "text", "text": clean_question},
                                {"type": "image_url", "image_url": {"url": image_url}}
                            ]
                        }
                    ],
                    "temperature": 0.3,
                    "max_tokens": 2048
                }
                resp = requests.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers=headers,
                    json=payload,
                    timeout=30
                )
                if resp.status_code == 200:
                    data = resp.json()
                    choices = data.get("choices", [])
                    if choices:
                        content = choices[0].get("message", {}).get("content", "")
                        if content:
                            return content
                else:
                    print(f"[Vision Fallback] OpenRouter ({v_model}) HTTP {resp.status_code}: {resp.text}")
            except Exception as e:
                print(f"[Vision Fallback] OpenRouter ({v_model}) exception: {e}")

    # -------------------------------------------------------------------------
    # Provider 3: Cloudflare Workers AI Vision
    # -------------------------------------------------------------------------
    cf_key = get_cloudflare_key(user_id)
    cf_account = get_cloudflare_account_id(user_id)
    if cf_key and cf_account:
        try:
            cf_url = f"https://api.cloudflare.com/client/v4/accounts/{cf_account}/ai/v1/chat/completions"
            headers = {
                "Authorization": f"Bearer {cf_key}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": "@cf/meta/llama-3.2-11b-vision-instruct",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": clean_question},
                            {"type": "image_url", "image_url": {"url": image_url}}
                        ]
                    }
                ],
                "max_tokens": 2048
            }
            resp = requests.post(cf_url, headers=headers, json=payload, timeout=30)
            if resp.status_code == 200:
                data = resp.json()
                choices = data.get("choices", [])
                if choices:
                    return choices[0].get("message", {}).get("content", "")
        except Exception as e:
            print(f"[Vision Fallback] Cloudflare Vision exception: {e}")

    return "I was unable to analyze the image with the available AI vision providers. Please check that a valid Gemini, OpenRouter, or Cloudflare API key is configured in Vault."
