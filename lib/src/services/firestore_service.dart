import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/banner_item.dart';
import '../models/booking.dart';
import '../models/branch.dart';
import '../models/coach.dart';
import '../models/court.dart';
import '../models/expense.dart';
import '../models/happy_hour_rule.dart';
import '../models/open_match.dart';
import '../models/package_offer.dart';
import '../models/voucher.dart';
import '../utils/slot_engine.dart';
import '../utils/time_utils.dart';
import '../utils/xp.dart';

/// Thrown when a slot was taken between viewing and confirming.
class SlotTakenException implements Exception {}

/// Thrown when trying to cancel later than the allowed cutoff.
class TooLateToCancelException implements Exception {}

/// Thrown when a voucher fails validation inside the booking transaction.
class VoucherRejectedException implements Exception {
  final String reason;

  VoucherRejectedException(this.reason);
}

/// Thrown when the wallet can't cover the requested amount (expired or
/// spent in the meantime).
class WalletRejectedException implements Exception {}

/// All Firestore reads/writes in one place.
///
/// Collections:
///  - branches/{branchId} + branches/{branchId}/courts/{courtId}
///  - happyHourRules/{ruleId}
///  - bookings/{bookingId}
///  - courtDays/{branchId_courtId_date}: one small "day sheet" per court per
///    day holding the busy intervals. Creating/cancelling a booking updates
///    the day sheet inside a TRANSACTION, so two customers can never take
///    overlapping slots — the database itself rejects the second attempt.
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  // ---------- Branches & courts ----------

  Stream<List<Branch>> branches() => _db
      .collection('branches')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map(Branch.fromDoc).toList());

  Stream<List<Court>> courts(String branchId) => _db
      .collection('branches')
      .doc(branchId)
      .collection('courts')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Court.fromDoc(d, branchId)).toList());

  Future<void> updateCourtPrices(
      String branchId, String courtId, Map<int, double> prices) {
    return _db
        .collection('branches')
        .doc(branchId)
        .collection('courts')
        .doc(courtId)
        .update({
      'prices': prices.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  // ---------- Happy hour rules ----------

  Stream<List<HappyHourRule>> happyHourRules() => _db
      .collection('happyHourRules')
      .snapshots()
      .map((s) => s.docs.map(HappyHourRule.fromDoc).toList());

  Future<void> saveHappyHourRule(HappyHourRule rule) {
    final col = _db.collection('happyHourRules');
    final doc = rule.id.isEmpty ? col.doc() : col.doc(rule.id);
    return doc.set(rule.toMap());
  }

  Future<void> setRuleActive(String ruleId, bool active) =>
      _db.collection('happyHourRules').doc(ruleId).update({'active': active});

  Future<void> deleteHappyHourRule(String ruleId) =>
      _db.collection('happyHourRules').doc(ruleId).delete();

  // ---------- Day sheets (busy intervals) ----------

  String _dayId(String branchId, String courtId, String date) =>
      '${branchId}_${courtId}_$date';

  DocumentReference<Map<String, dynamic>> _dayRef(
          String branchId, String courtId, String date) =>
      _db.collection('courtDays').doc(_dayId(branchId, courtId, date));

  static List<BusyInterval> intervalsFromDay(Map<String, dynamic>? data) {
    final raw = (data?['intervals'] as List?) ?? const [];
    return raw
        .map((e) => BusyInterval(
            (e['start'] as num).toInt(), (e['end'] as num).toInt()))
        .toList();
  }

  /// Live busy intervals for one court on one date.
  Stream<List<BusyInterval>> busyIntervals(
          String branchId, String courtId, String date) =>
      _dayRef(branchId, courtId, date)
          .snapshots()
          .map((doc) => intervalsFromDay(doc.data()));

  // ---------- Booking (the critical transaction) ----------

  /// Creates a booking atomically. Inside the transaction we re-read the
  /// day sheet and re-check for overlap; if someone else booked the same
  /// range a moment earlier, we throw [SlotTakenException] and nothing is
  /// written. When [booking.voucherCode] is set, the voucher is
  /// re-validated and its usage counters updated in the same transaction.
  Future<String> createBooking(Booking booking) async {
    final bookingRef = _db.collection('bookings').doc();
    final dayRef =
        _dayRef(booking.branchId, booking.courtId, booking.date);
    final voucherRef = booking.voucherCode == null
        ? null
        : _db.collection('vouchers').doc(booking.voucherCode);

    final userRef = booking.walletUsed > 0
        ? _db.collection('users').doc(booking.userId)
        : null;

    await _db.runTransaction((tx) async {
      final daySnap = await tx.get(dayRef);
      Voucher? voucher;
      if (voucherRef != null) {
        final vSnap = await tx.get(voucherRef);
        if (!vSnap.exists) {
          throw VoucherRejectedException('Unknown voucher code.');
        }
        voucher = Voucher.fromDoc(vSnap);
        final reason =
            voucher.rejectionReason(booking.userId, booking.branchId);
        if (reason != null) throw VoucherRejectedException(reason);
      }
      if (userRef != null) {
        final uSnap = await tx.get(userRef);
        final user = AppUser.fromDoc(uSnap);
        if (user.usableWallet(dateKey(DateTime.now())) <
            booking.walletUsed) {
          throw WalletRejectedException();
        }
      }

      final intervals = intervalsFromDay(daySnap.data());
      final clash = intervals
          .any((b) => b.overlaps(booking.startMinutes, booking.endMinutes));
      if (clash) throw SlotTakenException();

      if (userRef != null) {
        tx.update(userRef, {
          'walletBalance': FieldValue.increment(-booking.walletUsed),
        });
      }

      if (voucherRef != null && voucher != null) {
        tx.update(voucherRef, {
          'uses': FieldValue.increment(1),
          'totalDiscount': FieldValue.increment(booking.voucherDiscount),
          'usesByUser.${booking.userId}': FieldValue.increment(1),
        });
      }

      tx.set(bookingRef, booking.toMap());
      tx.set(
        dayRef,
        {
          'branchId': booking.branchId,
          'courtId': booking.courtId,
          'date': booking.date,
          'intervals': FieldValue.arrayUnion([
            {
              'start': booking.startMinutes,
              'end': booking.endMinutes,
              'bookingId': bookingRef.id,
            }
          ]),
        },
        SetOptions(merge: true),
      );
    });
    return bookingRef.id;
  }

  /// Cancels a booking and frees its interval, atomically.
  /// [enforceCutoff] applies the customer rule (>= 3h before start);
  /// admins pass false and can cancel anytime.
  Future<void> cancelBooking(Booking booking,
      {bool enforceCutoff = true, int cutoffHours = 3}) async {
    if (enforceCutoff) {
      final cutoff =
          booking.startDateTime.subtract(Duration(hours: cutoffHours));
      if (DateTime.now().isAfter(cutoff)) throw TooLateToCancelException();
    }
    final bookingRef = _db.collection('bookings').doc(booking.id);
    final dayRef =
        _dayRef(booking.branchId, booking.courtId, booking.date);

    final coachRef = booking.isLesson && booking.coachId != null
        ? _coachDayRef(booking.coachId!, booking.date)
        : null;

    await _db.runTransaction((tx) async {
      // Firestore requires all reads before any writes.
      final daySnap = await tx.get(dayRef);
      final coachSnap = coachRef == null ? null : await tx.get(coachRef);

      List<Map<String, dynamic>> withoutThisBooking(
              Map<String, dynamic>? data) =>
          List<Map<String, dynamic>>.from(
              ((data?['intervals'] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e)))
            ..removeWhere((e) => e['bookingId'] == booking.id);

      tx.update(dayRef, {'intervals': withoutThisBooking(daySnap.data())});
      tx.update(bookingRef, {'status': 'cancelled'});
      // An open match can't survive without its court.
      if (booking.openMatchId != null) {
        tx.update(_db.collection('openMatches').doc(booking.openMatchId!),
            {'status': 'cancelled'});
      }
      // A cancelled lesson frees the coach too.
      if (coachRef != null) {
        tx.set(
            coachRef,
            {'intervals': withoutThisBooking(coachSnap?.data())},
            SetOptions(merge: true));
      }
    });
  }

  // ---------- Prepaid packages & wallet ----------

  Stream<List<PackageOffer>> packages() =>
      _db.collection('packages').snapshots().map((s) {
        final list = s.docs.map(PackageOffer.fromDoc).toList();
        // Cheapest first, priciest last: Silver -> Gold -> VIP.
        list.sort((a, b) => a.order != b.order
            ? a.order.compareTo(b.order)
            : a.price.compareTo(b.price));
        return list;
      });

  Future<void> savePackage(PackageOffer p) {
    final col = _db.collection('packages');
    final doc = p.id.isEmpty ? col.doc() : col.doc(p.id);
    return doc.set(p.toMap());
  }

  Future<void> deletePackage(String id) =>
      _db.collection('packages').doc(id).delete();

  /// Owner grants a package after the customer pays at the club:
  /// wallet balance goes up, expiry extends, and a top-up log is kept.
  Future<void> grantPackage(AppUser customer, PackageOffer package) async {
    final newExpiry = dateKey(
        DateTime.now().add(Duration(days: package.validityDays)));
    final expiry = customer.walletExpiry.compareTo(newExpiry) > 0
        ? customer.walletExpiry
        : newExpiry;
    // Expired leftover credit is wiped before the new credit lands.
    final base = customer.usableWallet(dateKey(DateTime.now()));
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(customer.uid), {
      'walletBalance': base + package.credit,
      'walletExpiry': expiry,
    });
    batch.set(_db.collection('walletTopUps').doc(), {
      'uid': customer.uid,
      'customerName': customer.name,
      'packageName': package.name,
      'paid': package.price,
      'credit': package.credit,
      'expiry': expiry,
      'date': dateKey(DateTime.now()), // for accounting date ranges
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ---------- Academy (coaches & lessons) ----------

  Stream<List<Coach>> coaches() =>
      _db.collection('coaches').snapshots().map((s) {
        final list = s.docs.map(Coach.fromDoc).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<void> saveCoach(Coach coach) {
    final col = _db.collection('coaches');
    final doc = coach.id.isEmpty ? col.doc() : col.doc(coach.id);
    return doc.set(coach.toMap());
  }

  Future<void> deleteCoach(String id) =>
      _db.collection('coaches').doc(id).delete();

  /// Which court lessons use at this branch ('' = any free court).
  Future<void> setLessonCourt(String branchId, String courtId) =>
      _db.collection('branches').doc(branchId).update(
          {'lessonCourtId': courtId});

  /// Customer's wallet top-up history (credits granted by the owner).
  Stream<List<Map<String, dynamic>>> walletTopUps(String uid) => _db
      .collection('walletTopUps')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// Every booking of this user regardless of status — used to build the
  /// wallet activity list (debits + refunds of cancelled bookings).
  Stream<List<Booking>> allMyBookings(String uid) => _db
      .collection('bookings')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  /// Customer asks the club for a package (payment happens at the club
  /// or by transfer later); a Cloud Function notifies the admins.
  Future<void> requestPackage(AppUser customer, PackageOffer package) =>
      _db.collection('packageRequests').add({
        'uid': customer.uid,
        'customerName': customer.name,
        'customerPhone': customer.phone,
        'packageId': package.id,
        'packageName': package.name,
        'price': package.price,
        'credit': package.credit,
        'validityDays': package.validityDays,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Pending package requests for the owner's screen.
  Stream<List<({String id, Map<String, dynamic> data})>>
      pendingPackageRequests() => _db
          .collection('packageRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) =>
              [for (final d in s.docs) (id: d.id, data: d.data())]);

  Future<void> setPackageRequestStatus(String id, String status) =>
      _db.collection('packageRequests').doc(id).update({'status': status});

  DocumentReference<Map<String, dynamic>> _coachDayRef(
          String coachId, String date) =>
      _db.collection('coachDays').doc('${coachId}_$date');

  /// Lesson session length in minutes.
  static const int lessonMinutes = 60;

  /// Available lesson start times for a coach on a date at a branch:
  /// inside the coach's weekly windows, coach not already teaching, and a
  /// court free — the branch's lesson court if the owner assigned one,
  /// otherwise any free court. Returns (startMinutes, court) pairs.
  Future<List<(int, Court)>> lessonSlots({
    required Coach coach,
    required Branch branch,
    required List<Court> courts,
    required String date,
  }) async {
    final windows = coach.availability[weekdayOf(date)] ?? const [];
    if (windows.isEmpty || courts.isEmpty) return const [];

    final candidateCourts = branch.lessonCourtId.isEmpty
        ? courts
        : courts.where((c) => c.id == branch.lessonCourtId).toList();
    if (candidateCourts.isEmpty) return const [];

    // One read per court + one for the coach's day — in PARALLEL, so a
    // slow connection pays one round trip instead of one per court.
    final snaps = await Future.wait([
      for (final court in candidateCourts)
        _dayRef(branch.id, court.id, date).get(),
      _coachDayRef(coach.id, date).get(),
    ]);
    final courtBusy = <String, List<BusyInterval>>{
      for (final (i, court) in candidateCourts.indexed)
        court.id: intervalsFromDay(snaps[i].data()),
    };
    final coachBusy = intervalsFromDay(snaps.last.data());

    final now = DateTime.now();
    final isToday = dateKey(now) == date;
    final notBefore = isToday ? now.hour * 60 + now.minute : 0;

    final slots = <(int, Court)>[];
    for (int start = ClubHours.openMinutes;
        start + lessonMinutes <= ClubHours.closeMinutes;
        start += ClubHours.slotStepMinutes) {
      if (start < notBefore) continue;
      final end = start + lessonMinutes;
      final inWindow =
          windows.any((w) => start >= w.start && end <= w.end);
      if (!inWindow) continue;
      if (coachBusy.any((b) => b.overlaps(start, end))) continue;
      final court = candidateCourts
          .where((c) =>
              !courtBusy[c.id]!.any((b) => b.overlaps(start, end)))
          .firstOrNull;
      if (court != null) slots.add((start, court));
    }
    return slots;
  }

  /// Books a lesson atomically: reserves the court AND the coach in one
  /// transaction, so neither can be double-booked.
  Future<String> createLessonBooking(Booking booking) async {
    assert(booking.isLesson && booking.coachId != null);
    final bookingRef = _db.collection('bookings').doc();
    final dayRef = _dayRef(booking.branchId, booking.courtId, booking.date);
    final coachRef = _coachDayRef(booking.coachId!, booking.date);

    await _db.runTransaction((tx) async {
      final daySnap = await tx.get(dayRef);
      final coachSnap = await tx.get(coachRef);
      final courtClash = intervalsFromDay(daySnap.data())
          .any((b) => b.overlaps(booking.startMinutes, booking.endMinutes));
      final coachClash = intervalsFromDay(coachSnap.data())
          .any((b) => b.overlaps(booking.startMinutes, booking.endMinutes));
      if (courtClash || coachClash) throw SlotTakenException();

      final interval = {
        'start': booking.startMinutes,
        'end': booking.endMinutes,
        'bookingId': bookingRef.id,
      };
      tx.set(bookingRef, booking.toMap());
      tx.set(
          dayRef,
          {
            'branchId': booking.branchId,
            'courtId': booking.courtId,
            'date': booking.date,
            'intervals': FieldValue.arrayUnion([interval]),
          },
          SetOptions(merge: true));
      tx.set(
          coachRef,
          {
            'coachId': booking.coachId,
            'date': booking.date,
            'intervals': FieldValue.arrayUnion([interval]),
          },
          SetOptions(merge: true));
    });
    return bookingRef.id;
  }

  // ---------- Promo banners ----------

  Stream<List<BannerItem>> banners() =>
      _db.collection('banners').snapshots().map((s) {
        final list = s.docs.map(BannerItem.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Future<void> saveBanner(BannerItem banner) {
    final col = _db.collection('banners');
    final doc = banner.id.isEmpty ? col.doc() : col.doc(banner.id);
    return doc.set(banner.toMap());
  }

  Future<void> deleteBanner(String id) =>
      _db.collection('banners').doc(id).delete();

  // ---------- Vouchers ----------

  Stream<List<Voucher>> vouchers() => _db
      .collection('vouchers')
      .snapshots()
      .map((s) => s.docs.map(Voucher.fromDoc).toList());

  /// One-shot lookup for the checkout "Apply" button (final validation
  /// happens again inside the booking transaction).
  Future<Voucher?> voucherByCode(String code) async {
    final snap = await _db
        .collection('vouchers')
        .doc(code.trim().toUpperCase())
        .get();
    return snap.exists ? Voucher.fromDoc(snap) : null;
  }

  Future<void> saveVoucher(Voucher v) {
    // Never clobber live usage counters when the owner edits a voucher.
    final map = v.toMap()
      ..remove('uses')
      ..remove('totalDiscount')
      ..remove('usesByUser');
    return _db
        .collection('vouchers')
        .doc(v.code.trim().toUpperCase())
        .set(map, SetOptions(merge: true));
  }

  Future<void> setVoucherActive(String code, bool active) =>
      _db.collection('vouchers').doc(code).update({'active': active});

  Future<void> deleteVoucher(String code) =>
      _db.collection('vouchers').doc(code).delete();

  // ---------- Open matches ----------

  /// Open matches customers can browse (today onward, still open).
  Stream<List<OpenMatch>> openMatches() => _db
      .collection('openMatches')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((s) {
        final today = dateKey(DateTime.now());
        final list = s.docs
            .map(OpenMatch.fromDoc)
            .where((m) => m.date.compareTo(today) >= 0)
            .toList();
        list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        return list;
      });

  /// All matches (any status) on a date — used by the owner dashboard to
  /// tag bookings and list joined players.
  Stream<List<OpenMatch>> openMatchesOn(String date) => _db
      .collection('openMatches')
      .where('date', isEqualTo: date)
      .snapshots()
      .map((s) => s.docs.map(OpenMatch.fromDoc).toList());

  /// Turns one of the creator's bookings into an open match.
  Future<void> createOpenMatch(OpenMatch match) async {
    final matchRef = _db.collection('openMatches').doc();
    final bookingRef = _db.collection('bookings').doc(match.bookingId);
    final batch = _db.batch();
    batch.set(matchRef, match.toMap());
    batch.update(bookingRef, {
      'isOpenMatch': true,
      'openMatchId': matchRef.id,
    });
    await batch.commit();
  }

  /// Joins an open match atomically; throws [SlotTakenException] when the
  /// last spot was taken a moment earlier.
  Future<void> joinOpenMatch(
      String matchId, String uid, String name) async {
    final ref = _db.collection('openMatches').doc(matchId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final match = OpenMatch.fromDoc(snap);
      if (match.status != 'open' || match.hasJoined(uid)) {
        throw SlotTakenException();
      }
      final players = [
        for (final p in match.players) {'uid': p.uid, 'name': p.name},
        {'uid': uid, 'name': name},
      ];
      tx.update(ref, {
        'players': players,
        if (players.length >= match.playersNeeded) 'status': 'full',
      });
    });
  }

  /// Creator cancels the match (keeps the court booking).
  Future<void> cancelOpenMatch(OpenMatch match) async {
    final batch = _db.batch();
    batch.update(_db.collection('openMatches').doc(match.id),
        {'status': 'cancelled'});
    batch.update(_db.collection('bookings').doc(match.bookingId),
        {'isOpenMatch': false, 'openMatchId': null});
    await batch.commit();
  }

  // ---------- Queries ----------

  /// Customer's upcoming + past bookings (newest first).
  Stream<List<Booking>> myBookings(String userId) => _db
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', isEqualTo: 'confirmed')
      .snapshots()
      .map((s) {
        final list = s.docs.map(Booking.fromDoc).toList();
        list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        return list;
      });

  /// All confirmed bookings on one date (admin dashboard / day grid).
  Stream<List<Booking>> bookingsOn(String date, {String? branchId}) {
    Query<Map<String, dynamic>> q = _db
        .collection('bookings')
        .where('date', isEqualTo: date)
        .where('status', isEqualTo: 'confirmed');
    if (branchId != null) q = q.where('branchId', isEqualTo: branchId);
    return q.snapshots().map((s) {
      final list = s.docs.map(Booking.fromDoc).toList();
      list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      return list;
    });
  }

  /// Confirmed bookings in a date-key range (inclusive), for revenue.
  /// The status filter runs client-side so the query stays a simple
  /// single-field range (no composite index needed).
  Future<List<Booking>> bookingsBetween(
      String fromDate, String toDate) async {
    final s = await _db
        .collection('bookings')
        .where('date', isGreaterThanOrEqualTo: fromDate)
        .where('date', isLessThanOrEqualTo: toDate)
        .get();
    return s.docs
        .map(Booking.fromDoc)
        .where((b) => b.status == BookingStatus.confirmed)
        .toList();
  }

  /// Live version of [bookingsBetween]: updates instantly on local
  /// writes (latency-compensated), so the cash box reacts immediately
  /// even on slow connections.
  Stream<List<Booking>> bookingsBetweenStream(
          String fromDate, String toDate) =>
      _db
          .collection('bookings')
          .where('date', isGreaterThanOrEqualTo: fromDate)
          .where('date', isLessThanOrEqualTo: toDate)
          .snapshots()
          .map((s) => s.docs
              .map(Booking.fromDoc)
              .where((b) => b.status == BookingStatus.confirmed)
              .toList());

  // ---------- Accounting ----------

  /// Club expenses in a date-key range (inclusive), live.
  Stream<List<Expense>> expensesBetween(String fromDate, String toDate) =>
      _db
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: fromDate)
          .where('date', isLessThanOrEqualTo: toDate)
          .snapshots()
          .map((s) => s.docs.map(Expense.fromDoc).toList());

  Future<void> addExpense(Expense expense) =>
      _db.collection('expenses').add(expense.toMap());

  Future<void> deleteExpense(String id) =>
      _db.collection('expenses').doc(id).delete();

  /// Every package payment (all customers) — accounting income. Old
  /// entries may lack the 'date' key, so range filtering happens
  /// client-side using createdAt as a fallback.
  Stream<List<Map<String, dynamic>>> allWalletTopUps() =>
      _db.collection('walletTopUps').snapshots().map(
          (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  /// Records the cash received for a booking. Intentionally not awaited
  /// by callers: the local snapshot updates instantly and the write
  /// syncs in the background.
  Future<void> recordPayment(String bookingId, double amount) => _db
      .collection('bookings')
      .doc(bookingId)
      .update({'paidAmount': amount, 'paymentStatus': 'paid'});

  /// Awards the signed-in user's XP for games whose time has passed.
  ///
  /// The Cloud Function does this on the server every hour, but until
  /// the project is on the Blaze plan the function isn't deployed —
  /// so the app settles it on launch, otherwise the level bar never
  /// moves. Marks each booking xpAwarded so nothing is counted twice.
  Future<void> awardPendingXp(String uid) async {
    final s = await _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('xpAwarded', isEqualTo: false)
        .get();
    final now = DateTime.now();
    final played = s.docs
        .map(Booking.fromDoc)
        .where((b) =>
            b.status == BookingStatus.confirmed &&
            !b.isBlock &&
            b.startDateTime
                .add(Duration(minutes: b.durationMinutes))
                .isBefore(now))
        .toList();
    if (played.isEmpty) return;
    var xp = 0;
    for (final b in played) {
      xp += XpSystem.bookingXp +
          (b.isOpenMatch ? XpSystem.openMatchJoinBonus : 0);
    }
    final batch = _db.batch();
    for (final b in played) {
      batch.update(
          _db.collection('bookings').doc(b.id), {'xpAwarded': true});
    }
    batch.update(_db.collection('users').doc(uid), {
      'xp': FieldValue.increment(xp),
      'matchesPlayed': FieldValue.increment(played.length),
    });
    await batch.commit();
  }

  // ---------- First-run seeding ----------

  /// Creates the two branches and their courts with starter prices if the
  /// database is empty. Called from the admin screen; safe to re-run.
  Future<bool> seedClubIfEmpty() async {
    final existing = await _db.collection('branches').limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    const defaultPrices = {'60': 30.0, '90': 42.0, '120': 55.0};
    final batch = _db.batch();

    final airport = _db.collection('branches').doc('airport-road');
    batch.set(airport, {'name': 'Airport Road', 'order': 0});
    batch.set(airport.collection('courts').doc('court-1'), {
      'name': 'Court 1',
      'type': 'outdoor',
      'order': 0,
      'prices': defaultPrices,
    });
    batch.set(airport.collection('courts').doc('court-2'), {
      'name': 'Court 2',
      'type': 'indoor',
      'order': 1,
      'prices': defaultPrices,
    });
    batch.set(airport.collection('courts').doc('court-3'), {
      'name': 'Court 3',
      'type': 'indoor',
      'order': 2,
      'prices': defaultPrices,
    });

    final hazmieh = _db.collection('branches').doc('hazmieh');
    batch.set(hazmieh, {'name': 'Hazmieh', 'order': 1});
    batch.set(hazmieh.collection('courts').doc('court-1'), {
      'name': 'Court 1',
      'type': 'indoor',
      'order': 0,
      'prices': defaultPrices,
    });
    batch.set(hazmieh.collection('courts').doc('court-2'), {
      'name': 'Court 2',
      'type': 'indoor',
      'order': 1,
      'prices': defaultPrices,
    });

    await batch.commit();
    return true;
  }
}
