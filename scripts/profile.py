#!/usr/bin/env python3
"""Short preliminary baseline, not a substitute for the manual Instruments matrix.
Uses isolated app preferences. Does not enable login or change normal preferences.
Run after a Release build. The first state also records an Instruments trace.
"""
from pathlib import Path
import json, subprocess, time, sys
root = Path(__file__).resolve().parent.parent
binary = root / 'dist/Release/Tether.app/Contents/MacOS/Tether'
results = []
for mode in ['idle', 'wind', 'paused', 'hidden']:
    process = subprocess.Popen([str(binary), '--profile-test', '--profile-' + mode], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    trace = None
    try:
        time.sleep(5)
        if mode == 'idle' and '--skip-instruments' not in sys.argv:
            output = root / '.build/Tether-release-idle.trace'
            if not output.exists():
                trace = subprocess.Popen(['xcrun', 'xctrace', 'record', '--template', 'Time Profiler', '--time-limit', '5s', '--output', str(output), '--attach', str(process.pid)], stdout=(root / '.build/instruments-release.log').open('w'), stderr=subprocess.STDOUT)
        samples = []
        for _ in range(7):
            text = subprocess.check_output(['ps', '-p', str(process.pid), '-o', 'time=,rss=,%cpu='], text=True).split()
            samples.append({'elapsed': time.monotonic(), 'cpu_time': text[0], 'rss_kib': int(text[1]), 'ps_cpu_percent': float(text[2])})
            time.sleep(1)
        def seconds(value):
            parts = value.split(':')
            return sum(float(p) * (60 ** i) for i, p in enumerate(reversed(parts)))
        cpu = 100 * (seconds(samples[-1]['cpu_time']) - seconds(samples[0]['cpu_time'])) / (samples[-1]['elapsed'] - samples[0]['elapsed'])
        result = {'mode': mode, 'sample_interval_seconds': samples[-1]['elapsed'] - samples[0]['elapsed'], 'cpu_percent_one_core': round(cpu, 3), 'rss_kib_min': min(s['rss_kib'] for s in samples), 'rss_kib_max': max(s['rss_kib'] for s in samples), 'samples': samples}
        results.append(result)
        print(json.dumps({k: v for k, v in result.items() if k != 'samples'}), flush=True)
        if trace: print('Instruments exit:', trace.wait(timeout=30), flush=True)
    finally:
        # Allow the diagnostic app to quit and remove its isolated UserDefaults suite.
        process.wait(timeout=20)
(root / '.build/performance-baseline.json').write_text(json.dumps(results, indent=2))
