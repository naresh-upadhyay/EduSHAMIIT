import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI

load_dotenv("e:/EduSHAMIIT/.env")

api_key = os.getenv("GOOGLE_API_KEY")
model_name = "gemini-3.1-flash-lite"

print(f"Testing model: {model_name}")
print(f"API Key exists: {bool(api_key)}")

try:
    llm = ChatGoogleGenerativeAI(
        model=model_name,
        temperature=0.3,
        google_api_key=api_key
    )
    res = llm.invoke("Hi Shami, tell me what is 2+2.")
    print("SUCCESS!")
    print("Response:", res.content)
except Exception as e:
    print("FAILED!")
    print("Error details:", str(e))
