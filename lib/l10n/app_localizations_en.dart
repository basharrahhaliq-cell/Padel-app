// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Let\'s Padel';

  @override
  String get contactUsTitle => 'Contact us';

  @override
  String get contactUsHint => 'Questions? Chat with your branch on WhatsApp:';

  @override
  String whatsappButton(String branch) {
    return 'WhatsApp — $branch';
  }

  @override
  String get couldNotOpenWhatsapp => 'Could not open WhatsApp on this phone.';

  @override
  String get bookTab => 'Book';

  @override
  String get myBookingsTab => 'My Bookings';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get nameLabel => 'Full name';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '03 123 456';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetEmailSent => 'Password reset email sent.';

  @override
  String get noAccountYet => 'New here? Create an account';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get invalidPhone =>
      'Please enter a valid Lebanese phone number (e.g. 03 123 456).';

  @override
  String get skillLevelLabel => 'Your padel level';

  @override
  String get levelA => 'A — Advanced';

  @override
  String get levelB => 'B — Intermediate';

  @override
  String get levelC => 'C — Beginner–Intermediate';

  @override
  String get levelD => 'D — Beginner';

  @override
  String get marketingConsentLabel =>
      'Send me news, offers, and tournament invites';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileHint =>
      'Just a couple of details so the club can reach you about your bookings.';

  @override
  String get continueButton => 'Continue';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get fillAllFields => 'Please fill in all fields.';

  @override
  String authFailed(String message) {
    return 'Sign-in failed: $message';
  }

  @override
  String get chooseBranch => 'Choose a branch';

  @override
  String get chooseCourt => 'Choose a court';

  @override
  String get chooseDate => 'Date';

  @override
  String get chooseDuration => 'Game duration';

  @override
  String get chooseTime => 'Available start times';

  @override
  String get indoor => 'Indoor';

  @override
  String get outdoor => 'Outdoor';

  @override
  String durationLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String get happyHourTag => 'Happy Hour 🎉';

  @override
  String get noSlotsAvailable =>
      'No free times for this duration. Try another date or duration.';

  @override
  String get price => 'Price';

  @override
  String priceUsd(String price) {
    return '\$$price';
  }

  @override
  String get confirmBookingTitle => 'Confirm booking';

  @override
  String get bookingSummary => 'Booking summary';

  @override
  String get totalPrice => 'Total price';

  @override
  String get payAtClub => 'Payment is made at the club.';

  @override
  String get confirmButton => 'Confirm booking';

  @override
  String get bookingConfirmed => 'Booking confirmed! 🎾';

  @override
  String get reminderScheduled => 'We\'ll remind you 2 hours before your game.';

  @override
  String get slotTaken =>
      'Sorry, that time was just booked by someone else. Please pick another slot.';

  @override
  String get reminderTitle => 'Your padel game is in 2 hours!';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get noBookingsYet => 'No bookings yet. Book your first game!';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get cancelConfirmTitle => 'Cancel this booking?';

  @override
  String get cancelConfirmBody => 'This will free the court for other players.';

  @override
  String get keepBooking => 'Keep it';

  @override
  String get yesCancel => 'Yes, cancel';

  @override
  String get cancelTooLate =>
      'Bookings can only be cancelled up to 3 hours before the game.';

  @override
  String get bookingCancelled => 'Booking cancelled.';

  @override
  String get adminTitle => 'Owner';

  @override
  String get dashboardTab => 'Dashboard';

  @override
  String get dayGridTab => 'Day view';

  @override
  String get pricingTab => 'Pricing';

  @override
  String get revenueTab => 'Revenue';

  @override
  String get allBranches => 'All branches';

  @override
  String get allCourts => 'All courts';

  @override
  String bookingsCount(int count) {
    return '$count bookings';
  }

  @override
  String get blockedLabel => 'BLOCKED';

  @override
  String get blockTime => 'Block time';

  @override
  String get blockReasonLabel => 'Reason (e.g. maintenance)';

  @override
  String get blockButton => 'Block';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get invalidTimeRange => 'End time must be after start time.';

  @override
  String get blockOverlap =>
      'That range overlaps an existing booking or block.';

  @override
  String get adminCancelConfirm => 'Cancel this customer\'s booking?';

  @override
  String get customerLabel => 'Customer';

  @override
  String get basePrices => 'Base prices (USD)';

  @override
  String editPricesFor(String court) {
    return 'Prices — $court';
  }

  @override
  String get happyHourRules => 'Happy hour rules';

  @override
  String get newRule => 'New rule';

  @override
  String get editRule => 'Edit rule';

  @override
  String get ruleLabelField => 'Rule name';

  @override
  String get daysLabel => 'Days';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get courtsLabel => 'Courts';

  @override
  String get allCourtsOption => 'All courts';

  @override
  String get discountTypeLabel => 'Discount type';

  @override
  String get percentOff => 'Percent off';

  @override
  String get fixedPriceLabel => 'Fixed price (USD)';

  @override
  String get percentValueLabel => 'Percent (e.g. 20)';

  @override
  String get fixedValueLabel => 'Price in USD';

  @override
  String get activeLabel => 'Active';

  @override
  String get deleteRule => 'Delete rule';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved.';

  @override
  String get seedButton => 'Initialize club data (first run)';

  @override
  String get seedDone => 'Branches and courts created!';

  @override
  String get seedSkipped => 'Club data already exists.';

  @override
  String get revenueTitle => 'Expected revenue';

  @override
  String get todayLabel => 'Today';

  @override
  String get thisWeekLabel => 'This week (Mon–Sun)';

  @override
  String get revenueNote => 'Based on confirmed bookings (blocks excluded).';

  @override
  String genericError(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get loading => 'Loading…';

  @override
  String get firebaseNotConfigured => 'Firebase is not connected yet';

  @override
  String get firebaseSetupHint =>
      'Follow SETUP.md in the project to create your Firebase project, then run: flutterfire configure';
}
