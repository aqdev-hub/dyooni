import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/categories/categories_local_datasource.dart';
import '../../data/models/account.dart';
import '../../data/models/category_type.dart';
import '../accounts/accounts_provider.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final categoriesLocalDataSourceProvider = Provider<CategoriesLocalDataSource>(
  (ref) => CategoriesLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

/// Why a category name was refused. Mapped to localized text in the view.
enum CategoryNameError { empty, duplicate }

class CategoryNameException implements Exception {
  const CategoryNameException(this.error);
  final CategoryNameError error;
}

/// Why a category cannot be deleted. Mapped to localized text in the view.
enum CategoryDeleteBlock {
  /// "عام" — it is the all-accounts tab, not a real category.
  protected,

  /// Accounts still belong to it.
  inUse,

  /// It is the last real category: an account must always belong to one.
  lastOne,
}

class CategoryDeleteException implements Exception {
  const CategoryDeleteException(this.reason);
  final CategoryDeleteBlock reason;
}

/// Thrown when hiding a tab would leave Home with no tab at all.
class CategoryVisibilityException implements Exception {
  const CategoryVisibilityException();
}

/// What the person saved (or the three defaults). Screens must NOT read this: they read
/// [categoryTypesProvider], which also includes categories existing accounts use.
final categoryTypesStoreProvider = NotifierProvider<CategoryTypesStore, List<CategoryType>>(
  CategoryTypesStore.new,
);

class CategoryTypesStore extends Notifier<List<CategoryType>> {
  @override
  List<CategoryType> build() {
    final saved = ref.watch(categoriesLocalDataSourceProvider).get();
    if (saved == null || saved.isEmpty) return defaultCategoryTypes;
    // "عام" is guaranteed to exist (and stays first) even if the stored list was damaged.
    if (!saved.any((c) => c.isGeneral)) return [defaultCategoryTypes.first, ...saved];
    return saved;
  }

  static String _normalize(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// `null` when [raw] is acceptable; [excludeId] is the category being renamed.
  CategoryNameError? validateName(String raw, {String? excludeId}) {
    final name = _normalize(raw);
    if (name.isEmpty) return CategoryNameError.empty;
    final taken = ref.read(categoryTypesProvider).any((c) => c.id != excludeId && _normalize(c.name) == name);
    return taken ? CategoryNameError.duplicate : null;
  }

  /// Ids are never reused (a renamed category keeps its old id), or a NEW category with the old
  /// name would silently merge with the old one's accounts.
  String _uniqueId(String name, Iterable<String> takenIds) {
    final taken = takenIds.toSet();
    final base = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (!taken.contains(base)) return base;
    var n = 2;
    while (taken.contains('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  Future<void> _persist(List<CategoryType> next) async {
    await ref.read(categoriesLocalDataSourceProvider).save(next);
    state = next;
  }

  Future<CategoryType> add(String rawName) async {
    final error = validateName(rawName);
    if (error != null) throw CategoryNameException(error);
    final current = ref.read(categoryTypesProvider);
    final created = CategoryType(id: _uniqueId(rawName, current.map((c) => c.id)), name: rawName.trim());
    await _persist([...current, created]);
    return created;
  }

  Future<void> rename(String id, String rawName) async {
    final error = validateName(rawName, excludeId: id);
    if (error != null) throw CategoryNameException(error);
    final current = ref.read(categoryTypesProvider);
    await _persist([
      for (final c in current)
        if (c.id == id) c.copyWith(name: rawName.trim()) else c,
    ]);
  }

  /// Show/hide a category's tab on Home. At least one tab always stays visible.
  Future<void> setVisible(String id, bool visible) async {
    final current = ref.read(categoryTypesProvider);
    if (!visible && current.where((c) => c.visible && c.id != id).isEmpty) {
      throw const CategoryVisibilityException();
    }
    await _persist([
      for (final c in current)
        if (c.id == id) c.copyWith(visible: visible) else c,
    ]);
  }

  Future<void> delete(String id) async {
    if (id == generalCategoryId) throw const CategoryDeleteException(CategoryDeleteBlock.protected);
    if ((ref.read(categoryUsageProvider)[id] ?? 0) > 0) {
      throw const CategoryDeleteException(CategoryDeleteBlock.inUse);
    }
    final current = ref.read(categoryTypesProvider);
    if (current.where((c) => !c.isGeneral && c.id != id).isEmpty) {
      throw const CategoryDeleteException(CategoryDeleteBlock.lastOne);
    }
    final remaining = [for (final c in current) if (c.id != id) c];
    // Deleting the only visible tab must not leave Home without tabs.
    if (!remaining.any((c) => c.visible)) {
      remaining[0] = remaining[0].copyWith(visible: true);
    }
    await _persist(remaining);
  }
}

/// EVERY category that exists: the person's list, plus any category an existing account uses
/// that is missing from it (data from before this feature, or restored from another device).
/// No account can therefore ever end up in a category that cannot be seen or chosen.
final categoryTypesProvider = Provider<List<CategoryType>>((ref) {
  final stored = ref.watch(categoryTypesStoreProvider);
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final known = {for (final c in stored) c.id};
  final extra = <CategoryType>[];
  for (final a in accounts) {
    if (known.add(a.category.id)) {
      extra.add(CategoryType(id: a.category.id, name: legacyCategoryName(a.category.id) ?? a.category.id));
    }
  }
  return extra.isEmpty ? stored : [...stored, ...extra];
});

/// Real categories only — what an account can be put in (everything except "عام").
final assignableCategoriesProvider = Provider<List<CategoryType>>((ref) {
  return [for (final c in ref.watch(categoryTypesProvider)) if (!c.isGeneral) c];
});

/// How many accounts are in each category; "عام" counts all accounts.
final categoryUsageProvider = Provider<Map<String, int>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  final counts = <String, int>{generalCategoryId: accounts.length};
  for (final a in accounts) {
    counts[a.category.id] = (counts[a.category.id] ?? 0) + 1;
  }
  return counts;
});

/// The tabs Home shows, in list order. `null` stands for the "عام" (all accounts) tab. Never
/// empty.
final categoryTabsProvider = Provider<List<AccountCategory?>>((ref) {
  final tabs = <AccountCategory?>[
    for (final c in ref.watch(categoryTypesProvider))
      if (c.visible) (c.isGeneral ? null : AccountCategory(c.id)),
  ];
  return tabs.isEmpty ? const <AccountCategory?>[null] : tabs;
});

/// The tab Home is really on: the one the person picked if it is still visible, else the first
/// visible tab (e.g. after hiding or deleting the selected one).
final effectiveCategoryProvider = Provider.autoDispose<AccountCategory?>((ref) {
  final selected = ref.watch(selectedCategoryProvider);
  final tabs = ref.watch(categoryTabsProvider);
  return tabs.contains(selected) ? selected : tabs.first;
});

/// The category a NEW account (voice, or the add form's initial choice) starts in: "العملاء" if it
/// still exists, else the first real category.
final defaultAccountCategoryProvider = Provider<AccountCategory>((ref) {
  final real = ref.watch(assignableCategoriesProvider);
  if (real.any((c) => c.id == AccountCategory.client.id)) return AccountCategory.client;
  return real.isEmpty ? AccountCategory.client : AccountCategory(real.first.id);
});
