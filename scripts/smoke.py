#!/usr/bin/env python3
"""Real API + Docker smoke tests. Run on the installed M1, never prints auth."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--codex', action='store_true')
parser.add_argument('--recovery', action='store_true')
args = parser.parse_args()
env = dict(line.split('=', 1) for line in (root / '.env').read_text().splitlines() if line and not line.startswith('#') and '=' in line)
base = 'http://127.0.0.1:'+env.get('MATE_PORT', '8787')+'/api'
checks = []
task_ids = []
def check(name, condition=True):
    if not condition:
        raise AssertionError(name)
    checks.append(name)
    print('PASS', name, flush=True)
def api(path, body=None, token=None, expect=200):
    request = Request(base+path, data=None if body is None else json.dumps(body).encode(), headers={'Authorization': 'Bearer '+(env['MATE_TOKEN'] if token is None else token), 'Content-Type':'application/json'})
    try:
        with urlopen(request, timeout=20) as response:
            status, data = response.status, json.load(response)
    except HTTPError as e:
        status, data = e.code, json.load(e)
    if status != expect:
        raise AssertionError(f'{path}: expected {expect}, got {status}: {data}')
    return data
def create(name, prompt, agent='demo', approve=False):
    r = api('/tasks', {'project_id':'00000000000000000000000000000001', 'title':name, 'prompt':prompt, 'agent':agent, 'require_approval':approve}, expect=201)
    task_ids.append(r['task_id'])
    return r['task_id']
def detail(t):
    return api('/tasks/'+t)
def wait(t, statuses=('completed',), seconds=90):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        d=detail(t)
        if d['task']['status'] in statuses: return d
        if d['task']['status'] in ['failed','cancelled','interrupted'] and d['task']['status'] not in statuses:
            raise AssertionError('Unexpected terminal status: '+json.dumps(d['runs'][-1],ensure_ascii=False)[:3000])
        time.sleep(1)
    raise AssertionError('Timeout task '+t+' status '+json.dumps(detail(t),ensure_ascii=False)[:2500])
def approve(t):
    d=detail(t); a=d['approvals'][-1]
    api('/approvals/'+a['id'], {'approve':True})
    return a['id']
def docker(*cmd):
    return subprocess.check_output(['docker',*cmd], text=True, cwd=root)
def isolation(t):
    e=detail(t)['environment']
    c=json.loads(docker('inspect',e['container_name']))[0]
    host=c['HostConfig']
    check('non-root/read-only/capabilities/PID/CPU/memory limits', c['Config']['User']=='1000:1000' and host['ReadonlyRootfs'] and host['PidsLimit']==256 and host['NanoCpus']==2000000000 and host['Memory']==2147483648 and not host['Privileged'] and host['CapDrop']==['ALL'] and 'no-new-privileges' in host['SecurityOpt'])
    mounts=c['Mounts']
    check('only workspace/session volumes; no Docker socket', len(mounts)==2 and {m['Destination'] for m in mounts}=={'/workspace','/session'} and all(m['Type']=='volume' for m in mounts))
    check('finished task container stopped', not c['State']['Running'])
    return c

api('/status', token='', expect=401)
api('/status', token=env['WORKER_TOKEN'], expect=401)
api('/worker/heartbeat', {'worker_id':'bad'}, expect=401)
check('unauthenticated access and cross-role tokens rejected')
api('/tasks', {'project_id':'00000000000000000000000000000001','title':'invalid','prompt':'x','agent':'sh'}, expect=400)
check('agent allowlist enforced')
status=api('/status')
check('worker online', any(str(w['online'])=='1' for w in status['workers']))

if args.codex:
    t=create('검증 · 실제 Codex 덧셈 수정', 'sum.js의 sum(2,3)이 5가 되도록 버그를 수정하세요. 기존 테스트를 변경하거나 삭제하지 말고 node --test를 실행해 주세요.', 'codex')
    check('Codex waits for approval', detail(t)['task']['status']=='awaiting_approval')
    approve(t)
    d=wait(t, seconds=240)
    r=d['runs'][-1]
    session=d['task']['session_id']
    check('real Codex session and token usage recorded', bool(session) and json.loads(r['usage_json']).get('input_tokens',0)>0)
    check('real Codex fixes code; actual tests pass', '+export function sum' in r['diff'] and 'fail 0' in r['verification'] and r['exit_code']==0)
    first_env=d['environment']
    api('/tasks/'+t+'/turns', {'prompt':'기존 sum 수정은 유지하세요. multiply.js에 export function multiply(a,b)를 추가하고 multiply.test.js에 3*4=12 및 -2*3=-6 테스트를 작성하고 node --test를 실행해 주세요.'}, expect=201)
    approve(t)
    d=wait(t, seconds=240)
    check('Codex resumes exact session and workspace', d['task']['session_id']==session and d['environment']==first_env and len(d['runs'])==2)
    check('follow-up changes and real verification recorded', 'multiply.js' in d['runs'][-1]['diff'] and 'fail 0' in d['runs'][-1]['verification'])
    isolation(t)
elif args.recovery:
    t=create('검증 · 워커 강제 재시작 복구', '[slow] interrupted smoke')
    wait(t, ('running',))
    time.sleep(3)
    subprocess.run(['docker','compose','kill','-s','SIGKILL','worker'],cwd=root,check=True,stdout=subprocess.DEVNULL)
    subprocess.run(['docker','compose','up','-d','worker'],cwd=root,check=True,stdout=subprocess.DEVNULL)
    d=wait(t, ('interrupted',),seconds=90)
    check('worker restart marks interrupted without replay', d['runs'][-1]['status']=='interrupted')
    check('interrupted code changes preserved as diff', 'demo-progress.txt' in d['runs'][-1]['diff'] and '[slow] interrupted smoke' in d['runs'][-1]['diff'])
    isolation(t)
    e=d['environment']
    api('/tasks/'+t+'/turns', {'prompt':'복구 후 저장된 작업으로 재개'},expect=201)
    d=wait(t)
    check('explicit resume retains workspace/session', d['environment']==e and len(d['runs'])==2)
else:
    t=create('검증 · 승인 후 데모 실행','데모 승인과 이벤트 보존 검증',approve=True)
    check('approval stored before execution',detail(t)['task']['status']=='awaiting_approval')
    a=approve(t)
    api('/approvals/'+a, {'approve':True},expect=409)
    check('duplicate approval rejected')
    d=wait(t)
    r=d['runs'][-1]
    check('actual file diff and node test output persisted', 'sum.js' in r['diff'] and 'demo-result.txt' in r['diff'] and 'fail 0' in r['verification'])
    c=isolation(t)
    first=api('/tasks/'+t+'/events?after=0')
    check('new connection replays persistent events',len(first['events'])>=6)
    tail=api('/tasks/'+t+'/events?after='+str(first['next_cursor']))
    check('cursor replay returns no duplicates', not tail['events'])
    old_env=d['environment']
    api('/tasks/'+t+'/turns', {'prompt':'같은 작업 후속 요청'},expect=201)
    d=wait(t)
    check('follow-up reuses environment and creates new run', d['environment']==old_env and len(d['runs'])==2 and '같은 작업 후속 요청' in d['runs'][-1]['diff'])
    rejected=create('검증 · 승인 거절','never run',approve=True)
    a=detail(rejected)['approvals'][0]['id']
    api('/approvals/'+a, {'approve':False})
    check('rejection cancels without executing',detail(rejected)['task']['status']=='cancelled')
    t2=create('검증 · 중단','[slow] cancellation')
    wait(t2,('running',))
    api('/tasks/'+t2+'/turns',{'prompt':'invalid concurrent turn'},expect=409)
    check('concurrent turns on same task blocked')
    time.sleep(2)
    start=time.monotonic()
    api('/tasks/'+t2+'/cancel',{})
    d=wait(t2,('cancelled',),seconds=15)
    check('cancel terminates container promptly',time.monotonic()-start<10)
    check('cancel preserves changes already made', 'demo-progress.txt' in d['runs'][-1]['diff'])
    isolation(t2)
    # Three independent slow tasks exercise a two-slot queue.
    with ThreadPoolExecutor(max_workers=3) as pool:
        queued=list(pool.map(lambda i:create('검증 · 동시 실행 '+str(i),'[slow] concurrency '+str(i)),range(3)))
    time.sleep(5)
    states=[detail(q)['task']['status'] for q in queued]
    check('two running tasks and third queued', states.count('running')==2 and states.count('queued')==1)
    check('independent tasks have distinct workspaces',len({detail(q)['environment']['workspace_volume'] for q in queued})==3)
    for q in queued: api('/tasks/'+q+'/cancel',{})
    for q in queued: wait(q,('cancelled',),seconds=20)

report={'timestamp':datetime.now(timezone.utc).isoformat(),'mode':'codex' if args.codex else 'recovery' if args.recovery else 'demo','checks':checks,'task_ids':task_ids}
(root/'reports').mkdir(exist_ok=True)
(root/'reports'/('smoke-'+report['mode']+'.json')).write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('ALL PASS',len(checks), 'checks', flush=True)
