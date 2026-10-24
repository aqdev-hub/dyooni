import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../categories/categories_provider.dart';
import '../currencies/currencies_provider.dart';
import 'general_settings_provider.dart';

/// The category a NEW account starts in, decided by the person in الإعدادات:
///  1. the category they picked as the default (if it still exists);
///  2. otherwise "keep last": the category of the last account they saved;
///  3. otherwise the tab Home is on (when it is a real category), else the app default.
final newAccountCategoryProvider = Provider.autoDispose<AccountCategory>((ref) {
  final settings = ref.watch(generalSettingsProvider).value;
  final options = ref.watch(assignableCategoriesProvider);
  bool exists(String? id) => id != null && options.any((c) => c.id == id);

  if (exists(settings?.defaultCategoryId)) return AccountCategory(settings!.defaultCategoryId!);
  if (exists(settings?.lastUsedCategoryId)) return AccountCategory(settings!.lastUsedCategoryId!);
  return ref.watch(effectiveCategoryProvider) ?? ref.watch(defaultAccountCategoryProvider);
});

/// The currency a NEW account/transaction starts in: the default the person chose in الإعدادات
/// (if it still exists), otherwise "keep last" = the currency page currently open.
final newEntryCurrencyIdProvider = Provider.autoDispose<String>((ref) {
  final id = ref.watch(generalSettingsProvider).value?.defaultCurrencyId;
  final types = ref.watch(currencyTypesProvider);
  if (id != null && types.any((c) => c.id == id)) return id;
  return ref.watch(effectiveCurrencyIdProvider);
});
