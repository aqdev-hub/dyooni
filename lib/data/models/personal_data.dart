/// Business-card style details that appear in report headers, edited on the "Personal Data"
/// screen. Ships with Dyooni's own branding as the default (never the signed-in user's real
/// name/email) so the report header never looks blank before someone customizes it.
///
/// [signaturePath]/[stampPath] being `null` does NOT mean "nothing is shown" — both the Personal
/// Data screen and the generated PDF report fall back to Dyooni's own bundled default images
/// (`assets/icons/default_signature.png` / `assets/icons/default_stamp.png`) until the person
/// picks their own, so a report never ships with a blank signature/stamp box. See
/// personal_data_screen.dart's preview widgets and pdf_report_service.dart's
/// `_loadCustomOrDefaultImage` for the two places this fallback is applied.
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
    this.logoPath,
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

  /// Local file path to a custom logo image picked via image_picker, or `null` to use Dyooni's
  /// own bundled app_logo.png (the default, shown until the person picks their own).
  final String? logoPath;

  /// Local file path to the hand-drawn signature PNG saved by SignatureCaptureScreen, or the
  /// bundled default signature image (`assets/icons/default_signature.png`) if the person never
  /// drew/picked one yet — see the class doc comment above.
  final String? signaturePath;

  /// Local file path to the stamp image picked via image_picker, or the bundled default stamp
  /// image (`assets/icons/default_stamp.png`) if none was chosen yet — see the class doc comment
  /// above.
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
    email: 'dyooniaqdev@gmail.com',
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
        'logoPath': logoPath,
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
        logoPath: json['logoPath'] as String?,
        signaturePath: json['signaturePath'] as String?,
        stampPath: json['stampPath'] as String?,
      );
}
