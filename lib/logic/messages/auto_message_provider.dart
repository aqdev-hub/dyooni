import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/messages/auto_message_local_datasource.dart';
import '../../data/models/auto_message_settings.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;

final autoMessageLocalDataSourceProvider = Provider<AutoMessageLocalDataSource>(
  (ref) => AutoMessageLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

final autoMessageSettingsProvider =
    NotifierProvider<AutoMessageSettingsController, AutoMessageSettings>(AutoMessageSettingsController.new);

class AutoMessageSettingsController extends Notifier<AutoMessageSettings> {
  @override
  AutoMessageSettings build() => ref.watch(autoMessageLocalDataSourceProvider).getSettings();

  Future<void> update(AutoMessageSettings Function(AutoMessageSettings) change) async {
    state = change(state);
    await ref.read(autoMessageLocalDataSourceProvider).saveSettings(state);
  }
}

/// accountId → that account's override. Accounts with no entry follow the global settings.
final accountAutoMessagesProvider =
    NotifierProvider<AccountAutoMessagesController, Map<String, AccountAutoMessage>>(AccountAutoMessagesController.new);

class AccountAutoMessagesController extends Notifier<Map<String, AccountAutoMessage>> {
  @override
  Map<String, AccountAutoMessage> build() => ref.watch(autoMessageLocalDataSourceProvider).getOverrides();

  Future<void> setFor(String accountId, AccountAutoMessage value) async {
    final next = {...state};
    if (value.isDefault) {
      next.remove(accountId);
    } else {
      next[accountId] = value;
    }
    state = next;
    await ref.read(autoMessageLocalDataSourceProvider).saveOverrides(state);
  }
}
