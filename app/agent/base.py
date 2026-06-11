import os
from abc import ABC
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()


class BaseAgent(ABC):
    def __init__(self, model: str):
        api_key = os.getenv("OPENAI_API_KEY")
        base_url = os.getenv("OPENAI_BASE_URL")
        
        # Auto-detect Google Gemini keys
        if api_key and (api_key.startswith("AQ") or api_key.startswith("AIza")):
            if not base_url:
                base_url = "https://generativelanguage.googleapis.com/v1beta/openai/"
            if model.startswith("gpt-"):
                model = "gemini-2.5-flash-lite"
                
        self.client = OpenAI(api_key=api_key, base_url=base_url)
        self.model = model
