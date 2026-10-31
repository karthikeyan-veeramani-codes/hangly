#!/usr/bin/env python3
"""Sustained isolated Release verification. No installation, uploads or system settings.
Process suite: 60+ seconds measured per scenario, after 10s warm-up, no builds/tests.
Instrument suite: separate actual PIDs, 60s Time Profiler / Allocations / Power attempt,
plus early/late leaks scans across a 150s import/render/delete workload.
"""
from pathlib import Path
import argparse, hashlib, json, os, statistics, subprocess, time
root = Path(__file__).resolve().parent.parent
out = root / '.build/m21-performance'
out.mkdir(parents=True, exist_ok=True)
binary = root / 'dist/Release/Tether.app/Contents/MacOS/Tether'
parser=argparse.ArgumentParser(); parser.add_argument('--suite', choices=['process','instruments','all'], default='all'); args=parser.parse_args()
digest=hashlib.sha256(binary.read_bytes()).hexdigest()
report_path=out/'results.json'
report=json.loads(report_path.read_text()) if report_path.exists() else {'date':'2026-10-31','binary_sha256':digest,'process':[],'instruments':[]}
if report['binary_sha256'] != digest: raise SystemExit('Release binary differs from checkpoint; archive/remove previous m21-performance results before a new run.')
def save(): report_path.write_text(json.dumps(report,indent=2)+'\n')
def seconds(value): return sum(float(p)*60**i for i,p in enumerate(reversed(value.split(':'))))
def sample(pid):
    parts=subprocess.check_output(['ps','-p',str(pid),'-o','time=,rss='],text=True).split()
    return {'time':time.monotonic(),'cpu_seconds':seconds(parts[0]),'rss_kib':int(parts[1])}
def launch(name,count,mode,duration,logging=False):
    diagnostic=out/(name+'-diagnostic.json')
    command=[str(binary),'--profile-test','--profile-count',str(count),'--profile-seconds',str(duration),'--profile-warmup','5','--diagnostics-json',str(diagnostic),'--profile-'+mode]
    env=os.environ.copy()
    if logging: env['MallocStackLogging']='1'
    log=(out/(name+'-app.log')).open('w')
    process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env)
    return process,diagnostic,log
def finish(process,log):
    try: code=process.wait(timeout=120)
    except subprocess.TimeoutExpired:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()
        raise RuntimeError('Diagnostic process failed to quit on its deadline')
    finally: log.close()
    if code: raise RuntimeError(f'Diagnostic app exited {code}')
if args.suite in ['process','all']:
    cases=[(1,'idle'),(1,'swing'),(3,'idle'),(3,'swing'),(6,'idle'),(6,'swing'),(6,'wind'),(1,'paused'),(1,'hidden'),(1,'settings'),(1,'library'),(1,'idle'),(1,'paused'),(3,'idle')]
    for index,(count,mode) in enumerate(cases):
        name=f'{index+1:02d}-{count}-{mode}'
        if any(r['name']==name for r in report['process']): continue
        print('START',name,flush=True)
        process,diagnostic,log=launch(name,count,mode,77)
        try:
            time.sleep(10)
            samples=[]
            for i in range(61):
                samples.append(sample(process.pid))
                if i in [20,40,60]: print('PROGRESS',name,i,'seconds','RSS',samples[-1]['rss_kib'],'KiB',flush=True)
                time.sleep(1)
            finish(process,log)
        except BaseException:
            if process.poll() is None: process.terminate(); process.wait(timeout=10)
            log.close(); raise
        elapsed=samples[-1]['time']-samples[0]['time']
        result={'name':name,'count':count,'mode':mode,'measured_seconds':elapsed,'cpu_percent_one_core':100*(samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'])/elapsed,
                'rss_kib_min':min(s['rss_kib'] for s in samples),'rss_kib_max':max(s['rss_kib'] for s in samples),
                'rss_kib_first10_mean':statistics.mean(s['rss_kib'] for s in samples[:10]),'rss_kib_last10_mean':statistics.mean(s['rss_kib'] for s in samples[-10:]),'samples':samples,
                'diagnostic':json.loads(diagnostic.read_text()) if diagnostic.exists() else None}
        report['process'].append(result); save()
        print('DONE',name,round(result['cpu_percent_one_core'],3),'% CPU',round(result['rss_kib_max']/1024,2),'MiB',flush=True)

def record(name,count,mode,template,duration=60):
    print('INSTRUMENT START',name,template,flush=True)
    process,diagnostic,log=launch(name,count,mode,duration+28)
    time.sleep(8)
    trace=out/(name+'.trace')
    with (out/(name+'-record.log')).open('w') as output:
        code=subprocess.run(['xcrun','xctrace','record','--template',template,'--time-limit',str(duration)+'s','--output',str(trace),'--attach',str(process.pid)],stdout=output,stderr=subprocess.STDOUT).returncode
    finish(process,log)
    toc=out/(name+'-toc.xml')
    export=subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(toc)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    entry={'name':name,'template':template,'duration_requested':duration,'record_exit':code,'export_exit':export.returncode,'export_message':export.stdout,'diagnostic':json.loads(diagnostic.read_text()) if diagnostic.exists() else None}
    if template=='Time Profiler' and export.returncode==0:
        subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--xpath','/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]','--output',str(out/(name+'-samples.xml'))],stdout=subprocess.DEVNULL,check=True)
    report['instruments'].append(entry); save(); print('INSTRUMENT DONE',name,'record',code,'export',export.returncode,flush=True)
if args.suite in ['instruments','all']:
    for name,count,mode,template in [('time-paused',1,'paused','Time Profiler'),('time-six-wind',6,'wind','Time Profiler')]:
        if not any(r['name']==name for r in report['instruments']): record(name,count,mode,template)
    if not any(r['name']=='allocations-churn' for r in report['instruments']):
        name='allocations-churn'; print('INSTRUMENT START',name,flush=True)
        process,diagnostic,log=launch(name,1,'churn',165,True)
        time.sleep(10)
        def leaks(label):
            with (out/(name+'-leaks-'+label+'.log')).open('w') as stream:
                return subprocess.run(['leaks','--noContent',str(process.pid)],stdout=stream,stderr=subprocess.STDOUT).returncode
        early=leaks('early')
        trace=out/(name+'.trace')
        with (out/(name+'-record.log')).open('w') as stream:
            recorder=subprocess.Popen(['xcrun','xctrace','record','--template','Allocations','--time-limit','60s','--output',str(trace),'--attach',str(process.pid)],stdout=stream,stderr=subprocess.STDOUT)
            memory=[]
            for i in range(26):
                memory.append(sample(process.pid))
                if i%6==0: print('CHURN',i*5,'seconds','RSS',memory[-1]['rss_kib'],'KiB',flush=True)
                time.sleep(5)
            record_code=recorder.wait(timeout=30)
        late=leaks('late'); finish(process,log)
        export=subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(out/(name+'-toc.xml'))],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        report['instruments'].append({'name':name,'template':'Allocations + live leaks scans','record_exit':record_code,'export_exit':export.returncode,'early_leaks_exit':early,'late_leaks_exit':late,'memory_samples':memory,'diagnostic':json.loads(diagnostic.read_text()) if diagnostic.exists() else None});save()
        print('INSTRUMENT DONE',name,'record',record_code,'leaks',early,late,flush=True)
    if not any(r['name']=='power-six-wind' for r in report['instruments']): record('power-six-wind',6,'wind','Power Profiler')
assert hashlib.sha256(binary.read_bytes()).hexdigest()==digest,'Binary changed during measurement'
print('COMPLETE',report_path,flush=True)
