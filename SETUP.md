# Let's Padel App — Owner's Setup Guide

This guide assumes **zero coding experience**. Follow it top to bottom, one
step at a time. You only do most of this once.

---

## Part 0 — Install the tools (once, ~30 minutes)

You need a computer (Mac if you want the iPhone version — Apple requires a
Mac to build iOS apps; Windows works fine for Android).

1. **Install Flutter**: follow https://docs.flutter.dev/get-started/install
   and pick your operating system. At the end, run `flutter doctor` in a
   terminal — it tells you what's missing and how to fix it.
2. **Install Android Studio** (from the same page) — this gives you the
   Android tools even if you never open the program itself.
3. On a Mac, also install **Xcode** from the App Store (for iPhone builds).
4. Get this project onto your computer:
   ```
   git clone https://github.com/basharrahhaliq-cell/Padel-app.git
   cd Padel-app
   flutter pub get
   ```

## Part 1 — Create your Firebase project (once, ~15 minutes)

Firebase is the app's database + login system. The free tier ("Spark") is
more than enough to start.

1. Go to https://console.firebase.google.com and sign in with a Google
   account (use the club's Google account, not a personal one, if possible).
2. Click **Add project** → name it e.g. `padel-club` → Google Analytics is
   optional (you can say no) → **Create project**.
3. In the left menu open **Build → Authentication → Get started**:
   - Enable **Email/Password**.
   - Enable **Phone** (for SMS-code login). Note: SMS login is free for
     small volumes but requires the paid "Blaze" plan for production use —
     you can launch with Email only and turn Phone on later.
4. Open **Build → Firestore Database → Create database** → choose
   **Production mode** → pick the region closest to Lebanon
   (`europe-west1` is a good choice) → **Enable**.
5. Set the security rules: in Firestore click the **Rules** tab, delete
   what's there, paste the entire contents of the `firestore.rules` file
   from this project, and click **Publish**.

## Part 2 — Connect the app to YOUR Firebase (once, ~10 minutes)

In a terminal, inside the project folder:

```
dart pub global activate flutterfire_cli
flutterfire configure
```

- It asks you to log in to Firebase, then to pick your project
  (`padel-club`) and platforms — select **android** and **ios**.
- It automatically rewrites `lib/firebase_options.dart` with your project's
  keys and registers the Android/iOS apps in Firebase. That's the entire
  connection — no other file needs editing.

## Part 3 — Run it on your own phone (~10 minutes)

**Android (easiest):**
1. On the phone: Settings → About phone → tap **Build number** 7 times
   (unlocks Developer options) → Developer options → enable **USB debugging**.
2. Plug the phone into the computer, accept the prompt on the phone.
3. In the project folder run: `flutter run` — the app installs and opens.

**iPhone:** open `ios/Runner.xcworkspace` in Xcode, sign in with your Apple
ID under Signing & Capabilities, select your phone at the top, press Run.
(First run requires trusting the developer profile in iPhone Settings →
General → VPN & Device Management.)

## Part 4 — First-time app setup (5 minutes)

1. In the app, **create an account** with your own email — this makes you a
   normal customer for now.
2. Make yourself the owner: in the Firebase console open
   **Firestore Database → Data → `users`** → click the single document there
   (that's you) → change the `role` field from `customer` to `admin`.
3. Restart the app — you now land on the **Owner dashboard**.
4. Open the **Pricing** tab and tap **"Initialize club data (first run)"** —
   this creates your two branches and five courts with starter prices
   ($30/$42/$55 for 60/90/120 min).
5. Edit the base prices per court, and add your happy hour rules.
6. Create a second account (different email) on another phone — or sign out —
   to experience the customer side and make a test booking.

## Part 5 — Publishing to the stores (when you're ready)

### Google Play (Android) — ~$25 one-time fee
1. Create a developer account at https://play.google.com/console.
2. Create a **signing key** (one-time):
   ```
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Keep this file and its password safe forever — losing it means losing the
   ability to update the app. Then follow
   https://docs.flutter.dev/deployment/android to point the project at it
   (a small `android/key.properties` file).
3. Build the upload file: `flutter build appbundle`
   → the file appears at `build/app/outputs/bundle/release/app-release.aab`.
4. In Play Console: create the app, upload the `.aab`, fill in the store
   listing (name, description, screenshots — take them from your phone),
   complete the content questionnaires, and submit. First review usually
   takes a few days.

### Apple App Store (iPhone) — $99/year
1. Enroll at https://developer.apple.com (Apple Developer Program).
2. In Xcode set your **Team** under Signing & Capabilities, and a unique
   Bundle Identifier (already set to `com.padelclub.padelApp` — you can keep it).
3. Build: `flutter build ipa`, then open the generated archive in Xcode's
   **Organizer** and click **Distribute App → App Store Connect**.
4. In https://appstoreconnect.apple.com: create the app, add screenshots
   and description, pick the build you uploaded, and submit for review.
5. For phone-number login on iOS, also upload your **APNs key** in Firebase:
   Firebase console → Project settings → Cloud Messaging → Apple app
   configuration (Apple's docs walk you through creating the key).

## Everyday things you'll want to know

- **Change prices / happy hours**: Owner app → Pricing tab. Old bookings keep
  the price they were booked at.
- **Block a court** (maintenance, private event): Dashboard tab → the ⊘
  button next to the date.
- **Cancel any booking**: Dashboard tab → trash icon on the booking.
- **See the day at a glance**: Day view tab — one row per court, 8 AM–11 PM.
- **Revenue**: Revenue tab — today + this week, per branch.
- **Add Arabic later**: all app text lives in `lib/l10n/app_en.arb`. Create
  `app_ar.arb` next to it with the same keys translated, add `Locale('ar')`
  in `lib/main.dart`, and Flutter does the rest (including right-to-left).
- **Online payments later**: every booking already stores a `paymentStatus`
  field (`pay_at_club`), so a payment provider can be added without
  restructuring the database.

## If something goes wrong

- `flutter doctor` diagnoses tool problems.
- `flutter clean && flutter pub get` fixes most weird build errors.
- The app shows "Firebase is not connected yet" → Part 2 wasn't completed on
  this computer (`flutterfire configure`).
- Check Firestore data live: Firebase console → Firestore Database → Data.
