import 'package:shared_preferences/shared_preferences.dart';

/// What SplashGate should do once onboarding+auth are resolved, when an interrupted "add
/// account"/"add transaction" draft is found still sitting in SharedPreferences — see
/// FormDraftStorage's doc comment for why a draft can outlive the app process entirely: it's
/// written to disk immediately, unlike the in-memory Navigator stack that held the "Add
/// Account"/"Add Transaction" dialog. If Android kills this app's process while the native
/// camera Activity is in the foreground (see AndroidManifest.xml's "Camera-crash mitigation
/// notes"), the draft survives even though the dialog itself does not — this is what lets the
/// person be taken straight back to finish what they were doing, instead of landing on an
/// empty-looking Home with no indication anything was in progress.
sealed class InterruptedFormRecovery {
  const InterruptedFormRecovery();
}

/// Resume "إضافة حساب جديد" — its draft key carries no extra information, so recovering just
/// means opening the screen again; AddAccountScreen's own `_restoreDraftIfAny()` does the rest.
class ResumeAddAccount extends InterruptedFormRecovery {
  const ResumeAddAccount();
}

/// Resume "إضافة عملية" for [accountId] — the draft key itself is suffixed with the account id
/// (see AddTransactionScreen's `_draftKey`), which is the only piece of information this needs;
/// AddTransactionScreen's own `_restoreDraftIfAny()` recovers everything else.
class ResumeAddTransaction extends InterruptedFormRecovery {
  const ResumeAddTransaction(this.accountId);
  final String accountId;
}

const addAccountDraftKey = 'draft_add_account';
const addTransactionDraftPrefix = 'draft_add_transaction_';

/// Looks for exactly one interrupted create-flow draft — `null` in the overwhelmingly common
/// case (a normal app start with nothing left mid-entry). Deliberately checks the ACCOUNT draft
/// first: if one exists, it was necessarily opened more recently than any transaction draft
/// could have been (a transaction draft can only exist once an account already existed to add
/// one to), so it's the more relevant screen to resume.
InterruptedFormRecovery? findInterruptedFormDraft(SharedPreferences prefs) {
  if (prefs.containsKey(addAccountDraftKey)) return const ResumeAddAccount();
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(addTransactionDraftPrefix)) continue;
    final accountId = key.substring(addTransactionDraftPrefix.length);
    if (accountId.isNotEmpty) return ResumeAddTransaction(accountId);
  }
  return null;
}
