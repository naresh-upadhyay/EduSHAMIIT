"""
EduSHAMIIT Backend Test Suite Package Initialization
Ensures backend root is on sys.path for test discovery and standalone execution.
"""
import os
import sys

backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)
