import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {existsSync, readFileSync} from 'node:fs';
type Run={id:string;task_id:string;agent:'demo'|'codex';prompt:string;session_id:string|null;container_name:string;workspace_volume:string;session_volume:string};
type Event={type:string;data:Record<string,unknown>};
type Result={status:string;result:string;diff?:string;verification?:string;usage?:unknown;exit_code?:number|null};
const wid='m1-primary';
const base=process.env.API_URL??'http://web/api';
const token=process.env.WORKER_TOKEN??'';
const concurrency=Number(process.env.MAX_CONCURRENT??2);
const timeout=Number(process.env.RUN_TIMEOUT_SECONDS??900);
if(!Number.isInteger(concurrency)||concurrency<1||concurrency>8||!Number.isFinite(timeout)||timeout<5||timeout>86400) throw Error('invalid limits');
const running=new Map<string,Promise<void>>();
let shuttingDown=false;
const delay=(ms:number)=>new Promise(r=>setTimeout(r,ms));
async function api<T=Record<string,unknown>>(path:string, body:Record<string,unknown>={}):Promise<T> {
  const r=await fetch(base+'/worker/'+path,{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({worker_id:wid,...body}),signal:AbortSignal.timeout(15000)});
  if(!r.ok) throw Error(`API ${path}: ${r.status} ${(await r.text()).slice(0,200)}`);
  return r.json() as Promise<T>;
}
async function docker(args:string[], stdin?:string):Promise<{code:number;out:string;err:string}> {
  return new Promise((resolve,reject)=>{
    const p=spawn('docker',args,{stdio:['pipe','pipe','pipe']}); let out='',err='';
    p.stdout.on('data',b=>out=(out+b).slice(-1000000)); p.stderr.on('data',b=>err=(err+b).slice(-100000));
    p.once('error',reject); p.once('close',code=>resolve({code:code??-1,out,err})); p.stdin.end(stdin);
  });
}
function names(r:Run) {
  if(!/^[a-f0-9]{32}$/.test(r.task_id)||!['demo','codex'].includes(r.agent)) throw Error('invalid task');
  if(r.container_name!=='mate-task-'+r.task_id||r.workspace_volume!=='mate-work-'+r.task_id||r.session_volume!=='mate-session-'+r.task_id) throw Error('invalid environment');
}
async function inspect(r:Run) {
  names(r); const v=await docker(['inspect',r.container_name]);
  if(v.code!==0) return null;
  const c=JSON.parse(v.out)[0];
  if(c.Config.Labels?.['mate.managed']!=='task'||c.Config.Labels?.['mate.task']!==r.task_id) throw Error('unowned container');
  return c;
}
async function stop(r:Run) { if(await inspect(r)) { const x=await docker(['stop','-t','3',r.container_name]); if(x.code) throw Error(x.err); } }
async function snapshot(r:Run):Promise<string> {
  const c=await inspect(r); if(!c) return '';
  if(!c.State.Running) {const x=await docker(['start',r.container_name]);if(x.code)throw Error(x.err);}
  const d=await docker(['exec',r.container_name,'sh','-c','git add -N . && git diff HEAD -- .']);
  return d.out;
}
async function setup(r:Run) {
  names(r);
  if(!await inspect(r)) {
    for(const v of [r.workspace_volume,r.session_volume]) {
      const check=await docker(['volume','inspect',v]);
      if(check.code===0) { const labels=JSON.parse(check.out)[0].Labels; if(labels?.['mate.task']!==r.task_id) throw Error('unowned volume'); }
      else { const x=await docker(['volume','create','--label','mate.managed=task','--label','mate.task='+r.task_id,v]); if(x.code) throw Error(x.err); }
    }
    const x=await docker(['create','--name',r.container_name,'--label','mate.managed=task','--label','mate.task='+r.task_id,'--init','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges','--pids-limit','256','--cpus',process.env.TASK_CPU??'2','--memory',process.env.TASK_MEMORY??'2g','--memory-swap',process.env.TASK_MEMORY??'2g','--tmpfs','/tmp:rw,nosuid,size=256m','--tmpfs','/home/node:rw,nosuid,uid=1000,gid=1000,size=64m','--network',r.agent==='demo'?'none':'bridge','--mount','type=volume,src='+r.workspace_volume+',dst=/workspace','--mount','type=volume,src='+r.session_volume+',dst=/session','mate-agent:0.1.0']);
    if(x.code) throw Error(x.err);
    // Fresh named volumes are root owned. Bootstrap only our two known volume paths.
    const init=await docker(['run','--rm','--network','none','--user','0','--mount','type=volume,src='+r.workspace_volume+',dst=/workspace','--mount','type=volume,src='+r.session_volume+',dst=/session','mate-agent:0.1.0','sh','-c','if [ ! -d /workspace/.git ]; then cp -R /opt/agent/sample/. /workspace/; git -C /workspace init; fi; mkdir -p /session/codex; chown -R 1000:1000 /workspace /session; chmod 700 /session/codex']);
    if(init.code) throw Error(init.err);
  }
  const c=await inspect(r);
  if(!c.State.Running) { const x=await docker(['start',r.container_name]); if(x.code) throw Error(x.err); }
  if(r.agent==='codex') {
    const auth=await docker(['exec',r.container_name,'test','-r','/session/codex/auth.json']);
    if(auth.code!==0) {
      if(!existsSync('/run/mate-secrets/codex-auth.json')) throw Error('Codex 인증 파일이 없습니다. scripts/configure.py --codex-auth로 설정해 주세요.');
      // Write through the task's own UID. Root exec cannot traverse a mode-700
      // session directory with ALL capabilities dropped. Secrets travel only on stdin.
      const authWrite=await docker(['exec','-i',r.container_name,'node','-e',"const fs=require('fs'); const p='/session/codex/auth.json'; try{fs.unlinkSync(p)}catch(e){if(e.code!=='ENOENT')throw e}; fs.writeFileSync(p,fs.readFileSync(0),{mode:0o600})"],readFileSync('/run/mate-secrets/codex-auth.json','utf8'));
      if(authWrite.code) throw Error(authWrite.err);
    }
  }
}
async function execute(r:Run) {
  let result:Result={status:'failed',result:'실행 결과를 받지 못했습니다.'};
  let pending:Event[]=[], chain=Promise.resolve(); let failure:Error|null=null;
  let flushTimer:ReturnType<typeof setInterval>|undefined;
  const flush=()=>{const batch=pending.splice(0,50); if(!batch.length) return; chain=chain.then(async()=>{
    for(let i=0;;i++) { try {await api('events',{run_id:r.id,events:batch});return;} catch(e) {if(i>=2)throw e;await delay(1000);} }
  }); chain.catch(e=>{failure=e;});};
  try {
    await setup(r);
    const p=spawn('docker',['exec','-i',r.container_name,'node','/opt/agent/run.mjs'],{stdio:['pipe','pipe','pipe']});
    p.stdin.end(JSON.stringify({agent:r.agent,prompt:r.prompt,session_id:r.session_id,model:process.env.CODEX_MODEL??''})+'\n');
    let eventCount=0;
    const lines=createInterface({input:p.stdout});
    lines.on('line',line=>{try {
      if(line.length>750000) throw Error('event too large');
      const e=JSON.parse(line) as Event;
      if(e.type==='result') {result=e.data as unknown as Result;return;}
      if(++eventCount>5000) {failure=Error('이벤트 수 제한에 도달했습니다.');return;}
      pending.push(e); if(pending.length>=50) flush();
    } catch(e) {failure=e as Error;} });
    createInterface({input:p.stderr}).on('line',line=>pending.push({type:'log',data:{text:line.slice(0,5000)}}));
    flushTimer=setInterval(flush,500);
    let exited=false;
    const closed=new Promise<number>((resolve,reject)=>{p.once('error',reject);p.once('close',code=>{exited=true;resolve(code??-1);});});
    const deadline=Date.now()+timeout*1000;
    while(!exited) {
      await delay(700);
      if(exited) break;
      const poll=await api<{cancel_requested:boolean}>('poll',{run_id:r.id});
      if(poll.cancel_requested||Date.now()>deadline||shuttingDown||failure) {
        result={status:poll.cancel_requested?'cancelled':shuttingDown?'interrupted':'failed',result:poll.cancel_requested?'사용자가 실행을 중단했습니다.':shuttingDown?'서버 종료로 중단되었습니다. 후속 요청으로 재개할 수 있습니다.':failure?String(failure):'실행 시간 제한을 초과했습니다.'};
        await stop(r); break;
      }
    }
    const code=await closed;
    if(code!==0 && result.status==='completed') result={...result,status:'failed',result:'에이전트 프로세스가 비정상 종료되었습니다.'};
    if(flushTimer) clearInterval(flushTimer);
    while(pending.length) flush(); await chain;
    if(failure) throw failure;
  } catch(e) {
    result={status:'failed',result:(e as Error).message};
    try {await stop(r);} catch(stopError) {console.error('stop failed',String(stopError));throw stopError;}
  } finally {if(flushTimer)clearInterval(flushTimer);}
  // Preserve failed/cancelled diffs, too. Do not run more project code after cancellation.
  if(!result.diff) result.diff=await snapshot(r);
  await stop(r); // A stopped container retains code and sessions, uses no CPU or memory.
  for(let i=0;;i++) {try{await api('finish',{run_id:r.id,...result});break;}catch(e){if(i>=4)throw e;await delay(1500);}}
}
async function heartbeat() {
  const info=await docker(['info','--format','{{json .}}']); if(info.code) throw Error(info.err);
  const d=JSON.parse(info.out);
  await api('heartbeat',{info:{name:'M1 Mac · Docker ARM64',architecture:d.Architecture,cpus:d.NCPU,memory_bytes:d.MemTotal,docker:d.ServerVersion,max_concurrent:concurrency,run_timeout_seconds:timeout,task_cpu:process.env.TASK_CPU??'2',task_memory:process.env.TASK_MEMORY??'2g',codex_auth:existsSync('/run/mate-secrets/codex-auth.json'),active:running.size}});
}
process.on('SIGTERM',()=>{shuttingDown=true;});process.on('SIGINT',()=>{shuttingDown=true;});
async function main() {
  for(;;) {try{await heartbeat();break;}catch(e){console.error(String(e));await delay(3000);}}
  const recovery=await api<{runs:Run[]}>('recovery');
  for(const r of recovery.runs) {
    await stop(r);
    const diff=await snapshot(r); await stop(r);
    await api('finish',{run_id:r.id,status:'interrupted',diff,result:'실행 관리자 재시작을 감지했습니다. 기존 명령을 종료했으며 자동 재실행하지 않습니다. 후속 요청으로 저장된 코드·세션에서 이어갈 수 있습니다.'});
  }
  let lastBeat=0;
  while(!shuttingDown) {
    try {
      if(Date.now()-lastBeat>4000){await heartbeat();lastBeat=Date.now();}
      if(running.size<concurrency) {
        const {run}=await api<{run:Run|null}>('claim');
        if(run){ const p=execute(run).catch(e=>{console.error('Run failed',run.id,String(e));shuttingDown=true;}).finally(()=>running.delete(run.id));running.set(run.id,p);continue; }
      }
    }catch(e){console.error(String(e));}
    await delay(1000);
  }
  await Promise.allSettled(running.values());
}
await main();
