import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjt_j1/content.dart';
import 'package:bjt_j1/main.dart';
import 'package:bjt_j1/progress.dart';

class MemoryProgress extends Progress {
  int saved = 0;
  @override
  Future<void> record(Question q, bool correct) async {
    saved++;
  }

  @override
  Future<void> finish(int total, int correct, int seconds, String mode) async {}
}

void main() {
  testWidgets('Quiz lưu câu trả lời và kết thúc được', (tester) async {
    final progress = MemoryProgress();
    final question = Question('sample', {
      'id': 1,
      'type': 'single',
      'prompt': 'Chọn câu đúng',
      'explanation': 'Giải thích',
      'data': {
        'options': [
          {'text': 'Đáp án đúng', 'correct': true},
          {'text': 'Đáp án sai', 'correct': false},
        ],
      },
    });
    await tester.pumpWidget(BjtApp(lessons: const [], progress: progress));
    expect(find.text('J1 trong 8 tuần'), findsOneWidget);
    final context = tester.element(find.text('J1 trong 8 tuần'));
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => QuizScreen(questions: [question], progress: progress),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Đáp án đúng'));
    await tester.pump();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(progress.saved, 1);
    expect(find.text('Giải thích'), findsOneWidget);
    await tester.tap(find.text('Kết thúc'));
    await tester.pumpAndSettle();
    expect(find.text('HOÀN THÀNH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Nội dung có đủ dạng câu, đáp án chuẩn và audio tồn tại', () {
    final lessons =
        (jsonDecode(File('assets/lessons.json').readAsStringSync()) as List)
            .cast<Json>()
            .map(Lesson.new)
            .toList();
    expect(lessons.length, 125);
    final ids = <String>{};
    final types = <String>{};
    for (final l in lessons) {
      if (l.audio != null) expect(File(l.audio!).existsSync(), isTrue);
      for (final q in l.questions) {
        expect(ids.add(q.id), isTrue, reason: q.id);
        types.add(q.type);
        final answer = q.type == 'order' || q.type == 'match'
            ? List.generate(q.entries.length, (i) => i)
            : [
                for (var i = 0; i < q.entries.length; i++)
                  if (q.entries[i]['correct'] == true) i,
              ];
        expect(answer, isNotEmpty, reason: q.id);
        expect(q.check(answer), isTrue, reason: q.id);
        expect(q.check([]), isFalse, reason: q.id);
        if (q.type == 'order' || q.type == 'match') {
          expect(q.check(answer.reversed.toList()), isFalse, reason: q.id);
        }
      }
    }
    expect(types, {'single', 'multiple', 'order', 'match'});
  });
  test('Lịch ôn có reset và giới hạn', () {
    expect(nextInterval(0, true), 1);
    expect(nextInterval(4, true), 8);
    expect(nextInterval(30, true), 30);
    expect(nextInterval(30, false), 1);
  });
}
