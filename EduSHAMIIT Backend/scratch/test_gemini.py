import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI

load_dotenv("e:/EduSHAMIIT/.env")

api_key = os.getenv("GOOGLE_API_KEY")
models = ["gemini-1.5-flash", "gemini-2.0-flash", "gemini-2.5-flash", "gemini-3.1-flash-lite"]

for model_name in models:
    print(f"\n--- Testing model: {model_name} ---")
    try:
        llm = ChatGoogleGenerativeAI(
            model=model_name,
            temperature=0.3,
            google_api_key=api_key
        )
        res = llm.invoke("Hi Shami, tell me what is 2+2.")
        print(f"SUCCESS for {model_name}!")
        print("Response:", res.content)
    except Exception as e:
        print(f"FAILED for {model_name}!")
        print("Error details:", str(e))
