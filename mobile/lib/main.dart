import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'content.dart';
import 'progress.dart';
import 'ui.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
SupabaseClient? get cloud => supabaseUrl.isEmpty || supabaseKey.isEmpty
    ? null
    : Supabase.instance.client;
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

class BjtApp extends StatefulWidget {
  const BjtApp({super.key, required this.lessons, required this.progress});
  final List<Lesson> lessons;
  final Progress progress;
  @override
  State<BjtApp> createState() => _BjtAppState();
}

class _BjtAppState extends State<BjtApp> {
  final tabs = CupertinoTabController();
  StreamSubscription<AuthState>? auth;
  String search = '', category = 'all';
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
    tabs.dispose();
    super.dispose();
  }

  void quiz(BuildContext context, List<Question> qs, {bool timed = false}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => QuizScreen(questions: qs, progress: p, timed: timed),
      ),
    );
  }

  void openLesson(BuildContext context, Lesson lesson) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LessonScreen(lesson: lesson, progress: p),
      ),
    );
  }

  void review(BuildContext context, {bool mistakes = false}) {
    final ids = mistakes
        ? p.reviews.entries
              .where((e) => (e.value['wrong_count'] as int) > 0)
              .map((e) => e.key)
              .toSet()
        : p.due;
    quiz(context, questions.where((q) => ids.contains(q.id)).take(30).toList());
  }

  void j1Quiz(BuildContext context) {
    final pool =
        widget.lessons
            .where((l) => l.level.startsWith('J1'))
            .expand((l) => l.questions)
            .toList()
          ..shuffle();
    quiz(context, pool.take(30).toList(), timed: true);
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

  Widget header(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '文',
              style: TextStyle(
                fontFamily: 'NotoSansJP',
                fontSize: 19,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'BJT STUDY',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: () => tabs.index = 3,
            child: const Icon(
              CupertinoIcons.person_crop_circle,
              color: muted,
              size: 27,
            ),
          ),
        ],
      ),
      const SizedBox(height: 23),
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: muted, height: 1.5),
      ),
      const SizedBox(height: 25),
    ],
  );

  Widget lessonButton(BuildContext context, Lesson l) {
    final style = lessonStyle(l.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => openLesson(context, l),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: style.$3.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(style.$2, color: style.$3, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          style.$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: style.$3,
                          ),
                        ),
                        const Spacer(),
                        pill(l.level, color: style.$3),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      l.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l.questions.length} câu hỏi${l.type == 'listening'
                          ? l.audio == null
                                ? ' · Chỉ có lời thoại'
                                : ' · Audio offline'
                          : ' · ${l.items.length} mục học'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget planRow(
    String number,
    String title,
    String detail,
    String minutes,
    Color color,
    VoidCallback? onPressed,
  ) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 14),
    onPressed: onPressed,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onPressed == null ? muted : ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          minutes,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(width: 9),
        const Icon(CupertinoIcons.chevron_right, size: 12, color: muted),
      ],
    ),
  );

  List<Widget> home(BuildContext context) {
    final day = DateTime.now().difference(p.start).inDays;
    final listening = dailyLessons
        .where((l) => l.type == 'listening')
        .firstOrNull;
    final reading = dailyLessons
        .where((l) => l.type != 'listening')
        .firstOrNull;
    final mistakes = p.reviews.values
        .where((r) => (r['wrong_count'] as int) > 0)
        .length;
    return [
      header('Hôm nay', 'Nền tảng N1 · 90 phút mỗi ngày'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LỘ TRÌNH CÁ NHÂN',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB8C5DB),
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'J1 trong 8 tuần',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.white,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        weeklyFocus[p.week],
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Color(0xFFD0D8E6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                WeekRing(week: p.week),
              ],
            ),
            const SizedBox(height: 19),
            Container(height: 1, color: const Color(0xFF3B465F)),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(CupertinoIcons.flag, size: 14, color: accent),
                const SizedBox(width: 7),
                const Text(
                  'Mục tiêu 530+',
                  style: TextStyle(fontSize: 11, color: CupertinoColors.white),
                ),
                const Spacer(),
                Text(
                  'Còn ${(56 - day).clamp(0, 56)} ngày',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB8C5DB),
                  ),
                ),
              ],
            ),
          ],
        ),
        color: ink,
      ),
      const SizedBox(height: 14),
      CupertinoButton(
        color: accent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        borderRadius: BorderRadius.circular(15),
        onPressed: widget.lessons.isEmpty ? null : () => j1Quiz(context),
        child: const Row(
          children: [
            Icon(CupertinoIcons.play_fill, size: 16, color: ink),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bắt đầu luyện J1',
                style: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text('30 câu', style: TextStyle(fontSize: 12, color: ink)),
          ],
        ),
      ),
      sectionHeading('Phiên học hôm nay', trailing: '90 PHÚT'),
      panel(
        Column(
          children: [
            planRow(
              '01',
              'Ôn tập đến hạn',
              p.due.isEmpty
                  ? 'Chưa có câu đến hạn'
                  : '${p.due.length} câu cần ôn lại',
              '15′',
              positive,
              p.due.isEmpty ? null : () => review(context),
            ),
            Container(height: 1, color: line),
            planRow(
              '02',
              'Nghe & hiểu ý định',
              'Nghe trước, xem lời thoại sau',
              '30′',
              const Color(0xFF6574B3),
              listening == null ? null : () => openLesson(context, listening),
            ),
            Container(height: 1, color: line),
            planRow(
              '03',
              'Đọc & xử lý tình huống',
              'Lập luận, kính ngữ và lựa chọn',
              '30′',
              const Color(0xFFB1754A),
              reading == null ? null : () => openLesson(context, reading),
            ),
            Container(height: 1, color: line),
            planRow(
              '04',
              'Chữa lỗi hôm nay',
              mistakes == 0
                  ? 'Lỗi sai sẽ xuất hiện ở đây'
                  : '$mistakes câu từng sai',
              '15′',
              const Color(0xFF9A6C92),
              mistakes == 0 ? null : () => review(context, mistakes: true),
            ),
          ],
        ),
      ),
      sectionHeading('Dành cho bạn', trailing: 'NGHE · J1'),
      for (final l in dailyLessons) lessonButton(context, l),
    ];
  }

  List<Widget> catalog(BuildContext context) {
    final filtered = widget.lessons
        .where(
          (l) =>
              (category == 'all' || l.type == category) &&
              l.title.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return [
      header(
        'Kho bài học',
        '${widget.lessons.length} bài · học theo tình huống công việc',
      ),
      CupertinoSearchTextField(
        placeholder: 'Tìm chủ đề, tên bài học…',
        padding: const EdgeInsets.all(15),
        backgroundColor: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        onChanged: (v) => setState(() => search = v),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 43,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final entry in const {
              'all': 'Tất cả',
              'listening': 'Nghe',
              'grammar': 'Ngữ pháp',
              'vocab': 'Từ vựng',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  color: category == entry.key ? ink : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => setState(() => category = entry.key),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: category == entry.key
                          ? CupertinoColors.white
                          : muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      sectionHeading('Khám phá bài học', trailing: '${filtered.length} BÀI'),
      if (filtered.isEmpty)
        card('CHƯA TÌM THẤY', 'Thử một từ khóa hoặc chủ đề khác.'),
      for (final l in filtered) lessonButton(context, l),
    ];
  }

  List<Widget> practice(BuildContext context) => [
    header('Luyện đề', 'Rèn tốc độ · hiểu tình huống · chữa lỗi'),
    for (final count in [30, 80]) ...[
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                pill(
                  count == 30 ? 'LUYỆN NHANH' : 'LUYỆN SỨC BỀN',
                  color: count == 30 ? positive : const Color(0xFF6574B3),
                ),
                const Spacer(),
                const Icon(CupertinoIcons.timer, color: muted, size: 22),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '$count câu hỏi',
              style: const TextStyle(
                fontSize: 27,
                letterSpacing: -1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count phút · Nghe, đọc và tình huống\nXem giải thích sau khi nộp bài',
              style: const TextStyle(fontSize: 12, color: muted, height: 1.7),
            ),
            const SizedBox(height: 14),
            action(
              'Bắt đầu luyện',
              widget.lessons.isEmpty
                  ? null
                  : () {
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
                    },
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ],
    action(
      'Mở sổ lỗi của bạn',
      () => review(context, mistakes: true),
      secondary: true,
    ),
    const SizedBox(height: 12),
    const Text(
      'Đề luyện lấy từ kho bài học. Kết quả không quy đổi thành điểm BJT chính thức.',
      style: TextStyle(fontSize: 11, color: muted, height: 1.6),
    ),
  ];

  List<Widget> stats() {
    final accuracy = p.answered == 0
        ? 0
        : (p.correct * 100 / p.answered).round();
    final minutes =
        p.sessions.values.fold<int>(0, (n, s) => n + (s['seconds'] as int)) ~/
        60;
    final history = p.sessions.values.toList()
      ..sort(
        (a, b) =>
            (b['updated_at'] as String).compareTo(a['updated_at'] as String),
      );
    return [
      header('Tiến độ của bạn', 'Mỗi phiên học đều là một bước tiến.'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TỶ LỆ TRẢ LỜI ĐÚNG',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Color(0xFFB8C5DB),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$accuracy%',
                  style: const TextStyle(
                    fontSize: 48,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${p.correct} / ${p.answered} câu',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB8C5DB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            progressBar(accuracy / 100),
          ],
        ),
        color: ink,
      ),
      const SizedBox(height: 15),
      panel(
        Row(
          children: [
            metric('$minutes', 'Phút luyện bài tập'),
            metric('${p.due.length}', 'Câu đến hạn ôn'),
          ],
        ),
      ),
      sectionHeading('Tài khoản & đồng bộ'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.person_crop_circle,
                  size: 35,
                  color: ink,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cloud?.auth.currentUser?.email ?? 'Hồ sơ của bạn',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cloud?.auth.currentUser == null
                            ? 'Tiến độ lưu trên thiết bị'
                            : 'Có thể sao lưu tiến độ',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (cloud == null)
              const Text(
                'Bạn đang học offline.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            if (cloud != null && cloud!.auth.currentUser == null)
              action('Đăng nhập Google', login),
            if (cloud?.auth.currentUser != null) ...[
              action(
                p.syncing ? 'Đang đồng bộ…' : 'Đồng bộ tiến độ',
                p.syncing ? null : () => p.sync(cloud!),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await cloud!.auth.signOut();
                },
                child: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ],
        ),
      ),
      if (message != null || p.syncError != null)
        card('THÔNG BÁO', message ?? p.syncError!),
      sectionHeading(
        'Những phiên gần đây',
        trailing: '${p.sessions.length} PHIÊN',
      ),
      if (history.isEmpty)
        card(
          'BẮT ĐẦU TỪ HÔM NAY',
          'Hoàn thành một phiên luyện để ghi lại kết quả đầu tiên.',
        ),
      for (final s in history.take(15))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: panel(
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: positive.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark,
                    color: positive,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['mode'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(s['seconds'] as int) ~/ 60} phút luyện tập',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${s['correct']}/${s['total']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'BJT · J1',
    debugShowCheckedModeBanner: false,
    theme: CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: ink,
      scaffoldBackgroundColor: paper,
      textTheme: CupertinoTextThemeData(
        textStyle: appTextStyle,
        actionTextStyle: appTextStyle,
        actionSmallTextStyle: appTextStyle.copyWith(fontSize: 13),
        navTitleTextStyle: appTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        navActionTextStyle: appTextStyle,
        tabLabelTextStyle: appTextStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: p,
      builder: (_, _) => CupertinoTabScaffold(
        controller: tabs,
        tabBar: CupertinoTabBar(
          backgroundColor: CupertinoColors.white,
          activeColor: ink,
          inactiveColor: muted,
          height: 60,
          iconSize: 22,
          border: const Border(top: BorderSide(color: line, width: .7)),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.sun_max),
              activeIcon: Icon(CupertinoIcons.sun_max_fill),
              label: 'Hôm nay',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book),
              activeIcon: Icon(CupertinoIcons.book_fill),
              label: 'Bài học',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.timer),
              label: 'Luyện đề',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              activeIcon: Icon(CupertinoIcons.chart_bar_fill),
              label: 'Tiến độ',
            ),
          ],
        ),
        tabBuilder: (_, tab) => CupertinoTabView(
          builder: (context) => CupertinoPageScaffold(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                children: switch (tab) {
                  0 => home(context),
                  1 => catalog(context),
                  2 => practice(context),
                  _ => stats(),
                },
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
  bool get isPlaying =>
      player.playing && player.processingState != ProcessingState.completed;
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
      if (isPlaying) {
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

  Widget audioPanel() => StreamBuilder<PlayerState>(
    stream: player.playerStateStream,
    builder: (_, _) => panel(
      Column(
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.headphones, size: 20, color: accent),
              SizedBox(width: 9),
              Text(
                'NGHE & NẮM Ý CHÍNH',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFCBD5E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                onPressed: loaded ? () => player.seek(Duration.zero) : null,
                child: const Icon(
                  CupertinoIcons.repeat,
                  color: Color(0xFFCBD5E5),
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              CupertinoButton(
                padding: const EdgeInsets.all(24),
                color: accent,
                borderRadius: BorderRadius.circular(40),
                onPressed: busy ? null : play,
                child: busy
                    ? const CupertinoActivityIndicator(color: ink)
                    : Icon(
                        isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 27,
                        color: ink,
                      ),
              ),
              const SizedBox(width: 14),
              CupertinoButton(
                onPressed: loaded
                    ? () => player.seek(
                        Duration(
                          milliseconds: (player.position.inMilliseconds + 10000)
                              .clamp(0, player.duration?.inMilliseconds ?? 0),
                        ),
                      )
                    : null,
                child: const Icon(
                  CupertinoIcons.goforward_10,
                  color: Color(0xFFCBD5E5),
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (_, duration) => StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (_, position) {
                final total = duration.data?.inMilliseconds ?? 0;
                final elapsed = (position.data?.inMilliseconds ?? 0).clamp(
                  0,
                  total,
                );
                return Column(
                  children: [
                    CupertinoSlider(
                      value: total == 0 ? 0 : elapsed / total,
                      activeColor: accent,
                      onChanged: total == 0
                          ? null
                          : (v) => player.seek(
                              Duration(milliseconds: (v * total).round()),
                            ),
                    ),
                    Row(
                      children: [
                        Text(
                          clock(elapsed ~/ 1000),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCBD5E5),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          clock(total ~/ 1000),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCBD5E5),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'Nghe một lượt trước khi mở lời thoại.',
            style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E5)),
          ),
        ],
      ),
      color: ink,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final style = lessonStyle(l.type);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: paper,
        border: null,
        middle: Text(
          style.$1,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
                children: [
                  Row(
                    children: [
                      pill(l.level, color: style.$3),
                      const SizedBox(width: 8),
                      Text(
                        '${l.items.length} mục học · ${l.questions.length} câu hỏi',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    l.title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (l.type == 'listening') ...[
                    if (l.audio != null)
                      audioPanel()
                    else
                      card(
                        'BÀI ĐỌC HỘI THOẠI',
                        'Bài này chưa có file audio. Bạn có thể mở lời thoại và làm bài tập.',
                      ),
                    if (error != null) card('AUDIO', error!),
                  ],
                  const SizedBox(height: 18),
                  panel(
                    Column(
                      children: [
                        if (l.type == 'listening')
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Hiện lời thoại',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: transcript,
                                activeTrackColor: ink,
                                onChanged: (v) =>
                                    setState(() => transcript = v),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Giải thích tiếng Việt',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            CupertinoSwitch(
                              value: translation,
                              activeTrackColor: ink,
                              onChanged: (v) => setState(() => translation = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (l.type == 'listening' && !transcript)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.text_alignleft,
                            size: 30,
                            color: muted.withValues(alpha: .6),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tập trung vào phần nghe',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bật lời thoại khi bạn cần đối chiếu.',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  if (l.type != 'listening' || transcript) ...[
                    sectionHeading(
                      l.type == 'listening'
                          ? 'Lời thoại hội thoại'
                          : 'Nội dung bài học',
                      trailing: '日本語',
                    ),
                    for (var i = 0; i < l.items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    (i + 1).toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                  ),
                                  if (l.items[i]['speaker'] != null) ...[
                                    const SizedBox(width: 9),
                                    Text(
                                      l.items[i]['speaker'] as String,
                                      style: TextStyle(
                                        fontFamily: 'NotoSansJP',
                                        fontSize: 11,
                                        color: style.$3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l.items[i]['jp'] as String,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansJP',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  height: 1.8,
                                ),
                              ),
                              if (l.items[i]['reading'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    l.items[i]['reading'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'NotoSansJP',
                                      fontSize: 12,
                                      color: muted,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              if (l.items[i]['example_jp'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    l.items[i]['example_jp'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'NotoSansJP',
                                      fontSize: 15,
                                      height: 1.8,
                                    ),
                                  ),
                                ),
                              if (translation)
                                for (final text
                                    in [
                                      l.items[i]['meaning'],
                                      l.items[i]['example_vi'],
                                      if (l.type != 'listening')
                                        l.items[i]['note'],
                                    ].whereType<String>().where(
                                      (s) => s.isNotEmpty,
                                    ))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: muted,
                                        height: 1.8,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Container(
              color: paper,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: action(
                'Làm bài tập · ${l.questions.length} câu',
                () async {
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
                },
              ),
            ),
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
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Luyện tập'),
          backgroundColor: paper,
          border: null,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: card(
              'CHƯA CÓ CÂU HỎI',
              'Hoàn thành một bài học để bắt đầu xây dựng sổ ôn tập.',
            ),
          ),
        ),
      );
    }
    final q = widget.questions[index];
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: paper,
        border: null,
        middle: Text(
          finished
              ? 'Kết quả'
              : widget.timed
              ? 'Luyện có thời gian'
              : 'Luyện tập',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                children: [
                  if (finished) ...[
                    panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_alt_circle_fill,
                                color: accent,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'HOÀN THÀNH',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCBD5E5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 23),
                          Text(
                            '$correct / ${widget.questions.length}',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'Câu trả lời đúng · ${clock(watch.elapsed.inSeconds)} luyện tập',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCBD5E5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          progressBar(correct / widget.questions.length),
                        ],
                      ),
                      color: ink,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Kết quả luyện tập, không phải điểm BJT.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    sectionHeading('Xem lại câu trả lời'),
                    for (final r in results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              pill(
                                r.$2 ? 'Đúng' : 'Cần ôn lại',
                                color: r.$2
                                    ? positive
                                    : const Color(0xFFB86D51),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                r.$1.prompt,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 13),
                              Text(
                                r.$1.explanation,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: muted,
                                  height: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Text(
                          'CÂU ${(index + 1).toString().padLeft(2, '0')} / ${widget.questions.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: muted,
                          ),
                        ),
                        const Spacer(),
                        if (widget.timed)
                          pill(
                            clock(remaining),
                            color: remaining < 60
                                ? const Color(0xFFB86D51)
                                : ink,
                          ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    progressBar(
                      (index + 1) / widget.questions.length,
                      color: ink,
                    ),
                    const SizedBox(height: 25),
                    Text(
                      switch (q.type) {
                        'single' => 'CHỌN MỘT ĐÁP ÁN',
                        'multiple' => 'CHỌN CÁC ĐÁP ÁN ĐÚNG',
                        'order' => 'SẮP XẾP CÂU',
                        _ => 'GHÉP CẶP',
                      },
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.prompt,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (q.type == 'single' || q.type == 'multiple')
                      for (var display = 0; display < order.length; display++)
                        choice(
                          String.fromCharCode(65 + display),
                          q.entries[order[display]]['text'] as String,
                          selected:
                              answer.contains(order[display]) ||
                              (checked != null &&
                                  !widget.timed &&
                                  q.entries[order[display]]['correct'] == true),
                          color: checked != null && !widget.timed
                              ? q.entries[order[display]]['correct'] == true
                                    ? positive
                                    : const Color(0xFFB86D51)
                              : ink,
                          onPressed: checked != null || saving
                              ? null
                              : () => setState(() {
                                  final i = order[display];
                                  if (q.type == 'single') {
                                    answer = [i];
                                  } else if (answer.contains(i)) {
                                    answer.remove(i);
                                  } else {
                                    answer.add(i);
                                  }
                                }),
                        ),
                    if (q.type == 'order') ...[
                      panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CÂU CỦA BẠN',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              answer.isEmpty
                                  ? 'Chạm các mảnh bên dưới để ghép câu.'
                                  : answer
                                        .map(
                                          (i) => q.entries[i]['text'] as String,
                                        )
                                        .join(''),
                              style: TextStyle(
                                fontFamily: answer.isEmpty
                                    ? 'NotoSans'
                                    : 'NotoSansJP',
                                fontSize: answer.isEmpty ? 13 : 19,
                                color: answer.isEmpty ? muted : ink,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final i in order)
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 13,
                              ),
                              color: CupertinoColors.white,
                              disabledColor: line,
                              borderRadius: BorderRadius.circular(12),
                              onPressed:
                                  checked != null ||
                                      saving ||
                                      answer.contains(i)
                                  ? null
                                  : () => setState(() => answer.add(i)),
                              child: Text(
                                q.entries[i]['text'] as String,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansJP',
                                  fontSize: 16,
                                  color: ink,
                                ),
                              ),
                            ),
                        ],
                      ),
                      CupertinoButton(
                        onPressed: checked != null || saving
                            ? null
                            : () => setState(() => answer = []),
                        child: const Text(
                          'Xếp lại',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                    ],
                    if (q.type == 'match')
                      for (var left = 0; left < q.entries.length; left++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            '${left + 1}. ${q.entries[left]['left']}',
                            style: const TextStyle(
                              fontFamily: 'NotoSansJP',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1.8,
                            ),
                          ),
                        ),
                        for (var display = 0; display < order.length; display++)
                          choice(
                            String.fromCharCode(65 + display),
                            q.entries[order[display]]['right'] as String,
                            selected: answer[left] == order[display],
                            onPressed: checked != null || saving
                                ? null
                                : () => setState(
                                    () => answer[left] = order[display],
                                  ),
                          ),
                      ],
                    if (checked != null && !widget.timed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: panel(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    checked!
                                        ? CupertinoIcons
                                              .checkmark_alt_circle_fill
                                        : CupertinoIcons.info_circle,
                                    color: checked!
                                        ? positive
                                        : const Color(0xFFB86D51),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    checked! ? 'Đúng' : 'Cần ôn lại',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                q.explanation,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.8,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (error != null) card('LƯU DỮ LIỆU', error!),
                ],
              ),
            ),
            Container(
              color: paper,
              padding: const EdgeInsets.fromLTRB(22, 5, 22, 7),
              child: Column(
                children: [
                  if (finished)
                    action('Xong', () => Navigator.of(context).pop()),
                  if (!finished && checked == null)
                    action(
                      'Xác nhận',
                      saving || answer.isEmpty || answer.contains(-1)
                          ? null
                          : submit,
                    ),
                  if (!finished && checked != null)
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
                  if (!finished && widget.timed)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      onPressed: saving ? null : finish,
                      child: const Text(
                        'Nộp bài',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
