/// The id of the built-in "محلي" currency. It is the page every account without transactions
/// lives on, the default for new entries, and it can never be deleted — so there is always at
/// least one currency to put an amount in.
const defaultCurrencyId = 'LOCAL';

/// A currency the person manages themselves (drawer → العملات) — "محلي", "أجنبي", "دولار" …
///
/// WHY an id AND a name: a Transaction stores only the [id] (its `currency` field), never the
/// name. Renaming a currency therefore changes how every one of its transactions is labelled
/// without touching a single transaction. The id of a person-created currency is its original
/// name (made unique), so even if the currency list is ever lost (a restore on another device),
/// the id still reads as a meaningful name instead of an opaque code.
///
/// The ids 'LOCAL', 'YER', 'USD', 'SAR', 'AED', 'EGP', 'KWD' are the fixed codes the app used
/// before currencies became editable; existing transactions keep working because they already
/// store exactly these.
class CurrencyType {
  const CurrencyType({required this.id, required this.name});

  final String id;
  final String name;

  CurrencyType copyWith({String? name}) => CurrencyType(id: id, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory CurrencyType.fromJson(Map<String, dynamic> json) =>
      CurrencyType(id: json['id'] as String, name: json['name'] as String);

  @override
  bool operator ==(Object other) => other is CurrencyType && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'CurrencyType($id, $name)';
}

/// What a brand-new installation starts with: exactly the two currencies of the reference
/// screen. Anything else is added by the person.
const defaultCurrencyTypes = <CurrencyType>[
  CurrencyType(id: defaultCurrencyId, name: 'محلي'),
  CurrencyType(id: 'FOREIGN', name: 'أجنبي'),
];

/// Names for the codes older versions of the app wrote into transactions. Used only when a
/// transaction refers to a currency that is not (yet) in the person's list.
const _legacyNames = <String, String>{
  'LOCAL': 'محلي',
  'YER': 'ريال يمني',
  'USD': 'دولار أمريكي',
  'SAR': 'ريال سعودي',
  'AED': 'درهم إماراتي',
  'EGP': 'جنيه مصري',
  'KWD': 'دينار كويتي',
};

String? legacyCurrencyName(String id) => _legacyNames[id];

/// The name to show for [id]: the person's own name if the currency is in [list], else the
/// legacy name for an old code, else the id itself (which, by construction above, reads as a
/// name for person-created currencies).
String currencyNameOf(List<CurrencyType> list, String id) {
  for (final currency in list) {
    if (currency.id == id) return currency.name;
  }
  return legacyCurrencyName(id) ?? id;
}
