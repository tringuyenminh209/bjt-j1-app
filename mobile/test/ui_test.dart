import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bjt_j1/content.dart';
import 'package:bjt_j1/main.dart';
import 'package:bjt_j1/progress.dart';

void main() {
  testWidgets('Giao diện iPhone: navigation, search, text scale và preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      for (final family in ['NotoSans', 'NotoSansJP']) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('fonts/$family.ttf'))).load();
      }
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    final lessons = (await tester.runAsync(loadLessons))!;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BjtApp(lessons: lessons, progress: Progress()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('J1 trong 8 tuần'), findsOneWidget);
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    await capture('home');
    for (final entry in {
      'Bài học': 'catalog',
      'Luyện đề': 'practice',
      'Tiến độ': 'progress',
    }.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.text(entry.key),
        ),
      );
      await tester.pumpAndSettle();
      await capture(entry.value);
    }
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Bài học'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoSearchTextField),
      'khong-co-bai-nao-123',
    );
    await tester.pumpAndSettle();
    expect(find.text('CHƯA TÌM THẤY'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), '');
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Kho bài học'));
    final lesson = lessons.firstWhere((l) => l.level == 'J1');
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => QuizScreen(
          questions: lesson.questions.take(1).toList(),
          progress: Progress(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('quiz');
    Navigator.of(tester.element(find.text('Xác nhận'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('Hôm nay'),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 812);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    await tester.pumpAndSettle();
    await capture('home-large-text');
  });
}
