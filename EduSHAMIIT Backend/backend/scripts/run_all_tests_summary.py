import os
import sys
import glob
import time
import subprocess

def run_all():
    test_dir = "/app/tests"
    test_files = sorted(glob.glob(os.path.join(test_dir, "test_*.py")))
    
    total = len(test_files)
    passed = 0
    failed = 0
    failures = []
    
    print("=" * 80)
    print(f"🚀 EXECUTING ALL {total} FASTAPI BACKEND TEST SUITES")
    print("=" * 80)
    
    start_total = time.time()
    
    for idx, test_file in enumerate(test_files, 1):
        test_name = os.path.basename(test_file)
        print(f"[{idx:02d}/{total:02d}] Running {test_name:<48}", end=" ", flush=True)
        t0 = time.time()
        
        proc = subprocess.run(
            [sys.executable, test_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=120
        )
        duration = time.time() - t0
        
        if proc.returncode == 0:
            passed += 1
            print(f"✅ PASSED ({duration:.2f}s)")
        else:
            failed += 1
            print(f"❌ FAILED ({duration:.2f}s)")
            failures.append((test_name, proc.stdout, proc.stderr))
            
    total_time = time.time() - start_total
    print("\n" + "=" * 80)
    print(f"🏁 MASTER TEST RUN COMPLETE IN {total_time:.2f}s")
    print(f"   TOTAL SUITES: {total}")
    print(f"   PASSED:       {passed} ({passed / total * 100:.1f}%)")
    print(f"   FAILED:       {failed}")
    print("=" * 80)
    
    if failures:
        print("\n❌ FAILURE DETAILS:")
        for name, out, err in failures:
            print(f"\n--- {name} ---")
            print("STDOUT:\n", out[-1000:] if len(out) > 1000 else out)
            print("STDERR:\n", err[-1000:] if len(err) > 1000 else err)

if __name__ == "__main__":
    run_all()
