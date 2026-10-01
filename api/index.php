<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
function out(mixed $value, int $code = 200): never { http_response_code($code); echo json_encode($value, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE); exit; }
function fail(string $message, int $code = 400): never { out(['error' => $message], $code); }
function input(): array {
    $raw = file_get_contents('php://input');
    if (strlen($raw) > 2000000) fail('요청이 너무 큽니다.', 413);
    $v = json_decode($raw ?: '{}', true, 64, JSON_THROW_ON_ERROR);
    if (!is_array($v) || array_is_list($v) && $v !== []) fail('JSON 객체가 필요합니다.');
    return $v;
}
function str(array $b, string $key, int $max = 12000): string {
    $v = $b[$key] ?? null;
    if (!is_string($v) || trim($v) === '' || strlen($v) > $max) fail("잘못된 {$key}");
    return trim($v);
}
function uid(): string { return bin2hex(random_bytes(16)); }
function query(string $sql, array $params = []): PDOStatement { global $db; $s = $db->prepare($sql); $s->execute($params); return $s; }
function event(string $task, string $run, string $type, array $data): void {
    query('INSERT INTO events(task_id,run_id,type,data_json) VALUES(?,?,?,?)', [$task,$run,$type,json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE)]);
}
function task(string $id, bool $lock = false): array {
    $t = query('SELECT * FROM tasks WHERE id=?' . ($lock ? ' FOR UPDATE' : ''), [$id])->fetch();
    if (!$t) fail('작업을 찾을 수 없습니다.',404);
    return $t;
}
function newRun(array $t, string $prompt, bool $approve): string {
    $id = uid(); $status = $approve ? 'awaiting_approval' : 'queued';
    query('INSERT INTO runs(id,task_id,prompt,status) VALUES(?,?,?,?)', [$id,$t['id'],$prompt,$status]);
    query('UPDATE tasks SET status=?,updated_at=NOW(3) WHERE id=?', [$status,$t['id']]);
    event($t['id'],$id,'user_message',['text'=>$prompt]);
    if ($approve) {
        query('INSERT INTO approvals(id,run_id,reason) VALUES(?,?,?)', [uid(),$id,'격리된 작업 폴더에서 명령 실행·파일 수정·외부 AI 접속을 허용합니다. 배포와 외부 서비스 쓰기는 허용하지 않습니다.']);
        event($t['id'],$id,'approval_requested',['text'=>'실행 승인을 기다립니다.']);
    }
    return $id;
}
try {
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $method = $_SERVER['REQUEST_METHOD'];
    if ($path === '/api/health' && $method === 'GET') out(['service'=>'mate','version'=>'0.1.0']);
    $worker = str_starts_with($path, '/api/worker/');
    $token = getenv($worker ? 'WORKER_TOKEN' : 'MATE_TOKEN') ?: '';
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (strlen($token) < 24 || !hash_equals('Bearer '.$token,$auth)) fail('로그인이 필요합니다.',401);
    $db = new PDO('mysql:host=db;dbname=mate;charset=utf8mb4','mate',getenv('DB_PASSWORD'),[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);
    if ($path === '/api/status' && $method === 'GET') {
        $workers = query('SELECT *, heartbeat_at > NOW() - INTERVAL 15 SECOND AS online FROM workers')->fetchAll();
        foreach ($workers as &$w) { $w['info'] = json_decode($w['info_json'],true); unset($w['info_json']); }
        out(['workers'=>$workers,'projects'=>query('SELECT * FROM projects')->fetchAll(),'tasks'=>query('SELECT * FROM tasks ORDER BY updated_at DESC LIMIT 100')->fetchAll()]);
    }
    if ($path === '/api/tasks' && $method === 'POST') {
        $b=input(); $agent=$b['agent'] ?? 'demo'; if (!in_array($agent,['demo','codex'],true)) fail('지원하지 않는 에이전트');
        $project=str($b,'project_id',32); if (!query('SELECT id FROM projects WHERE id=?',[$project])->fetch()) fail('프로젝트 없음');
        $title=str($b,'title',200); $prompt=str($b,'prompt'); $id=uid();
        $db->beginTransaction();
        query('INSERT INTO tasks(id,project_id,title,agent,status) VALUES(?,?,?,?,?)',[$id,$project,$title,$agent,'queued']);
        query('INSERT INTO environments VALUES(?,?,?,?)',[$id,'mate-task-'.$id,'mate-work-'.$id,'mate-session-'.$id]);
        $rid=newRun(['id'=>$id],$prompt,$agent==='codex'||($b['require_approval']??false)===true);
        $db->commit(); out(['task_id'=>$id,'run_id'=>$rid],201);
    }
    if (preg_match('~^/api/tasks/([a-f0-9]{32})(?:/(turns|cancel|events))?$~',$path,$m)) {
        $id=$m[1]; $action=$m[2]??'';
        if ($method==='GET' && $action==='') {
            out(['task'=>task($id),'environment'=>query('SELECT * FROM environments WHERE task_id=?',[$id])->fetch(),
                'runs'=>query('SELECT * FROM runs WHERE task_id=? ORDER BY created_at',[$id])->fetchAll(),
                'approvals'=>query('SELECT a.* FROM approvals a JOIN runs r ON a.run_id=r.id WHERE r.task_id=? ORDER BY r.created_at',[$id])->fetchAll()]);
        }
        if ($method==='GET' && $action==='events') {
            task($id); $after=$_GET['after']??'0'; if (!ctype_digit((string)$after)) fail('잘못된 cursor');
            $rows=query('SELECT * FROM events WHERE task_id=? AND id>? ORDER BY id LIMIT 200',[$id,$after])->fetchAll();
            foreach($rows as &$e) { $e['data']=json_decode($e['data_json'],true); unset($e['data_json']); }
            out(['events'=>$rows,'next_cursor'=>$rows ? end($rows)['id'] : (int)$after]);
        }
        if ($method==='POST' && $action==='turns') {
            $b=input(); $prompt=str($b,'prompt'); $db->beginTransaction(); $t=task($id,true);
            if (in_array($t['status'],['queued','running','awaiting_approval','cancelling'],true)) fail('현재 실행을 마치거나 중단한 뒤 요청해 주세요.',409);
            $rid=newRun($t,$prompt,$t['agent']==='codex'||($b['require_approval']??false)===true);
            $db->commit(); out(['run_id'=>$rid],201);
        }
        if ($method==='POST' && $action==='cancel') {
            $db->beginTransaction(); $t=task($id,true);
            $r=query("SELECT * FROM runs WHERE task_id=? AND status IN ('queued','awaiting_approval','running') ORDER BY created_at DESC LIMIT 1 FOR UPDATE",[$id])->fetch();
            if ($r) {
                $status=$r['status']==='running'?'cancelling':'cancelled';
                query("UPDATE runs SET cancel_requested=1,status=?,finished_at=IF(?='cancelled',NOW(3),NULL) WHERE id=?",[$status==='cancelling'?'running':$status,$status,$r['id']]);
                query("UPDATE approvals SET status='rejected',decided_at=NOW(3) WHERE run_id=? AND status='pending'",[$r['id']]);
                query('UPDATE tasks SET status=?,updated_at=NOW(3) WHERE id=?',[$status,$id]);
                event($id,$r['id'],'cancel_requested',['text'=>'중단 요청을 저장했습니다.']);
            }
            $db->commit(); out(['ok'=>true]);
        }
    }
    if (preg_match('~^/api/approvals/([a-f0-9]{32})$~',$path,$m) && $method==='POST') {
        $b=input(); if (!isset($b['approve']) || !is_bool($b['approve'])) fail('approve boolean 필요');
        $db->beginTransaction();
        // Keep lock order tasks -> runs -> approval, same as cancel/claim.
        $a=query('SELECT a.*,r.task_id FROM approvals a JOIN runs r ON r.id=a.run_id WHERE a.id=?',[$m[1]])->fetch();
        if (!$a) fail('승인 요청 없음',404); task($a['task_id'],true);
        $r=query('SELECT * FROM runs WHERE id=? FOR UPDATE',[$a['run_id']])->fetch();
        $a=query('SELECT * FROM approvals WHERE id=? FOR UPDATE',[$m[1]])->fetch();
        if ($a['status']!=='pending'||$r['status']!=='awaiting_approval') fail('이미 처리한 요청입니다.',409);
        $status=$b['approve']?'queued':'cancelled';
        query('UPDATE approvals SET status=?,decided_at=NOW(3) WHERE id=?',[$b['approve']?'approved':'rejected',$m[1]]);
        query("UPDATE runs SET status=?,finished_at=IF(?='cancelled',NOW(3),NULL) WHERE id=?",[$status,$status,$a['run_id']]);
        query('UPDATE tasks SET status=?,updated_at=NOW(3) WHERE id=?',[$status,$r['task_id']]);
        event($r['task_id'],$r['id'],'approval_decided',['approved'=>$b['approve']]);
        $db->commit(); out(['ok'=>true]);
    }
    if ($worker && $method==='POST') {
        $b=input(); $wid=str($b,'worker_id',80);
        if ($path==='/api/worker/heartbeat') {
            query('INSERT INTO workers(id,info_json) VALUES(?,?) ON DUPLICATE KEY UPDATE info_json=VALUES(info_json),heartbeat_at=NOW(3)',[$wid,json_encode($b['info']??[])]);
            out(['ok'=>true]);
        }
        if ($path==='/api/worker/recovery') out(['runs'=>query("SELECT r.*,t.session_id,t.agent,e.* FROM runs r JOIN tasks t ON t.id=r.task_id JOIN environments e ON e.task_id=t.id WHERE r.worker_id=? AND r.status='running'",[$wid])->fetchAll()]);
        if ($path==='/api/worker/claim') {
            $db->beginTransaction();
            $t=query("SELECT t.* FROM tasks t WHERE t.status='queued' ORDER BY t.updated_at LIMIT 1 FOR UPDATE SKIP LOCKED")->fetch();
            if (!$t) { $db->commit(); out(['run'=>null]); }
            $r=query("SELECT * FROM runs WHERE task_id=? AND status='queued' ORDER BY created_at LIMIT 1 FOR UPDATE",[$t['id']])->fetch();
            if (!$r) throw new RuntimeException('queue inconsistency');
            query("UPDATE runs SET status='running',worker_id=?,started_at=NOW(3) WHERE id=?",[$wid,$r['id']]);
            query("UPDATE tasks SET status='running',updated_at=NOW(3) WHERE id=?",[$t['id']]);
            event($t['id'],$r['id'],'started',['text'=>'실행 관리자가 작업을 받았습니다.']);
            $env=query('SELECT * FROM environments WHERE task_id=?',[$t['id']])->fetch();
            $db->commit(); out(['run'=>array_merge($r,$env,['id'=>$r['id'],'agent'=>$t['agent'],'session_id'=>$t['session_id']])]);
        }
        $rid=str($b,'run_id',32);
        $r=query('SELECT * FROM runs WHERE id=? AND worker_id=?',[$rid,$wid])->fetch();
        if (!$r) fail('실행 권한 없음',403);
        if ($path==='/api/worker/poll') out(['cancel_requested'=>(bool)$r['cancel_requested']]);
        if ($r['status']!=='running') fail('종료된 실행입니다.',409);
        if ($path==='/api/worker/events') {
            $ev=$b['events']??[]; if (!is_array($ev)||count($ev)>100) fail('잘못된 events');
            $db->beginTransaction();
            foreach($ev as $e) {
                $type=str($e,'type',50); $data=$e['data']??[]; if (!is_array($data)) fail('data 객체 필요');
                event($r['task_id'],$rid,$type,$data);
                if ($type==='session' && isset($data['id']) && is_string($data['id']) && preg_match('/^[a-f0-9-]{36}$/',$data['id'])) query('UPDATE tasks SET session_id=? WHERE id=?',[$data['id'],$r['task_id']]);
            }
            $db->commit(); out(['ok'=>true]);
        }
        if ($path==='/api/worker/finish') {
            $status=$b['status']??''; if (!in_array($status,['completed','failed','cancelled','interrupted'],true)) fail('잘못된 완료 상태');
            $db->beginTransaction(); task($r['task_id'],true);
            $r=query('SELECT * FROM runs WHERE id=? FOR UPDATE',[$rid])->fetch();
            if ($r['status']!=='running') fail('이미 종료됨',409);
            if ($r['cancel_requested']) $status='cancelled';
            query('UPDATE runs SET status=?,result=?,diff=?,verification=?,usage_json=?,exit_code=?,finished_at=NOW(3) WHERE id=?',[$status,substr((string)($b['result']??''),0,500000),substr((string)($b['diff']??''),0,500000),substr((string)($b['verification']??''),0,100000),json_encode($b['usage']??[]),$b['exit_code']??null,$rid]);
            query('UPDATE tasks SET status=?,updated_at=NOW(3) WHERE id=?',[$status,$r['task_id']]);
            event($r['task_id'],$rid,$status,['text'=>$b['result']??$status]);
            $db->commit(); out(['ok'=>true]);
        }
    }
    fail('경로를 찾을 수 없습니다.',404);
} catch (JsonException $e) { fail('잘못된 JSON'); }
catch (Throwable $e) {
    if (isset($db) && $db->inTransaction()) $db->rollBack();
    error_log($e->getMessage()); fail('서버 처리 중 오류가 발생했습니다.',500);
}
