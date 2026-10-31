#!/usr/bin/env python3
"""Short reproducible M2 scenarios using isolated preferences and the exact Release PID.
No app installs, login items, user preferences, uploads or new dependencies.
Run with no concurrent builds/tests. Longer Instruments runs remain a release gate.
"""
from pathlib import Path
import hashlib, json, subprocess, time
root = Path(__file__).resolve().parent.parent
binary = root / 'dist/Release/Tether.app/Contents/MacOS/Tether'
scenarios = [(1,'idle'),(1,'paused'),(1,'idle'),(1,'paused'),(1,'wind'),(1,'hidden'),(3,'idle'),(3,'wind'),(6,'idle'),(6,'wind'),(6,'ambient')]
results = []
for count, mode in scenarios:
    process = subprocess.Popen([str(binary), '--profile-test', '--profile-count', str(count), '--profile-' + mode], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(5)
        samples = []
        for index in range(7):
            row = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'time=,rss=,%cpu='], text=True).split()
            samples.append({'elapsed': time.monotonic(), 'cpu_time': row[0], 'rss_kib': int(row[1]), 'ps_cpu_percent': float(row[2])})
            time.sleep(1)
        def seconds(value):
            return sum(float(p) * 60 ** i for i,p in enumerate(reversed(value.split(':'))))
        elapsed = samples[-1]['elapsed'] - samples[0]['elapsed']
        result = {'count':count, 'mode':mode, 'sample_interval_seconds':elapsed, 'cpu_percent_one_core':round(100*(seconds(samples[-1]['cpu_time'])-seconds(samples[0]['cpu_time']))/elapsed,3), 'rss_kib_min':min(s['rss_kib'] for s in samples), 'rss_kib_max':max(s['rss_kib'] for s in samples), 'samples':samples}
        results.append(result)
        print(json.dumps({k:v for k,v in result.items() if k != 'samples'}), flush=True)
    finally:
        process.wait(timeout=20)
report = {'date':'2026-10-31', 'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(), 'method':'Universal Release/native arm64; 5s warm-up then 7 ps samples over ~6s. Diagnostic modes use isolated preferences; idle variations/sleep disabled except ambient scenario. CPU-time resolution 0.01s. No overlapping builds/tests.', 'results':results}
(root / '.build/m2-performance.json').write_text(json.dumps(report,indent=2)+'\n')
