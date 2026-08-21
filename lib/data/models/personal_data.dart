/// Business-card style details that appear in report headers, edited on the "Personal Data"
/// screen. Ships with Dyooni's own branding as the default (never the signed-in user's real
/// name/email) so the report header never looks blank before someone customizes it.
///
/// KNOWN SCOPE LIMIT, stated plainly: this data is not wired into `pdf_report_service.dart` yet
/// — saving here persists real values for real, but the PDF report header still uses its own
/// hardcoded `appName`/`reportTitle` strings. Connecting the two is future work.
class PersonalData {
  const PersonalData({
    required this.nameAr,
    required this.nameEn,
    required this.addressAr,
    required this.addressEn,
    required this.phone,
    required this.email,
    required this.signatureEnabled,
    required this.stampEnabled,
    this.signaturePath,
    this.stampPath,
  });

  final String nameAr;
  final String nameEn;
  final String addressAr;
  final String addressEn;
  final String phone;
  final String email;
  final bool signatureEnabled;
  final bool stampEnabled;

  /// Local file path to the hand-drawn signature PNG saved by SignatureCaptureScreen, or `null`
  /// if the person never drew one yet.
  final String? signaturePath;

  /// Local file path to the stamp image picked via image_picker, or `null` if none was chosen.
  final String? stampPath;

  /// Dyooni's own default report-header identity — shown until the person fills in their own.
  /// Phone is deliberately left blank rather than a fabricated-looking number (a fake real-style
  /// phone number here could mislead someone into thinking it's a working contact line).
  static const dyooniDefault = PersonalData(
    nameAr: 'ديوني',
    nameEn: 'Dyooni',
    addressAr: 'تطبيق إدارة الحسابات والديون',
    addressEn: 'Debt & Accounts Management App',
    phone: '',
    email: 'support@dyooni.app',
    signatureEnabled: true,
    stampEnabled: true,
  );

  Map<String, dynamic> toJson() => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'addressAr': addressAr,
        'addressEn': addressEn,
        'phone': phone,
        'email': email,
        'signatureEnabled': signatureEnabled,
        'stampEnabled': stampEnabled,
        'signaturePath': signaturePath,
        'stampPath': stampPath,
      };

  factory PersonalData.fromJson(Map<String, dynamic> json) => PersonalData(
        nameAr: json['nameAr'] as String? ?? dyooniDefault.nameAr,
        nameEn: json['nameEn'] as String? ?? dyooniDefault.nameEn,
        addressAr: json['addressAr'] as String? ?? dyooniDefault.addressAr,
        addressEn: json['addressEn'] as String? ?? dyooniDefault.addressEn,
        phone: json['phone'] as String? ?? dyooniDefault.phone,
        email: json['email'] as String? ?? dyooniDefault.email,
        signatureEnabled: json['signatureEnabled'] as bool? ?? true,
        stampEnabled: json['stampEnabled'] as bool? ?? true,
        signaturePath: json['signaturePath'] as String?,
        stampPath: json['stampPath'] as String?,
      );
}
