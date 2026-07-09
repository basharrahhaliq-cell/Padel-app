# Padel Club — Court Booking App

A Flutter (iOS + Android) app for booking padel courts at the club's two
branches (Airport Road: 3 courts, Hazmieh: 2 courts), backed by Firebase
(Firestore + Auth + notifications).

**New here? Read [SETUP.md](SETUP.md)** — a step-by-step, no-experience-needed
guide to connecting Firebase, running the app on your phone, and publishing
to the App Store / Google Play.

## What it does

**Customers**
- Sign up with email or phone (SMS code)
- Book in seconds: branch → court → date → duration (60/90/120 min) → time
- Only start times where the *full* game fits (8 AM–11 PM, 30-min steps) are shown
- Exact price on every slot, happy-hour slots tagged 🎉
- "My bookings" with cancellation up to 3 hours before the game
- Automatic reminder notification 2 hours before each game
- Payment at the club (structure ready for online payment later)

**Owner (admin role)**
- Dashboard of all reservations, filterable by branch/court/date
- Day view: timeline grid per court showing booked ranges and gaps
- Edit base prices per court per duration; create/toggle happy hour rules
  (percent off or fixed price; by branch, courts, weekdays, time window)
- Cancel any booking; block time ranges for maintenance/events
- Expected revenue per branch, per day and week

**Under the hood**
- Double bookings are impossible: every booking runs a Firestore
  *transaction* against a per-court-per-day "day sheet" document
- Prices are stored on each booking — historical bookings keep their price
- All UI text lives in `lib/l10n/app_en.arb` → translation-ready (Arabic later)
- Core booking/pricing logic is pure Dart with unit tests (`flutter test`)

## Project layout

```
lib/
  main.dart                 app entry point
  firebase_options.dart     replaced by `flutterfire configure`
  l10n/app_en.arb           every text string in the app
  src/
    theme.dart              colors (court blue + padel-ball lime)
    models/                 Branch, Court, Booking, HappyHourRule, AppUser
    services/               Firestore, Auth, Notifications
    utils/                  slot availability + pricing engine (unit-tested)
    screens/
      auth/                 login / sign-up
      customer/             booking flow, my bookings
      admin/                dashboard, day grid, pricing, revenue
firestore.rules             database security rules (paste into Firebase)
```

## Development

```
flutter pub get
flutter analyze
flutter test
flutter run
```
