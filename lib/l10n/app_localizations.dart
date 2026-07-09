import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Padel Club'**
  String get appTitle;

  /// No description provided for @bookTab.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookTab;

  /// No description provided for @myBookingsTab.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookingsTab;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @emailTab.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailTab;

  /// No description provided for @phoneTab.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneTab;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get nameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+961 3 123 456'**
  String get phoneHint;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent.'**
  String get resetEmailSent;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get noAccountYet;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @smsCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get smsCodeLabel;

  /// No description provided for @verifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyCode;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get fillAllFields;

  /// No description provided for @authFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {message}'**
  String authFailed(String message);

  /// No description provided for @chooseBranch.
  ///
  /// In en, this message translates to:
  /// **'Choose a branch'**
  String get chooseBranch;

  /// No description provided for @chooseCourt.
  ///
  /// In en, this message translates to:
  /// **'Choose a court'**
  String get chooseCourt;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get chooseDate;

  /// No description provided for @chooseDuration.
  ///
  /// In en, this message translates to:
  /// **'Game duration'**
  String get chooseDuration;

  /// No description provided for @chooseTime.
  ///
  /// In en, this message translates to:
  /// **'Available start times'**
  String get chooseTime;

  /// No description provided for @indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// No description provided for @outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get outdoor;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationLabel(int minutes);

  /// No description provided for @happyHourTag.
  ///
  /// In en, this message translates to:
  /// **'Happy Hour 🎉'**
  String get happyHourTag;

  /// No description provided for @noSlotsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No free times for this duration. Try another date or duration.'**
  String get noSlotsAvailable;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @priceUsd.
  ///
  /// In en, this message translates to:
  /// **'\${price}'**
  String priceUsd(String price);

  /// No description provided for @confirmBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get confirmBookingTitle;

  /// No description provided for @bookingSummary.
  ///
  /// In en, this message translates to:
  /// **'Booking summary'**
  String get bookingSummary;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total price'**
  String get totalPrice;

  /// No description provided for @payAtClub.
  ///
  /// In en, this message translates to:
  /// **'Payment is made at the club.'**
  String get payAtClub;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get confirmButton;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed! 🎾'**
  String get bookingConfirmed;

  /// No description provided for @reminderScheduled.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you 2 hours before your game.'**
  String get reminderScheduled;

  /// No description provided for @slotTaken.
  ///
  /// In en, this message translates to:
  /// **'Sorry, that time was just booked by someone else. Please pick another slot.'**
  String get slotTaken;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your padel game is in 2 hours!'**
  String get reminderTitle;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @noBookingsYet.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet. Book your first game!'**
  String get noBookingsYet;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @cancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get cancelConfirmTitle;

  /// No description provided for @cancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will free the court for other players.'**
  String get cancelConfirmBody;

  /// No description provided for @keepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepBooking;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get yesCancel;

  /// No description provided for @cancelTooLate.
  ///
  /// In en, this message translates to:
  /// **'Bookings can only be cancelled up to 3 hours before the game.'**
  String get cancelTooLate;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled.'**
  String get bookingCancelled;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get adminTitle;

  /// No description provided for @dashboardTab.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTab;

  /// No description provided for @dayGridTab.
  ///
  /// In en, this message translates to:
  /// **'Day view'**
  String get dayGridTab;

  /// No description provided for @pricingTab.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricingTab;

  /// No description provided for @revenueTab.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueTab;

  /// No description provided for @allBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get allBranches;

  /// No description provided for @allCourts.
  ///
  /// In en, this message translates to:
  /// **'All courts'**
  String get allCourts;

  /// No description provided for @bookingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bookings'**
  String bookingsCount(int count);

  /// No description provided for @blockedLabel.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED'**
  String get blockedLabel;

  /// No description provided for @blockTime.
  ///
  /// In en, this message translates to:
  /// **'Block time'**
  String get blockTime;

  /// No description provided for @blockReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (e.g. maintenance)'**
  String get blockReasonLabel;

  /// No description provided for @blockButton.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockButton;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @invalidTimeRange.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time.'**
  String get invalidTimeRange;

  /// No description provided for @blockOverlap.
  ///
  /// In en, this message translates to:
  /// **'That range overlaps an existing booking or block.'**
  String get blockOverlap;

  /// No description provided for @adminCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this customer\'s booking?'**
  String get adminCancelConfirm;

  /// No description provided for @customerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customerLabel;

  /// No description provided for @basePrices.
  ///
  /// In en, this message translates to:
  /// **'Base prices (USD)'**
  String get basePrices;

  /// No description provided for @editPricesFor.
  ///
  /// In en, this message translates to:
  /// **'Prices — {court}'**
  String editPricesFor(String court);

  /// No description provided for @happyHourRules.
  ///
  /// In en, this message translates to:
  /// **'Happy hour rules'**
  String get happyHourRules;

  /// No description provided for @newRule.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get newRule;

  /// No description provided for @editRule.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get editRule;

  /// No description provided for @ruleLabelField.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleLabelField;

  /// No description provided for @daysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get daysLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @courtsLabel.
  ///
  /// In en, this message translates to:
  /// **'Courts'**
  String get courtsLabel;

  /// No description provided for @allCourtsOption.
  ///
  /// In en, this message translates to:
  /// **'All courts'**
  String get allCourtsOption;

  /// No description provided for @discountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get discountTypeLabel;

  /// No description provided for @percentOff.
  ///
  /// In en, this message translates to:
  /// **'Percent off'**
  String get percentOff;

  /// No description provided for @fixedPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed price (USD)'**
  String get fixedPriceLabel;

  /// No description provided for @percentValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Percent (e.g. 20)'**
  String get percentValueLabel;

  /// No description provided for @fixedValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Price in USD'**
  String get fixedValueLabel;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @deleteRule.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get deleteRule;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// No description provided for @seedButton.
  ///
  /// In en, this message translates to:
  /// **'Initialize club data (first run)'**
  String get seedButton;

  /// No description provided for @seedDone.
  ///
  /// In en, this message translates to:
  /// **'Branches and courts created!'**
  String get seedDone;

  /// No description provided for @seedSkipped.
  ///
  /// In en, this message translates to:
  /// **'Club data already exists.'**
  String get seedSkipped;

  /// No description provided for @revenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Expected revenue'**
  String get revenueTitle;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @thisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'This week (Mon–Sun)'**
  String get thisWeekLabel;

  /// No description provided for @revenueNote.
  ///
  /// In en, this message translates to:
  /// **'Based on confirmed bookings (blocks excluded).'**
  String get revenueNote;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String genericError(String message);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @firebaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not connected yet'**
  String get firebaseNotConfigured;

  /// No description provided for @firebaseSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Follow SETUP.md in the project to create your Firebase project, then run: flutterfire configure'**
  String get firebaseSetupHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
