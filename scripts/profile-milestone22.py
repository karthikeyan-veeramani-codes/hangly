#!/usr/bin/env python3
"""Exact-binary, isolated 60–180s comparisons. No global settings or user data changes."""
import argparse,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent.parent
p=argparse.ArgumentParser();p.add_argument('--label',required=True);p.add_argument('--binary',default='dist/Release/Tether.app/Contents/MacOS/Tether');p.add_argument('--suite',choices=['process','time','allocations','endurance'],default='process');p.add_argument('--seconds',type=int,default=60);a=p.parse_args()
if not 60<=a.seconds<=180:raise SystemExit('Use 60–180 seconds')
binary=(root/a.binary).resolve();out=root/'.build/m22-performance'/a.label;out.mkdir(parents=True,exist_ok=True)
digest=hashlib.sha256(binary.read_bytes()).hexdigest();path=out/'results.json'
report=json.loads(path.read_text()) if path.exists() else {'binary_sha256':digest,'process':[],'instruments':[]}
if report['binary_sha256']!=digest:raise SystemExit('Checkpoint hash differs')
def save():path.write_text(json.dumps(report,indent=2)+'\n')
def launch(name,count,mode,seconds,stack=False):
 diag=out/(name+'-diagnostic.json');log=open(out/(name+'-app.log'),'w');env=os.environ.copy()
 if stack:env['MallocStackLogging']='1'
 cmd=[str(binary),'--profile-test','--profile-count',str(count),'--profile-'+mode,'--profile-warmup','10','--profile-seconds',str(seconds),'--diagnostics-json',str(diag)]
 return subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=env),diag,log
def sample(pid):
 v=subprocess.check_output(['ps','-p',str(pid),'-o','time=,rss='],text=True).split();return {'time':time.monotonic(),'cpu_seconds':sum(float(x)*60**i for i,x in enumerate(reversed(v[0].split(':')))),'rss_kib':int(v[1])}
def finish(proc,diag,log):
 try:code=proc.wait(timeout=35)
 except subprocess.TimeoutExpired:proc.terminate();proc.wait(timeout=5);raise
 finally:log.close()
 if code:raise RuntimeError('App exit '+str(code))
 return json.loads(diag.read_text())
if a.suite=='process':
 for count,mode in [(6,'wind'),(3,'idle'),(1,'paused'),(1,'hidden'),(6,'wind')]:
  name=f'{len(report["process"])+1:02d}-{count}-{mode}';print('START',name,flush=True)
  proc,diag,log=launch(name,count,mode,a.seconds+18)
  try:
   time.sleep(10);samples=[]
   for i in range(a.seconds+1):
    samples.append(sample(proc.pid))
    if i%20==0:print('PROGRESS',name,i,flush=True)
    if i<a.seconds:time.sleep(1)
   data=finish(proc,diag,log)
  finally:
   if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
  elapsed=samples[-1]['time']-samples[0]['time'];row={'name':name,'count':count,'mode':mode,'measured_seconds':elapsed,'cpu_percent_one_core':100*(samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'])/elapsed,'rss_kib_min':min(s['rss_kib'] for s in samples),'rss_kib_max':max(s['rss_kib'] for s in samples),'samples':samples,'diagnostic':data};report['process'].append(row);save();print('DONE',name,row['cpu_percent_one_core'],flush=True)
else:
 mode='endurance' if a.suite in ['endurance','allocations'] else 'wind';name=a.suite
 free=shutil.disk_usage(root).free;print('FREE',free,flush=True)
 if a.suite=='allocations' and free<8*1024**3:
  report['instruments'].append({'name':name,'status':'BLOCKED','free_bytes':free,'reason':'8 GiB minimum reserve not available; prior capture exhausted volume'});save();raise SystemExit(0)
 proc,diag,log=launch(name,6,mode,max(165,a.seconds+30),a.suite in ['endurance','allocations']);time.sleep(10);memory=[]
 def leaks(label):
  with open(out/(name+'-leaks-'+label+'.log'),'w') as f:return subprocess.run(['leaks','--noContent',str(proc.pid)],stdout=f,stderr=subprocess.STDOUT).returncode
 row={'name':name,'free_bytes_start':free}
 if a.suite in ['endurance','allocations']:row['early_leaks_exit']=leaks('early')
 recorder=None
 if a.suite in ['time','allocations']:
  stream=open(out/(name+'-record.log'),'w');trace=out/(name+'.trace');recorder=subprocess.Popen(['xcrun','xctrace','record','--template','Time Profiler' if a.suite=='time' else 'Allocations','--time-limit',str(a.seconds)+'s','--output',str(trace),'--attach',str(proc.pid)],stdout=stream,stderr=subprocess.STDOUT)
 deadline=time.monotonic()+a.seconds
 try:
  while time.monotonic()<deadline:
   memory.append(sample(proc.pid));print('SAMPLE',len(memory),memory[-1]['rss_kib'],flush=True)
   if recorder and shutil.disk_usage(root).free<3*1024**3:recorder.terminate();row['storage_cutoff']=True;break
   time.sleep(5)
  if recorder:
   row['record_exit']=recorder.wait(timeout=25);stream.close()
   exp=subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(out/(name+'-toc.xml'))],capture_output=True,text=True);row['export_exit']=exp.returncode;row['export_message']=exp.stdout+exp.stderr
   if a.suite=='time' and exp.returncode==0:subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--xpath','/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]','--output',str(out/(name+'-samples.xml'))],check=True)
  if a.suite in ['endurance','allocations']:row['late_leaks_exit']=leaks('late')
  # Continue sampling until shortly before the automatic exit for retained-memory trends.
  while proc.poll() is None:
   try:memory.append(sample(proc.pid))
   except subprocess.CalledProcessError:break
   time.sleep(5)
  row['diagnostic']=finish(proc,diag,log);row['memory_samples']=memory;report['instruments'].append(row);save()
 finally:
  if recorder and recorder.poll() is None:recorder.terminate();recorder.wait(timeout=10)
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
assert hashlib.sha256(binary.read_bytes()).hexdigest()==digest
print('COMPLETE',path,flush=True)
