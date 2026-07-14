import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/models/app_user.dart';
import 'package:padel_app/src/models/booking.dart';
import 'package:padel_app/src/models/package_offer.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/utils/time_utils.dart';

Booking booking({double walletUsed = 0, int start = 18 * 60}) => Booking(
      id: '',
      branchId: 'airport-road',
      courtId: 'court-1',
      branchName: 'Airport Road',
      courtName: 'Court 1',
      date: dateKey(DateTime.now().add(const Duration(days: 1))),
      startMinutes: start,
      durationMinutes: 60,
      userId: 'u1',
      userName: 'Test',
      userPhone: '+9613123456',
      price: 30,
      status: BookingStatus.confirmed,
      walletUsed: walletUsed,
    );

void main() {
  test('grantPackage credits the wallet with the right expiry', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({'name': 'Test'});
    final service = FirestoreService(db);
    const user = AppUser(
        uid: 'u1',
        name: 'Test',
        phone: '+9613123456',
        email: 't@x.com',
        role: 'customer');
    const pack = PackageOffer(
        id: 'p1',
        name: 'Gold',
        price: 300,
        credit: 400,
        validityDays: 30,
        active: true);

    await service.grantPackage(user, pack);

    final doc = await db.collection('users').doc('u1').get();
    expect(doc.get('walletBalance'), 400);
    expect(
        doc.get('walletExpiry'),
        dateKey(DateTime.now().add(const Duration(days: 30))));
    final log = await db.collection('walletTopUps').get();
    expect(log.docs.single.get('paid'), 300);
  });

  test('booking with wallet decrements the balance atomically', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'name': 'Test',
      'walletBalance': 100.0,
      'walletExpiry':
          dateKey(DateTime.now().add(const Duration(days: 10))),
    });
    final service = FirestoreService(db);

    await service.createBooking(booking(walletUsed: 30));

    final doc = await db.collection('users').doc('u1').get();
    expect(doc.get('walletBalance'), 70);
  });

  test('booking is rejected when the wallet cannot cover it', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'name': 'Test',
      'walletBalance': 10.0,
      'walletExpiry':
          dateKey(DateTime.now().add(const Duration(days: 10))),
    });
    final service = FirestoreService(db);

    expect(() => service.createBooking(booking(walletUsed: 30)),
        throwsA(isA<WalletRejectedException>()));
  });

  test('expired wallet credit is unusable', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'name': 'Test',
      'walletBalance': 100.0,
      'walletExpiry':
          dateKey(DateTime.now().subtract(const Duration(days: 1))),
    });
    final service = FirestoreService(db);

    expect(() => service.createBooking(booking(walletUsed: 30)),
        throwsA(isA<WalletRejectedException>()));
  });
}
