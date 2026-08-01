import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_dag.dart';
import 'app_localizations_ee.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tw.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('dag'),
    Locale('ee'),
    Locale('en'),
    Locale('tw')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI'**
  String get appTitle;

  /// Confirm outbreak report
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get outbreakConfirm;

  /// Flag outbreak report as incorrect
  ///
  /// In en, this message translates to:
  /// **'Flag Incorrect'**
  String get outbreakFlagIncorrect;

  /// Zoom to outbreak location
  ///
  /// In en, this message translates to:
  /// **'Zoom to outbreak'**
  String get outbreakZoomToOutbreak;

  /// Title when nearby outbreak is detected
  ///
  /// In en, this message translates to:
  /// **'Nearby Outbreak Detected'**
  String get outbreakNearbyDetectedTitle;

  /// Submit report anyway
  ///
  /// In en, this message translates to:
  /// **'Submit Anyway'**
  String get outbreakSubmitAnyway;

  /// Confirm existing outbreak report
  ///
  /// In en, this message translates to:
  /// **'Confirm Existing'**
  String get outbreakConfirmExisting;

  /// Retry loading outbreak map
  ///
  /// In en, this message translates to:
  /// **'Retry Map'**
  String get outbreakRetryMap;

  /// Report disease to outbreak map
  ///
  /// In en, this message translates to:
  /// **'Report to Outbreak Map'**
  String get reportToOutbreakMap;

  /// Post disease to community
  ///
  /// In en, this message translates to:
  /// **'Post to Community'**
  String get postToCommunity;

  /// Scan engine unavailable message
  ///
  /// In en, this message translates to:
  /// **'Scan Engine Unavailable'**
  String get scanEngineUnavailable;

  /// Ask community button
  ///
  /// In en, this message translates to:
  /// **'Ask Community'**
  String get askCommunity;

  /// Add photo button
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get outbreakAddPhoto;

  /// Security warning dialog title
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarningTitle;

  /// Proceed anyway button
  ///
  /// In en, this message translates to:
  /// **'Proceed Anyway'**
  String get proceedAnyway;

  /// Show password tooltip
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPasswordTooltip;

  /// Hide password tooltip
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePasswordTooltip;

  /// Turn flashlight on tooltip
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight on'**
  String get torchOnTooltip;

  /// Turn flashlight off tooltip
  ///
  /// In en, this message translates to:
  /// **'Turn flashlight off'**
  String get torchOffTooltip;

  /// Turn on batch scanning tooltip
  ///
  /// In en, this message translates to:
  /// **'Turn on batch scanning'**
  String get batchModeOnTooltip;

  /// Turn off batch scanning tooltip
  ///
  /// In en, this message translates to:
  /// **'Turn off batch scanning'**
  String get batchModeOffTooltip;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @startScanning.
  ///
  /// In en, this message translates to:
  /// **'Start Scanning'**
  String get startScanning;

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent Scans'**
  String get recentScans;

  /// No description provided for @noRecentScans.
  ///
  /// In en, this message translates to:
  /// **'No recent scans found'**
  String get noRecentScans;

  /// No description provided for @farmHealth.
  ///
  /// In en, this message translates to:
  /// **'Farm Health'**
  String get farmHealth;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @guestLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get guestLogin;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline — using local data'**
  String get offlineBanner;

  /// No description provided for @weakConnectionBanner.
  ///
  /// In en, this message translates to:
  /// **'Weak connection — some features may be slow'**
  String get weakConnectionBanner;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App preferences & data'**
  String get settingsSubtitle;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @sectionDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get sectionDisplay;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @largeTextMode.
  ///
  /// In en, this message translates to:
  /// **'Large Text Mode'**
  String get largeTextMode;

  /// No description provided for @showConfidenceScore.
  ///
  /// In en, this message translates to:
  /// **'Show Confidence Score'**
  String get showConfidenceScore;

  /// No description provided for @sectionModelData.
  ///
  /// In en, this message translates to:
  /// **'Model & Data'**
  String get sectionModelData;

  /// No description provided for @modelVersion.
  ///
  /// In en, this message translates to:
  /// **'Model Version'**
  String get modelVersion;

  /// No description provided for @modelVersionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get modelVersionActive;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check Updates'**
  String get checkUpdates;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingUpdates;

  /// No description provided for @clearScanHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Scan History'**
  String get clearScanHistory;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI provides guidance only. Always consult a qualified agricultural expert for critical decisions.'**
  String get disclaimer;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Scan History?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all scan records. This cannot be undone.'**
  String get clearHistoryBody;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure? This will permanently delete your account and all cloud data.'**
  String get deleteAccountBody;

  /// No description provided for @yesIAmSure.
  ///
  /// In en, this message translates to:
  /// **'Yes, I am sure'**
  String get yesIAmSure;

  /// No description provided for @confirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmDeletion;

  /// No description provided for @reauthDescription.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your credentials to permanently delete your account.'**
  String get reauthDescription;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'DELETE PERMANENTLY'**
  String get deletePermanently;

  /// No description provided for @confirmWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Confirm with Google'**
  String get confirmWithGoogle;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @profilePhotoUrl.
  ///
  /// In en, this message translates to:
  /// **'Profile photo URL'**
  String get profilePhotoUrl;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// No description provided for @totalScans.
  ///
  /// In en, this message translates to:
  /// **'Total Scans'**
  String get totalScans;

  /// No description provided for @healthScore.
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get healthScore;

  /// No description provided for @diseases.
  ///
  /// In en, this message translates to:
  /// **'Diseases'**
  String get diseases;

  /// No description provided for @diseaseAlerts.
  ///
  /// In en, this message translates to:
  /// **'Disease Alerts'**
  String get diseaseAlerts;

  /// No description provided for @highQualityScans.
  ///
  /// In en, this message translates to:
  /// **'High Quality Scans'**
  String get highQualityScans;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @outbreakMap.
  ///
  /// In en, this message translates to:
  /// **'Outbreak Map'**
  String get outbreakMap;

  /// No description provided for @reportDiseaseHere.
  ///
  /// In en, this message translates to:
  /// **'Report Disease Here'**
  String get reportDiseaseHere;

  /// No description provided for @recentDiseaseReports.
  ///
  /// In en, this message translates to:
  /// **'Recent Disease Reports'**
  String get recentDiseaseReports;

  /// No description provided for @noOutbreakReports.
  ///
  /// In en, this message translates to:
  /// **'No outbreak reports yet.'**
  String get noOutbreakReports;

  /// No description provided for @couldNotLoadReports.
  ///
  /// In en, this message translates to:
  /// **'Could not load outbreak reports.'**
  String get couldNotLoadReports;

  /// No description provided for @outbreakReported.
  ///
  /// In en, this message translates to:
  /// **'Outbreak reported. Thank you!'**
  String get outbreakReported;

  /// No description provided for @failedToSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report.'**
  String get failedToSubmitReport;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional notes (optional)'**
  String get additionalNotes;

  /// No description provided for @diseaseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Disease Library'**
  String get diseaseLibrary;

  /// No description provided for @diseaseLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse all supported crops and their known diseases'**
  String get diseaseLibrarySubtitle;

  /// No description provided for @searchCropOrDisease.
  ///
  /// In en, this message translates to:
  /// **'Search crop or disease…'**
  String get searchCropOrDisease;

  /// No description provided for @noDiseasesMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No diseases match your search.'**
  String get noDiseasesMatchSearch;

  /// No description provided for @causeLabel.
  ///
  /// In en, this message translates to:
  /// **'Cause'**
  String get causeLabel;

  /// No description provided for @treatmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get treatmentLabel;

  /// No description provided for @farmHealthScore.
  ///
  /// In en, this message translates to:
  /// **'Farm Health Score'**
  String get farmHealthScore;

  /// No description provided for @healthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// No description provided for @diseased.
  ///
  /// In en, this message translates to:
  /// **'Diseased'**
  String get diseased;

  /// No description provided for @couldNotLoadFarmData.
  ///
  /// In en, this message translates to:
  /// **'Could not load farm data'**
  String get couldNotLoadFarmData;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @scanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan Now'**
  String get scanNow;

  /// No description provided for @scanNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect crop diseases instantly'**
  String get scanNowSubtitle;

  /// No description provided for @exploreSection.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreSection;

  /// No description provided for @outbreaks.
  ///
  /// In en, this message translates to:
  /// **'Outbreaks'**
  String get outbreaks;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @climateIntelligence.
  ///
  /// In en, this message translates to:
  /// **'Climate Intelligence'**
  String get climateIntelligence;

  /// No description provided for @sevenDayScanTrend.
  ///
  /// In en, this message translates to:
  /// **'7-Day Scan Trend'**
  String get sevenDayScanTrend;

  /// No description provided for @tipOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Tip of the Day'**
  String get tipOfTheDay;

  /// No description provided for @myCrops.
  ///
  /// In en, this message translates to:
  /// **'My Crops'**
  String get myCrops;

  /// No description provided for @addCrop.
  ///
  /// In en, this message translates to:
  /// **'Add Crop'**
  String get addCrop;

  /// No description provided for @cropType.
  ///
  /// In en, this message translates to:
  /// **'Crop Type'**
  String get cropType;

  /// No description provided for @addCropPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a crop to track planting milestones and get reminders.'**
  String get addCropPrompt;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @addedToBatch.
  ///
  /// In en, this message translates to:
  /// **'Added to batch ({count})'**
  String addedToBatch(int count);

  /// No description provided for @analyseBatch.
  ///
  /// In en, this message translates to:
  /// **'Analyse batch ({count})'**
  String analyseBatch(int count);

  /// No description provided for @batchImages.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String batchImages(int count);

  /// No description provided for @scanCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Crop'**
  String get scanCropTitle;

  /// No description provided for @cameraRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera & Storage Access Required'**
  String get cameraRequiredTitle;

  /// No description provided for @cameraRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'To detect crop diseases, CropGuard AI needs permission to use your camera to scan leaves, and access your gallery to upload existing crop photos.'**
  String get cameraRequiredDesc;

  /// No description provided for @grantPermissions.
  ///
  /// In en, this message translates to:
  /// **'Grant Permissions'**
  String get grantPermissions;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @initialisingCamera.
  ///
  /// In en, this message translates to:
  /// **'Initializing camera…'**
  String get initialisingCamera;

  /// No description provided for @scanGuidance.
  ///
  /// In en, this message translates to:
  /// **'Centre a single leaf inside the frame'**
  String get scanGuidance;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @urlLabel.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get urlLabel;

  /// No description provided for @analyse.
  ///
  /// In en, this message translates to:
  /// **'Analyse'**
  String get analyse;

  /// No description provided for @analysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing…'**
  String get analysing;

  /// No description provided for @batchModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Mode'**
  String get batchModeTitle;

  /// No description provided for @batchModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture multiple leaves and analyze them all at once. Great for checking a whole field quickly.'**
  String get batchModeDesc;

  /// No description provided for @turnOnBatchMode.
  ///
  /// In en, this message translates to:
  /// **'Turn ON Batch Mode'**
  String get turnOnBatchMode;

  /// No description provided for @scanFromUrl.
  ///
  /// In en, this message translates to:
  /// **'Scan from URL'**
  String get scanFromUrl;

  /// No description provided for @scanFromUrlDesc.
  ///
  /// In en, this message translates to:
  /// **'Paste a link to a crop photo (e.g. from WhatsApp or the web).'**
  String get scanFromUrlDesc;

  /// No description provided for @imageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrlLabel;

  /// No description provided for @qualityLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get qualityLighting;

  /// No description provided for @qualityFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get qualityFocus;

  /// No description provided for @qualityPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get qualityPlacement;

  /// No description provided for @qualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get qualityGood;

  /// No description provided for @qualityFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get qualityFair;

  /// No description provided for @qualityPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor image quality detected.'**
  String get qualityPoor;

  /// No description provided for @healthyCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Healthy Crop'**
  String get healthyCropTitle;

  /// No description provided for @diseaseDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Disease Detected'**
  String get diseaseDetectedTitle;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image no longer available'**
  String get imageUnavailable;

  /// No description provided for @cropCareTips.
  ///
  /// In en, this message translates to:
  /// **'Crop Care Tips'**
  String get cropCareTips;

  /// No description provided for @treatmentSteps.
  ///
  /// In en, this message translates to:
  /// **'Treatment Steps'**
  String get treatmentSteps;

  /// No description provided for @bestSprayWindow.
  ///
  /// In en, this message translates to:
  /// **'Best Spray Window'**
  String get bestSprayWindow;

  /// No description provided for @requestExpertHelp.
  ///
  /// In en, this message translates to:
  /// **'Request Expert Help'**
  String get requestExpertHelp;

  /// No description provided for @scanAnotherCrop.
  ///
  /// In en, this message translates to:
  /// **'Scan Another Crop'**
  String get scanAnotherCrop;

  /// No description provided for @feedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Was this diagnosis wrong?'**
  String get feedbackPrompt;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get feedbackThanks;

  /// No description provided for @cropNotFoundPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t see your crop here?'**
  String get cropNotFoundPrompt;

  /// No description provided for @cropReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Crop report submitted. Thank you!'**
  String get cropReportSubmitted;

  /// No description provided for @trackTreatmentPlan.
  ///
  /// In en, this message translates to:
  /// **'Track Treatment Plan'**
  String get trackTreatmentPlan;

  /// No description provided for @treatmentPlanSaved.
  ///
  /// In en, this message translates to:
  /// **'Treatment Plan Saved!'**
  String get treatmentPlanSaved;

  /// No description provided for @expertHelpDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe your situation and an agronomist will respond.'**
  String get expertHelpDesc;

  /// No description provided for @expertHelpHint.
  ///
  /// In en, this message translates to:
  /// **'My crops are showing…'**
  String get expertHelpHint;

  /// No description provided for @correctDiagnosisTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct the Diagnosis'**
  String get correctDiagnosisTitle;

  /// No description provided for @correctDiagnosisDesc.
  ///
  /// In en, this message translates to:
  /// **'What is the correct diagnosis?'**
  String get correctDiagnosisDesc;

  /// No description provided for @searchDiseaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Search disease label…'**
  String get searchDiseaseLabel;

  /// No description provided for @reportMissingCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Missing Crop'**
  String get reportMissingCropTitle;

  /// No description provided for @reportMissingCropDescResult.
  ///
  /// In en, this message translates to:
  /// **'Help us improve! What crop is this and what do you see?'**
  String get reportMissingCropDescResult;

  /// No description provided for @cropNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop Name (e.g. Cocoa, Cashew)'**
  String get cropNameLabel;

  /// No description provided for @symptomsObservedLabel.
  ///
  /// In en, this message translates to:
  /// **'Symptoms observed'**
  String get symptomsObservedLabel;

  /// No description provided for @symptomsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. brown spots, wilting leaves…'**
  String get symptomsHint;

  /// No description provided for @analysingDesc.
  ///
  /// In en, this message translates to:
  /// **'Running AI disease detection on your crop image.'**
  String get analysingDesc;

  /// No description provided for @scanHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get scanHistoryTitle;

  /// No description provided for @searchHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search by crop or disease…'**
  String get searchHistoryHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get filterHealthy;

  /// No description provided for @filterDiseased.
  ///
  /// In en, this message translates to:
  /// **'Diseased'**
  String get filterDiseased;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// No description provided for @sortMostConfident.
  ///
  /// In en, this message translates to:
  /// **'Most confident first'**
  String get sortMostConfident;

  /// No description provided for @sortLeastConfident.
  ///
  /// In en, this message translates to:
  /// **'Least confident first'**
  String get sortLeastConfident;

  /// No description provided for @sortByCrop.
  ///
  /// In en, this message translates to:
  /// **'By crop type'**
  String get sortByCrop;

  /// No description provided for @comparisonModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Comparison Mode'**
  String get comparisonModeLabel;

  /// No description provided for @exportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected'**
  String get exportSelected;

  /// No description provided for @monthlySummary.
  ///
  /// In en, this message translates to:
  /// **'Monthly Summary'**
  String get monthlySummary;

  /// No description provided for @compareScans.
  ///
  /// In en, this message translates to:
  /// **'Compare Scans'**
  String get compareScans;

  /// No description provided for @scanDeleted.
  ///
  /// In en, this message translates to:
  /// **'Scan deleted'**
  String get scanDeleted;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @noScansFound.
  ///
  /// In en, this message translates to:
  /// **'No scans found'**
  String get noScansFound;

  /// No description provided for @noScansFoundDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan a crop to build your history'**
  String get noScansFoundDesc;

  /// No description provided for @shareUpdate.
  ///
  /// In en, this message translates to:
  /// **'Share an update'**
  String get shareUpdate;

  /// No description provided for @farmUpdate.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening on your farm?'**
  String get farmUpdate;

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image…'**
  String get uploadingImage;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @noPostsDesc.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share an update with other farmers.'**
  String get noPostsDesc;

  /// No description provided for @expertResponse.
  ///
  /// In en, this message translates to:
  /// **'Expert Response'**
  String get expertResponse;

  /// No description provided for @reportPost.
  ///
  /// In en, this message translates to:
  /// **'Report Post'**
  String get reportPost;

  /// No description provided for @reportPostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to report this post for inappropriate content?'**
  String get reportPostConfirm;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @communitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with other farmers'**
  String get communitySubtitle;

  /// No description provided for @diseaseLibrarySubtitleMore.
  ///
  /// In en, this message translates to:
  /// **'Learn about crop threats'**
  String get diseaseLibrarySubtitleMore;

  /// No description provided for @outbreakMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See nearby disease reports'**
  String get outbreakMapSubtitle;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @achievementsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your farming milestones'**
  String get achievementsSubtitle;

  /// No description provided for @treatmentTracker.
  ///
  /// In en, this message translates to:
  /// **'Treatment Tracker'**
  String get treatmentTracker;

  /// No description provided for @treatmentTrackerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow your crop treatment plans'**
  String get treatmentTrackerSubtitle;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your farm stats and preferences'**
  String get profileSubtitle;

  /// No description provided for @settingsSubtitleMore.
  ///
  /// In en, this message translates to:
  /// **'Language, display, and data'**
  String get settingsSubtitleMore;

  /// No description provided for @aboutCropGuard.
  ///
  /// In en, this message translates to:
  /// **'About CropGuard AI'**
  String get aboutCropGuard;

  /// No description provided for @aboutCropGuardDesc.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI is your assistant for healthier crops.'**
  String get aboutCropGuardDesc;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your CropGuard account'**
  String get loginSubtitle;

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email first'**
  String get enterEmailFirst;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @keepGuestScansTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your guest scans?'**
  String get keepGuestScansTitle;

  /// No description provided for @keepScans.
  ///
  /// In en, this message translates to:
  /// **'Keep Scans'**
  String get keepScans;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join CropGuard AI today'**
  String get registerSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @agreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get agreeToThe;

  /// No description provided for @hasAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get hasAccountPrompt;

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Strength:'**
  String get passwordStrengthLabel;

  /// No description provided for @strengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get strengthFair;

  /// No description provided for @strengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strengthStrong;

  /// No description provided for @strengthVeryStrong.
  ///
  /// In en, this message translates to:
  /// **'Very Strong'**
  String get strengthVeryStrong;

  /// No description provided for @batchScanSummary.
  ///
  /// In en, this message translates to:
  /// **'Batch Scan Summary'**
  String get batchScanSummary;

  /// No description provided for @aggregatedResult.
  ///
  /// In en, this message translates to:
  /// **'Aggregated Result'**
  String get aggregatedResult;

  /// No description provided for @individualLeafResults.
  ///
  /// In en, this message translates to:
  /// **'Individual Leaf Results'**
  String get individualLeafResults;

  /// No description provided for @scanAnotherBatch.
  ///
  /// In en, this message translates to:
  /// **'Scan Another Batch'**
  String get scanAnotherBatch;

  /// No description provided for @noResultsLoaded.
  ///
  /// In en, this message translates to:
  /// **'No results loaded'**
  String get noResultsLoaded;

  /// No description provided for @percentConfidence.
  ///
  /// In en, this message translates to:
  /// **'{pct}% confidence'**
  String percentConfidence(int pct);

  /// No description provided for @lowConfidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Confidence'**
  String get lowConfidenceTitle;

  /// No description provided for @lowConfidenceResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Low Confidence Result'**
  String get lowConfidenceResultTitle;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @cropNotInList.
  ///
  /// In en, this message translates to:
  /// **'My crop is not in the list'**
  String get cropNotInList;

  /// No description provided for @reportSubmittedThanks.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you!'**
  String get reportSubmittedThanks;

  /// No description provided for @reportMissingCropDesc.
  ///
  /// In en, this message translates to:
  /// **'What crop are you scanning? This helps us train our AI.'**
  String get reportMissingCropDesc;

  /// No description provided for @cropNameSimpleLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop Name'**
  String get cropNameSimpleLabel;

  /// No description provided for @observedSymptomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Observed Symptoms (optional)'**
  String get observedSymptomsLabel;

  /// No description provided for @diseaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Disease'**
  String get diseaseLabel;

  /// No description provided for @diseaseNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Disease name'**
  String get diseaseNameLabel;

  /// No description provided for @diseaseNameHint.
  ///
  /// In en, this message translates to:
  /// **'Type the disease name'**
  String get diseaseNameHint;

  /// No description provided for @diseaseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type the disease name.'**
  String get diseaseNameRequired;

  /// No description provided for @diseaseRiskWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'Disease Risk This Week'**
  String get diseaseRiskWeekTitle;

  /// No description provided for @diseaseRiskWeekSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Weather-based outlook — inspect early.'**
  String get diseaseRiskWeekSubtitle;

  /// No description provided for @diseaseRiskLowMessage.
  ///
  /// In en, this message translates to:
  /// **'Low disease risk this week based on the forecast. Keep up routine scouting.'**
  String get diseaseRiskLowMessage;

  /// No description provided for @riskLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'HIGH'**
  String get riskLevelHigh;

  /// No description provided for @riskLevelModerate.
  ///
  /// In en, this message translates to:
  /// **'MODERATE'**
  String get riskLevelModerate;

  /// No description provided for @riskLevelLow.
  ///
  /// In en, this message translates to:
  /// **'LOW'**
  String get riskLevelLow;

  /// No description provided for @cropTomato.
  ///
  /// In en, this message translates to:
  /// **'Tomato'**
  String get cropTomato;

  /// No description provided for @cropCocoa.
  ///
  /// In en, this message translates to:
  /// **'Cocoa'**
  String get cropCocoa;

  /// No description provided for @cropMaize.
  ///
  /// In en, this message translates to:
  /// **'Maize'**
  String get cropMaize;

  /// No description provided for @cropRice.
  ///
  /// In en, this message translates to:
  /// **'Rice'**
  String get cropRice;

  /// No description provided for @riskNameLateBlight.
  ///
  /// In en, this message translates to:
  /// **'Late Blight'**
  String get riskNameLateBlight;

  /// No description provided for @riskNameEarlyBlight.
  ///
  /// In en, this message translates to:
  /// **'Early Blight'**
  String get riskNameEarlyBlight;

  /// No description provided for @riskNameBlackPod.
  ///
  /// In en, this message translates to:
  /// **'Black Pod'**
  String get riskNameBlackPod;

  /// No description provided for @riskNameLeafBlightRust.
  ///
  /// In en, this message translates to:
  /// **'Leaf Blight / Rust'**
  String get riskNameLeafBlightRust;

  /// No description provided for @riskNameRiceBlast.
  ///
  /// In en, this message translates to:
  /// **'Rice Blast'**
  String get riskNameRiceBlast;

  /// No description provided for @riskReasonLateBlight.
  ///
  /// In en, this message translates to:
  /// **'Humid ({hum}%) and mild ({temp}°C) conditions favour late blight.'**
  String riskReasonLateBlight(int hum, int temp);

  /// No description provided for @riskReasonEarlyBlight.
  ///
  /// In en, this message translates to:
  /// **'Warm ({temp}°C) and moist ({hum}%) — watch for early blight spots.'**
  String riskReasonEarlyBlight(int hum, int temp);

  /// No description provided for @riskReasonBlackPod.
  ///
  /// In en, this message translates to:
  /// **'Prolonged wet weather ({hum}% humidity) raises black pod risk.'**
  String riskReasonBlackPod(int hum);

  /// No description provided for @riskReasonLeafBlightRust.
  ///
  /// In en, this message translates to:
  /// **'Humid ({hum}%), warm ({temp}°C) spells favour leaf blight and rust.'**
  String riskReasonLeafBlightRust(int hum, int temp);

  /// No description provided for @riskReasonRiceBlast.
  ///
  /// In en, this message translates to:
  /// **'Wet, warm ({temp}°C) conditions are ideal for rice blast.'**
  String riskReasonRiceBlast(int temp);

  /// No description provided for @sevenDayForecast.
  ///
  /// In en, this message translates to:
  /// **'7-Day Forecast'**
  String get sevenDayForecast;

  /// No description provided for @plantedOn.
  ///
  /// In en, this message translates to:
  /// **'Planted: {date}'**
  String plantedOn(String date);

  /// No description provided for @weatherUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable: {error}'**
  String weatherUnavailable(String error);

  /// No description provided for @noScansYet.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get noScansYet;

  /// No description provided for @noScansYetDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan your first crop to see results here'**
  String get noScansYetDesc;

  /// No description provided for @backLabel.
  ///
  /// In en, this message translates to:
  /// **'← Back'**
  String get backLabel;

  /// No description provided for @startPlan.
  ///
  /// In en, this message translates to:
  /// **'Start Plan'**
  String get startPlan;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @reportsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reports'**
  String reportsCount(int count);

  /// No description provided for @treatmentPlanAdded.
  ///
  /// In en, this message translates to:
  /// **'Treatment plan added'**
  String get treatmentPlanAdded;

  /// No description provided for @noTreatmentPlansYet.
  ///
  /// In en, this message translates to:
  /// **'No treatment plans yet'**
  String get noTreatmentPlansYet;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @exportCount.
  ///
  /// In en, this message translates to:
  /// **'Export ({count})'**
  String exportCount(int count);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @proFarmer.
  ///
  /// In en, this message translates to:
  /// **'PRO FARMER'**
  String get proFarmer;

  /// No description provided for @syncingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Syncing photo…'**
  String get syncingPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @aiConfidence.
  ///
  /// In en, this message translates to:
  /// **'AI confidence'**
  String get aiConfidence;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @treatments.
  ///
  /// In en, this message translates to:
  /// **'Treatments'**
  String get treatments;

  /// No description provided for @monthlySummaryReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary report'**
  String get monthlySummaryReport;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @supportedCrops.
  ///
  /// In en, this message translates to:
  /// **'Supported Crops'**
  String get supportedCrops;

  /// No description provided for @disclaimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimerLabel;

  /// No description provided for @statScans.
  ///
  /// In en, this message translates to:
  /// **'Scans'**
  String get statScans;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statStreak;

  /// No description provided for @statPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get statPlans;

  /// No description provided for @aboutSubtitleVersion.
  ///
  /// In en, this message translates to:
  /// **'App version, terms, and privacy'**
  String get aboutSubtitleVersion;

  /// No description provided for @settingsSubtitleShort.
  ///
  /// In en, this message translates to:
  /// **'Display and data'**
  String get settingsSubtitleShort;

  /// No description provided for @mainNavigation.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get mainNavigation;

  /// No description provided for @permissionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permissionCamera;

  /// No description provided for @permissionLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permissionLocation;

  /// No description provided for @privacyLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: May 2025'**
  String get privacyLastUpdated;

  /// No description provided for @termsEffective.
  ///
  /// In en, this message translates to:
  /// **'Effective: May 2025'**
  String get termsEffective;

  /// No description provided for @permissionCameraDesc.
  ///
  /// In en, this message translates to:
  /// **'To scan crop leaves for disease detection'**
  String get permissionCameraDesc;

  /// No description provided for @permissionLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'To map disease outbreaks in your region'**
  String get permissionLocationDesc;

  /// No description provided for @permissionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotifications;

  /// No description provided for @permissionNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'To send treatment reminders and outbreak alerts'**
  String get permissionNotificationsDesc;

  /// No description provided for @permissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions & Privacy'**
  String get permissionsTitle;

  /// No description provided for @permissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on your device. We never sell or share your information.'**
  String get permissionsBody;

  /// No description provided for @onboardingEnableStart.
  ///
  /// In en, this message translates to:
  /// **'Enable & Get Started'**
  String get onboardingEnableStart;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to CropGuard AI'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Spot tomato blight, maize rust, and cassava mosaic before they spread. Built for Ghanaian farmers with local crop knowledge.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Your Crops'**
  String get onboardingScanTitle;

  /// No description provided for @onboardingScanBody.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at any leaf. CropGuard AI analyses the image in seconds and identifies diseases with detailed treatment advice.'**
  String get onboardingScanBody;

  /// No description provided for @onboardingStepDetected.
  ///
  /// In en, this message translates to:
  /// **'Disease Detected'**
  String get onboardingStepDetected;

  /// No description provided for @onboardingStepTreatment.
  ///
  /// In en, this message translates to:
  /// **'Treatment Plan'**
  String get onboardingStepTreatment;

  /// No description provided for @onboardingStepRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery Tracked'**
  String get onboardingStepRecovery;

  /// No description provided for @onboardingActTitle.
  ///
  /// In en, this message translates to:
  /// **'Act Fast, Save More'**
  String get onboardingActTitle;

  /// No description provided for @onboardingActBody.
  ///
  /// In en, this message translates to:
  /// **'Get treatment plans, track farm health over time, and connect with agricultural experts — all offline-capable.'**
  String get onboardingActBody;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @checkInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get checkInbox;

  /// No description provided for @resetLinkSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to '**
  String get resetLinkSentTo;

  /// No description provided for @resendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get resendLink;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart crop disease detection'**
  String get appTagline;

  /// No description provided for @lowConfidenceExplanation.
  ///
  /// In en, this message translates to:
  /// **'The AI detected a possible disease but is only {pct}% confident. This result may not be accurate.'**
  String lowConfidenceExplanation(int pct);

  /// No description provided for @lowConfidenceTips.
  ///
  /// In en, this message translates to:
  /// **'For a more accurate result, try:\n• Taking a clearer, closer photo\n• Ensuring good lighting\n• Focusing on a single leaf with visible symptoms'**
  String get lowConfidenceTips;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get genericError;

  /// No description provided for @resultNotFound.
  ///
  /// In en, this message translates to:
  /// **'Result not found.'**
  String get resultNotFound;

  /// No description provided for @couldNotLoadResult.
  ///
  /// In en, this message translates to:
  /// **'Could not load result.'**
  String get couldNotLoadResult;

  /// No description provided for @sendFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send feedback. Please try again.'**
  String get sendFeedbackFailed;

  /// No description provided for @submitReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report. Please try again.'**
  String get submitReportFailed;

  /// No description provided for @sendRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request. Please try again.'**
  String get sendRequestFailed;

  /// No description provided for @sprayAdvisoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather data unavailable for spray advisory.'**
  String get sprayAdvisoryUnavailable;

  /// No description provided for @deleteAccountReauth.
  ///
  /// In en, this message translates to:
  /// **'For security, confirm your password or sign in with Google again before deleting.'**
  String get deleteAccountReauth;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @modelUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your model is up to date.'**
  String get modelUpToDate;

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get analysisFailed;

  /// No description provided for @milestoneFertilizer.
  ///
  /// In en, this message translates to:
  /// **'Fertilizer reminder in {days}d'**
  String milestoneFertilizer(int days);

  /// No description provided for @milestoneHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'Health check in {days}d'**
  String milestoneHealthCheck(int days);

  /// No description provided for @milestoneHarvestWindow.
  ///
  /// In en, this message translates to:
  /// **'Harvest window in {days}d'**
  String milestoneHarvestWindow(int days);

  /// No description provided for @milestoneHarvestReached.
  ///
  /// In en, this message translates to:
  /// **'Harvest window reached'**
  String get milestoneHarvestReached;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Please check permissions and try again.'**
  String get cameraUnavailable;

  /// No description provided for @torchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Torch is not available on this device.'**
  String get torchUnavailable;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture image.'**
  String get captureFailed;

  /// No description provided for @urlNotImage.
  ///
  /// In en, this message translates to:
  /// **'URL does not point to an image.'**
  String get urlNotImage;

  /// No description provided for @urlLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image from URL.'**
  String get urlLoadFailed;

  /// No description provided for @batchAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Batch analysis failed for all images.'**
  String get batchAllFailed;

  /// No description provided for @batchAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Batch analysis failed'**
  String get batchAnalysisFailed;

  /// No description provided for @noImagesToAnalyse.
  ///
  /// In en, this message translates to:
  /// **'No images to analyse.'**
  String get noImagesToAnalyse;

  /// No description provided for @qualityBlurry.
  ///
  /// In en, this message translates to:
  /// **'Image is too blurry. Please hold the camera steady.'**
  String get qualityBlurry;

  /// No description provided for @qualityTooDark.
  ///
  /// In en, this message translates to:
  /// **'Image is too dark. Please use more light or the torch.'**
  String get qualityTooDark;

  /// No description provided for @qualityTooBright.
  ///
  /// In en, this message translates to:
  /// **'Image is too bright. Please avoid direct glare.'**
  String get qualityTooBright;

  /// No description provided for @qualityTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Image resolution is too low.'**
  String get qualityTooSmall;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download image (HTTP {code}).'**
  String downloadFailed(int code);

  /// No description provided for @batchPartial.
  ///
  /// In en, this message translates to:
  /// **'Analysed {analysed} of {total} images.'**
  String batchPartial(int analysed, int total);

  /// No description provided for @seasonalCalendar.
  ///
  /// In en, this message translates to:
  /// **'Seasonal Calendar: {status}'**
  String seasonalCalendar(String status);

  /// No description provided for @badgeFirstScanTitle.
  ///
  /// In en, this message translates to:
  /// **'First Scan'**
  String get badgeFirstScanTitle;

  /// No description provided for @badgeFirstScanDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first crop scan'**
  String get badgeFirstScanDesc;

  /// No description provided for @badgeScanStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Streak'**
  String get badgeScanStreakTitle;

  /// No description provided for @badgeScanStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan crops for 7 days straight'**
  String get badgeScanStreakDesc;

  /// No description provided for @badgeDiseaseDetectiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Disease Detective'**
  String get badgeDiseaseDetectiveTitle;

  /// No description provided for @badgeDiseaseDetectiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Detect 10 distinct diseases'**
  String get badgeDiseaseDetectiveDesc;

  /// No description provided for @badgeProFarmerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Farmer'**
  String get badgeProFarmerTitle;

  /// No description provided for @badgeProFarmerDesc.
  ///
  /// In en, this message translates to:
  /// **'Reach 100 scans'**
  String get badgeProFarmerDesc;

  /// No description provided for @badgeHarvestHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Harvest Hero'**
  String get badgeHarvestHeroTitle;

  /// No description provided for @badgeHarvestHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a treatment plan'**
  String get badgeHarvestHeroDesc;

  /// No description provided for @badgeCommunityVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Voice'**
  String get badgeCommunityVoiceTitle;

  /// No description provided for @badgeCommunityVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Share 5 community posts'**
  String get badgeCommunityVoiceDesc;

  /// No description provided for @badgeQuickResponderTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Responder'**
  String get badgeQuickResponderTitle;

  /// No description provided for @badgeQuickResponderDesc.
  ///
  /// In en, this message translates to:
  /// **'Act on one plan quickly'**
  String get badgeQuickResponderDesc;

  /// No description provided for @badgeMapReporterTitle.
  ///
  /// In en, this message translates to:
  /// **'Map Reporter'**
  String get badgeMapReporterTitle;

  /// No description provided for @badgeMapReporterDesc.
  ///
  /// In en, this message translates to:
  /// **'Submit 3 outbreak reports'**
  String get badgeMapReporterDesc;

  /// No description provided for @privacySection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get privacySection1Title;

  /// No description provided for @privacySection1Body.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI collects the following information: account email and display name, crop scan images processed locally on your device, and aggregate usage analytics (no personal data). We do not sell your data.'**
  String get privacySection1Body;

  /// No description provided for @privacySection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. How We Use Your Data'**
  String get privacySection2Title;

  /// No description provided for @privacySection2Body.
  ///
  /// In en, this message translates to:
  /// **'Your data is used to provide the disease detection service, improve model accuracy through anonymised feedback, and deliver expert consultation requests. Scan images are never transmitted to external servers without your explicit consent.'**
  String get privacySection2Body;

  /// No description provided for @privacySection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Data Storage'**
  String get privacySection3Title;

  /// No description provided for @privacySection3Body.
  ///
  /// In en, this message translates to:
  /// **'Scan results are stored locally on your device using SQLite. Cloud sync is optional and gated behind authentication. You can delete all local data at any time from Settings → Clear Scan History.'**
  String get privacySection3Body;

  /// No description provided for @privacySection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Third-Party Services'**
  String get privacySection4Title;

  /// No description provided for @privacySection4Body.
  ///
  /// In en, this message translates to:
  /// **'We use Firebase for authentication and optional cloud sync (governed by Google\'s Privacy Policy). We do not share data with any other third parties.'**
  String get privacySection4Body;

  /// No description provided for @privacySection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Contact'**
  String get privacySection5Title;

  /// No description provided for @privacySection5Body.
  ///
  /// In en, this message translates to:
  /// **'For privacy enquiries, contact privacy@cropguardai.com.'**
  String get privacySection5Body;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Body.
  ///
  /// In en, this message translates to:
  /// **'By using CropGuard AI, you agree to these Terms of Service. If you disagree with any part, please do not use the application.'**
  String get termsSection1Body;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Medical / Agronomical Disclaimer'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Body.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI provides guidance based on AI image analysis. Results are not a substitute for expert agronomical advice. Always consult a qualified agronomist before applying treatments, especially chemical pesticides.'**
  String get termsSection2Body;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. User Responsibilities'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Body.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for the accuracy of information you provide, appropriate use of treatment recommendations, and compliance with local agricultural regulations.'**
  String get termsSection3Body;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Intellectual Property'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Body.
  ///
  /// In en, this message translates to:
  /// **'All content, models, and branding within CropGuard AI are the property of CropGuard AI Ltd. Unauthorised reproduction is prohibited.'**
  String get termsSection4Body;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Limitation of Liability'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Body.
  ///
  /// In en, this message translates to:
  /// **'CropGuard AI Ltd is not liable for any crop losses, financial damages, or adverse outcomes resulting from the use of this application.'**
  String get termsSection5Body;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. Changes to Terms'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Body.
  ///
  /// In en, this message translates to:
  /// **'We may update these terms periodically. Continued use of the application constitutes acceptance of the revised terms.'**
  String get termsSection6Body;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @capturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture photo'**
  String get capturePhoto;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening on your farm?'**
  String get composerHint;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @shareAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Share usage analytics'**
  String get shareAnalytics;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint / Face ID'**
  String get biometricLock;

  /// No description provided for @appLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'App locked'**
  String get appLockedTitle;

  /// No description provided for @appLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock to access your farm data'**
  String get appLockedSubtitle;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock CropGuard AI'**
  String get unlockReason;

  /// No description provided for @treatmentEmptyHelp.
  ///
  /// In en, this message translates to:
  /// **'After a scan, tap \"Track Treatment\" on the result screen to start a plan.'**
  String get treatmentEmptyHelp;

  /// No description provided for @expertRequestSentMsg.
  ///
  /// In en, this message translates to:
  /// **'Request sent. An expert will get back to you.'**
  String get expertRequestSentMsg;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @resetPasswordCta.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordCta;

  /// No description provided for @enterNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for your account.'**
  String get enterNewPasswordHint;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been reset. Please sign in.'**
  String get passwordResetSuccess;

  /// No description provided for @resetLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid or has expired. Please request a new one.'**
  String get resetLinkInvalid;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMin6.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get passwordMin6;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get allCaughtUp;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @scanTrend7Day.
  ///
  /// In en, this message translates to:
  /// **'7-Day Scan Trend'**
  String get scanTrend7Day;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @exampleName.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kofi Mensah'**
  String get exampleName;

  /// No description provided for @diseaseOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get diseaseOther;

  /// No description provided for @closeComparison.
  ///
  /// In en, this message translates to:
  /// **'Close Comparison'**
  String get closeComparison;

  /// No description provided for @severityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severityLabel;

  /// No description provided for @scanDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan Date'**
  String get scanDateLabel;

  /// No description provided for @sharedFromCropGuard.
  ///
  /// In en, this message translates to:
  /// **'Shared from CropGuard AI'**
  String get sharedFromCropGuard;

  /// No description provided for @shareCauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Cause:'**
  String get shareCauseLabel;

  /// No description provided for @shareTreatmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Treatments:'**
  String get shareTreatmentsLabel;

  /// No description provided for @notificationsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Treatment reminders and alerts will appear here.'**
  String get notificationsEmptyDesc;

  /// No description provided for @badgesUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total} unlocked'**
  String badgesUnlocked(int unlocked, int total);

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @treatmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{pending} pending • {completed} done'**
  String treatmentSubtitle(int pending, int completed);

  /// No description provided for @plantedDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Planted {date} · Day {day}'**
  String plantedDayLabel(String date, int day);

  /// No description provided for @couldNotIdentify.
  ///
  /// In en, this message translates to:
  /// **'Could not identify this plant — please retake the photo in good lighting, closer to the leaf.'**
  String get couldNotIdentify;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Where is your farm?'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingRegionBody.
  ///
  /// In en, this message translates to:
  /// **'Select your region so we can show locally relevant disease risks and weather. You can change this later in Settings.'**
  String get onboardingRegionBody;

  /// No description provided for @selectRegion.
  ///
  /// In en, this message translates to:
  /// **'Select your region'**
  String get selectRegion;

  /// No description provided for @userRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get userRegionLabel;

  /// No description provided for @scanFirstCropHint.
  ///
  /// In en, this message translates to:
  /// **'Scan your first crop to see your farm health score'**
  String get scanFirstCropHint;

  /// No description provided for @scanSummaryHealthy.
  ///
  /// In en, this message translates to:
  /// **'{disease} looks healthy.'**
  String scanSummaryHealthy(String disease);

  /// No description provided for @scanSummaryDiseased.
  ///
  /// In en, this message translates to:
  /// **'{disease} detected.'**
  String scanSummaryDiseased(String disease);

  /// No description provided for @ttsResultSummary.
  ///
  /// In en, this message translates to:
  /// **'{disease}. Severity is {severity}. Treatment steps: {treatments}'**
  String ttsResultSummary(String disease, String severity, String treatments);
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
      <String>['dag', 'ee', 'en', 'tw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'dag':
      return AppLocalizationsDag();
    case 'ee':
      return AppLocalizationsEe();
    case 'en':
      return AppLocalizationsEn();
    case 'tw':
      return AppLocalizationsTw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
