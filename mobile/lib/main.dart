import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'content.dart';
import 'progress.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
SupabaseClient? get cloud => supabaseUrl.isEmpty || supabaseKey.isEmpty
    ? null
    : Supabase.instance.client;
const ink = Color(0xFF193B35);
const paper = Color(0xFFF6F4EC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    }
    final progress = Progress();
    await progress.init();
    runApp(BjtApp(lessons: await loadLessons(), progress: progress));
  } catch (e) {
    runApp(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không mở được dữ liệu học. Hãy đóng và mở lại app.\n$e',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget card(String title, String body) => Container(
  margin: const EdgeInsets.symmetric(vertical: 12),
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: ink,
        ),
      ),
      const SizedBox(height: 10),
      Text(body, style: const TextStyle(fontSize: 17, height: 1.5)),
    ],
  ),
);
Widget action(String title, VoidCallback? onPressed) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: CupertinoButton.filled(onPressed: onPressed, child: Text(title)),
);

class BjtApp extends StatefulWidget {
  const BjtApp({super.key, required this.lessons, required this.progress});
  final List<Lesson> lessons;
  final Progress progress;
  @override
  State<BjtApp> createState() => _BjtAppState();
}

class _BjtAppState extends State<BjtApp> {
  StreamSubscription<AuthState>? auth;
  String search = '';
  String category = 'all';
  String? message;
  Progress get p => widget.progress;
  List<Question> get questions =>
      widget.lessons.expand((l) => l.questions).toList();
  List<Lesson> get dailyLessons {
    final day = DateTime.now().difference(p.start).inDays;
    final result = <Lesson>[];
    for (final group in [
      widget.lessons.where((l) => l.type == 'listening').toList(),
      widget.lessons.where((l) => l.level.startsWith('J1')).toList(),
    ]) {
      if (group.isEmpty) continue;
      for (var i = 0; i < 2 && i < group.length; i++) {
        result.add(group[(day * 2 + i) % group.length]);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    auth = cloud?.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
      unawaited(p.sync(cloud!));
    });
    if (cloud != null) unawaited(p.sync(cloud!));
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  void quiz(BuildContext context, List<Question> qs, {bool timed = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => QuizScreen(questions: qs, progress: p, timed: timed),
      ),
    );
  }

  Future<void> login() async {
    try {
      await cloud!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'vn.bjt.j1://login-callback/',
      );
    } catch (e) {
      if (mounted) setState(() => message = 'Không đăng nhập được: $e');
    }
  }

  Widget lessonButton(BuildContext context, Lesson l) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: CupertinoButton(
      color: const Color(0xFFE6EBE3),
      padding: const EdgeInsets.all(16),
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => LessonScreen(lesson: l, progress: p),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${l.level} · ${l.title}\n${l.questions.length} câu hỏi',
          style: const TextStyle(color: ink),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'BJT · J1',
    theme: const CupertinoThemeData(
      primaryColor: ink,
      scaffoldBackgroundColor: paper,
    ),
    home: AnimatedBuilder(
      animation: p,
      builder: (context, _) => CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.sun_max),
              label: 'Hôm nay',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book),
              label: 'Luyện tập',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.timer),
              label: 'Luyện đề',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              label: 'Tiến độ',
            ),
          ],
        ),
        tabBuilder: (_, tab) => CupertinoTabView(
          builder: (context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(
                ['Hôm nay', 'Luyện tập', 'Luyện đề', 'Tiến độ'][tab],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (tab == 0) ...[
                    const Text(
                      '日本語で、働く。',
                      style: TextStyle(fontSize: 16, color: ink),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'J1 trong 8 tuần',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    card('TUẦN ${p.week + 1} / 8', weeklyFocus[p.week]),
                    card(
                      '90 PHÚT HÔM NAY',
                      '15′ ôn đến hạn · 30′ nghe\n30′ đọc / tình huống · 15′ chữa lỗi',
                    ),
                    action(
                      'Ôn đến hạn · ${p.due.length} câu',
                      p.due.isEmpty
                          ? null
                          : () => quiz(
                              context,
                              questions
                                  .where((q) => p.due.contains(q.id))
                                  .take(30)
                                  .toList(),
                            ),
                    ),
                    action('Luyện J1 · 30 câu', () {
                      final ids = widget.lessons
                          .where((l) => l.level.startsWith('J1'))
                          .map((l) => l.id)
                          .toSet();
                      final pool =
                          questions
                              .where((q) => ids.contains(q.lessonId))
                              .toList()
                            ..shuffle();
                      quiz(context, pool.take(30).toList(), timed: true);
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Gợi ý bài học',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final l in dailyLessons) lessonButton(context, l),
                  ],
                  if (tab == 1) ...[
                    CupertinoSearchTextField(
                      placeholder: 'Tìm bài học',
                      onChanged: (v) => setState(() => search = v),
                    ),
                    const SizedBox(height: 16),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: category,
                      children: const {
                        'all': Text('Tất cả'),
                        'listening': Text('Nghe'),
                        'grammar': Text('Ngữ pháp'),
                        'vocab': Text('Từ vựng'),
                      },
                      onValueChanged: (v) {
                        if (v != null) setState(() => category = v);
                      },
                    ),
                    for (final l in widget.lessons.where(
                      (l) =>
                          (category == 'all' || l.type == category) &&
                          l.title.toLowerCase().contains(search.toLowerCase()),
                    ))
                      lessonButton(context, l),
                  ],
                  if (tab == 2) ...[
                    card(
                      'LUYỆN CÓ THỜI GIAN',
                      'Câu hỏi từ kho bài học, không phải đề BJT chính thức. Kết quả không quy đổi thành điểm BJT.',
                    ),
                    for (final count in [30, 80])
                      action('$count câu · $count phút', () {
                        final pool =
                            widget.lessons
                                .where(
                                  (l) =>
                                      l.type == 'listening' ||
                                      l.level.startsWith('J1') ||
                                      l.level == 'J2',
                                )
                                .expand((l) => l.questions)
                                .toList()
                              ..shuffle();
                        quiz(context, pool.take(count).toList(), timed: true);
                      }),
                    action('Chữa câu từng sai', () {
                      final ids = p.reviews.entries
                          .where((e) => (e.value['wrong_count'] as int) > 0)
                          .map((e) => e.key)
                          .toSet();
                      quiz(
                        context,
                        questions
                            .where((q) => ids.contains(q.id))
                            .take(30)
                            .toList(),
                      );
                    }),
                  ],
                  if (tab == 3) ...[
                    card(
                      'KẾT QUẢ',
                      '${p.answered} câu đã làm · ${p.answered == 0 ? 0 : (p.correct * 100 / p.answered).round()}% đúng\n${p.due.length} câu đến hạn ôn',
                    ),
                    card(
                      'THỜI GIAN LUYỆN',
                      '${p.sessions.values.fold<int>(0, (n, s) => n + (s['seconds'] as int)) ~/ 60} phút trong các phiên bài tập',
                    ),
                    if (cloud == null)
                      card(
                        'ĐỒNG BỘ',
                        'Đang học offline. Google Login cần cấu hình Supabase khi build app.',
                      ),
                    if (cloud != null && cloud!.auth.currentUser == null)
                      action('Đăng nhập Google', login),
                    if (cloud?.auth.currentUser != null) ...[
                      card(
                        'TÀI KHOẢN',
                        cloud!.auth.currentUser!.email ?? 'Google',
                      ),
                      action(
                        p.syncing ? 'Đang đồng bộ…' : 'Đồng bộ tiến độ',
                        p.syncing ? null : () => p.sync(cloud!),
                      ),
                      action('Đăng xuất', () async {
                        await cloud!.auth.signOut();
                      }),
                    ],
                    if (message != null || p.syncError != null)
                      card('THÔNG BÁO', message ?? p.syncError!),
                    for (final s in p.sessions.values.toList().reversed.take(
                      15,
                    ))
                      card(
                        '${s['correct']} / ${s['total']} câu đúng',
                        '${s['mode']} · ${(s['seconds'] as int) ~/ 60} phút',
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson, required this.progress});
  final Lesson lesson;
  final Progress progress;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final player = AudioPlayer();
  bool transcript = false, translation = false, loaded = false, busy = false;
  String? error;
  @override
  void dispose() {
    unawaited(player.dispose());
    super.dispose();
  }

  Future<void> play() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!loaded) {
        await player.setAsset(widget.lesson.audio!);
        loaded = true;
      }
      if (player.playing) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.completed) {
          await player.seek(Duration.zero);
        }
        unawaited(
          player.play().catchError((Object e) {
            if (mounted) setState(() => error = 'Không phát được audio: $e');
          }),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Không phát được audio: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l.title)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            if (l.type == 'listening') ...[
              if (l.audio != null)
                StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (_, snap) => action(
                    busy
                        ? 'Đang tải…'
                        : (snap.data?.playing == true
                              ? 'Tạm dừng'
                              : 'Nghe hội thoại'),
                    busy ? null : play,
                  ),
                )
              else
                card(
                  'CHƯA CÓ AUDIO',
                  'Bài này có lời thoại; chưa có file âm thanh trong dữ liệu.',
                ),
              if (error != null) card('AUDIO', error!),
              action(
                transcript ? 'Ẩn lời thoại' : 'Hiện lời thoại sau khi nghe',
                () => setState(() => transcript = !transcript),
              ),
            ],
            action(
              translation ? 'Ẩn tiếng Việt' : 'Hiện giải thích tiếng Việt',
              () => setState(() => translation = !translation),
            ),
            if (l.type != 'listening' || transcript)
              for (final item in l.items)
                card(
                  '${item['speaker'] == null ? '' : '${item['speaker']} · '}${item['jp']}',
                  [
                    item['reading'],
                    item['example_jp'],
                    if (translation) item['meaning'],
                    if (translation) item['example_vi'],
                    if (translation && l.type != 'listening') item['note'],
                  ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
                ),
            action('Làm bài tập · ${l.questions.length} câu', () async {
              await player.pause();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => QuizScreen(
                    questions: l.questions,
                    progress: widget.progress,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.questions,
    required this.progress,
    this.timed = false,
  });
  final List<Question> questions;
  final Progress progress;
  final bool timed;
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0, correct = 0;
  List<int> answer = [], order = [];
  final results = <(Question, bool)>[];
  bool? checked;
  bool finished = false, saving = false;
  String? error;
  final watch = Stopwatch()..start();
  Timer? timer;
  int get remaining =>
      (widget.questions.length * 60 - watch.elapsed.inSeconds).clamp(0, 99999);
  @override
  void initState() {
    super.initState();
    prepare();
    if (widget.timed) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remaining == 0) {
          unawaited(finish());
        } else if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void prepare() {
    answer = [];
    checked = null;
    if (widget.questions.isNotEmpty && index < widget.questions.length) {
      order = List.generate(widget.questions[index].entries.length, (i) => i)
        ..shuffle();
      if (widget.questions[index].type == 'match') {
        answer = List.filled(order.length, -1);
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    watch.stop();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving || checked != null) return;
    final q = widget.questions[index];
    final ok = q.check(answer);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.progress.record(q, ok);
      if (!mounted) return;
      setState(() {
        checked = ok;
        if (ok) correct++;
        results.add((q, ok));
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Chưa lưu được câu trả lời: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> finish() async {
    if (finished || saving) return;
    timer?.cancel();
    watch.stop();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.progress.finish(
        widget.questions.length,
        correct,
        watch.elapsed.inSeconds,
        widget.timed ? 'Luyện có thời gian' : 'Luyện tập',
      );
      if (!mounted) return;
      setState(() => finished = true);
      if (cloud != null) unawaited(widget.progress.sync(cloud!));
    } catch (e) {
      if (mounted) setState(() => error = 'Chưa lưu được phiên học: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Luyện tập')),
        child: SafeArea(child: Center(child: Text('Chưa có câu hỏi phù hợp.'))),
      );
    }
    final q = widget.questions[index];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          finished ? 'Kết quả' : '${index + 1} / ${widget.questions.length}',
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (finished) ...[
              card(
                'HOÀN THÀNH',
                '$correct / ${widget.questions.length} câu đúng · ${watch.elapsed.inMinutes} phút\nKết quả luyện tập, không phải điểm BJT.',
              ),
              for (final r in results)
                card(
                  r.$2 ? 'Đúng · ${r.$1.prompt}' : 'Cần ôn · ${r.$1.prompt}',
                  r.$1.explanation,
                ),
            ] else ...[
              if (widget.timed)
                Text(
                  'Còn ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                ),
              Text(
                q.prompt,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (q.type == 'single' || q.type == 'multiple')
                for (final i in order)
                  CupertinoButton(
                    onPressed: checked != null || saving
                        ? null
                        : () => setState(() {
                            if (q.type == 'single') {
                              answer = [i];
                            } else if (answer.contains(i)) {
                              answer.remove(i);
                            } else {
                              answer.add(i);
                            }
                          }),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${answer.contains(i) ? '●' : '○'} ${q.entries[i]['text']}',
                      ),
                    ),
                  ),
              if (q.type == 'order') ...[
                card(
                  'CÂU CỦA BẠN',
                  answer.map((i) => q.entries[i]['text'] as String).join(''),
                ),
                Wrap(
                  children: [
                    for (final i in order)
                      CupertinoButton(
                        onPressed:
                            checked != null || saving || answer.contains(i)
                            ? null
                            : () => setState(() => answer.add(i)),
                        child: Text(q.entries[i]['text'] as String),
                      ),
                  ],
                ),
                action(
                  'Xếp lại',
                  checked != null || saving
                      ? null
                      : () => setState(() => answer = []),
                ),
              ],
              if (q.type == 'match')
                for (var left = 0; left < q.entries.length; left++) ...[
                  Text(
                    q.entries[left]['left'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final right in order)
                    CupertinoButton(
                      onPressed: checked != null || saving
                          ? null
                          : () => setState(() => answer[left] = right),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${answer[left] == right ? '●' : '○'} ${q.entries[right]['right']}',
                        ),
                      ),
                    ),
                ],
              if (checked == null)
                action(
                  'Xác nhận',
                  saving || answer.isEmpty || answer.contains(-1)
                      ? null
                      : submit,
                ),
              if (checked != null && !widget.timed)
                card(checked! ? 'Đúng' : 'Cần ôn lại', q.explanation),
              if (checked != null)
                action(
                  index + 1 == widget.questions.length
                      ? 'Kết thúc'
                      : 'Câu tiếp',
                  saving
                      ? null
                      : () {
                          if (index + 1 == widget.questions.length) {
                            unawaited(finish());
                          } else {
                            setState(() {
                              index++;
                              prepare();
                            });
                          }
                        },
                ),
              if (widget.timed) action('Nộp bài', saving ? null : finish),
            ],
            if (error != null) card('LƯU DỮ LIỆU', error!),
          ],
        ),
      ),
    );
  }
}
