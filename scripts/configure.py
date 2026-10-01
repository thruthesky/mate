#!/usr/bin/env python3
"""Configure a private, single-user Mate instance; never print credentials."""
import argparse
import os
from pathlib import Path
import secrets
import shutil

p = argparse.ArgumentParser()
p.add_argument('--codex-auth', action='store_true')
p.add_argument('--host', default='M1-MacBook-16.local')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
os.umask(0o077)
env = root / '.env'
if not env.exists():
    text = (root / '.env.example').read_text()
    for key in ['MATE_TOKEN', 'WORKER_TOKEN', 'DB_PASSWORD', 'DB_ROOT_PASSWORD']:
        lines = text.splitlines()
        text = '\n'.join(key+'='+secrets.token_hex(32) if line.startswith(key+'=') else line for line in lines)+'\n'
    env.write_text(text)
env.chmod(0o600)
private = root / '.secrets'
private.mkdir(mode=0o700, exist_ok=True)
if a.codex_auth:
    source = Path.home() / '.codex' / 'auth.json'
    if not source.is_file():
        raise SystemExit('Codex 로그인 파일이 없습니다. 먼저 codex login을 실행하세요.')
    shutil.copyfile(source, private / 'codex-auth.json')
    (private / 'codex-auth.json').chmod(0o600)
values = dict(line.split('=', 1) for line in env.read_text().splitlines() if line and not line.startswith('#') and '=' in line)
port = values.get('MATE_PORT', '8787')
(private / 'access.txt').write_text('Mate 개인 접속 주소 (이 파일을 공유하지 마세요)\nhttp://'+a.host+':'+port+'/#token='+values['MATE_TOKEN']+'\n')
print('설정 완료. 개인 접속 주소: .secrets/access.txt (키는 출력하지 않았습니다).')
