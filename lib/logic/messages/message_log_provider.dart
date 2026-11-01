import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/messages/message_log_local_datasource.dart';
import '../onboarding/onboarding_provider.dart' show sharedPreferencesProvider;
import 'message_templates.dart';

final messageLogLocalDataSourceProvider = Provider<MessageLogLocalDataSource>(
  (ref) => MessageLogLocalDataSource(ref.watch(sharedPreferencesProvider)),
);

/// "accountId|template" → when it was last sent.
final messageLogProvider = NotifierProvider<MessageLogController, Map<String, DateTime>>(MessageLogController.new);

class MessageLogController extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => ref.watch(messageLogLocalDataSourceProvider).get();

  static String keyFor(String accountId, MessageTemplate template) => '$accountId|${template.name}';

  Future<void> record(String accountId, MessageTemplate template) async {
    state = {...state, keyFor(accountId, template): DateTime.now()};
    await ref.read(messageLogLocalDataSourceProvider).save(state);
  }
}
