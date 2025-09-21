import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations._(this.locale);

  factory AppLocalizations(Locale locale) {
    final instance = AppLocalizations._(locale);
    _instance = instance;
    return instance;
  }

  final Locale locale;

  static AppLocalizations? _instance;

  static AppLocalizations get current =>
      _instance ?? AppLocalizations._(const Locale('en'));

  static const supportedLocales = [Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'Login': 'تسجيل الدخول',
      'Log in': 'تسجيل الدخول',
      'Welcome back to SpotnSend': 'مرحبًا بعودتك إلى سبوت آند سند',
      'Log in to monitor live reports and stay informed.':
          'سجّل الدخول لمتابعة البلاغات المباشرة والبقاء على اطلاع.',
      'Email or username': 'البريد الإلكتروني أو اسم المستخدم',
      'Enter your email or username': 'أدخل بريدك الإلكتروني أو اسم المستخدم',
      'Password': 'كلمة المرور',
      'Enter your password': 'أدخل كلمة المرور',
      'Keep me signed in': 'تذكرني',
      'Use tester account': 'استخدام حساب التجربة',
      "Don't have an account? ": 'ليس لديك حساب؟ ',
      'Sign up': 'إنشاء حساب',
      'Identifier': 'المعرف',
      'Email is required': 'البريد الإلكتروني مطلوب',
      'Enter a valid email': 'أدخل بريدًا إلكترونيًا صحيحًا',
      'Password is required': 'كلمة المرور مطلوبة',
      'Password must be at least 8 characters':
          'يجب أن تكون كلمة المرور 8 أحرف على الأقل',
      'Phone number is required': 'رقم الجوال مطلوب',
      'Enter a valid phone number': 'أدخل رقم جوال صحيحًا',
      'Enter the 6-digit code': 'أدخل الرمز المكوّن من 6 أرقام',
      'Only numbers are allowed': 'يُسمح بالأرقام فقط',
      '{field} is required': '{field} مطلوب',
      'Create your SpotnSend account': 'أنشئ حسابك في سبوت آند سند',
      'We need a few details to set up your secure profile.':
          'نحتاج بعض البيانات لإعداد ملفك الشخصي الآمن.',
      'Full name': 'الاسم الكامل',
      'Username': 'اسم المستخدم',
      'Email': 'البريد الإلكتروني',
      'Phone number': 'رقم الجوال',
      'SMS verification code': 'رمز التحقق عبر الرسائل',
      'Continue to ID verification': 'متابعة للتوثيق بالهوية',
      'Already have an account? ': 'لديك حساب بالفعل؟ ',
      'Verify your identity': 'تحقق من هويتك',
      'Upload your national ID so we can keep reporting trusted.':
          'حمّل الهوية الوطنية للحفاظ على موثوقية البلاغات.',
      'National ID number': 'رقم الهوية الوطنية',
      'Front of ID': 'الوجه الأمامي للهوية',
      'Upload a clear image of the front side': 'حمّل صورة واضحة للوجه الأمامي',
      'Back of ID': 'الوجه الخلفي للهوية',
      'Upload a clear image of the back side': 'حمّل صورة واضحة للوجه الخلفي',
      'Continue to selfie verification': 'متابعة للتوثيق بالصور',
      'Back to info': 'العودة للمعلومات',
      'Please upload both sides of your ID': 'يرجى تحميل وجهي الهوية',
      'Final step: Selfie verification': 'الخطوة الأخيرة: التحقق بالصور',
      'Capture a quick selfie so we can match it with your ID.':
          'التقط صورة ذاتية سريعة لمطابقتها مع هويتك.',
      'Tap capture to take your selfie': 'اضغط على التقط لالتقاط صورتك',
      'Capture selfie': 'التقاط صورة',
      'Retake selfie': 'إعادة التقاط الصورة',
      'What happens next?': 'ما الذي سيحدث لاحقًا؟',
      'Our team will verify your details shortly. You can explore reports but reporting will unlock once you are verified.':
          'سيتحقق فريقنا من بياناتك قريبًا. يمكنك استعراض البلاغات وسيتم تفعيل الإبلاغ بعد التحقق.',
      'Submit for verification': 'إرسال للتحقق',
      'Camera permission is required to capture a selfie.':
          'يتطلب التقاط الصورة إذن الوصول للكاميرا.',
      'Please capture a selfie to continue': 'يرجى التقاط صورة للمتابعة',
      'Please provide both username/email and password.':
          'يرجى إدخال اسم المستخدم/البريد وكلمة المرور معًا.',
      'Thank you! Your account is pending verification.':
          'شكرًا لك! حسابك قيد المراجعة.',
      'Reporting is locked until verification is complete.':
          'خدمة الإبلاغ غير متاحة حتى اكتمال التحقق.',
      'Reporting is locked until your account has been verified. You can still browse live map updates and notifications.':
          'الإبلاغ مقفل حتى يتم التحقق من حسابك. لا يزال بإمكانك استعراض الخريطة والتنبيهات.',
      'Map': 'الخريطة',
      'Report': 'إبلاغ',
      'Alerts': 'التنبيهات',
      'Account': 'الحساب',
      'Settings': 'الإعدادات',
      'Pending': 'قيد المراجعة',
      'Verified': 'موثق',
      'Reload profile': 'إعادة تحميل الملف',
      'Reports': 'البلاغات',
      'Feedback': 'التقييمات',
      'Phone updated.': 'تم تحديث رقم الجوال.',
      'Email updated.': 'تم تحديث البريد الإلكتروني.',
      'National ID': 'الهوية الوطنية',
      'Saved spots': 'المواقع المحفوظة',
      'Emergency': 'طوارئ',
      'Medical': 'حالات طبية',
      'Accident': 'حادث',
      'Infrastructure': 'بنية تحتية',
      'Pothole': 'حفرة',
      'Road damage': 'تلف الطريق',
      'Broken streetlight': 'إنارة شارع معطلة',
      'Utilities': 'خدمات',
      'Power outage': 'انقطاع كهرباء',
      'Water leak': 'تسرب مياه',
      'Gas leak': 'تسرب غاز',
      'Environment': 'بيئة',
      'Flooding': 'فيضان',
      'Pollution': 'تلوث',
      'Wildlife': 'حياة برية',
      'Community': 'مجتمع',
      'Event': 'فعالية',
      'Noise': 'إزعاج',
      'Gathering': 'تجمع',
      'Safety': 'سلامة',
      'Suspicious activity': 'نشاط مريب',
      'Hazard': 'خطر',
      'Other': 'أخرى',
      'Fire': 'حريق',
      'Add new spot': 'إضافة موقع جديد',
      'No saved spots yet. Add your home, office, or loved ones to stay alerted.':
          'لا توجد مواقع محفوظة بعد. أضف المنزل أو العمل أو أحبائك لتصلك التنبيهات.',
      'Saved spot removed.': 'تم حذف الموقع المحفوظ.',
      'Add saved spot': 'إضافة موقع محفوظ',
      'Name': 'الاسم',
      'Latitude': 'خط العرض',
      'Longitude': 'خط الطول',
      'Cancel': 'إلغاء',
      'Save': 'حفظ',
      'Enter valid coordinates.': 'أدخل إحداثيات صحيحة.',
      'Saved spot added.': 'تم حفظ الموقع.',
      'Lat {lat}, Lng {lng}': 'خط العرض {lat}، خط الطول {lng}',
      '{value} km': '{value} كم',
      'Enable location permissions to recenter the map.':
          'فعّل إذن الموقع لإعادة تمركز الخريطة.',
      'Loading nearby reports...': 'جاري تحميل البلاغات القريبة...',
      'MapTiler key missing': 'مفتاح MapTiler غير موجود',
      'Run the app with --dart-define=MAPTILER_KEY=YOUR_KEY to enable the live map.':
          'شغّل التطبيق باستخدام ‎--dart-define=MAPTILER_KEY=YOUR_KEY‎ لتفعيل الخريطة الحية.',
      'View list': 'عرض القائمة',
      'Filters': 'الفلاتر',
      'Filter reports': 'تصفية البلاغات',
      'Clear': 'مسح',
      'List view': 'عرض القائمة',
      'Include saved spots': 'تضمين المواقع المحفوظة',
      'Search radius': 'نطاق البحث',
      'Spot nearby incidents': 'اكتشف الحوادث القريبة',
      'Verification pending. Reporting is locked, but you can explore alerts in your area.':
          'التحقق قيد المراجعة. الإبلاغ غير متاح، لكن يمكنك استعراض التنبيهات القريبة.',
      'Stay alert with real-time safety intel from your community.':
          'ابق على اطلاع مع معلومات الأمان الفورية من مجتمعك.',
      'Latest reports nearby': 'أحدث البلاغات القريبة',
      'No reports in range': 'لا توجد بلاغات في النطاق',
      'Try increasing your radius or adjust filters to see more activity.':
          'جرّب زيادة النطاق أو تعديل الفلاتر لعرض نشاط أكثر.',
      'Failed to load reports: {error}': 'تعذّر تحميل البلاغات: {error}',
      'Notifications': 'الإشعارات',
      'No notifications yet': 'لا توجد إشعارات حتى الآن',
      'When alerts arrive, they will show up here.':
          'عند وصول التنبيهات ستظهر هنا.',
      'Failed to load notifications: {error}': 'تعذّر تحميل الإشعارات: {error}',
      'Mark all read': 'تعيين الكل كمقروء',
      'All notifications marked as read.': 'تم تعيين جميع الإشعارات كمقروءة.',
      'Clear all': 'مسح الكل',
      'Notifications cleared.': 'تم مسح الإشعارات.',
      'Notification removed.': 'تم حذف الإشعار.',
      'Mark unread': 'تعيين كغير مقروء',
      'Mark read': 'تعيين كمقروء',
      'No previous page to return to.': 'لا توجد صفحة سابقة للعودة إليها.',
      'Back': 'رجوع',
      'Submit a report': 'إرسال بلاغ',
      'Category': 'الفئة',
      'Sub-category': 'الفئة الفرعية',
      'Select a category': 'اختر فئة',
      'Select a sub-category': 'اختر فئة فرعية',
      'Description': 'الوصف',
      'Describe what is happening...': 'صف ما يحدث...',
      'Add photos or videos': 'أضف صورًا أو مقاطع فيديو',
      'Optional evidence helps responders assess severity.':
          'تساعد الأدلة الاختيارية الفرق على تقييم حجم الحالة.',
      '{count} attachment(s) selected': 'تم اختيار {count} مرفق',
      'Use current location': 'استخدام الموقع الحالي',
      'Disable to drop a manual pin later.':
          'ألغِ التفعيل لاختيار موقع يدويًا لاحقًا.',
      'I agree to the SpotnSend reporting policy':
          'أوافق على سياسة الإبلاغ في سبوت آند سند',
      'False reports can lead to legal consequences and a 3-month ban.':
          'قد تؤدي البلاغات الكاذبة إلى مساءلة قانونية وحظر لمدة ثلاثة أشهر.',
      'Continue': 'متابعة',
      'People': 'الأفراد',
      'Government': 'الجهات الحكومية',
      'Both': 'الكل',
      'Who should be notified?': 'من يجب إشعاره؟',
      'Verification Required': 'يتطلب التحقق',
      'Review account status': 'مراجعة حالة الحساب',
      'Before you submit': 'قبل الإرسال',
      'Government reports share your name, ID, and phone. False or misleading reports may result in legal action and 3-month account suspension. Proceed?':
          'سيتم مشاركة اسمك ورقم هويتك ورقم جوالك في البلاغات الحكومية. قد تؤدي البلاغات الكاذبة أو المضللة إلى إجراءات قانونية وتعليق الحساب لمدة ثلاثة أشهر. هل تريد المتابعة؟',
      'I understand': 'أنا أفهم',
      'You must agree to the warning before submitting.':
          'يجب الموافقة على التحذير قبل الإرسال.',
      'Report submitted. Officials will review shortly.':
          'تم إرسال البلاغ. سيتم مراجعته قريبًا.',
      'You must agree to the terms to continue':
          'يجب الموافقة على الشروط للمتابعة',
      'Please choose a category': 'يرجى اختيار فئة',
      'Unable to update saved spots.': 'تعذّر تحديث المواقع المحفوظة.',
      'You must be signed in to submit a report':
          'يجب تسجيل الدخول لإرسال البلاغ',
      'Login succeeded but no user data was returned.':
          'تم تسجيل الدخول لكن لم يتم استلام بيانات المستخدم.',
      'Please complete previous steps': 'يرجى إكمال الخطوات السابقة',
      'Invalid credentials. Please check your username or password.':
          'بيانات الدخول غير صحيحة. يرجى التحقق من اسم المستخدم أو كلمة المرور.',
      'Unable to sign in. Please try again.':
          'تعذّر تسجيل الدخول. يرجى المحاولة مرة أخرى.',
      'Connection failed. Check your network and try again.':
          'فشل الاتصال. تحقق من الشبكة وحاول مرة أخرى.',
      'Tester account is available in debug builds only.':
          'حساب التجربة متاح في وضع التطوير فقط.',
      'Unexpected error occurred.': 'حدث خطأ غير متوقع.',
      'Language': 'اللغة',
      'Notifications enabled.': 'تم تفعيل الإشعارات.',
      'Notifications disabled.': 'تم إيقاف الإشعارات.',
      'Two-factor authentication': 'التحقق بخطوتين',
      'Receive push notifications about nearby incidents and alerts.':
          'استلم إشعارات فورية عن الحوادث والتنبيهات القريبة.',
      'Add a verified phone for an extra security step.':
          'أضف رقمًا موثقًا لطبقة أمان إضافية.',
      'Language updated.': 'تم تحديث اللغة.',
      'Theme': 'السمة',
      'Light': 'فاتح',
      'Dark': 'داكن',
      'System': 'حسب النظام',
      'Change password': 'تغيير كلمة المرور',
      'Password reset flow coming soon.':
          'ميزة إعادة تعيين كلمة المرور ستتوفر قريبًا.',
      'Contact support': 'تواصل مع الدعم',
      'User guide': 'دليل المستخدم',
      'User guide will open in a future update.':
          'سيتم فتح دليل المستخدم في تحديث لاحق.',
      'Report a bug': 'الإبلاغ عن خطأ',
      'Bug report form coming soon.': 'نموذج الإبلاغ عن الأخطاء قادم قريبًا.',
      'Terms & Conditions': 'الشروط والأحكام',
      'Terms & Conditions screen placeholder.':
          'سيتم إضافة صفحة الشروط والأحكام لاحقًا.',
      'Enable Arabic RTL preview': 'تفعيل العرض بالعربية',
      'Back to English': 'العودة للإنجليزية',
      'App version ': 'إصدار التطبيق ',
      '2FA enabled.': 'تم تفعيل التحقق بخطوتين.',
      '2FA disabled.': 'تم إيقاف التحقق بخطوتين.',
      'Contact us at ': 'تواصل معنا عبر ',
      'Done': 'تم',
      'Add saved spots from account to get proactive alerts.':
          'أضف المواقع المحفوظة من الحساب للحصول على تنبيهات استباقية.',
      'Update {field}': 'تحديث {field}',
      'Your saved spots will always alert you.':
          'ستصلك تنبيهات دائمة من مواقعك المحفوظة.',
      'Back to map': 'العودة إلى الخريطة',
      'Invalid credentials. Please check your username or password and try again.':
          'بيانات اعتماد غير صحيحة. يرجى التحقق من اسم المستخدم أو كلمة المرور والمحاولة مرة أخرى.',
      'English': 'الإنجليزية',
      'Arabic': 'العربية',
      'Select Location': 'اختر الموقع',
      'Tap on the map to select a location': 'اضغط على الخريطة لاختيار الموقع',
      'Selected Location': 'الموقع المحدد',
      'Confirm Location': 'تأكيد الموقع',
      'Name this location': 'اسم هذا الموقع',
      'e.g., Home, Office, School': 'مثال: المنزل، المكتب، المدرسة',
      'Filters': 'الفلاتر',
      'Clear': 'مسح',
      'Include saved spots': 'تضمين المواقع المحفوظة',
      'Arabic Language': 'اللغة العربية',
      'Using Arabic interface': 'استخدام الواجهة العربية',
      'Using English interface': 'استخدام الواجهة الإنجليزية'
    }
  };

  String translate(String key, {Map<String, String>? params}) {
    final languageCode = _localizedValues.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    String template;
    if (languageCode == 'en') {
      template = key;
    } else {
      template = _localizedValues[languageCode]?[key] ?? key;
    }
    if (params == null || params.isEmpty) {
      return template;
    }
    var result = template;
    params.forEach((placeholder, value) {
      result = result.replaceAll('{$placeholder}', value);
    });
    return result;
  }

  String formatWithCount(String key, int count) {
    return translate(key, params: {'count': count.toString()});
  }

  String formatCoordinates(double lat, double lng) {
    return translate('Lat {lat}, Lng {lng}', params: {
      'lat': lat.toStringAsFixed(4),
      'lng': lng.toStringAsFixed(4),
    });
  }

  String updateFieldTitle(String field) {
    return translate('Update {field}', params: {'field': field});
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension LocalizationStringX on String {
  String tr({Map<String, String>? params}) =>
      AppLocalizations.current.translate(this, params: params);
}

extension LocalizationBuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
