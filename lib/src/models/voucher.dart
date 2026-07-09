import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/time_utils.dart';

/// An owner-created discount code (e.g. RAMADAN20). The code itself is
/// the document id, stored uppercase. Usage counters are updated inside
/// the booking transaction so limits hold even with simultaneous use.
class Voucher {
  final String code;
  final String discountType; // 'percent' | 'fixed'
  final double value; // percent off, or USD amount off
  final String expiry; // last valid day, yyyy-MM-dd
  final int maxUses;
  final int maxUsesPerCustomer;
  final List<String> branchIds; // empty = all branches
  final bool active;
  final int uses;
  final double totalDiscount;
  final Map<String, int> usesByUser;

  const Voucher({
    required this.code,
    required this.discountType,
    required this.value,
    required this.expiry,
    required this.maxUses,
    required this.maxUsesPerCustomer,
    required this.branchIds,
    required this.active,
    this.uses = 0,
    this.totalDiscount = 0,
    this.usesByUser = const {},
  });

  factory Voucher.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Voucher(
      code: doc.id,
      discountType: (data['discountType'] as String?) ?? 'percent',
      value: (data['value'] as num?)?.toDouble() ?? 0,
      expiry: (data['expiry'] as String?) ?? '',
      maxUses: (data['maxUses'] as num?)?.toInt() ?? 0,
      maxUsesPerCustomer:
          (data['maxUsesPerCustomer'] as num?)?.toInt() ?? 1,
      branchIds: List<String>.from(data['branchIds'] ?? const []),
      active: (data['active'] as bool?) ?? false,
      uses: (data['uses'] as num?)?.toInt() ?? 0,
      totalDiscount: (data['totalDiscount'] as num?)?.toDouble() ?? 0,
      usesByUser: Map<String, int>.from(
          (data['usesByUser'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, (v as num).toInt()))),
    );
  }

  Map<String, dynamic> toMap() => {
        'discountType': discountType,
        'value': value,
        'expiry': expiry,
        'maxUses': maxUses,
        'maxUsesPerCustomer': maxUsesPerCustomer,
        'branchIds': branchIds,
        'active': active,
        'uses': uses,
        'totalDiscount': totalDiscount,
        'usesByUser': usesByUser,
      };

  /// Why this voucher can't be used right now — or null when it can.
  String? rejectionReason(String uid, String branchId) {
    if (!active) return 'This code is not active.';
    if (expiry.isNotEmpty && expiry.compareTo(dateKey(DateTime.now())) < 0) {
      return 'This code has expired.';
    }
    if (branchIds.isNotEmpty && !branchIds.contains(branchId)) {
      return 'This code is not valid at this branch.';
    }
    if (maxUses > 0 && uses >= maxUses) {
      return 'This code has reached its usage limit.';
    }
    if (maxUsesPerCustomer > 0 &&
        (usesByUser[uid] ?? 0) >= maxUsesPerCustomer) {
      return 'You have already used this code the maximum number of times.';
    }
    return null;
  }

  /// Price after applying this voucher.
  double apply(double price) {
    final discounted = discountType == 'percent'
        ? price * (1 - value / 100)
        : price - value;
    return ((discounted.clamp(0, price)) * 100).roundToDouble() / 100;
  }
}
