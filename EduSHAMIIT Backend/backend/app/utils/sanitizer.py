"""
Input Sanitizer Utility - Prevents PostgREST Filter Injection and SQL Parsing Manipulation.
"""
import re

def sanitize_search_input(user_input: str, max_length: int = 100) -> str:
    """
    Sanitizes user search inputs by stripping PostgREST control characters 
    (commas, parentheses, quotes, percent signs, and semicolons).
    """
    if not user_input or not isinstance(user_input, str):
        return ""
    # Strip dangerous PostgREST filter operators & SQL injection characters
    clean = re.sub(r'[\(\),\'\"%;\\]', '', user_input.strip())
    return clean[:max_length]
