import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/time_utils.dart';

enum BookingStatus { confirmed, cancelled }

/// A reservation (or an owner "block" for maintenance / private events).
///
/// The price is stored on the booking at creation time, so later price
/// changes never affect existing bookings. `paymentStatus` is always
/// "pay_at_club" for now — the field exists so online payments can be
/// added later without a data migration.
class Booking {
  final String id;
  final String branchId;
  final String courtId;
  final String branchName;
  final String courtName;
  final String date; // "yyyy-MM-dd"
  final int startMinutes;
  final int durationMinutes;
  final String userId;
  final String userName;
  final String userPhone;
  final double price;
  final String? happyHourLabel; // set when a happy hour rule was applied
  final BookingStatus status;
  final bool isBlock; // true = owner block (maintenance / private event)
  final String? note; // reason for a block
  final DateTime? createdAt;
  final String paymentStatus;

  /// Set when the owner turned this booking into an Open Match.
  final bool isOpenMatch;
  final String? openMatchId;

  /// Set to true by the Cloud Function once XP was granted (after the
  /// game time has passed).
  final bool xpAwarded;

  /// Voucher applied at checkout (if any) and how much it saved.
  final String? voucherCode;
  final double voucherDiscount;

  /// Academy lesson fields (the student is userId/userName).
  final bool isLesson;
  final String? coachId;
  final String? coachName;
  final String? sessionType; // private | semi | group

  const Booking({
    required this.id,
    required this.branchId,
    required this.courtId,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.price,
    this.happyHourLabel,
    required this.status,
    this.isBlock = false,
    this.note,
    this.createdAt,
    this.paymentStatus = 'pay_at_club',
    this.isOpenMatch = false,
    this.openMatchId,
    this.xpAwarded = false,
    this.voucherCode,
    this.voucherDiscount = 0,
    this.isLesson = false,
    this.coachId,
    this.coachName,
    this.sessionType,
  });

  int get endMinutes => startMinutes + durationMinutes;

  DateTime get startDateTime => dateTimeOf(parseDateKey(date), startMinutes);

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Booking(
      id: doc.id,
      branchId: (data['branchId'] as String?) ?? '',
      courtId: (data['courtId'] as String?) ?? '',
      branchName: (data['branchName'] as String?) ?? '',
      courtName: (data['courtName'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      userPhone: (data['userPhone'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      happyHourLabel: data['happyHourLabel'] as String?,
      status: data['status'] == 'cancelled'
          ? BookingStatus.cancelled
          : BookingStatus.confirmed,
      isBlock: (data['isBlock'] as bool?) ?? false,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      paymentStatus: (data['paymentStatus'] as String?) ?? 'pay_at_club',
      isOpenMatch: (data['isOpenMatch'] as bool?) ?? false,
      openMatchId: data['openMatchId'] as String?,
      xpAwarded: (data['xpAwarded'] as bool?) ?? false,
      voucherCode: data['voucherCode'] as String?,
      voucherDiscount: (data['voucherDiscount'] as num?)?.toDouble() ?? 0,
      isLesson: (data['isLesson'] as bool?) ?? false,
      coachId: data['coachId'] as String?,
      coachName: data['coachName'] as String?,
      sessionType: data['sessionType'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'branchId': branchId,
        'courtId': courtId,
        'branchName': branchName,
        'courtName': courtName,
        'date': date,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'endMinutes': endMinutes,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'price': price,
        'happyHourLabel': happyHourLabel,
        'status': status == BookingStatus.cancelled ? 'cancelled' : 'confirmed',
        'isBlock': isBlock,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'paymentStatus': paymentStatus,
        'isOpenMatch': isOpenMatch,
        'openMatchId': openMatchId,
        'xpAwarded': false,
        'voucherCode': voucherCode,
        'voucherDiscount': voucherDiscount,
        'isLesson': isLesson,
        'coachId': coachId,
        'coachName': coachName,
        'sessionType': sessionType,
      };
}
