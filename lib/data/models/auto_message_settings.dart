/// How much the automatic balance message says.
enum AutoMessageContent { balanceOnly, detailed }

/// Which app opens to send it. [ask] = the person picks every time.
enum AutoMessageChannel { sms, whatsapp, ask }

/// What ONE account does, on top of the global defaults.
enum AccountAutoMode { useDefault, balanceOnly, detailed, off }

/// Same idea for the sending app, per account.
enum AccountAutoChannel { useDefault, sms, whatsapp, ask }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// The global settings of the automatic balance message ("إشعارات الرصيد التلقائية").
///
/// A text left empty means "use the built-in wording of the current language" — see
/// [AutoMessageTexts] in logic/messages/auto_message_builder.dart — so a person who never edits
/// anything still gets a complete, correctly translated message.
class AutoMessageSettings {
  const AutoMessageSettings({
    this.enabled = false,
    this.channel = AutoMessageChannel.ask,
    this.content = AutoMessageContent.balanceOnly,
    this.skipPreview = false,
    this.showDate = true,
    this.showAllCurrencies = true,
    this.minAmount = 0,
    this.intro = '',
    this.businessName = '',
    this.holderOwesText = '',
    this.owedToHolderText = '',
    this.totalHolderOwesText = '',
    this.totalOwedToHolderText = '',
    this.holderOwesNote = '',
    this.settledNote = '',
    this.detailsPrefix = '',
    this.footer = '',
  });

  /// Master switch: after saving an entry, offer to send the balance message.
  final bool enabled;
  final AutoMessageChannel channel;
  final AutoMessageContent content;

  /// `false` (default): show the message for a last look before sending. `true`: open the
  /// chosen app straight away with the message already written.
  final bool skipPreview;
  final bool showDate;

  /// Add the balance of every other currency the account has, not only the entry's currency.
  final bool showAllCurrencies;

  /// Entries below this amount do not trigger a message (0 = every entry does).
  final double minAmount;

  final String intro;
  final String businessName;
  final String holderOwesText;
  final String owedToHolderText;
  final String totalHolderOwesText;
  final String totalOwedToHolderText;
  final String holderOwesNote;
  final String settledNote;
  final String detailsPrefix;
  final String footer;

  AutoMessageSettings copyWith({
    bool? enabled,
    AutoMessageChannel? channel,
    AutoMessageContent? content,
    bool? skipPreview,
    bool? showDate,
    bool? showAllCurrencies,
    double? minAmount,
    String? intro,
    String? businessName,
    String? holderOwesText,
    String? owedToHolderText,
    String? totalHolderOwesText,
    String? totalOwedToHolderText,
    String? holderOwesNote,
    String? settledNote,
    String? detailsPrefix,
    String? footer,
  }) =>
      AutoMessageSettings(
        enabled: enabled ?? this.enabled,
        channel: channel ?? this.channel,
        content: content ?? this.content,
        skipPreview: skipPreview ?? this.skipPreview,
        showDate: showDate ?? this.showDate,
        showAllCurrencies: showAllCurrencies ?? this.showAllCurrencies,
        minAmount: minAmount ?? this.minAmount,
        intro: intro ?? this.intro,
        businessName: businessName ?? this.businessName,
        holderOwesText: holderOwesText ?? this.holderOwesText,
        owedToHolderText: owedToHolderText ?? this.owedToHolderText,
        totalHolderOwesText: totalHolderOwesText ?? this.totalHolderOwesText,
        totalOwedToHolderText: totalOwedToHolderText ?? this.totalOwedToHolderText,
        holderOwesNote: holderOwesNote ?? this.holderOwesNote,
        settledNote: settledNote ?? this.settledNote,
        detailsPrefix: detailsPrefix ?? this.detailsPrefix,
        footer: footer ?? this.footer,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'channel': channel.name,
        'content': content.name,
        'skipPreview': skipPreview,
        'showDate': showDate,
        'showAllCurrencies': showAllCurrencies,
        'minAmount': minAmount,
        'intro': intro,
        'businessName': businessName,
        'holderOwesText': holderOwesText,
        'owedToHolderText': owedToHolderText,
        'totalHolderOwesText': totalHolderOwesText,
        'totalOwedToHolderText': totalOwedToHolderText,
        'holderOwesNote': holderOwesNote,
        'settledNote': settledNote,
        'detailsPrefix': detailsPrefix,
        'footer': footer,
      };

  factory AutoMessageSettings.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] as String?) ?? '';
    final min = j['minAmount'];
    return AutoMessageSettings(
      enabled: j['enabled'] == true,
      channel: _enumByName(AutoMessageChannel.values, j['channel'], AutoMessageChannel.ask),
      content: _enumByName(AutoMessageContent.values, j['content'], AutoMessageContent.balanceOnly),
      skipPreview: j['skipPreview'] == true,
      showDate: j['showDate'] != false,
      showAllCurrencies: j['showAllCurrencies'] != false,
      minAmount: min is num && min >= 0 ? min.toDouble() : 0,
      intro: s('intro'),
      businessName: s('businessName'),
      holderOwesText: s('holderOwesText'),
      owedToHolderText: s('owedToHolderText'),
      totalHolderOwesText: s('totalHolderOwesText'),
      totalOwedToHolderText: s('totalOwedToHolderText'),
      holderOwesNote: s('holderOwesNote'),
      settledNote: s('settledNote'),
      detailsPrefix: s('detailsPrefix'),
      footer: s('footer'),
    );
  }
}

/// One account's override of the global settings.
class AccountAutoMessage {
  const AccountAutoMessage({this.mode = AccountAutoMode.useDefault, this.channel = AccountAutoChannel.useDefault});

  final AccountAutoMode mode;
  final AccountAutoChannel channel;

  bool get isDefault => mode == AccountAutoMode.useDefault && channel == AccountAutoChannel.useDefault;

  Map<String, dynamic> toJson() => {'mode': mode.name, 'channel': channel.name};

  factory AccountAutoMessage.fromJson(Map<String, dynamic> j) => AccountAutoMessage(
        mode: _enumByName(AccountAutoMode.values, j['mode'], AccountAutoMode.useDefault),
        channel: _enumByName(AccountAutoChannel.values, j['channel'], AccountAutoChannel.useDefault),
      );
}

/// What actually applies to one account once its override meets the global settings.
class EffectiveAutoMessage {
  const EffectiveAutoMessage({required this.active, required this.content, required this.channel});
  final bool active;
  final AutoMessageContent content;
  final AutoMessageChannel channel;
}

EffectiveAutoMessage resolveAutoMessage(AutoMessageSettings global, AccountAutoMessage? override) {
  final o = override ?? const AccountAutoMessage();
  final content = switch (o.mode) {
    AccountAutoMode.balanceOnly => AutoMessageContent.balanceOnly,
    AccountAutoMode.detailed => AutoMessageContent.detailed,
    _ => global.content,
  };
  final channel = switch (o.channel) {
    AccountAutoChannel.sms => AutoMessageChannel.sms,
    AccountAutoChannel.whatsapp => AutoMessageChannel.whatsapp,
    AccountAutoChannel.ask => AutoMessageChannel.ask,
    AccountAutoChannel.useDefault => global.channel,
  };
  // An account switched to balance-only/detailed is ON even when the master switch is off: that
  // is the point of choosing it for one account. Only "off" silences it.
  final active = switch (o.mode) {
    AccountAutoMode.off => false,
    AccountAutoMode.useDefault => global.enabled,
    _ => true,
  };
  return EffectiveAutoMessage(active: active, content: content, channel: channel);
}
