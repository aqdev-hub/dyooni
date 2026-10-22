/// The id of the built-in "عام" entry. It is NOT a category an account can belong to: it is the
/// "all accounts" tab. It only appears in the list so the person can show or hide that tab.
const generalCategoryId = 'general';

/// One entry of the person's category list (drawer → التصنيفات): a name, and whether it gets its
/// own tab on Home ([visible]).
///
/// An Account stores only the category [id] (see AccountCategory), never the name, so renaming a
/// category relabels all its accounts without touching them. The ids 'client' and 'supplier' are
/// what accounts saved before categories became editable already contain. The id of a
/// person-created category is its original name (made unique), so even if the list is ever lost
/// (a restore on another device) the id still reads as a meaningful name.
class CategoryType {
  const CategoryType({required this.id, required this.name, this.visible = true});

  final String id;
  final String name;
  final bool visible;

  bool get isGeneral => id == generalCategoryId;

  CategoryType copyWith({String? name, bool? visible}) =>
      CategoryType(id: id, name: name ?? this.name, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'visible': visible};

  factory CategoryType.fromJson(Map<String, dynamic> json) => CategoryType(
        id: json['id'] as String,
        name: json['name'] as String,
        visible: json['visible'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) =>
      other is CategoryType && other.id == id && other.name == name && other.visible == visible;

  @override
  int get hashCode => Object.hash(id, name, visible);

  @override
  String toString() => 'CategoryType($id, $name, visible: $visible)';
}

/// What a brand-new installation starts with — the three rows of the reference screen.
const defaultCategoryTypes = <CategoryType>[
  CategoryType(id: generalCategoryId, name: 'عام'),
  CategoryType(id: 'client', name: 'العملاء'),
  CategoryType(id: 'supplier', name: 'الموردين'),
];

const _legacyNames = <String, String>{
  generalCategoryId: 'عام',
  'client': 'العملاء',
  'supplier': 'الموردين',
};

String? legacyCategoryName(String id) => _legacyNames[id];

/// The name to show for [id]: the person's own name if it is in [list], else the built-in name,
/// else the id itself (which reads as a name for person-created categories).
String categoryNameOf(List<CategoryType> list, String id) {
  for (final category in list) {
    if (category.id == id) return category.name;
  }
  return legacyCategoryName(id) ?? id;
}
