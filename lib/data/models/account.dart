/// "له" (credit — owed to the user) vs "عليه" (debit — owed by the user) — a property of each
/// Transaction, not the Account itself (see transaction.dart). Kept here since both Account's
/// legacy JSON parsing and Transaction reference this same enum.
enum AccountDirection { credit, debit }

/// "عميل" vs "مورد" — drives the Home screen's tab filter (عملاء / موردين / عام).
enum AccountCategory { client, supplier }

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
  });

  final String id;
  final String name;
  final AccountCategory category;
  final DateTime createdDate;
  final String? details;
  final String? phone;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'createdDate': createdDate.toIso8601String(),
        'details': details,
        'phone': phone,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        // Defaults to `client` for any account saved before this field existed, so old local
        // data doesn't crash on load — see accounts_local_datasource.dart.
        category: AccountCategory.values.byName((json['category'] as String?) ?? 'client'),
        createdDate: DateTime.parse(
          (json['createdDate'] ?? json['date']) as String, // 'date' = pre-refactor key, see below
        ),
        details: json['details'] as String?,
        phone: json['phone'] as String?,
        updatedAt: json['updatedAt'] is String ? DateTime.tryParse(json['updatedAt'] as String) : null,
      );
}
