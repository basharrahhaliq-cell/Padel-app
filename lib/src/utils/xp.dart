/// XP levels — separate from the A/B/C/D skill level used for
/// matchmaking. Thresholds: level 2 at 200 XP, 3 at 500, 4 at 1000,
/// then +750 per level. Must match levelForXp in functions/index.js,
/// where the XP is actually awarded (after the game time has passed).
class XpSystem {
  XpSystem._();

  static const int bookingXp = 50;
  static const int openMatchJoinBonus = 20;
  static const int tournamentXp = 100;

  static int levelFor(int xp) {
    if (xp < 200) return 1;
    if (xp < 500) return 2;
    if (xp < 1000) return 3;
    return 4 + (xp - 1000) ~/ 750;
  }

  /// Total XP needed to reach [level] (level 1 = 0).
  static int thresholdFor(int level) {
    switch (level) {
      case <= 1:
        return 0;
      case 2:
        return 200;
      case 3:
        return 500;
      default:
        return 1000 + (level - 4) * 750;
    }
  }

  /// Progress within the current level, 0.0 – 1.0.
  static double progress(int xp) {
    final level = levelFor(xp);
    final from = thresholdFor(level);
    final to = thresholdFor(level + 1);
    return ((xp - from) / (to - from)).clamp(0.0, 1.0);
  }

  static int xpToNext(int xp) => thresholdFor(levelFor(xp) + 1) - xp;
}
