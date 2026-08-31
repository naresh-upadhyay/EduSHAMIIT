import os
import sys
import subprocess
import time

def main():
    app_dir = os.path.dirname(os.path.abspath(__file__))
    test_files = sorted([f for f in os.listdir(app_dir) if f.startswith("test_") and f.endswith(".py")])
    
    print("=" * 80)
    print(f"🚀 EDUSHAMIIT MASTER TEST RUNNER - RUNNING {len(test_files)} TEST SUITES")
    print("=" * 80)
    
    results = []
    total_start = time.time()
    
    for idx, test_file in enumerate(test_files, 1):
        test_path = os.path.join(app_dir, test_file)
        print(f"[{idx:02d}/{len(test_files):02d}] 🧪 Running {test_file}...", end=" ", flush=True)
        
        start = time.time()
        env = os.environ.copy()
        env["PYTHONPATH"] = "/app"
        env["DATABASE_URL"] = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@db:5432/postgres")
        env["API_BASE_URL"] = os.environ.get("API_BASE_URL", "http://localhost:8000")
        env["CLASSES_API_URL"] = os.environ.get("CLASSES_API_URL", "http://localhost:8000/api/classes")
        try:
            p = subprocess.run(
                [sys.executable, test_path],
                cwd="/app",
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=60
            )
            elapsed = time.time() - start
            if p.returncode == 0:
                print(f"✅ PASSED ({elapsed:.2f}s)")
                results.append((test_file, True, elapsed, ""))
            else:
                print(f"❌ FAILED (Exit Code: {p.returncode}) ({elapsed:.2f}s)")
                # Extract first error lines
                lines = [l for l in p.stdout.splitlines() if "Error" in l or "FAIL" in l or "Traceback" in l or "assert" in l]
                err_msg = lines[-1] if lines else "Non-zero exit code"
                results.append((test_file, False, elapsed, err_msg[:120]))
        except subprocess.TimeoutExpired:
            print(f"⏰ TIMEOUT (>45s)")
            results.append((test_file, False, 45.0, "Execution Timeout (>45s)"))
        except Exception as e:
            print(f"💥 ERROR: {e}")
            results.append((test_file, False, 0.0, str(e)))

    total_elapsed = time.time() - total_start
    passed_count = sum(1 for _, s, _, _ in results if s)
    failed_count = len(results) - passed_count
    
    print("\n" + "=" * 80)
    print("📊 TEST EXECUTION SUMMARY REPORT")
    print("=" * 80)
    print(f"{'#':<4} {'Test Suite Name':<45} {'Status':<10} {'Duration':<10} {'Details'}")
    print("-" * 80)
    for idx, (name, success, dur, err) in enumerate(results, 1):
        status_str = "✅ PASS" if success else "❌ FAIL"
        detail_str = "" if success else f"({err})"
        print(f"{idx:<4} {name:<45} {status_str:<10} {dur:>6.2f}s    {detail_str}")
        
    print("=" * 80)
    print(f"🏁 TOTAL SUITES : {len(results)}")
    print(f"✅ PASSED       : {passed_count}")
    print(f"❌ FAILED       : {failed_count}")
    print(f"⏱️ TOTAL TIME   : {total_elapsed:.2f}s")
    print(f"🎯 SUCCESS RATE : {(passed_count / len(results)) * 100:.1f}%")
    print("=" * 80)

if __name__ == "__main__":
    main()
