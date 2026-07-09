import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/utils/xp.dart';

void main() {
  test('levels follow the club thresholds', () {
    expect(XpSystem.levelFor(0), 1);
    expect(XpSystem.levelFor(199), 1);
    expect(XpSystem.levelFor(200), 2);
    expect(XpSystem.levelFor(499), 2);
    expect(XpSystem.levelFor(500), 3);
    expect(XpSystem.levelFor(999), 3);
    expect(XpSystem.levelFor(1000), 4);
    expect(XpSystem.levelFor(1749), 4);
    expect(XpSystem.levelFor(1750), 5); // +750
    expect(XpSystem.levelFor(2500), 6);
  });

  test('thresholds are consistent with levelFor', () {
    for (int level = 1; level <= 10; level++) {
      final xp = XpSystem.thresholdFor(level);
      expect(XpSystem.levelFor(xp), level);
      if (xp > 0) expect(XpSystem.levelFor(xp - 1), level - 1);
    }
  });

  test('progress runs 0..1 inside a level', () {
    expect(XpSystem.progress(0), 0);
    expect(XpSystem.progress(100), 0.5); // halfway to 200
    expect(XpSystem.progress(199), closeTo(0.995, 0.001));
    expect(XpSystem.progress(200), 0); // fresh level 2
  });

  test('xpToNext counts down to the next threshold', () {
    expect(XpSystem.xpToNext(0), 200);
    expect(XpSystem.xpToNext(450), 50);
    expect(XpSystem.xpToNext(1000), 750);
  });
}
