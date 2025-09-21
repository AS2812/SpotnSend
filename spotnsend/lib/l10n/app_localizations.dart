import 'package:flutter/widgets.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ar.dart';

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
    'en': {
      // Detailed Content - English
      'app_overview_content':
          'SpotnSend is a citizen safety app that lets users report hazards in real time (such as fires, accidents, floods, or crimes) and receive alerts about nearby dangers. It uses an interactive emergency response map to keep communities informed and safe. The app also forwards critical information to emergency services when needed. By engaging citizens in safety monitoring, SpotnSend helps reduce emergency response times and increase public awareness of local hazards.',

      'signup_guide_content':
          'Download SpotnSend and create an account using your mobile number or email. You will receive a verification code (OTP) to activate your account. Ensure you agree to the app\'s Privacy Policy and Terms of Use before proceeding.',

      'id_upload_guide_content':
          'For identity verification, SpotnSend requires you to upload a clear photo of your Egyptian National ID (بطاقة الرقم القومي). This confirms that each user is a real person. The app processes this ID securely and will use it only to verify your identity; it is not shared without your permission. (Note: National ID numbers and personal data are protected under Egyptian law.)',

      'reporting_guide_content':
          'To report a hazard, tap the "Report" button and choose the type of danger (fire, crime, accident, etc.). The app will use your GPS location or let you pin the location on the map. You can add a photo or description for clarity. Once submitted, your report is sent to other users nearby and relevant authorities (e.g. police or ambulance) if necessary.',

      'map_notifications_guide_content':
          'The app\'s main screen is a live map showing recent hazard reports as icons or markers. You can pan and zoom to see incidents in your area. You will receive push notifications about new dangers near you, based on your location. You can configure notification settings (e.g., radius or types of alerts) in the app. Stay aware: when you see a hazard on the map or receive an alert, use caution and avoid the area if possible.',

      'verification_guide_content':
          'SpotnSend may verify reports before broadcasting them to all users. This can involve confirming details with other users or officials. Verified reports help prevent false alarms. When you submit an ID or report, an admin review may approve your submission. Once verified, you will see a confirmation message.',

      'safety_principles_content':
          'Prioritize your safety. Do not approach dangerous situations; maintain a safe distance. If you are in immediate danger, call emergency services (e.g. 122 for police, 123 for ambulance in Egypt) before or while using the app. Verify information: treat app alerts as informational and confirm through official sources if possible. Report responsibly. Only submit accurate, on-the-ground information. Avoid jokes, pranks, or irrelevant content.',

      'identity_verification_content':
          'SpotnSend requires your Egyptian National ID number and phone number to verify your identity. This ensures that reports come from real individuals. Your ID and phone are treated as personal data under Egyptian law. You must provide accurate information; submitting false identity details is prohibited and may lead to legal penalties. Your personal data are collected only with your explicit consent. We use this data solely to provide SpotnSend services and to improve safety features.',

      'data_sharing_content':
          'SpotnSend will not share your ID or personal data with third parties without your consent, except as required by law. Your emergency reports (location, description, photos) are shared in real time with nearby users and may be forwarded to emergency authorities (police, medical responders, etc.) to facilitate quick assistance. Under Egyptian law, authorities can request personal data if necessary. The app does not sell or use your personal information for marketing.',

      'false_reporting_content':
          'Users must only report genuine hazards. Deliberately submitting a false report is prohibited. Under Egyptian law, spreading false information that threatens public safety is a crime. Violators can face severe penalties, including up to five years imprisonment and hefty fines. SpotnSend may permanently ban any user found to be filing false or malicious reports, and will cooperate with authorities in any legal investigation.',

      'platform_usage_content':
          'You agree to use SpotnSend in a lawful and respectful manner. You may not use the app to commit crimes, harass others, send spam, or upload illegal or copyrighted content. Respect other users: do not impersonate someone else or misuse anyone\'s personal information. You are responsible for maintaining the confidentiality of your account credentials.',

      'governing_law_content':
          'These Terms & Conditions are governed by the laws of Egypt. Any disputes arising from your use of SpotnSend will be resolved in the competent courts of Egypt. By using this app, you agree to abide by Egyptian law and consent to the jurisdiction of Egyptian courts.',

      'password_security_tips':
          'Use a strong password with at least 8 characters, including uppercase and lowercase letters, numbers, and special symbols. Avoid using personal information like your birthdate or name. Never share your password with anyone and don\'t use the same password across multiple sites.',
    },
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
      'Using English interface': 'استخدام الواجهة الإنجليزية',
      'Logout': 'تسجيل الخروج',
      'Are you sure you want to logout?': 'هل أنت متأكد من تسجيل الخروج؟',

      // Terms & Conditions
      'SpotnSend Terms & Conditions': 'شروط وأحكام SpotnSend',
      'Identity Verification & Privacy': 'التحقق من الهوية والخصوصية',
      'Data Sharing': 'مشاركة البيانات',
      'False Reporting and Accountability': 'المسؤولية عن التقارير الكاذبة',
      'Platform Usage Rules': 'قواعد استخدام المنصة',
      'Governing Law and Jurisdiction': 'القانون المطبق والاختصاص القضائي',
      'By using SpotnSend, you agree to these terms and conditions.':
          'باستخدام SpotnSend، فإنك توافق على هذه الشروط والأحكام.',

      // User Guide
      'SpotnSend User Guide': 'دليل المستخدم لـ SpotnSend',
      'Overview of Purpose and Value': 'نظرة عامة على الغرض والقيمة',
      'Sign-Up': 'التسجيل',
      'ID Upload': 'رفع بطاقة الهوية',
      'Reporting Hazards': 'الإبلاغ عن المخاطر',
      'Viewing Map and Notifications': 'عرض الخريطة والإشعارات',
      'Verification of Reports': 'التحقق من التقارير',
      'Safety Principles & User Responsibilities':
          'مبادئ السلامة ومسؤوليات المستخدم',
      'Emergency Numbers': 'أرقام الطوارئ',
      'Police: 122 | Ambulance: 123 | Fire: 180':
          'الشرطة: 122 | الإسعاف: 123 | الحريق: 180',

      // Change Password
      'Change Password': 'تغيير كلمة المرور',
      'Update Your Password': 'تحديث كلمة المرور',
      'Enter your current password and choose a new secure password.':
          'أدخل كلمة المرور الحالية واختر كلمة مرور جديدة آمنة.',
      'Current Password': 'كلمة المرور الحالية',
      'Enter your current password': 'أدخل كلمة المرور الحالية',
      'New Password': 'كلمة المرور الجديدة',
      'Enter your new password': 'أدخل كلمة المرور الجديدة',
      'Confirm New Password': 'تأكيد كلمة المرور الجديدة',
      'Confirm your new password': 'أكد كلمة المرور الجديدة',
      'New passwords do not match': 'كلمات المرور الجديدة غير متطابقة',
      'Passwords do not match': 'كلمات المرور غير متطابقة',
      'Password changed successfully': 'تم تغيير كلمة المرور بنجاح',
      'Failed to change password. Please try again.':
          'فشل في تغيير كلمة المرور. يرجى المحاولة مرة أخرى.',
      'Password Security Tips': 'نصائح أمان كلمة المرور',

      // Report Bug
      'Report a Bug': 'الإبلاغ عن خطأ',
      'Help Us Improve SpotnSend': 'ساعدنا في تحسين SpotnSend',
      'Report bugs to help us make the app better for everyone.':
          'أبلغ عن الأخطاء لمساعدتنا في جعل التطبيق أفضل للجميع.',
      'Bug Title': 'عنوان الخطأ',
      'Brief description of the issue': 'وصف مختصر للمشكلة',
      'Severity Level': 'مستوى الخطورة',
      'Low': 'منخفض',
      'Medium': 'متوسط',
      'High': 'عالي',
      'Critical': 'حرج',
      'Describe what happened and what you expected':
          'صف ما حدث وما كنت تتوقعه',
      'Steps to Reproduce': 'خطوات إعادة المشكلة',
      '1. Open the app\n2. Navigate to...\n3. Click on...':
          '1. افتح التطبيق\n2. انتقل إلى...\n3. اضغط على...',
      'Submit Bug Report': 'إرسال تقرير الخطأ',
      'Bug report submitted successfully. Thank you!':
          'تم إرسال تقرير الخطأ بنجاح. شكراً لك!',
      'Failed to submit bug report. Please try again.':
          'فشل في إرسال تقرير الخطأ. يرجى المحاولة مرة أخرى.',
      'Need immediate help?': 'تحتاج مساعدة فورية؟',
      'Contact support at support@spotnsend.com':
          'تواصل مع الدعم على support@spotnsend.com',
      'Category': 'الفئة',
      'Sub-category': 'الفئة الفرعية',
      'Select a category': 'اختر فئة',
      'Select a sub-category': 'اختر فئة فرعية',
      'Select category first': 'اختر الفئة أولاً',

      // Detailed Content
      'app_overview_content':
          'يتيح تطبيق SpotnSend للمواطنين الإبلاغ عن المخاطر في الوقت الحقيقي (مثل الحرائق والحوادث والفيضانات والجرائم) واستقبال تنبيهات عن الأخطار القريبة. يستخدم التطبيق خريطة طوارئ تفاعلية لإبقاء المجتمع على اطلاع. كما يقوم بتحويل المعلومات الحرجة إلى خدمات الطوارئ عند الحاجة. من خلال إشراك المواطنين في مراقبة السلامة، يساعد SpotnSend في تقليل زمن الاستجابة في الحالات الطارئة وزيادة الوعي العام بالمخاطر المحلية.',

      'signup_guide_content':
          'حمّل تطبيق SpotnSend وأنشئ حساباً باستخدام رقم هاتفك المحمول أو بريدك الإلكتروني. ستتلقى رمز تحقق (OTP) لتفعيل حسابك. تأكد من الموافقة على سياسة الخصوصية والشروط قبل المتابعة.',

      'id_upload_guide_content':
          'من أجل التحقق من هويتك، يطلب SpotnSend رفع صورة واضحة لبطاقة الرقم القومي المصرية الخاصة بك. هذا يؤكد أن كل مستخدم هو شخص حقيقي. يقوم التطبيق بمعالجة هذه البطاقة بأمان ولن يستخدمها إلا للتحقق من هويتك، ولن تتم مشاركتها بدون إذنك. (ملاحظة: تُعامل أرقام البطاقة القومية والبيانات الشخصية حسب قانون حماية البيانات المصري.)',

      'reporting_guide_content':
          'للإبلاغ عن خطر، اضغط على زر "إبلاغ" واختر نوع الخطر (حريق، جريمة، حادث، إلخ). سيستخدم التطبيق نظام تحديد المواقع (GPS) الخاص بك أو يمكنك تحديد الموقع على الخريطة يدوياً. يمكنك إضافة صورة أو وصف لمزيد من التوضيح. عند الإرسال، يُنشر تقريرك على المستخدمين القريبين ومع الجهات المختصة (مثل الشرطة أو الإسعاف) إذا لزم الأمر.',

      'map_notifications_guide_content':
          'الشاشة الرئيسية للتطبيق تحتوي على خريطة حيّة تعرض تقارير المخاطر الأخيرة على شكل أيقونات أو علامات. يمكنك تحريك الخريطة وتكبيرها لرؤية الحوادث في منطقتك. ستتلقى إشعارات فورية حول الأخطار الجديدة القريبة منك بناءً على موقعك. يمكنك ضبط إعدادات الإشعارات (مثل نطاق الإشعار أو نوع الخطر). تذكر: عند رؤية خطر على الخريطة أو استلام تنبيه، كن حذراً وتجنب المنطقة إن أمكن.',

      'verification_guide_content':
          'قد يقوم SpotnSend بالتحقق من صحة التقارير قبل نشرها للجميع. يشمل ذلك التأكد من التفاصيل عبر مراجعتها من قبل مستخدمين آخرين أو جهات رسمية. تساعد التقارير المؤكدة في تجنب الإنذارات الكاذبة. عند إرسال هويتك أو تقريرك، قد يراجعها مسؤول التطبيق ويوافق عليها. بعد التحقق، ستصلك رسالة تأكيد.',

      'safety_principles_content':
          'السلامة أولاً. لا تقم بالاقتراب من المواقف الخطرة وحافظ على مسافة آمنة. إذا كنت في خطر مباشر، اتصل فوراً بخدمات الطوارئ (مثل 122 للشرطة، 123 للإسعاف في مصر) قبل استخدام التطبيق أو خلاله. تحقق من المعلومات: تعامل مع التنبيهات كمعلومات مساعدة وحاول تأكيدها عبر مصادر رسمية إن أمكن. أبلغ بمسؤولية. قدم معلومات دقيقة وحقيقية فقط. تجنب النكات أو البلاغات الكاذبة أو المحتوى غير المناسب.',

      'identity_verification_content':
          'يطلب SpotnSend رقم البطاقة القومية المصرية ورقم هاتفك للتحقق من هويتك. هذا يضمن أن التقارير صادرة عن أشخاص حقيقيين. تُعامل بيانات هويتك وهاتفك على أنها بيانات شخصية طبقاً للقانون المصري. يجب تقديم معلومات صحيحة؛ يُحظر تقديم بيانات هوية زائفة وقد يؤدي ذلك إلى عقوبات قانونية. يتم جمع بياناتك الشخصية فقط بموافقتك الصريحة. نستخدم هذه البيانات لخدمات التطبيق فقط ولتحسين وظائف السلامة.',

      'data_sharing_content':
          'لن يشارك SpotnSend بطاقتك أو بياناتك الشخصية مع أي طرف ثالث دون موافقتك، إلا إذا تطلب القانون ذلك. تقاريرك الطارئة (الموقع، الوصف، الصور) تُشارك فورياً مع المستخدمين القريبين وقد تُحوّل إلى الجهات الطارئة (الشرطة، الإسعاف، إلخ) لتسهيل الاستجابة السريعة. بموجب القانون المصري، يمكن للسلطات المختصة طلب البيانات الشخصية إذا لزم الأمر. لا يقوم التطبيق ببيع معلوماتك الشخصية أو استخدامها في التسويق.',

      'false_reporting_content':
          'يجب على المستخدمين الإبلاغ عن مخاطر حقيقية فقط. يُحظر عمداً تقديم تقرير كاذب. بموجب القانون المصري، نشر معلومات زائفة تهدد السلامة العامة جريمة. يمكن للمخالفين أن يواجهوا عقوبات صارمة، بما في ذلك السجن لمدة تصل إلى خمس سنوات وغرامات كبيرة. قد يؤدي أي تحقيق يظهر تورط المستخدم في إرسال تقارير كاذبة أو ضارة إلى حظر حسابه نهائياً، وسيتعاون SpotnSend مع السلطات في أي متابعة قانونية.',

      'platform_usage_content':
          'توافق على استخدام SpotnSend بطريقة قانونية ومحترمة. لا يجوز لك استخدام التطبيق لارتكاب جرائم أو مضايقة الآخرين أو إرسال محتوى غير مرغوب أو رفع محتوى غير قانوني أو محمي بحقوق الطبع والنشر. احترم المستخدمين الآخرين: لا تنتحل شخصية أحدهم أو تسيء استخدام معلوماتهم الشخصية. أنت مسؤول عن الحفاظ على سرية بيانات حسابك.',

      'governing_law_content':
          'تخضع هذه الشروط والأحكام لقوانين جمهورية مصر العربية. يتم حل أي نزاعات تنشأ عن استخدامك لـSpotnSend في المحاكم المختصة بمصر. باستخدامك لهذا التطبيق، فإنك توافق على الالتزام بالقانون المصري والخضوع لاختصاص محاكم مصر.',

      'password_security_tips':
          'استخدم كلمة مرور قوية تحتوي على 8 أحرف على الأقل، وتشمل أحرفاً كبيرة وصغيرة وأرقاماً ورموزاً خاصة. تجنب استخدام معلومات شخصية مثل تاريخ ميلادك أو اسمك. لا تشارك كلمة المرور مع أحد ولا تستخدم نفس كلمة المرور في مواقع متعددة.'
    }
  };

  String translate(String key, {Map<String, String>? params}) {
    final languageCode = locale.languageCode;
    String template;

    if (languageCode == 'ar') {
      template =
          arabicLocalizations[key] ?? _localizedValues['ar']?[key] ?? key;
    } else {
      template = englishLocalizations[key] ?? key;
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
