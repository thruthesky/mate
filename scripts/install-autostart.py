#!/usr/bin/env python3
"""Install only Mate's own per-user LaunchAgent. No root or system services."""
from pathlib import Path
import plistlib
import subprocess
import os

root = Path(__file__).resolve().parents[1]
agents = Path.home() / 'Library' / 'LaunchAgents'
agents.mkdir(parents=True, exist_ok=True)
logs = root / 'logs'
logs.mkdir(exist_ok=True)
label = 'com.mate.personal-server'
dest = agents / (label+'.plist')
dest.write_bytes(plistlib.dumps({
    'Label':label,
    'ProgramArguments':['/bin/bash',str(root/'scripts'/'start-macos.sh')],
    'RunAtLoad':True,
    'StandardOutPath':str(logs/'startup.log'),
    'StandardErrorPath':str(logs/'startup-error.log'),
}))
dest.chmod(0o600)
domain = 'gui/'+str(os.getuid())
subprocess.run(['launchctl','bootout',domain+'/'+label],capture_output=True)
subprocess.run(['launchctl','bootstrap',domain,str(dest)],check=True)
print('Mate 로그인 시 자동 시작 등록 완료:', dest)
