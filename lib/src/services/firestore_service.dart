import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/banner_item.dart';
import '../models/booking.dart';
import '../models/branch.dart';
import '../models/court.dart';
import '../models/happy_hour_rule.dart';
import '../models/open_match.dart';
import '../models/voucher.dart';
import '../utils/slot_engine.dart';
import '../utils/time_utils.dart';

/// Thrown when a slot was taken between viewing and confirming.
class SlotTakenException implements Exception {}

/// Thrown when trying to cancel later than the allowed cutoff.
class TooLateToCancelException implements Exception {}

/// Thrown when a voucher fails validation inside the booking transaction.
class VoucherRejectedException implements Exception {
  final String reason;

  VoucherRejectedException(this.reason);
}

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

      final intervals = intervalsFromDay(daySnap.data());
      final clash = intervals
          .any((b) => b.overlaps(booking.startMinutes, booking.endMinutes));
      if (clash) throw SlotTakenException();

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

    await _db.runTransaction((tx) async {
      final daySnap = await tx.get(dayRef);
      final raw = List<Map<String, dynamic>>.from(
          ((daySnap.data()?['intervals'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e)));
      raw.removeWhere((e) => e['bookingId'] == booking.id);
      tx.update(dayRef, {'intervals': raw});
      tx.update(bookingRef, {'status': 'cancelled'});
      // An open match can't survive without its court.
      if (booking.openMatchId != null) {
        tx.update(_db.collection('openMatches').doc(booking.openMatchId!),
            {'status': 'cancelled'});
      }
    });
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
  Future<List<Booking>> bookingsBetween(
      String fromDate, String toDate) async {
    final s = await _db
        .collection('bookings')
        .where('status', isEqualTo: 'confirmed')
        .where('date', isGreaterThanOrEqualTo: fromDate)
        .where('date', isLessThanOrEqualTo: toDate)
        .get();
    return s.docs.map(Booking.fromDoc).toList();
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
