"""
Pytest configuration for EduSHAMIIT Backend
Provides universal test fixtures, path initialization, and mock settings.
"""
import os
import sys

# Ensure backend root is always on sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)
