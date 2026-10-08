import 'dart:convert';
import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;

class Lesson {
  Lesson(this.json);
  final Json json;
  String get id => json['id'] as String;
  String get title => json['title'] as String;
  String get type => json['type'] as String;
  String get level => json['level'] as String;
  String? get audio => json['audio'] as String?;
  List<Json> get items => (json['items'] as List).cast<Json>();
  List<Question> get questions => (json['questions'] as List)
      .cast<Json>()
      .map((q) => Question(id, q))
      .toList();
}

class Question {
  Question(this.lessonId, this.json);
  final String lessonId;
  final Json json;
  String get id => '$lessonId:${json['id']}';
  String get type => json['type'] as String;
  String get prompt => json['prompt'] as String;
  String get explanation => json['explanation'] as String? ?? '';
  Json get data => json['data'] as Json;
  List<Json> get entries =>
      ((data[type == 'order'
                  ? 'pieces'
                  : type == 'match'
                  ? 'pairs'
                  : 'options'])
              as List)
          .cast<Json>();
  bool check(List<int> answer) {
    final expected = type == 'order' || type == 'match'
        ? List.generate(entries.length, (i) => i)
        : [
            for (var i = 0; i < entries.length; i++)
              if (entries[i]['correct'] == true) i,
          ];
    if (type == 'single' || type == 'multiple') answer = [...answer]..sort();
    return answer.length == expected.length &&
        List.generate(
          expected.length,
          (i) => answer[i] == expected[i],
        ).every((v) => v);
  }
}

Future<List<Lesson>> loadLessons() async {
  final raw =
      jsonDecode(await rootBundle.loadString('assets/lessons.json')) as List;
  return raw.cast<Json>().map(Lesson.new).toList();
}

int nextInterval(int previous, bool correct) =>
    correct ? (previous == 0 ? 1 : (previous * 2).clamp(1, 30)) : 1;

const weeklyFocus = [
  'Đánh giá đầu vào · xác định điểm yếu',
  'Điện thoại · báo cáo · quan hệ trong–ngoài công ty',
  'Họp · email · kính ngữ trong tình huống',
  'Đàm phán · khiếu nại · ý định người nói',
  'Đọc tài liệu · suy luận · quyết định',
  'Luyện có thời gian · chữa lỗi',
  'Đề luyện tổng hợp · ưu tiên kỹ năng yếu',
  'Ôn lỗi · câu chưa gặp · ổn định tốc độ',
];
