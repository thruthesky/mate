import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MateApp());
const bg = Color(0xff0d111b);
const panel = Color(0xff171d2a);
const accent = Color(0xff9cf2c5);
const muted = Color(0xff9aa6bc);
const labels = {
  'queued': '대기 중',
  'running': '실행 중',
  'awaiting_approval': '승인 대기',
  'cancelling': '중단 처리 중',
  'cancelled': '중단됨',
  'completed': '완료',
  'failed': '실패',
  'interrupted': '복구 대기',
};
const active = ['queued', 'running', 'awaiting_approval', 'cancelling'];

class MateApp extends StatelessWidget {
  const MateApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mate · AI 작업 관리자',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: panel,
      ),
      cardTheme: const CardThemeData(color: panel, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    home: const Console(),
  );
}

class Console extends StatefulWidget {
  const Console({super.key});
  @override
  State<Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<Console> {
  final tokenInput = TextEditingController();
  final prompt = TextEditingController();
  String token = '', selected = '', cursor = '0', error = '';
  Map<String, dynamic> status = {}, detail = {};
  final List<Map<String, dynamic>> events = [];
  Timer? timer;
  bool polling = false, busy = false;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    final fragment = Uri.splitQueryString(Uri.base.fragment);
    if (fragment['token'] case final String value) {
      token = value;
    }
    timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    if (token.isNotEmpty) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    tokenInput.dispose();
    prompt.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> api(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final url = Uri.base.resolve('/api$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final response =
        await (body == null
                ? http.get(url, headers: headers)
                : http.post(url, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 20));
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) throw Exception(data['error'] ?? '요청 실패');
    return data;
  }

  Future<void> refresh() async {
    if (token.isEmpty || polling || !mounted) return;
    polling = true;
    try {
      final s = await api('/status');
      final id = selected;
      Map<String, dynamic>? d;
      List<Map<String, dynamic>> ev = [];
      String next = cursor;
      if (id.isNotEmpty) {
        d = await api('/tasks/$id');
        final e = await api('/tasks/$id/events?after=$next');
        ev = (e['events'] as List).cast<Map<String, dynamic>>();
        next = '${e['next_cursor']}';
      }
      if (!mounted) return;
      setState(() {
        status = s;
        error = '';
        if (selected == id && d != null) {
          detail = d;
          events.addAll(ev);
          cursor = next;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      polling = false;
    }
  }

  Future<void> act(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void choose(String id) {
    setState(() {
      selected = id;
      detail = {};
      events.clear();
      cursor = '0';
      tab = 0;
    });
    refresh();
  }

  Future<void> createTask() async {
    final title = TextEditingController();
    final text = TextEditingController(
      text: 'sum.js의 덧셈 오류를 고치고 node --test로 확인해 주세요.',
    );
    String agent = 'codex';
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('새 작업 맡기기'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '샘플 · Node 테스트 프로젝트',
                    style: TextStyle(color: accent),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: title,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '작업 이름',
                      hintText: '예: 덧셈 오류 수정',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: agent,
                    decoration: const InputDecoration(labelText: '에이전트'),
                    items: const [
                      DropdownMenuItem(
                        value: 'codex',
                        child: Text('Codex · 실제 AI'),
                      ),
                      DropdownMenuItem(
                        value: 'demo',
                        child: Text('데모 · 외부 AI 호출 없음'),
                      ),
                    ],
                    onChanged: submitting
                        ? null
                        : (v) => update(() => agent = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: text,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 4000,
                    decoration: const InputDecoration(labelText: '요청 내용'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '작업마다 별도 코드 폴더와 컨테이너를 만듭니다. Codex는 실행 전 승인을 기다립니다.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          text.text.trim().isEmpty) {
                        return;
                      }
                      update(() => submitting = true);
                      try {
                        final r = await api('/tasks', {
                          'project_id': '00000000000000000000000000000001',
                          'title': title.text.trim(),
                          'prompt': text.text.trim(),
                          'agent': agent,
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        choose(r['task_id'] as String);
                      } catch (e) {
                        if (ctx.mounted) {
                          update(() => submitting = false);
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              child: Text(submitting ? '저장 중…' : '작업 만들기'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    text.dispose();
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (token.isEmpty) return login();
    final workers = status['workers'] as List? ?? [];
    final online = workers.any((w) => '${w['online']}' == '1');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, color: accent, size: 30),
                  const SizedBox(width: 12),
                  const Text(
                    'mate',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (MediaQuery.sizeOf(context).width > 550)
                    const Text('AI 작업 관리자', style: TextStyle(color: muted)),
                  const Spacer(),
                  Icon(
                    Icons.circle,
                    color: online ? accent : Colors.orange,
                    size: 9,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    online ? 'M1 연결됨' : '워커 연결 대기',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: '로그아웃',
                    onPressed: () {
                      setState(() {
                        token = '';
                        status = {};
                        detail = {};
                        selected = '';
                        events.clear();
                      });
                    },
                    icon: const Icon(Icons.logout, size: 20),
                  ),
                ],
              ),
            ),
            if (error.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.red.withValues(alpha: .13),
                padding: const EdgeInsets.all(12),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 800) {
                    return selected.isEmpty
                        ? taskList()
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => selected = ''),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('작업 목록'),
                                ),
                              ),
                              Expanded(child: taskDetail()),
                            ],
                          );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 310, child: taskList()),
                      const VerticalDivider(width: 1),
                      Expanded(child: taskDetail()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget login() => Scaffold(
    body: Center(
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hub_outlined, color: accent, size: 48),
              const SizedBox(height: 20),
              const Text(
                '당신의 AI 작업실',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'M1 Mac에서 작업을 실행하고\n어디서든 진행 상황과 결과를 확인하세요.',
                style: TextStyle(color: muted, height: 1.7),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: tokenInput,
                obscureText: true,
                decoration: const InputDecoration(labelText: '개인 접속 키'),
                onSubmitted: (_) => signIn(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: signIn,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('작업실 열기'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '접속 키는 설치 폴더의 .env에 저장됩니다.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  void signIn() {
    if (tokenInput.text.trim().isEmpty) return;
    setState(() => token = tokenInput.text.trim());
    refresh();
  }

  Widget taskList() {
    final tasks = (status['tasks'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      color: const Color(0xff111724),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WORKSPACE',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '나의 작업',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : createTask,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('새 작업'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text(
                      '첫 작업을 만들어 주세요.',
                      style: TextStyle(color: muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, i) {
                      final t = tasks[i];
                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        decoration: BoxDecoration(
                          color: selected == t['id']
                              ? accent.withValues(alpha: .08)
                              : panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected == t['id']
                                ? accent.withValues(alpha: .5)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            '${t['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${t['agent']}'.toUpperCase(),
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const Spacer(),
                                badge('${t['status']}'),
                              ],
                            ),
                          ),
                          onTap: () => choose('${t['id']}'),
                        ),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              '브라우저를 닫아도 작업은 계속됩니다.\n코드와 대화는 서버에 보존됩니다.',
              style: TextStyle(color: muted, fontSize: 11, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget badge(String value) {
    final color = value == 'completed'
        ? accent
        : value == 'failed'
        ? Colors.redAccent
        : value == 'awaiting_approval'
        ? Colors.amber
        : muted;
    return Text(
      labels[value] ?? value,
      style: TextStyle(color: color, fontSize: 11),
    );
  }

  Widget taskDetail() {
    if (selected.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, color: accent, size: 54),
            SizedBox(height: 20),
            Text('목표를 맡기고, 결과를 확인하세요.', style: TextStyle(fontSize: 22)),
            SizedBox(height: 12),
            Text(
              '작업을 선택하면 대화 · 코드 변경 · 검증 결과를 볼 수 있습니다.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      );
    }
    if (detail['task'] == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = detail['task'] as Map<String, dynamic>;
    final runs = (detail['runs'] as List).cast<Map<String, dynamic>>();
    final latest = runs.isEmpty ? <String, dynamic>{} : runs.last;
    final approvals = (detail['approvals'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['status'] == 'pending')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t['agent']}'.toUpperCase(),
                      style: const TextStyle(
                        color: accent,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t['title']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              badge('${t['status']}'),
              const SizedBox(width: 16),
              if (active.contains(t['status']))
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => act(() async {
                          await api('/tasks/$selected/cancel', {});
                        }),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('중단'),
                ),
            ],
          ),
        ),
        if (approvals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '실행 승인이 필요합니다',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${approvals.first['reason']}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                  await api(
                                    '/approvals/${approvals.first['id']}',
                                    {'approve': true},
                                  );
                                }),
                          child: const Text('승인하고 실행'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => act(() async {
                                  await api(
                                    '/approvals/${approvals.first['id']}',
                                    {'approve': false},
                                  );
                                }),
                          child: const Text('거절'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Wrap(
            spacing: 10,
            children: List.generate(
              4,
              (i) => ChoiceChip(
                label: Text(['진행 기록', '코드 변경', '검증 결과', '실행 이력'][i]),
                selected: tab == i,
                onSelected: (_) => setState(() => tab = i),
              ),
            ),
          ),
        ),
        Expanded(
          child: tab == 0
              ? eventView()
              : tab == 1
              ? codeView('${latest['diff'] ?? ''}', '아직 저장된 코드 변경이 없습니다.')
              : tab == 2
              ? codeView(
                  '${latest['verification'] ?? ''}',
                  '실행이 끝나면 테스트 결과가 표시됩니다.',
                )
              : runHistory(runs),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: prompt,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !active.contains(t['status']) && !busy,
                  decoration: InputDecoration(
                    hintText: active.contains(t['status'])
                        ? '진행 중입니다. 다음 요청은 실행이 끝난 뒤 보낼 수 있습니다.'
                        : '같은 코드와 세션으로 후속 요청을 보내세요.',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: active.contains(t['status']) || busy
                    ? null
                    : () => act(() async {
                        if (prompt.text.trim().isEmpty) return;
                        await api('/tasks/$selected/turns', {
                          'prompt': prompt.text.trim(),
                        });
                        prompt.clear();
                      }),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Icon(Icons.arrow_upward, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget runHistory(List<Map<String, dynamic>> runs) => ListView(
    padding: const EdgeInsets.all(24),
    children: runs.reversed
        .map(
          (r) => Card(
            child: ExpansionTile(
              title: Text(
                '${r['prompt']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${labels[r['status']] ?? r['status']} · ${r['created_at']} · exit ${r['exit_code'] ?? '—'}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('${r['result'] ?? '진행 중'}'),
                      const SizedBox(height: 10),
                      Text(
                        '사용량: ${r['usage_json'] ?? '—'}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      if ((r['diff'] ?? '') != '')
                        SelectableText(
                          '${r['diff']}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      if ((r['verification'] ?? '') != '')
                        SelectableText(
                          '${r['verification']}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
  Widget codeView(String text, String empty) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: SelectableText(
      text.isEmpty ? empty : text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.7,
        color: muted,
      ),
    ),
  );
  Widget eventView() => ListView.builder(
    padding: const EdgeInsets.all(24),
    itemCount: events.length,
    itemBuilder: (context, i) {
      final e = events[i];
      final d = e['data'] as Map<String, dynamic>;
      if (e['type'] == 'usage' || e['type'] == 'session') {
        return const SizedBox.shrink();
      }
      final user = e['type'] == 'user_message';
      final text = d['text'] ?? d['command'] ?? d['changes'] ?? jsonEncode(d);
      return Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: user ? accent.withValues(alpha: .09) : panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user ? '나' : '${e['type']} · ${e['created_at']}',
                style: const TextStyle(color: accent, fontSize: 10),
              ),
              const SizedBox(height: 8),
              SelectableText(
                '$text',
                style: const TextStyle(height: 1.6, fontSize: 13),
              ),
              if ((d['output'] ?? '') != '')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SelectableText(
                    '${d['output']}',
                    style: const TextStyle(
                      color: muted,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
