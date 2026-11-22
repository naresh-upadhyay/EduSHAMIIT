import os
import sys
import subprocess
import time
from typing import List, Dict, Any

BACKEND_DIR = os.path.abspath(os.path.dirname(__file__))
TESTS_DIR = os.path.join(BACKEND_DIR, "tests")

ENV = os.environ.copy()
ENV["PYTHONPATH"] = BACKEND_DIR
ENV["DATABASE_URL"] = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"
ENV["SUPABASE_URL"] = "http://127.0.0.1:8000"
ENV["API_BASE_URL"] = "http://127.0.0.1:8082"

def run_single_test(test_file: str) -> Dict[str, Any]:
    test_path = os.path.join(TESTS_DIR, test_file)
    start = time.time()
    
    # Try running directly with python
    proc = subprocess.run(
        [sys.executable, test_path],
        cwd=BACKEND_DIR,
        env=ENV,
        capture_output=True,
        text=True,
        timeout=180
    )
    duration = time.time() - start
    
    if proc.returncode == 0:
        return {
            "file": test_file,
            "status": "PASS",
            "duration": round(duration, 2),
            "output": proc.stdout[-300:] if proc.stdout else "",
            "error": ""
        }
    else:
        # If exit code != 0, check if it's a pytest file
        if "def test_" in open(test_path, "r", encoding="utf-8", errors="ignore").read() and "if __name__" not in open(test_path, "r", encoding="utf-8", errors="ignore").read():
            try:
                proc2 = subprocess.run(
                    [sys.executable, "-m", "pytest", test_path, "-q"],
                    cwd=BACKEND_DIR,
                    env=ENV,
                    capture_output=True,
                    text=True,
                    timeout=180
                )
                if proc2.returncode == 0:
                    return {
                        "file": test_file,
                        "status": "PASS",
                        "duration": round(time.time() - start, 2),
                        "output": proc2.stdout[-300:] if proc2.stdout else "",
                        "error": ""
                    }
                else:
                    return {
                        "file": test_file,
                        "status": "FAIL",
                        "duration": round(time.time() - start, 2),
                        "output": proc2.stdout[-500:],
                        "error": proc2.stderr[-500:]
                    }
            except Exception as e:
                pass

        err_out = proc.stderr[-1000:] if proc.stderr else proc.stdout[-1000:]
        return {
            "file": test_file,
            "status": "FAIL",
            "duration": round(duration, 2),
            "output": proc.stdout[-500:],
            "error": err_out
        }

if __name__ == "__main__":
    test_files = sorted([f for f in os.listdir(TESTS_DIR) if f.startswith("test_") and f.endswith(".py")])
    
    # Optional start/end slice via arguments
    start_idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    end_idx = int(sys.argv[2]) if len(sys.argv) > 2 else len(test_files)
    batch = test_files[start_idx:end_idx]
    
    print(f"Running test batch [{start_idx}:{end_idx}] ({len(batch)} files)...")
    
    results = []
    passed = 0
    failed = 0
    
    for idx, tf in enumerate(batch, 1):
        print(f"[{idx}/{len(batch)}] Running {tf}...", end=" ", flush=True)
        try:
            res = run_single_test(tf)
            if res["status"] == "PASS":
                passed += 1
                print(f"PASS ({res['duration']}s)")
            else:
                failed += 1
                print(f"FAIL ({res['duration']}s)")
                print(f"   Error: {res['error'].strip()[:200]}")
            results.append(res)
        except subprocess.TimeoutExpired:
            failed += 1
            print(f"TIMEOUT (>90s)")
            results.append({"file": tf, "status": "TIMEOUT", "duration": 90, "error": "TimeoutExpired"})
        except Exception as e:
            failed += 1
            print(f"ERROR: {e}")
            results.append({"file": tf, "status": "ERROR", "duration": 0, "error": str(e)})

    print("\n" + "=" * 60)
    print(f"BATCH SUMMARY: {passed} PASSED, {failed} FAILED out of {len(batch)} tests")
    print("=" * 60)
    
    if failed > 0:
        print("\nFailed Tests:")
        for r in results:
            if r["status"] != "PASS":
                print(f"- {r['file']}: {r.get('error', '').strip()[:150]}")
