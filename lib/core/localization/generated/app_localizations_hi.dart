// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'DoseWise';

  @override
  String get navHome => 'घर';

  @override
  String get greetingMorning => 'सुप्रभात';

  @override
  String get greetingAfternoon => 'नमस्ते';

  @override
  String get greetingEvening => 'शुभ संध्या';

  @override
  String get homeNextMedicine => 'अगली दवा';

  @override
  String get homeTakeMedicine => 'दवा लें';

  @override
  String get homeSkip => 'छोड़ें';

  @override
  String get homeTaken => 'लिया';

  @override
  String get homeRemaining => 'बाकी';

  @override
  String get homeMissed => 'छूटी';

  @override
  String get homeTodayMedicines => 'आज की दवाएँ';

  @override
  String get homeWellnessSubtitle => 'यह रहा आज का आपका सेहत प्लान।';

  @override
  String get homeUpcomingDose => 'आगामी खुराक';

  @override
  String get homeMarkAsTaken => 'ली — चिह्नित करें';

  @override
  String get homeScheduleTitle => 'आज का शेड्यूल';

  @override
  String get homeLogNow => 'अभी दर्ज करें';

  @override
  String get homeDailyProgress => 'आज की प्रगति';

  @override
  String get navMeds => 'दवाएँ';

  @override
  String get homeNoMedicines => 'अभी कोई दवा नहीं जोड़ी गई';

  @override
  String get homeNoMoreToday => 'आज के लिए कोई और दवा नहीं 🎉';

  @override
  String get homeDosesDone => 'खुराक पूरी हुई';

  @override
  String homeInMin(int minutes) {
    return '$minutes मिनट में';
  }

  @override
  String homeInHours(int hours) {
    return '$hours घंटे में';
  }

  @override
  String homeInDays(int days) {
    return '$days दिन में';
  }

  @override
  String get homeDueNow => 'अभी लें!';

  @override
  String get homeTakeNowBanner => 'अभी लें!';

  @override
  String get homeTakeNowSubtitle => 'एक खुराक बाकी है';

  @override
  String get alarmTitle => 'दवा लेने का समय हो गया!';

  @override
  String alarmSubtitle(String name, String dose) {
    return '$name — $dose';
  }

  @override
  String get alarmSnooze => 'स्नूज़';

  @override
  String get alarmLater => 'बाद में लूँगा/लूँगी';

  @override
  String homeOverdueMin(int minutes) {
    return '$minutes मिनट देर';
  }

  @override
  String get medPresetWeekdays => 'सप्ताह के दिन';

  @override
  String get medPresetWeekends => 'वीकेंड';

  @override
  String get medDuplicate => 'कॉपी बनाएं';

  @override
  String get medDuplicateHint => 'इस दवा की एक कॉपी बनाएं';

  @override
  String get pauseAll => 'सभी दवाएं रोकें';

  @override
  String get pauseAllConfirm =>
      'यह सभी सक्रिय दवाओं और उनके रिमाइंडर को रोक देगा। आप बाद में इन्हें फिर से शुरू कर सकते हैं।';

  @override
  String get resumeAll => 'सभी शुरू करें';

  @override
  String homeStreak(int days) {
    return '$days दिन की स्ट्रीक! जारी रखें! 🎉';
  }

  @override
  String get homeBatchMarkAll => 'सभी ले लीं';

  @override
  String get homeAllDoneToday => 'आज के लिए सब हो गया! 🎉';

  @override
  String homeOverdueHours(int hours) {
    return '$hours घंटे देर';
  }

  @override
  String get homeAddFirst => 'अपनी पहली दवा जोड़ें';

  @override
  String get homeEmptySchedule => 'आज के लिए कोई रिमाइंडर नहीं';

  @override
  String get statusTaken => 'लिया';

  @override
  String get statusSkipped => 'छोड़ा';

  @override
  String get statusMissed => 'छूटी';

  @override
  String get statusPending => 'बाकी';

  @override
  String get statusSnoozed => 'स्नूज़';

  @override
  String get medTitle => 'मेरी दवाएँ';

  @override
  String get medAdd => 'दवा जोड़ें';

  @override
  String get medEdit => 'दवा बदलें';

  @override
  String get medName => 'दवा का नाम';

  @override
  String get medNameHint => 'जैसे: BP टैबलेट';

  @override
  String get medDose => 'मात्रा';

  @override
  String get medDoseHint => 'जैसे: 1';

  @override
  String get medDoseUnit => 'इकाई';

  @override
  String get medDoseUnitHint => 'जैसे: गोली, बूँद, चम्मच';

  @override
  String get medNotes => 'नोट (वैकल्पिक)';

  @override
  String get medFoodInstruction => 'खाने से संबंध';

  @override
  String get foodNone => 'कोई विशेष निर्देश नहीं';

  @override
  String get foodBefore => 'खाने से पहले';

  @override
  String get foodAfter => 'खाने के बाद';

  @override
  String get foodWith => 'खाने के साथ';

  @override
  String get medFrequency => 'कितनी बार?';

  @override
  String get freqEveryDay => 'रोज़';

  @override
  String get freqSpecificDays => 'कुछ दिन';

  @override
  String get freqOnce => 'एक बार';

  @override
  String get freqMultiple => 'दिन में कई बार';

  @override
  String get medSelectDays => 'दिन चुनें';

  @override
  String get medReminderTime => 'रिमाइंडर का समय';

  @override
  String get medQuickTimes => 'त्वरित समय — एक दबाव में';

  @override
  String get medTimeSlotMorning => 'सुबह';

  @override
  String get medTimeSlotAfternoon => 'दोपहर';

  @override
  String get medTimeSlotEvening => 'शाम';

  @override
  String get medTimeSlotNight => 'रात';

  @override
  String get medUnitQuick => 'सामान्य इकाइयाँ — एक दबाव में';

  @override
  String get medUnitMg => 'mg';

  @override
  String get medUnitMl => 'ml';

  @override
  String get medUnitTablet => 'गोली';

  @override
  String get medUnitCapsule => 'कैप्सूल';

  @override
  String get medUnitDrop => 'बूँद';

  @override
  String get medUnitSpoon => 'चम्मच';

  @override
  String get medAddAnotherTime => 'और समय जोड़ें';

  @override
  String get medSave => 'सेव करें';

  @override
  String get medDelete => 'हटाएँ';

  @override
  String get medPause => 'रोकें';

  @override
  String get medResume => 'फिर शुरू करें';

  @override
  String get medActive => 'चालू';

  @override
  String get medInactive => 'रोका हुआ';

  @override
  String get medDeleteTitle => 'दवा हटाएँ?';

  @override
  String medDeleteBody(String name) {
    return 'इससे \"$name\" और इसके भविष्य के रिमाइंडर हट जाएँगे। इसे वापस नहीं लाया जा सकता।';
  }

  @override
  String get medDeleted => 'दवा हटा दी गई';

  @override
  String get medSaved => 'दवा सेव हो गई';

  @override
  String get medPausedMsg => 'रिमाइंडर रोक दिए गए';

  @override
  String get medResumedMsg => 'रिमाइंडर फिर शुरू हो गए';

  @override
  String get medNoMedicines =>
      'अभी कोई दवा नहीं।\nशुरू करने के लिए \"दवा जोड़ें\" दबाएँ।';

  @override
  String get medSearch => 'दवाएं खोजें...';

  @override
  String get medSearchEmpty => 'आपकी खोज से कोई दवा मेल नहीं खाती';

  @override
  String get medStockTracking => 'स्टॉक ट्रैकिंग (वैकल्पिक)';

  @override
  String get medStockCountHint => 'मौजूदा गोलियां (जैसे 30)';

  @override
  String get medRefillAtHint => 'याद दिलाएं जब (जैसे 5)';

  @override
  String get medRefillTitle => 'रिफिल का समय!';

  @override
  String medRefillBody(String name, int remaining) {
    return '$name कम हो रही है ($remaining बची हैं)। रिफिल का समय।';
  }

  @override
  String get medOnceDate => 'तारीख़';

  @override
  String get medTime => 'समय';

  @override
  String get histTitle => 'इतिहास';

  @override
  String get histToday => 'आज';

  @override
  String get histThisWeek => 'इस हफ़्ते';

  @override
  String get histAll => 'सब';

  @override
  String get histScheduled => 'निर्धारित';

  @override
  String get histActual => 'वास्तविक';

  @override
  String histShowing(String label, int count) {
    return 'दिखा रहे हैं: $label ($count)';
  }

  @override
  String medActiveCount(int active, int total) {
    return '$total में से $active चालू';
  }

  @override
  String medStockLeft(int count) {
    return '$count बची';
  }

  @override
  String get histAdherence => 'अनुपालन';

  @override
  String get histTakenCount => 'लिया';

  @override
  String get histMissedCount => 'छूटी';

  @override
  String get histSkippedCount => 'छोड़ा';

  @override
  String get histPendingCount => 'बाकी';

  @override
  String get histEmpty => 'अभी कोई इतिहास नहीं';

  @override
  String get histExport => 'CSV एक्सपोर्ट';

  @override
  String get medConflictTitle => 'शेड्यूल टकराव';

  @override
  String medConflictBody(String names) {
    return 'ये दवाएं पहले से उसी समय निर्धारित हैं: $names। क्या फिर भी जारी रखें?';
  }

  @override
  String get histTrendGood => 'अनुपालन अच्छा दिख रहा है!';

  @override
  String get histTrendNeedsWork => 'अनुपालन में सुधार की ज़रूरत है';

  @override
  String get setData => 'डेटा';

  @override
  String get setExportJson => 'बैकअप एक्सपोर्ट';

  @override
  String get setExportJsonDesc => 'सभी दवाएं और इतिहास JSON में सेव करें';

  @override
  String histTotal(int count) {
    return 'कुल: $count';
  }

  @override
  String get setTitle => 'सेटिंग्स';

  @override
  String get setLanguage => 'भाषा';

  @override
  String get setNotificationSound => 'सूचना की आवाज़';

  @override
  String get setVoiceReminder => 'आवाज़ से रिमाइंडर';

  @override
  String get setVoiceOn => 'दवा का नाम बोलकर बताएँ';

  @override
  String get setSnoozeDuration => 'स्नूज़ की अवधि';

  @override
  String get setGracePeriod => 'कितनी देर बाद \'छूटी\' मानें';

  @override
  String get setAdvanceAlarm => 'अग्रिम अलार्म';

  @override
  String get setAdvanceAlarmDesc => 'दवा के समय से पहले अलार्म शुरू करें';

  @override
  String get off => 'बंद';

  @override
  String get testNotification => 'सूचना ध्वनि परीक्षण';

  @override
  String get testNotifSent => 'परीक्षण सूचना भेजी गई! अपनी आवाज़ जाँचें।';

  @override
  String get setDarkMode => 'रूप-रंग';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'हल्का';

  @override
  String get themeDark => 'गहरा';

  @override
  String get setAbout => 'जानकारी';

  @override
  String get setPermissions => 'अनुमतियाँ';

  @override
  String get setNotifyPermission => 'सूचना की अनुमति';

  @override
  String get setExactAlarm => 'सटीक अलार्म की अनुमति';

  @override
  String get setBattery => 'बैटरी / बैकग्राउंड';

  @override
  String get permissionGranted => 'मिल गई';

  @override
  String get permissionDenied => 'नहीं मिली — अनुमति देने के लिए दबाएँ';

  @override
  String get setNotifDesc => 'रिमाइंडर दिखाने की अनुमति दें';

  @override
  String get setExactDesc => 'रिमाइंडर ठीक समय पर बजने दें';

  @override
  String get setBatteryDesc => 'बैकग्राउंड में रिमाइंडर काम करते रहें';

  @override
  String get setBatteryRestricted => 'प्रतिबंधित';

  @override
  String get setBatteryWarning =>
      'वैकल्पिक: कुछ फ़ोन में बैटरी सेवर रिमाइंडर में देरी कर सकता है। DoseWise को \"Unrestricted\" सेट करने के लिए दबाएँ।';

  @override
  String get testNotifFailed =>
      'टेस्ट सूचना नहीं भेज सके। Android सेटिंग्स खोलें और DoseWise के लिए सूचनाएँ चालू करें।';

  @override
  String get setTestScheduled => 'शेड्यूल किया रिमाइंडर टेस्ट करें (1 मिनट)';

  @override
  String get setTestScheduledSent =>
      'लगभग 1 मिनट बाद के लिए रिमाइंडर सेट है। ऐप बंद करें और फ़ोन लॉक करें — यह बजना और वाइब्रेट होना चाहिए।';

  @override
  String get setTestScheduledInexact =>
      'लगभग 1 मिनट के लिए सेट है, पर सटीक अलार्म बंद हैं इसलिए देर हो सकती है। समय पर रिमाइंडर के लिए सटीक अलार्म चालू करें।';

  @override
  String get setTestScheduledFailed =>
      'टेस्ट शेड्यूल नहीं कर सके। जाँचें कि सूचनाएँ चालू हैं।';

  @override
  String setScheduledCount(int count) {
    return 'इस फ़ोन पर शेड्यूल रिमाइंडर: $count';
  }

  @override
  String get aboutBody =>
      'DoseWise सिर्फ़ याद दिलाने और रिकॉर्ड रखने का साधन है। यह कोई चिकित्सीय सलाह नहीं देता। हमेशा अपने डॉक्टर के निर्देशों का पालन करें।';

  @override
  String get notifTitle => '💊 दवा का समय हो गया है';

  @override
  String notifBody(String name, String dose) {
    return 'लें: $name — $dose';
  }

  @override
  String get notifActionTaken => 'लिया';

  @override
  String notifActionSnooze(int minutes) {
    return '$minutes मिनट बाद';
  }

  @override
  String get notifActionSkip => 'छोड़ें';

  @override
  String get permNotifTitle => 'सूचनाएँ अनुमति दें?';

  @override
  String get permNotifBody =>
      'रिमाइंडर सूचना के रूप में दिखेंगे, भले ही ऐप बंद हो। कृपया सूचनाएँ अनुमति दें।';

  @override
  String get permExactTitle => 'सटीक अलार्म की अनुमति दें?';

  @override
  String get permExactBody =>
      'रिमाइंडर ठीक समय पर बजने के लिए Android को अनुमति चाहिए। सिस्टम सेटिंग्स खुलेंगी — कृपया \"सटीक अलार्म दें\" चालू करें।';

  @override
  String get permOk => 'ठीक है';

  @override
  String get permCancel => 'अभी नहीं';

  @override
  String get obWelcome => 'स्वागत है!';

  @override
  String get obTitle => 'DoseWise';

  @override
  String get obBody =>
      'मैं आपको समय पर दवा लेने की याद दिलाऊँगा। इसमें बस एक मिनट लगेगा।';

  @override
  String get obName => 'मैं आपको क्या बुलाऊँ? (वैकल्पिक)';

  @override
  String get obNameHint => 'जैसे: माँ';

  @override
  String get obStart => 'शुरू करें';

  @override
  String get obSkip => 'अभी छोड़ें';

  @override
  String get obBatteryWhy => 'यह क्यों ज़रूरी है?';

  @override
  String get obBatteryHow =>
      'अपने फ़ोन की Settings में जाएँ, इस app को ढूंढें, और \'Battery optimization\' बंद करें या \'Unrestricted\' चुनें। इससे रिमाइंडर बंद app में भी काम करते रहेंगे।';

  @override
  String voiceTimeToTake(String name, String dose) {
    return 'दवा लेने का समय हो गया है। $name, $dose।';
  }

  @override
  String get voiceTaken => 'शाबाश! दवा ले ली गई।';

  @override
  String get voiceSkipped => 'दवा छोड़ दी गई।';

  @override
  String get undo => 'वापस करें';

  @override
  String get undoTaken => 'दवा ले ली गई';

  @override
  String get undoSkipped => 'दवा छोड़ दी गई';

  @override
  String get homeSkipConfirmTitle => 'यह खुराक छोड़ें?';

  @override
  String homeSkipConfirmBody(String name) {
    return 'क्या आप $name को छोड़ना चाहते हैं? इसे छोड़ा हुआ चिह्नित किया जाएगा।';
  }

  @override
  String get btnSave => 'सेव करें';

  @override
  String get btnCancel => 'रद्द करें';

  @override
  String get btnClose => 'बंद करें';

  @override
  String minutes(int minutes) {
    return '$minutes मिनट';
  }

  @override
  String get speakReminder => 'रिमाइंडर बोलें';

  @override
  String get missedAlertTitle => '⚠️ दवा छूट गई';

  @override
  String missedAlertBody(String name, String time) {
    return '$time पर $name नहीं ली गई';
  }

  @override
  String get familySync => 'परिवार और सिंक';

  @override
  String get familySyncDesc => 'दवाइयाँ और इतिहास परिवार से साझा करें';

  @override
  String get familySyncIntro =>
      'परिवार देख सकता है कि दवा ली गई या नहीं और दवा छूटने पर सूचना मिलती है। सब कुछ आपके परिवार तक ही सीमित रहता है।';

  @override
  String get syncSetupHint =>
      'एक कोड बनाएँ ताकि परिवार आपकी दवाओं में मदद कर सके — और परिवार के सदस्य का कोड डालकर उनकी दवाओं में मदद करें। आप दोनों कर सकते हैं।';

  @override
  String get syncCreateCode => 'मेरा फ़ैमिली कोड बनाएँ';

  @override
  String get syncHaveCode => 'मेरे पास फ़ैमिली कोड है';

  @override
  String get syncJoinAnother => 'दूसरा फ़ैमिली कोड जोड़ें';

  @override
  String get syncRolePrimary => 'मैं यहाँ दवा लेती/लेता हूँ';

  @override
  String get syncRolePrimaryDesc => 'यह फ़ोन दवा लेने वाले व्यक्ति का है';

  @override
  String get syncRoleWatcher => 'मैं परिवार से हूँ — मदद करना चाहता/चाहती हूँ';

  @override
  String get syncRoleWatcherDesc =>
      'दवाइयों पर नज़र रखें और छूटने पर सूचना पाएँ';

  @override
  String get syncCodeLabel => 'परिवार कोड';

  @override
  String get syncCodeHint => '6 अक्षर का कोड दर्ज करें';

  @override
  String get syncPrimaryHint =>
      'मरीज़ के फ़ोन पर Family Sync खोलें और \"I take medicines here\" दबाकर यह कोड पाएँ।';

  @override
  String get syncJoin => 'परिवार से जुड़ें';

  @override
  String get syncCreate => 'परिवार बनाएँ';

  @override
  String get syncCopied => 'कोड कॉपी हो गया';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get syncOn => 'सिंक चालू है';

  @override
  String get syncOff => 'सिंक बंद है';

  @override
  String syncLastSync(String time) {
    return 'आख़िरी सिंक: $time';
  }

  @override
  String get syncNever => 'कभी नहीं';

  @override
  String get syncFailed => 'सिंक विफल';

  @override
  String get syncErrorPermission =>
      'क्लाउड डेटाबेस ने अनुरोध अस्वीकार कर दिया। इस Firebase प्रोजेक्ट के Firestore सुरक्षा नियम सेट नहीं हैं — firestore.rules डिप्लॉय करें या Firebase Console → Firestore → Rules में डालें।';

  @override
  String get syncErrorNetwork =>
      'सर्वर से संपर्क नहीं हो सका। अपना इंटरनेट कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get syncErrorAuth =>
      'साइन-इन अस्वीकार हुआ। Firebase console में Anonymous और Google साइन-इन चालू करें, और इस ऐप का SHA-1 दर्ज करें।';

  @override
  String get syncErrorDetail => 'विवरण';

  @override
  String get syncDisable => 'सिंक बंद करें';

  @override
  String get syncDisableConfirm =>
      'सिंक बंद करने पर यह फ़ोन परिवार से अलग हो जाएगा। दवाइयाँ इसी फ़ोन पर रहेंगी।';

  @override
  String get syncNotConfigured =>
      'इस ऐप के लिए क्लाउड सिंक अभी तैयार नहीं है (google-services.json जोड़ें)। इसके बिना भी ऐप पूरी तरह से काम करता है।';

  @override
  String get missedAlerts => 'छूटी दवा की सूचना';

  @override
  String get missedAlertsDesc => 'दवा छूटने पर सूचना पाएँ';

  @override
  String get syncStatusSynced => 'सब सिंक हो गया';

  @override
  String get syncStatusSyncing => 'सिंक हो रहा है…';

  @override
  String syncPendingCount(int count) {
    return '$count परिवर्तन सिंक होने की प्रतीक्षा में';
  }

  @override
  String get syncRetrying => 'अपने आप फिर कोशिश होगी';

  @override
  String get syncCodeShare => 'यह कोड परिवार को दें';

  @override
  String get caregiverTitle => 'परिवार डैशबोर्ड';

  @override
  String get caregiverDesc => 'साप्ताहिक अनुपालन और आज की दवाएँ';

  @override
  String get caregiverRefresh => 'रीफ़्रेश करें';

  @override
  String get caregiverThisWeek => 'इस हफ़्ते';

  @override
  String get notifDiagnostics => 'सूचना जाँच';

  @override
  String get notifFixAll => 'सभी ठीक करें';

  @override
  String get notifStatusOk => 'सभी अनुमतियाँ सही हैं';

  @override
  String get notifStatusNeedsFix =>
      'कुछ सेटिंग्स रिमाइंडर को प्रभावित कर सकती हैं';

  @override
  String get notifOpenSystemSettings => 'सिस्टम सेटिंग्स खोलें';

  @override
  String get syncGoogleSignIn => 'Google से जारी रखें';

  @override
  String get syncSignOut => 'साइन आउट';

  @override
  String get syncSignInFailed =>
      'साइन-इन असफल। कृपया अपना इंटरनेट कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get loginSubtitle =>
      'परिवार के साथ दवाएँ सिंक करने के लिए साइन इन करें, या ऑफलाइन ऐप इस्तेमाल करें।';

  @override
  String get loginWithGoogle => 'Google से जारी रखें';

  @override
  String get loginOr => 'या';

  @override
  String get loginSkip => 'ऑफलाइन इस्तेमाल करें';

  @override
  String get loginOfflineNote =>
      'आप बाद में Settings से कभी भी साइन इन कर सकते हैं।';

  @override
  String get familySyncNotConfigured =>
      'Firebase कॉन्फ़िगर नहीं है। फ़ैमिली सिंक के लिए Firebase सेटअप ज़रूरी है। ऐप बिना Firebase के भी पूरी तरह ऑफलाइन काम करता है।';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get profilePersonalInfo => 'व्यक्तिगत जानकारी';

  @override
  String get profileAccount => 'खाता';

  @override
  String get profileAge => 'उम्र';

  @override
  String get profileAgeHint => 'जैसे: 65';

  @override
  String get profileEditInfo => 'जानकारी बदलें';

  @override
  String get profileSaved => 'प्रोफ़ाइल अपडेट हो गई';

  @override
  String get profileSignOut => 'साइन आउट';

  @override
  String get profileSignOutDesc => 'अपने Google खाते से साइन आउट करें';

  @override
  String get profileSignOutConfirm =>
      'क्या आप साइन आउट करना चाहते हैं? आपका डेटा इसी फ़ोन पर रहेगा।';

  @override
  String get profileSignedOut => 'सफलतापूर्वक साइन आउट हो गया';

  @override
  String get profileSignInPrompt =>
      'अपनी दवाओं को विभिन्न डिवाइसों पर परिवार के साथ सिंक करने के लिए Google से साइन इन करें।';

  @override
  String get profileWelcomeBack => 'वापसी पर स्वागत!';

  @override
  String get profileSignedIn => 'Google से साइन इन हैं';

  @override
  String get profileOfflineMode => 'ऑफ़लाइन मोड';

  @override
  String get profileGuestUser => 'अतिथि उपयोगकर्ता';

  @override
  String get profileNoName => 'नाम सेट नहीं';

  @override
  String get profileNotSet => 'सेट नहीं';

  @override
  String get profileEmail => 'ईमेल';

  @override
  String get profileNoInfoYet =>
      'अभी कोई व्यक्तिगत जानकारी नहीं। अपना नाम और उम्र जोड़ने के लिए \"जानकारी बदलें\" दबाएँ।';

  @override
  String get navProfile => 'प्रोफ़ाइल';
}
