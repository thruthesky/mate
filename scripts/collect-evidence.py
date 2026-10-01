#!/usr/bin/env python3
"""Collect bounded installed-instance test evidence, excluding credentials."""
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
from urllib.request import Request, urlopen

root=Path(__file__).resolve().parents[1]
env=dict(line.split('=',1) for line in (root/'.env').read_text().splitlines() if line and not line.startswith('#') and '=' in line)
def api(path):
    with urlopen(Request('http://127.0.0.1:'+env.get('MATE_PORT','8787')+'/api'+path,headers={'Authorization':'Bearer '+env['MATE_TOKEN']}),timeout=20) as r:
        return json.load(r)
reports=[json.loads((root/'reports'/('smoke-'+m+'.json')).read_text()) for m in ['demo','recovery','codex']]
status=api('/status')
data={'captured_at':datetime.now(timezone.utc).isoformat(),'workers':status['workers'],'checks_passed':sum(len(r['checks']) for r in reports),'tasks':[]}
for report in reports:
    for task_id in report['task_ids']:
        d=api('/tasks/'+task_id)
        data['tasks'].append({'mode':report['mode'],'task':d['task'],'environment':d['environment'],'runs':d['runs']})
data['services']=subprocess.check_output(['docker','compose','ps','--format','json'],cwd=root,text=True)
data['resources']=subprocess.check_output(['docker','stats','--no-stream','--format','{{.Name}} {{.CPUPerc}} {{.MemUsage}}'],cwd=root,text=True)
data['agent_image']=subprocess.check_output(['docker','image','inspect','mate-agent:0.1.0','--format','{{.Architecture}} {{.Id}}'],text=True).strip()
out=root/'reports'/'m1-evidence.json'
out.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
print('검증 근거 저장:',out,'항목:',data['checks_passed'])
