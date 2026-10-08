import 'dart:math' as math;
import 'package:flutter/cupertino.dart';

const ink = Color(0xFF202C45);
const paper = Color(0xFFF6F7FA);
const muted = Color(0xFF667085);
const accent = Color(0xFFE99360);
const line = Color(0xFFE5E9F0);
const positive = Color(0xFF32816F);
const appTextStyle = TextStyle(
  fontFamily: 'NotoSans',
  fontFamilyFallback: ['NotoSansJP'],
  color: ink,
  fontSize: 15,
);

String clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

Widget panel(Widget child, {Color color = CupertinoColors.white}) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(22),
  ),
  child: child,
);

Widget card(String title, String body) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(fontSize: 16, height: 1.65, color: ink),
        ),
      ],
    ),
  ),
);

Widget action(
  String title,
  VoidCallback? onPressed, {
  bool secondary = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
    color: secondary ? const Color(0xFFE9EDF5) : ink,
    disabledColor: const Color(0xFFE5E9EF),
    borderRadius: BorderRadius.circular(15),
    onPressed: onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onPressed == null
                  ? muted
                  : secondary
                  ? ink
                  : CupertinoColors.white,
            ),
          ),
        ),
        Icon(
          CupertinoIcons.arrow_right,
          size: 18,
          color: onPressed == null
              ? muted
              : secondary
              ? ink
              : CupertinoColors.white,
        ),
      ],
    ),
  ),
);

Widget pill(String title, {Color color = ink}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    title,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
  ),
);

Widget sectionHeading(String title, {String? trailing}) => Padding(
  padding: const EdgeInsets.only(top: 26, bottom: 14),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
      ),
      if (trailing != null)
        Text(trailing, style: const TextStyle(fontSize: 12, color: muted)),
    ],
  ),
);

Widget metric(String value, String label) => Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: muted)),
    ],
  ),
);

Widget progressBar(double value, {Color color = accent}) => ClipRRect(
  borderRadius: BorderRadius.circular(4),
  child: Container(
    height: 5,
    color: line,
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0, 1),
      child: Container(color: color),
    ),
  ),
);

(String, IconData, Color) lessonStyle(String type) => switch (type) {
  'listening' => (
    'Nghe hiểu',
    CupertinoIcons.headphones,
    const Color(0xFF6574B3),
  ),
  'grammar' => ('Ngữ pháp', CupertinoIcons.doc_text, positive),
  _ => ('Từ vựng', CupertinoIcons.book, const Color(0xFFB1754A)),
};

Widget choice(
  String label,
  String text, {
  required bool selected,
  required VoidCallback? onPressed,
  Color color = ink,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Semantics(
    selected: selected,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: .06)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? color : paper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? CupertinoColors.white : muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, height: 1.6, color: ink),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class WeekRing extends StatelessWidget {
  const WeekRing({super.key, required this.week});
  final int week;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tuần ${week + 1} trên 8',
    child: SizedBox(
      width: 94,
      height: 94,
      child: CustomPaint(
        painter: _RingPainter((week + 1) / 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (week + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.white,
                  ),
                ),
                const Text(
                  '/ 08 TUẦN',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: Color(0xFFBDC6D9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect.deflate(4), paint..color = const Color(0xFF3B465F));
    canvas.drawArc(
      rect.deflate(4),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint..color = accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}
