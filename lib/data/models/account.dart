/// "له" (credit — owed to the user) vs "عليه" (debit — owed by the user) — a property of each
/// Transaction, not the Account itself (see transaction.dart). Kept here since both Account's
/// legacy JSON parsing and Transaction reference this same enum.
enum AccountDirection { credit, debit }

/// Which category an account belongs to (عملاء / موردين / any the person adds in drawer → التصنيفات).
///
/// Deliberately NOT an `enum` any more: categories are now managed by the person, so the set is
/// open. It is a thin wrapper over the category's [id]; the two built-in ids keep their old
/// spelling ('client', 'supplier') so every account saved before this change still loads, and
/// `AccountCategory.client` / `.supplier` keep working wherever they were used. The names the
/// person SEES live in the category list (logic/categories/categories_provider.dart), never here.
class AccountCategory {
  const AccountCategory(this.id);

  final String id;

  /// Same value as [id] — kept because older code read `category.name` (it was an enum).
  String get name => id;

  static const client = AccountCategory('client');
  static const supplier = AccountCategory('supplier');

  @override
  bool operator ==(Object other) => other is AccountCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AccountCategory($id)';
}

/// A person/entity — NOT a balance. Balance and transaction count are always derived from that
/// account's Transactions (see logic/transactions/transactions_provider.dart), never stored here.
/// This split exists so an account can accumulate many entries over time, matching the reference
/// screenshots' "16 عملية" badge — a single stored amount could never represent that.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.category,
    required this.createdDate,
    this.details,
    this.phone,
    this.updatedAt,
    this.ceiling,
    this.attachmentPath,
  });

  final String id;
  final String name;
  final AccountCategory category;
  final DateTime createdDate;
  final String? details;
  final String? phone;
  final DateTime? updatedAt;

  /// سقف/حد الحساب الائتماني — اختياري، يُدخَل فقط عندما تكون
  /// GeneralSettings.showAccountCeilingOnAdd مفعّلة (انظر
  /// logic/settings/general_settings_provider.dart و view/screens/accounts/add_account_screen.dart).
  /// لا يوجد بعد أي منطق تنبيه/تجاوز حد فعلي مبني على هذه القيمة — حقل مُخزَّن فقط في هذه الدفعة.
  final double? ceiling;

  /// Optional photo attached to the account itself. Unlike a transaction attachment, this can
  /// be safely changed from the account edit form.
  final String? attachmentPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.id,
        'createdDate': createdDate.toIso8601String(),
        'details': details,
        'phone': phone,
        'updatedAt': updatedAt?.toIso8601String(),
        'ceiling': ceiling,
        'attachmentPath': attachmentPath,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        // Defaults to `client` for any account saved before this field existed, so old local
        // data doesn't crash on load — see accounts_local_datasource.dart.
        category: AccountCategory((json['category'] as String?) ?? 'client'),
        createdDate: DateTime.parse(
          (json['createdDate'] ?? json['date']) as String, // 'date' = pre-refactor key, see below
        ),
        details: json['details'] as String?,
        phone: json['phone'] as String?,
        updatedAt: json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt'] as String) : null,
        ceiling: (json['ceiling'] as num?)?.toDouble(),
        attachmentPath: json['attachmentPath'] as String?,
      );
}
