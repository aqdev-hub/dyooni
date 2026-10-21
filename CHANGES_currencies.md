# العملات — v9

- Drawer → العملات opens "إدارة العملات" (add / rename / delete; row shows number of transactions).
- Currency list is stored on the device (SharedPreferences). Defaults: محلي، أجنبي. Currencies already used by
  old transactions (USD, SAR …) are merged in automatically with their old Arabic names.
- Transactions store the currency id; renaming a currency relabels all its transactions.
- Home: a currency chip chooses the page; only accounts with entries in that currency are listed, with
  balances/counts/totals in that currency. Accounts with no entries appear on محلي.
- Account Details: shows only the selected currency's transactions/totals/statement; the dollar icon switches
  (only currencies the account uses). Adding/editing/voice-saving moves the view to the saved currency.
- Currency picker (add account/transaction) now lists the managed currencies.
- Icons: success (transparent), mic (record button + voice nav item only), bulb; all PNGs downsized.
- Known: backups (local/Drive) do not yet carry the currency NAMES list; reports screen totals are still
  all-currency; account ceiling check is now per currency.
