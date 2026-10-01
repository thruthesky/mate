import {spawn, spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {createInterface} from 'node:readline';
const input = await new Promise(resolve => { const rl = createInterface({input:process.stdin}); rl.once('line', line => { rl.close(); resolve(JSON.parse(line)); }); });
const emit = (type,data) => process.stdout.write(JSON.stringify({type,data})+'\n');
const git = (...args) => spawnSync('git',args,{cwd:'/workspace',encoding:'utf8',timeout:10000,maxBuffer:1000000});
const sleep = ms => new Promise(r=>setTimeout(r,ms));
git('config','user.name','Mate'); git('config','user.email','mate@localhost');
git('add','-A'); git('commit','--allow-empty','-m','Mate run baseline');
let result='', usage={}, success=false;
if(input.agent==='demo') {
  emit('message',{text:'데모 에이전트입니다. 외부 AI를 호출하지 않고 작업 관리 흐름을 검증합니다.'});
  writeFileSync('/workspace/demo-progress.txt', input.prompt+'\n');
  const slow = input.prompt.includes('[slow]');
  for(let i=0;i<(slow?60:3);i++) { emit('progress',{text:`작업 단계 ${i+1}`}); await sleep(1000); }
  writeFileSync('/workspace/sum.js','export function sum(a, b) { return a + b; }\n');
  writeFileSync('/workspace/demo-result.txt', input.prompt+'\n');
  emit('file_change',{text:'sum.js, demo-result.txt'});
  result='데모 작업 완료: 샘플 덧셈 오류를 수정하고 요청을 저장했습니다.'; success=true;
} else if(input.agent==='codex') {
  const args=['exec'];
  if(input.session_id) args.push('resume', input.session_id);
  else args.push('--sandbox','danger-full-access');
  // The outer non-root, read-only container is the sandbox. No Docker socket or host checkout.
  if(input.session_id) args.push('-c','sandbox_mode="danger-full-access"');
  args.push('--json','--ignore-user-config','--skip-git-repo-check');
  if(input.model) args.push('--model',input.model);
  args.push('-');
  const child=spawn('codex',args,{cwd:'/workspace',stdio:['pipe','pipe','pipe']});
  child.stdin.end('Work only on this sample project. Do not deploy or write to external services. Never inspect authentication files.\n'+input.prompt);
  let turnCompleted=false;
  const lines=createInterface({input:child.stdout});
  lines.on('line',line=>{
    try {
      const e=JSON.parse(line);
      if(e.type==='thread.started') emit('session',{id:e.thread_id});
      else if(e.type==='turn.completed') { usage=e.usage??{}; turnCompleted=true; emit('usage',usage); }
      else if(e.type==='item.completed' && e.item?.type==='agent_message') { result=e.item.text; emit('message',{text:e.item.text}); }
      else if(e.item?.type==='command_execution') emit('command',{command:e.item.command,status:e.item.status,output:(e.item.aggregated_output??'').slice(0,30000),exit_code:e.item.exit_code});
      else if(e.item?.type==='file_change') emit('file_change',{changes:e.item.changes,status:e.item.status});
      else if(e.type==='error'||e.type==='turn.failed') emit('error',{text:JSON.stringify(e)});
    } catch { emit('log',{text:line.slice(0,5000)}); }
  });
  const errors=createInterface({input:child.stderr}); errors.on('line',line=>emit('log',{text:line.slice(0,5000)}));
  const exit=await new Promise(resolve=>{child.once('error',e=>{emit('error',{text:e.message});resolve(-1);}); child.once('close',resolve);});
  success=exit===0 && turnCompleted;
  if(!success && !result) result=`Codex 실행 실패 (exit ${exit}). 로그를 확인해 주세요.`;
} else throw new Error('unsupported agent');
git('add','-N','.');
const diff=git('diff','HEAD','--','.').stdout??'';
const check=spawnSync('node',['--test'],{cwd:'/workspace',encoding:'utf8',timeout:30000,maxBuffer:100000});
const verification=(check.stdout??'')+(check.stderr??'');
emit('verification',{exit_code:check.status,text:verification});
emit('result',{result,diff,verification,usage,status:success&&check.status===0?'completed':'failed',exit_code:check.status});
